import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';
import 'cloudinary_service.dart';

class SyncEstado {
  final bool activo;
  final int pendientes;
  final String ultimaSincro;
  const SyncEstado({
    this.activo = false,
    this.pendientes = 0,
    this.ultimaSincro = '',
  });
}

/// Motor de sincronización entre cajas usando Firestore como almacén
/// central. Las cajas comparten productos/stock, ventas, compras, clientes,
/// cartera, devoluciones y, para los reportes, los movimientos y cierres de
/// caja. Cada cajón se cuadra solo con sus propios movimientos.
class SyncService {
  SyncService._() : _fInyectado = null;

  /// Para pruebas: una caja que sincroniza contra una nube simulada.
  @visibleForTesting
  SyncService.paraPruebas(FirebaseFirestore nube) : _fInyectado = nube;

  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;

  final FirebaseFirestore? _fInyectado;
  FirebaseFirestore get _f => _fInyectado ?? FirebaseFirestore.instance;
  final DBHelper _db = DBHelper();

  String? _negocioId;
  String? _usuarioUid;
  String _dispositivoUuid = '';
  bool _subiendo = false;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs =
      [];
  Timer? _timerImagenes;
  Timer? _timerAutoSync;
  Timer? _timerMantenimiento;

  /// Notificador reactivo para que pantallas abiertas (POS, Inventario) refresquen en tiempo real
  static final ValueNotifier<int> cambiosRemotosNotifier = ValueNotifier<int>(0);

  /// Imágenes locales que aún no se subieron a Storage (uuid|path).
  final Set<String> _imagenesPorSubir = {};

  /// Productos cuya imagen remota no se pudo descargar (uuid|url).
  final Set<String> _imagenesPorBajar = {};

  final ValueNotifier<SyncEstado> estado = ValueNotifier(
    const SyncEstado(),
  );

  String get dispositivoUuid => _dispositivoUuid;
  String? get negocioId => _negocioId;
  bool get activo => _negocioId != null;

  CollectionReference<Map<String, dynamic>> _col(String sub) {
    return _f.collection('negocios').doc(_negocioId!).collection(sub);
  }

  Future<void> iniciar({
    required String negocioId,
    required String usuarioUid,
  }) async {
    if (activo && _negocioId == negocioId && _usuarioUid == usuarioUid) {
      await _refrescarEstado();
      return;
    }
    await detener();
    _negocioId = negocioId;
    _usuarioUid = usuarioUid;
    _dispositivoUuid = await _db.obtenerDispositivoUuid();

    await _db.guardarConfiguracion('sync_negocio_id', negocioId);
    await _db.guardarConfiguracion('sync_usuario_uid', usuarioUid);

    final cfg = await _db.obtenerConfiguracion();
    if (cfg['sync_activo'] != '1') {
      await _precargarSiVacio();
      await _refrescarEstado();
      return;
    }

    try {
      final db = await _db.database;
      final cntRes = await db.rawQuery('SELECT COUNT(*) FROM productos');
      final nProds =
          (cntRes.isNotEmpty ? cntRes.first.values.first as num? : 0)?.toInt() ??
              0;
      if (nProds > 0) {
        await _db.prepararParaSincronizar(_dispositivoUuid);
        await _subirPendientes();
        await _reconciliarStockSiHaceFalta();
      } else {
        await _descargaInicial();
        // Negocio nuevo (la nube no tenía productos): arranca con el catálogo.
        if (await _precargarSiVacio()) cambiosRemotosNotifier.value++;
        await _subirPendientes();
      }
      await _instalarListeners();
      DBHelper.onDatoEncolado = () {
        unawaited(sincronizarAhora().catchError((e) {}));
      };
      _timerAutoSync = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _subirPendientes(),
      );
      _timerImagenes = Timer.periodic(
        const Duration(seconds: 45),
        (_) => _retrabajarImagenes(),
      );
      // Mantenimiento una vez al día, sin frenar el arranque.
      _timerMantenimiento = Timer(
        const Duration(minutes: 2),
        () => unawaited(mantenimiento().catchError((e) {
          debugPrint('SyncService mantenimiento: $e');
        })),
      );
      _refrescarEstado();
    } catch (e) {
      debugPrint('SyncService iniciar error: $e');
      // Sin internet en el primer uso: igual se puede trabajar con el
      // catálogo; al conectarse, la siembra no pisa lo que ya esté en la nube.
      await _precargarSiVacio();
      await _refrescarEstado();
      return;
    }
  }

  // ======================= MANTENIMIENTO =======================

  /// Los movimientos de stock solo sirven para avisar a las otras cajas; el
  /// total ya está en cada producto (stock_recon). Pasados estos días se
  /// borran de la nube para no llenar el espacio del plan gratuito.
  static const int diasMovimientosStock = 60;

  /// Una caja que estuvo más de estos días sin conectarse ya no puede
  /// confiar en los movimientos (algunos pudieron borrarse): toma el stock de
  /// cada producto directamente de la nube. Es menor que el borrado para
  /// dejar margen.
  static const int diasParaReconciliar = 45;

  static const Duration _cadaMantenimiento = Duration(hours: 20);

  /// Tras mucho tiempo sin conexión, el stock local se iguala al de la nube.
  Future<void> _reconciliarStockSiHaceFalta() async {
    await _cargarMarcas();
    final marca = _marcas['STOCK_OP'];
    if (marca == null) return;
    final dias = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(marca))
        .inDays;
    if (dias < diasParaReconciliar) return;
    await reconciliarStock();
  }

  /// Iguala el stock de cada producto al de la nube. Solo se hace si no
  /// quedan movimientos propios sin subir (si no, se perderían).
  @visibleForTesting
  Future<bool> reconciliarStock() async {
    final pendientes = (await _db.obtenerPendientes())
        .where((p) => p['tipo'] == 'STOCK_OP')
        .length;
    if (pendientes > 0) return false;
    final base = DateTime.now().millisecondsSinceEpoch;
    final productos = await _col('productos').get();
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final doc in productos.docs) {
        final recon = (doc.data()['stock_recon'] as num?)?.toDouble();
        if (recon == null) continue;
        await txn.rawUpdate(
          'UPDATE productos SET stock_actual = ? WHERE uuid = ?',
          [recon, doc.id],
        );
      }
    });
    // Lo anterior a este momento ya está en el stock de cada producto.
    _baseStockMs = base;
    await _db.guardarConfiguracion('sync_base_stock', base.toString());
    await _guardarMarca('STOCK_OP', base);
    cambiosRemotosNotifier.value++;
    return true;
  }

  /// Limpieza diaria: borra de la nube los movimientos de stock viejos y,
  /// en este equipo, los registros internos que ya no se necesitan.
  @visibleForTesting
  Future<Map<String, int>> mantenimiento({bool forzar = false}) async {
    final res = {'nube': 0, 'subidos': 0, 'aplicados': 0};
    if (!activo) return res;
    final cfg = await _db.obtenerConfiguracion();
    final ultima = int.tryParse(cfg['sync_mantenimiento_ms'] ?? '') ?? 0;
    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (!forzar && ahora - ultima < _cadaMantenimiento.inMilliseconds) return res;

    // 1. Nube: movimientos de stock de más de 60 días, por tandas pequeñas
    //    (cada borrado cuenta en la cuota diaria gratuita).
    final limite = ahora - const Duration(days: diasMovimientosStock).inMilliseconds;
    for (var tanda = 0; tanda < 10; tanda++) {
      final viejos = await _col('stock_ops')
          .where('fecha_epoch', isLessThan: limite)
          .limit(400)
          .get();
      if (viejos.docs.isEmpty) break;
      final batch = _f.batch();
      for (final d in viejos.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      res['nube'] = res['nube']! + viejos.docs.length;
      if (viejos.docs.length < 400) break;
    }

    // 2. Este equipo: lo que ya se subió hace más de 7 días.
    final db = await _db.database;
    final hace7 = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    res['subidos'] = await db.delete('sync_pendientes',
        where: 'estado = 1 AND creado_en < ?', whereArgs: [hace7]);

    // 3. Este equipo: marcas de movimientos de stock ya borrados de la nube
    //    (con margen extra; no se vuelven a leer porque la escucha es
    //    incremental).
    if (_marcas.containsKey('STOCK_OP')) {
      final limiteLocal = ahora - const Duration(days: diasMovimientosStock + 15).inMilliseconds;
      res['aplicados'] = await db.delete('sync_aplicados',
          where: "tipo = 'STOCK_OP' AND epoch > 0 AND epoch < ?", whereArgs: [limiteLocal]);
    }

    await _db.guardarConfiguracion('sync_mantenimiento_ms', ahora.toString());
    return res;
  }

  /// Precarga el catálogo maestro si este equipo no tiene productos.
  Future<bool> _precargarSiVacio() async {
    try {
      final db = await _db.database;
      final r = await db.rawQuery('SELECT COUNT(*) AS n FROM productos');
      if (((r.first['n'] as num?)?.toInt() ?? 0) > 0) return false;
      return await _db.precargarCatalogoMaestro(forzar: false) > 0;
    } catch (e) {
      debugPrint('SyncService precarga catálogo: $e');
      return false;
    }
  }

  Future<void> detener() async {
    DBHelper.onDatoEncolado = null;
    _timerAutoSync?.cancel();
    _timerAutoSync = null;
    _timerImagenes?.cancel();
    _timerImagenes = null;
    _timerMantenimiento?.cancel();
    _timerMantenimiento = null;
    _imagenesPorSubir.clear();
    _imagenesPorBajar.clear();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _negocioId = null;
    _usuarioUid = null;
    _dispositivoUuid = '';
    estado.value = const SyncEstado();
  }

  /// Colecciones que se escuchan y el tipo con que se aplican.
  static const Map<String, String> _colecciones = {
    'productos': 'PRODUCTO',
    'stock_ops': 'STOCK_OP',
    'clientes': 'CLIENTE',
    'ventas': 'VENTA',
    'compras': 'COMPRA',
    'cartera': 'CARTERA',
    'mermas': 'MERMA',
    'promociones': 'PROMOCION',
    'caja_movimientos': 'CAJA_MOV',
    'cierres': 'CIERRE',
    'devoluciones': 'DEVOLUCION',
  };

  /// Margen al retomar: lo de los últimos minutos se vuelve a leer (aplicar
  /// es idempotente), así un reloj un poco adelantado no hace perder nada.
  static const Duration _margenMarca = Duration(minutes: 30);

  /// Última marca de tiempo del servidor vista por colección (sync_ts).
  final Map<String, int> _marcas = {};

  /// Momento en que este equipo descargó los productos con su stock.
  int _baseStockMs = 0;

  Future<void> _cargarMarcas() async {
    final cfg = await _db.obtenerConfiguracion();
    _baseStockMs = int.tryParse(cfg['sync_base_stock'] ?? '') ?? 0;
    _marcas.clear();
    for (final tipo in _colecciones.values) {
      final v = int.tryParse(cfg['sync_marca_$tipo'] ?? '');
      if (v != null && v > 0) _marcas[tipo] = v;
    }
  }

  Future<void> _guardarMarca(String tipo, int ms) async {
    if (ms <= (_marcas[tipo] ?? 0)) return;
    _marcas[tipo] = ms;
    await _db.guardarConfiguracion('sync_marca_$tipo', ms.toString());
  }

  /// Después de una lectura completa: lo que venga desde ahora.
  Future<void> _marcarTodoDesdeAhora() async {
    final ahora = DateTime.now().millisecondsSinceEpoch;
    for (final tipo in _colecciones.values) {
      await _guardarMarca(tipo, ahora);
    }
  }

  /// Escucha solo lo que cambió desde la última vez (campo sync_ts que se
  /// escribe con la hora del servidor). Antes cada caja releía todo el
  /// historial del negocio al abrir: con meses de uso eso agotaba la cuota
  /// gratuita de Firestore en una sola apertura.
  Future<void> _instalarListeners() async {
    await _cargarMarcas();
    final sinMarca = _colecciones.values.any((t) => !_marcas.containsKey(t));
    for (final e in _colecciones.entries) {
      final tipo = e.value;
      final marca = _marcas[tipo];
      Query<Map<String, dynamic>> q = _col(e.key);
      if (marca != null) {
        final desde = marca - _margenMarca.inMilliseconds;
        q = q.where('sync_ts', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(desde));
      }
      _subs.add(q.snapshots().listen(
            (snap) => _procesarSnapshot(snap, tipo),
            onError: (e) => debugPrint('SyncService escucha $tipo: $e'),
          ));
    }
    // Equipo que ya tenía datos de antes de esta versión: la primera vez lee
    // todo (como antes) y desde ahí queda incremental.
    if (sinMarca) {
      unawaited(Future.delayed(const Duration(seconds: 20), () async {
        for (final tipo in _colecciones.values) {
          if (!_marcas.containsKey(tipo)) {
            await _guardarMarca(tipo, DateTime.now().millisecondsSinceEpoch);
          }
        }
      }));
    }
  }

  Future<void> _procesarSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
    String tipo,
  ) async {
    bool huboCambios = false;
    final cambios = List.of(snap.docChanges);
    if (tipo == 'PRODUCTO') {
      // Primero productos simples y luego combos, para que sus componentes existan.
      cambios.sort((a, b) {
        final ca = (a.doc.data()?['es_combo'] as num?)?.toInt() ?? 0;
        final cb = (b.doc.data()?['es_combo'] as num?)?.toInt() ?? 0;
        return ca.compareTo(cb);
      });
    }
    for (final dc in cambios) {
      if (dc.type == DocumentChangeType.removed) continue;
      try {
        switch (tipo) {
          case 'PRODUCTO':
            await _aplicarProducto(dc.doc);
            huboCambios = true;
            break;
          case 'STOCK_OP':
            await _aplicarStockOp(dc.doc);
            huboCambios = true;
            break;
          case 'VENTA':
            await _aplicarVenta(dc.doc);
            huboCambios = true;
            break;
          case 'COMPRA':
            await _aplicarCompra(dc.doc);
            huboCambios = true;
            break;
          case 'CLIENTE':
            await _aplicarCliente(dc.doc, bootstrap: false);
            huboCambios = true;
            break;
          case 'CARTERA':
            await _aplicarCartera(dc.doc, bootstrap: false);
            huboCambios = true;
            break;
          case 'MERMA':
            await _aplicarMerma(dc.doc);
            huboCambios = true;
            break;
          case 'PROMOCION':
            await _aplicarPromocion(dc.doc);
            huboCambios = true;
            break;
          case 'CAJA_MOV':
            huboCambios = await _aplicarMovCaja(dc.doc) || huboCambios;
            break;
          case 'CIERRE':
            huboCambios = await _aplicarCierre(dc.doc) || huboCambios;
            break;
          case 'DEVOLUCION':
            huboCambios = await _aplicarDevolucion(dc.doc) || huboCambios;
            break;
        }
      } catch (e) {
        debugPrint('SyncService aplicar $tipo: $e');
      }
    }
    int maxMarca = 0;
    for (final dc in cambios) {
      final ts = dc.doc.data()?['sync_ts'];
      if (ts is Timestamp && ts.millisecondsSinceEpoch > maxMarca) {
        maxMarca = ts.millisecondsSinceEpoch;
      }
    }
    if (maxMarca > 0) await _guardarMarca(tipo, maxMarca);
    if (huboCambios) {
      cambiosRemotosNotifier.value++;
    }
  }

  // ======================= DESCARGA INICIAL (equipo nuevo) =======================

  Future<void> _descargaInicial() async {
    _baseStockMs = DateTime.now().millisecondsSinceEpoch;
    await _db.guardarConfiguracion('sync_base_stock', _baseStockMs.toString());
    final productos = await _col('productos').get();
    final docsProd = List.of(productos.docs)
      ..sort((a, b) {
        final ca = (a.data()['es_combo'] as num?)?.toInt() ?? 0;
        final cb = (b.data()['es_combo'] as num?)?.toInt() ?? 0;
        return ca.compareTo(cb);
      });
    for (final doc in docsProd) {
      await _aplicarProducto(doc, bootstrap: true);
    }

    // Los movimientos de stock no se descargan: el stock de cada producto
    // ya los incluye (stock_recon). Desde aquí solo se escuchan los nuevos.
    await _guardarMarca('STOCK_OP', DateTime.now().millisecondsSinceEpoch);

    final clientes = await _col('clientes').get();
    for (final doc in clientes.docs) {
      await _aplicarCliente(doc, bootstrap: true);
    }

    final cartera = await _col('cartera').get();
    for (final doc in cartera.docs) {
      await _aplicarCartera(doc, bootstrap: true, soloInsertar: true);
    }

    final ventas = await _col('ventas').get();
    for (final doc in ventas.docs) {
      await _aplicarVenta(doc);
    }

    final compras = await _col('compras').get();
    for (final doc in compras.docs) {
      await _aplicarCompra(doc);
    }
    
    final mermas = await _col('mermas').get();
    for (final doc in mermas.docs) {
      await _aplicarMerma(doc);
    }
    
    final promos = await _col('promociones').get();
    for (final doc in promos.docs) {
      await _aplicarPromocion(doc);
    }

    // Historial financiero de las demás cajas (para los reportes).
    final movsCaja = await _col('caja_movimientos').get();
    for (final doc in movsCaja.docs) {
      await _aplicarMovCaja(doc);
    }
    final cierres = await _col('cierres').get();
    for (final doc in cierres.docs) {
      await _aplicarCierre(doc);
    }
    final devoluciones = await _col('devoluciones').get();
    for (final doc in devoluciones.docs) {
      await _aplicarDevolucion(doc);
    }
    await _marcarTodoDesdeAhora();
    
    cambiosRemotosNotifier.value++;
  }

  // ======================= APLICAR DOCUMENTOS REMOTOS =======================

  Future<void> _aplicarProducto(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool bootstrap = false,
  }) async {
    final data = doc.data();
    if (data == null) return;
    final uuid = doc.id;
    final epoch = (data['actualizado_epoch'] as num?)?.toInt() ?? 0;
    final aplicado = await _db.obtenerAplicado('PRODUCTO', uuid);
    final epochAplicado = (aplicado?['epoch'] as num?)?.toInt() ?? -1;
    if (aplicado != null && epoch <= epochAplicado && !bootstrap) return;

    final db = await _db.database;
    final existente = await db.query(
      'productos',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    final datos = <String, dynamic>{
      'nombre': data['nombre'],
      'codigo_barras': data['codigo_barras'],
      'codigo_plu': data['codigo_plu'],
      'categoria': data['categoria'],
      'precio_costo': data['precio_costo'],
      'precio_venta': data['precio_venta'],
      'es_pesable': data['es_pesable'] ?? 0,
      'es_combo': data['es_combo'] ?? 0,
      'esta_activo': data['esta_activo'] ?? 1,
    };
    final asset = (data['imagen_asset'] ?? '').toString();
    if (asset.startsWith('assets/') &&
        (existente.isEmpty || (existente.first['imagen_path'] ?? '').toString().isEmpty)) {
      datos['imagen_path'] = asset;
    }
    // Primera vez que este equipo recibe un producto creado o sembrado en
    // otra caja: su stock es el de la nube (el local era una copia sin uso,
    // por ejemplo el catálogo maestro con stock 0).
    final deOtraCaja = (data['dispositivo_uuid'] ?? '') != _dispositivoUuid;
    if (bootstrap || (aplicado == null && deOtraCaja && data['stock_recon'] != null)) {
      datos['stock_actual'] =
          ((data['stock_recon'] as num?)?.toDouble() ?? 0);
    }
    if (existente.isNotEmpty) {
      await db.update(
        'productos',
        datos,
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      await db.insert('productos', {
        ...datos,
        'uuid': uuid,
        'stock_actual':
            ((data['stock_recon'] as num?)?.toDouble() ?? 0),
      });
    }
    final idLocal = await _db.idProductoPorUuid(uuid);
    if (idLocal != null) {
      if (data['combo_componentes'] is List) {
        await _db.sincronizarComponentesCombo(idLocal, data['combo_componentes'] as List);
      }
      if (data['presentaciones'] is List) {
        await _db.sincronizarPresentaciones(idLocal, data['presentaciones'] as List);
      }
    }
    await _db.guardarAplicado('PRODUCTO', uuid, epoch);

    final url = (data['imagen_url'] ?? '').toString();
    if (url.isNotEmpty) {
      unawaited(_bajarImagenProducto(uuid, url));
    }
  }

  // ======================= IMÁGENES EN FIREBASE STORAGE =======================

  Future<Directory> _dirImagenesSync() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}imagenes_sync',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _subirImagen(String uuid, String path) async {
    // 1. Intentar subir primero vía Cloudinary (sin requerir tarjeta de crédito)
    try {
      final cloudUrl = await CloudinaryService().subirImagen(
        localPath: path,
        negocioId: _negocioId ?? 'general',
        productoUuid: uuid,
      );
      if (cloudUrl != null && cloudUrl.isNotEmpty) {
        return cloudUrl;
      }
    } catch (e) {
      debugPrint('Cloudinary upload fallback a Storage: $e');
    }

    // 2. Fallback a Firebase Storage si aplica
    final ext =
        (path.contains('.') ? path.split('.').last : 'jpg').toLowerCase();
    final ref = FirebaseStorage.instance
        .ref()
        .child('negocios/$_negocioId/productos/$uuid.$ext');
    await ref.putFile(File(path));
    return ref.getDownloadURL();
  }

  /// Descarga la imagen del producto al disco local y actualiza imagen_path.
  /// Si no se puede (sin internet) queda pendiente para reintentar.
  Future<void> _bajarImagenProducto(String uuid, String url) async {
    final db = await _db.database;
    final existente = await db.query(
      'productos',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (existente.isEmpty) return;
    final row = existente.first;
    final pathActual = (row['imagen_path'] ?? '').toString();
    final cfg = await _db.obtenerConfiguracion();
    final urlSync = (cfg['img_url_$uuid'] ?? '').toString();

    if (urlSync == url) return;

    // Imagen elegida localmente (no descargada aún): se conserva y se marca.
    if (urlSync.isEmpty &&
        pathActual.isNotEmpty &&
        (await File(pathActual).exists())) {
      await _db.guardarConfiguracion('img_url_$uuid', url);
      _imagenesPorBajar.remove('$uuid\u0000$url');
      return;
    }

    final dir = await _dirImagenesSync();
    final destino = '${dir.path}${Platform.pathSeparator}$uuid.jpg';
    try {
      Uint8List? bytes;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200) {
          bytes = resp.bodyBytes;
        } else {
          throw Exception('HTTP ${resp.statusCode}');
        }
      } else {
        bytes = await FirebaseStorage.instance
            .refFromURL(url)
            .getData(10 * 1024 * 1024);
      }
      if (bytes == null) throw Exception('Imagen vacia');
      await File(destino).writeAsBytes(bytes, flush: true);
      await db.rawUpdate(
        'UPDATE productos SET imagen_path = ? WHERE uuid = ?',
        [destino, uuid],
      );
      await _db.guardarConfiguracion('img_url_$uuid', url);
      _imagenesPorBajar.remove('$uuid\u0000$url');
    } catch (e) {
      _imagenesPorBajar.add('$uuid\u0000$url');
      debugPrint('SyncService imagen download $uuid: $e');
    }
  }

  /// Reintenta subir/descargar imágenes pendientes (corre cada 45 segundos).
  Future<void> _retrabajarImagenes() async {
    if (!activo) return;

    for (final item in _imagenesPorSubir.toList()) {
      final parts = item.split('\u0000');
      if (parts.length != 2) continue;
      final uuid = parts[0];
      final path = parts[1];
      try {
        if (await File(path).exists()) {
          final url = await _subirImagen(uuid, path);
          await _col('productos').doc(uuid).update({'imagen_url': url, 'sync_ts': FieldValue.serverTimestamp()});
        }
        _imagenesPorSubir.remove(item);
      } catch (e) {
        debugPrint('SyncService imagen retry upload $uuid: $e');
      }
    }

    for (final item in _imagenesPorBajar.toList()) {
      final parts = item.split('\u0000');
      if (parts.length != 2) continue;
      await _bajarImagenProducto(parts[0], parts[1]);
    }
  }

  Future<void> _aplicarStockOp(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;
    final uuid = doc.id;
    final aplicado = await _db.obtenerAplicado('STOCK_OP', uuid);
    if (aplicado != null) return;

    // Movimientos anteriores a la descarga inicial de este equipo ya vienen
    // sumados en el stock de cada producto: no se cuentan dos veces.
    final ts = data['sync_ts'];
    if (_baseStockMs > 0 && ts is Timestamp && ts.millisecondsSinceEpoch <= _baseStockMs) {
      await _db.guardarAplicado('STOCK_OP', uuid, (data['fecha_epoch'] as num?)?.toInt() ?? 0);
      return;
    }

    final productId = await _db.idProductoPorUuid(
      (data['producto_uuid'] ?? '').toString(),
    );
    final cantidad = (data['cantidad'] as num?)?.toDouble() ?? 0;
    if (productId != null && cantidad != 0) {
      final db = await _db.database;
      await db.rawUpdate(
        'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
        [cantidad, productId],
      );
    }
    await _db.guardarAplicado(
      'STOCK_OP',
      uuid,
      (data['fecha_epoch'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _aplicarVenta(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;
    final uuid = doc.id;
    final fechaEpoch = (data['fecha_epoch'] as num?)?.toInt() ?? 0;
    final actualizadoEpoch = (data['actualizado_epoch'] as num?)?.toInt() ?? 0;
    // Una devolución o anulación posterior cambia la versión de la venta.
    final epoch = actualizadoEpoch > fechaEpoch ? actualizadoEpoch : fechaEpoch;
    final aplicado = await _db.obtenerAplicado('VENTA', uuid);
    final epochAplicado = (aplicado?['epoch'] as num?)?.toInt() ?? -1;
    if (aplicado != null && epoch <= epochAplicado) {
      await _aplicarCambioAnulacion(data, uuid);
      return;
    }

    final db = await _db.database;
    final existente = await db.query(
      'ventas',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    final clienteId =
        await _db.idClientePorUuid((data['cliente_uuid'] ?? '').toString());
    final usuarioIdHelper =
        await _db.idUsuarioPorAuthUid((data['usuario_uid'] ?? '').toString());
    final anuladaPor = await _db
        .idUsuarioPorAuthUid((data['anulada_por_uid'] ?? '').toString());

    final datos = <String, dynamic>{
      'fecha': data['fecha'],
      'total': data['total'],
      'metodo_pago': data['metodo_pago'],
      'anulada': (data['anulada'] ?? 0) == 1 ? 1 : 0,
      'dispositivo_uuid': data['dispositivo_uuid'],
      'usuario_id': usuarioIdHelper ?? 0,
      'cliente_id': clienteId ?? 0,
      'metodo_pago_detalle': data['metodo_pago_detalle'],
      'efectivo_cobrado': data['efectivo_cobrado'],
      'anulada_en': data['anulada_en'],
      'anulada_por': anuladaPor,
      'motivo_anulacion': data['motivo_anulacion'],
      'actualizado_epoch': actualizadoEpoch,
    };
    final detalle = (data['detalle'] as List?) ?? [];
    await db.transaction((txn) async {
      int vId;
      if (existente.isNotEmpty) {
        vId = existente.first['id'] as int;
        if (datos['efectivo_cobrado'] == null) {
          datos.remove('efectivo_cobrado'); // no borrar el dato local
        }
        await txn.update('ventas', datos, where: 'id = ?', whereArgs: [vId]);
        // Solo una versión posterior trae cambios en las líneas.
        if (actualizadoEpoch == 0) return;
        await txn.delete('detalle_ventas', where: 'venta_id = ?', whereArgs: [vId]);
      } else {
        vId = await txn.insert('ventas', {...datos, 'uuid': uuid});
      }
      for (final item in detalle) {
        final pm = Map<String, dynamic>.from(item as Map);
        final res = await txn.query(
          'productos',
          columns: ['id'],
          where: 'uuid = ?',
          whereArgs: [(pm['producto_uuid'] ?? '').toString()],
          limit: 1,
        );
        await txn.insert('detalle_ventas', {
          'venta_id': vId,
          'producto_id': res.isEmpty ? null : res.first['id'],
          'nombre_producto': pm['nombre_producto'],
          'cantidad': pm['cantidad'],
          'cantidad_descontada': pm['cantidad_descontada'],
          'precio_unitario': pm['precio_unitario'],
          'costo_unitario': pm['costo_unitario'] ?? 0,
          'subtotal': pm['subtotal'],
        });
      }
    });
    await _db.guardarAplicado('VENTA', uuid, epoch);
  }

  /// Maneja la llegada tardía de una anulación de venta (solo cambia el estado).
  Future<void> _aplicarCambioAnulacion(
    Map<String, dynamic> data,
    String uuid,
  ) async {
    if ((data['anulada'] ?? 0) != 1) return;
    final vId = await _db.idVentaPorUuid(uuid);
    if (vId != null) {
      final db = await _db.database;
      await db.update(
        'ventas',
        {'anulada': 1},
        where: 'id = ?',
        whereArgs: [vId],
      );
    }
  }

  /// Movimiento de caja de otra caja: queda guardado con su dispositivo, así
  /// sirve a los reportes pero no entra al cuadre de este cajón.
  Future<bool> _aplicarMovCaja(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return false;
    if ((data['dispositivo_uuid'] ?? '') == _dispositivoUuid) return false;
    final db = await _db.database;
    final existe = await db.query('caja_movimientos',
        columns: ['id'], where: 'uuid = ?', whereArgs: [doc.id], limit: 1);
    if (existe.isNotEmpty) return false;
    await db.insert('caja_movimientos', {
      'uuid': doc.id,
      'fecha': data['fecha'],
      'tipo': data['tipo'],
      'monto': data['monto'],
      'descripcion': data['descripcion'],
      'categoria': data['categoria'],
      'resta_caja': data['resta_caja'] ?? 0,
      'venta_id':
          await _db.idVentaPorUuid((data['venta_uuid'] ?? '').toString()),
      'usuario_id': await _db
              .idUsuarioPorAuthUid((data['usuario_uid'] ?? '').toString()) ??
          0,
      'dispositivo_uuid': data['dispositivo_uuid'],
    });
    return true;
  }

  Future<bool> _aplicarCierre(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return false;
    if ((data['dispositivo_uuid'] ?? '') == _dispositivoUuid) return false;
    final db = await _db.database;
    final existe = await db.query('cierres_caja',
        columns: ['id'], where: 'uuid = ?', whereArgs: [doc.id], limit: 1);
    if (existe.isNotEmpty) return false;
    const campos = [
      'fecha', 'fecha_inicio', 'fecha_fin', 'base', 'ventas_turno',
      'ventas_turno_global', 'ingresos_turno', 'gastos_turno', 'total_sistema',
      'real_contado', 'diferencia', 'estado', 'detalle', 'dispositivo_uuid',
      'caja_nombre',
    ];
    await db.insert('cierres_caja', {
      for (final c in campos) c: data[c],
      'uuid': doc.id,
      'usuario_id': await _db
              .idUsuarioPorAuthUid((data['usuario_uid'] ?? '').toString()) ??
          0,
    });
    return true;
  }

  /// Registro de una devolución hecha en otra caja (para el reporte de
  /// control). El cambio en la venta llega con la venta misma.
  Future<bool> _aplicarDevolucion(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return false;
    final db = await _db.database;
    final existe = await db.query('devoluciones',
        columns: ['id'], where: 'uuid = ?', whereArgs: [doc.id], limit: 1);
    if (existe.isNotEmpty) return false;
    await db.insert('devoluciones', {
      'uuid': doc.id,
      'fecha': data['fecha'],
      'venta_id':
          await _db.idVentaPorUuid((data['venta_uuid'] ?? '').toString()),
      'producto_id':
          await _db.idProductoPorUuid((data['producto_uuid'] ?? '').toString()),
      'nombre_producto': data['nombre_producto'],
      'cantidad': data['cantidad'],
      'monto': data['monto'],
      'efectivo': data['efectivo'] ?? 0,
      'metodo_pago': data['metodo_pago'],
      'motivo': data['motivo'],
      'usuario_id': await _db
              .idUsuarioPorAuthUid((data['usuario_uid'] ?? '').toString()) ??
          0,
      'dispositivo_uuid': data['dispositivo_uuid'],
    });
    return true;
  }

  Future<void> _aplicarCliente(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool bootstrap = false,
  }) async {
    final data = doc.data();
    if (data == null) return;
    final uuid = doc.id;
    final epoch = (data['actualizado_epoch'] as num?)?.toInt() ?? 0;
    final aplicado = await _db.obtenerAplicado('CLIENTE', uuid);
    final epochAplicado = (aplicado?['epoch'] as num?)?.toInt() ?? -1;
    if (aplicado != null && epoch <= epochAplicado && !bootstrap) return;

    final db = await _db.database;
    final existente = await db.query(
      'clientes',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    final datos = <String, dynamic>{
      'nombre': data['nombre'],
      'telefono': data['telefono'],
      'direccion': data['direccion'],
      'cupo_credito': data['cupo_credito'] ?? 0,
      'esta_activo': data['esta_activo'] ?? 1,
    };
    if (bootstrap) {
      datos['deuda_actual'] =
          (data['deuda_actual'] as num?)?.toDouble() ?? 0;
    }
    if (existente.isNotEmpty) {
      if (bootstrap) {
        datos['deuda_actual'] =
            (data['deuda_actual'] as num?)?.toDouble() ?? 0;
      }
      await db.update(
        'clientes',
        datos,
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      await db.insert('clientes', {
        ...datos,
        'uuid': uuid,
        'deuda_actual':
            (data['deuda_actual'] as num?)?.toDouble() ?? 0,
      });
    }
    await _db.guardarAplicado('CLIENTE', uuid, epoch);
  }

  Future<void> _aplicarCompra(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;
    final uuid = doc.id;
    final epoch = (data['fecha_epoch'] as num?)?.toInt() ?? 0;
    final aplicado = await _db.obtenerAplicado('COMPRA', uuid);
    final epochAplicado = (aplicado?['epoch'] as num?)?.toInt() ?? -1;
    if (aplicado != null && epoch <= epochAplicado) return;

    final db = await _db.database;
    final existente = await db.query(
      'compras',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    final usuarioIdHelper =
        await _db.idUsuarioPorAuthUid((data['usuario_uid'] ?? '').toString());
    if (existente.isNotEmpty) {
      final cId = existente.first['id'] as int;
      await db.update(
        'compras',
        {
          'fecha': data['fecha'],
          'total': data['total'],
          'metodo_pago': data['metodo_pago'],
          'proveedor': data['proveedor'],
          'usuario_id': usuarioIdHelper ?? 0,
        },
        where: 'id = ?',
        whereArgs: [cId],
      );
    } else {
      final cId = await db.insert('compras', {
        'uuid': uuid,
        'fecha': data['fecha'],
        'total': data['total'],
        'metodo_pago': data['metodo_pago'],
        'proveedor': data['proveedor'],
        'usuario_id': usuarioIdHelper ?? 0,
      });
      final detalle = (data['detalle'] as List?) ?? [];
      for (final item in detalle) {
        final pm = item as Map<String, dynamic>;
        final pId = await _db.idProductoPorUuid(
          (pm['producto_uuid'] ?? '').toString(),
        );
        await db.insert('detalle_compras', {
          'compra_id': cId,
          'producto_id': pId,
          'nombre_producto': pm['nombre_producto'],
          'cantidad': pm['cantidad'],
          'costo_unitario': pm['costo_unitario'],
          'subtotal': pm['subtotal'],
        });
      }
    }
    await _db.guardarAplicado('COMPRA', uuid, epoch);
  }

  Future<void> _aplicarMerma(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    if (data == null) return;
    final uuid = doc.id;
    final db = await _db.database;

    final existe = await db.query(
      'mermas',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (existe.isNotEmpty) return;

    final pLocal =
        await _db.idProductoPorUuid((data['producto_uuid'] ?? '').toString());
    await db.insert('mermas', {
      'fecha': data['fecha'],
      'producto_id': pLocal ?? data['producto_id'],
      'producto_uuid': data['producto_uuid'],
      'nombre_producto': data['nombre_producto'],
      'cantidad': data['cantidad'],
      'costo_unitario': data['costo_unitario'],
      'total_perdida': data['total_perdida'],
      'motivo': data['motivo'],
      'usuario_id': data['usuario_id'],
      'uuid': uuid,
    });
  }

  Future<void> _aplicarPromocion(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    if (data == null) return;
    final uuid = doc.id;
    final epoch = (data['actualizado_epoch'] as num?)?.toInt() ?? 0;
    
    final aplicado = await _db.obtenerAplicado('PROMOCION', uuid);
    final epochAplicado = (aplicado?['epoch'] as num?)?.toInt() ?? -1;
    if (aplicado != null && epoch <= epochAplicado) return;

    final db = await _db.database;
    if ((data['eliminada'] ?? 0) == 1) {
      await db.delete('promociones', where: 'uuid = ?', whereArgs: [uuid]);
      await _db.guardarAplicado('PROMOCION', uuid, epoch);
      return;
    }
    final existe = await db.query('promociones', where: 'uuid = ?', whereArgs: [uuid], limit: 1);
    
    Map<String, dynamic> payload = Map.from(data);
    payload.remove('actualizado_epoch');
    payload.remove('dispositivo_uuid');
    payload.remove('sync_ts');
    payload.remove('eliminada');
    
    if (existe.isNotEmpty) {
      payload.remove('id'); // No actualizar el ID local
      await db.update('promociones', payload, where: 'uuid = ?', whereArgs: [uuid]);
    } else {
      payload.remove('id'); // Insertar para auto-generar
      payload['uuid'] = uuid;
      await db.insert('promociones', payload);
    }
    
    await _db.guardarAplicado('PROMOCION', uuid, epoch);
  }

  Future<void> _aplicarCartera(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool bootstrap = false,
    bool soloInsertar = false,
  }) async {
    final data = doc.data();
    if (data == null) return;
    final uuid = doc.id;
    final aplicado = await _db.obtenerAplicado('CARTERA', uuid);
    if (aplicado != null) return;

    final db = await _db.database;
    final clienteId = await _db.idClientePorUuid(
      (data['cliente_uuid'] ?? '').toString(),
    );
    final ventaId =
        await _db.idVentaPorUuid((data['venta_uuid'] ?? '').toString());
    final usuarioIdHelper =
        await _db.idUsuarioPorAuthUid((data['usuario_uid'] ?? '').toString());
    final monto = (data['monto'] as num?)?.toDouble() ?? 0;
    final deudaCambio = (data['deuda_cambio'] as num?)?.toDouble() ?? monto;
    final epoch = (data['fecha_epoch'] as num?)?.toInt() ?? 0;
    final fechaIso = epoch > 0
        ? DateTime.fromMillisecondsSinceEpoch(epoch).toIso8601String()
        : DateTime.now().toIso8601String();

    if (bootstrap && !soloInsertar) {
      await _db.guardarAplicado('CARTERA', uuid, epoch);
      return;
    }

    await db.insert('movimientos_cartera', {
      'cliente_id': clienteId,
      'tipo': data['tipo'],
      'venta_id': ventaId,
      'fecha': fechaIso,
      'monto': monto,
      'usuario_id': usuarioIdHelper ?? 0,
      'uuid': uuid,
    });
    if (!bootstrap) {
      if (clienteId != null && deudaCambio != 0) {
        await db.rawUpdate(
          'UPDATE clientes SET deuda_actual = deuda_actual + ? WHERE id = ?',
          [deudaCambio, clienteId],
        );
      }
    }
    await _db.guardarAplicado('CARTERA', uuid, epoch);
  }

  // ======================= SUBIDA DE PENDIENTES =======================

  Future<void> _subirPendientes() async {
    if (_subiendo || !activo) return;
    _subiendo = true;
    try {
      final pendientes = await _db.obtenerPendientes();
      for (final p in pendientes) {
        try {
          final ok = await _subirUno(p);
          if (ok) {
            await _db.marcarPendienteSubido(p['id'] as int);
          }
        } catch (e) {
          debugPrint('SyncService subir ${p['tipo']}: $e');
        }
      }
    } finally {
      _subiendo = false;
      await _refrescarEstado();
    }
  }

  Future<bool> _subirUno(Map<String, dynamic> pendiente) async {
    final tipo = pendiente['tipo'] as String;
    final uuid = pendiente['uuid'] as String;
    final datosRaw = pendiente['datos']?.toString() ?? '';
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(datosRaw.isEmpty ? '{}' : datosRaw)
          as Map<String, dynamic>;
    } catch (e) {
      return false;
    }

    switch (tipo) {
      case 'PRODUCTO':
        final payload = <String, dynamic>{
          'nombre': data['nombre'],
          'codigo_barras': data['codigo_barras'],
          'codigo_plu': data['codigo_plu'],
          'categoria': data['categoria'],
          'precio_costo': data['precio_costo'],
          'precio_venta': data['precio_venta'],
          'es_pesable': data['es_pesable'] ?? 0,
          'es_combo': data['es_combo'] ?? 0,
          'esta_activo': data['esta_activo'] ?? 1,
          'actualizado_epoch': data['actualizado_epoch'],
          'dispositivo_uuid': data['dispositivo_uuid'],
        };
        if (data.containsKey('stock_recon')) {
          payload['stock_recon'] = data['stock_recon'];
          payload['stock_recon_epoch'] = data['stock_recon_epoch'] ?? data['actualizado_epoch'] ?? 0;
        }
        // Componentes del combo y paquetes: viajan con el producto.
        if (data['combo_componentes'] != null) {
          payload['combo_componentes'] = data['combo_componentes'];
        }
        if (data['presentaciones'] != null) {
          payload['presentaciones'] = data['presentaciones'];
        }
        final imgLocal = (data['imagen_path_local'] ?? '').toString();
        // Las fotos del catálogo maestro vienen dentro de la app en todas las
        // cajas: no se suben (ahorra cuota de Cloudinary y tiempo); se indica
        // cuál es para que la otra caja la tome de sí misma.
        final esDelCatalogo = imgLocal.startsWith('assets/');
        if (esDelCatalogo) payload['imagen_asset'] = imgLocal;
        if (!esDelCatalogo && imgLocal.isNotEmpty && await File(imgLocal).exists()) {
          try {
            payload['imagen_url'] = await _subirImagen(uuid, imgLocal);
          } catch (e) {
            // Si falla, la meta se sube igual y la imagen queda en cola de retry.
            _imagenesPorSubir.add('$uuid\u0000$imgLocal');
            debugPrint('SyncService imagen upload $uuid: $e');
          }
        }
        payload['sync_ts'] = FieldValue.serverTimestamp();
        final esSemilla = data['semilla'] == true;
        if (!esSemilla && !payload.containsKey('stock_recon')) {
          await _col('productos').doc(uuid).set(payload, SetOptions(merge: true));
          return true;
        }
        await _f.runTransaction((tx) async {
          final ref = _col('productos').doc(uuid);
          final actual = await tx.get(ref);
          // Siembra (datos que el equipo tenía antes de sincronizar o
          // catálogo maestro): si el producto ya existe en la nube no se
          // pisa, así una caja nueva no reemplaza precios ni stock.
          if (esSemilla && actual.exists) return;
          // Ajuste absoluto de stock: solo si es más nuevo que el último que
          // tiene la nube (un reintento o una copia restaurada traen uno viejo
          // que borraría las ventas hechas después).
          final previo = (actual.data()?['stock_recon_epoch'] as num?)?.toInt() ?? 0;
          final este = (payload['stock_recon_epoch'] as num?)?.toInt() ?? 0;
          if (!actual.exists) {
            tx.set(ref, payload);
            return;
          }
          if (previo >= este) {
            payload.remove('stock_recon');
            payload.remove('stock_recon_epoch');
          }
          // update: solo cambia los campos enviados, nunca borra los demás.
          tx.update(ref, payload);
        });
        return true;

      case 'STOCK_OP':
        // En una transacción y solo si el movimiento no existe: si la
        // conexión se corta después de guardarlo y se reintenta (o se
        // restaura una copia), el stock de la nube no se suma dos veces.
        final op = data;
        final pu = (op['producto_uuid'] ?? '').toString();
        await _f.runTransaction((tx) async {
          final ref = _col('stock_ops').doc(uuid);
          if ((await tx.get(ref)).exists) return;
          tx.set(ref, {
            'producto_uuid': op['producto_uuid'],
            'cantidad': op['cantidad'],
            'fecha_epoch': op['fecha_epoch'],
            'dispositivo_uuid': op['dispositivo_uuid'],
            'sync_ts': FieldValue.serverTimestamp(),
          });
          if (pu.isNotEmpty) {
            tx.update(
              _col('productos').doc(pu),
              {'stock_recon': FieldValue.increment(op['cantidad'] ?? 0)},
            );
          }
        });
        return true;

      case 'VENTA':
        await _col('ventas').doc(uuid).set({...data, 'sync_ts': FieldValue.serverTimestamp()});
        return true;

      case 'MERMA':
        await _col('mermas').doc(uuid).set({...data, 'sync_ts': FieldValue.serverTimestamp()});
        return true;

      case 'VENTA_ANULA':
        await _col('ventas').doc(uuid).update({
          'anulada': 1,
          'actualizado_epoch': data['actualizado_epoch'],
          'sync_ts': FieldValue.serverTimestamp(),
          if (data['anulada_en'] != null) 'anulada_en': data['anulada_en'],
          if (data['anulada_por_uid'] != null)
            'anulada_por_uid': data['anulada_por_uid'],
          if (data['motivo_anulacion'] != null)
            'motivo_anulacion': data['motivo_anulacion'],
        });
        return true;

      case 'VENTA_ACTUALIZA':
        // update (no set): si la venta aún no subió, falla y se reintenta
        // después de ella, sin pisarla.
        await _col('ventas').doc(uuid).update({
          'total': data['total'],
          'metodo_pago_detalle': data['metodo_pago_detalle'],
          'detalle': data['detalle'],
          'actualizado_epoch': data['actualizado_epoch'],
          'sync_ts': FieldValue.serverTimestamp(),
        });
        return true;

      case 'DEVOLUCION':
        await _col('devoluciones').doc(uuid).set({...data, 'sync_ts': FieldValue.serverTimestamp()});
        return true;

      case 'CAJA_MOV':
        await _col('caja_movimientos').doc(uuid).set({...data, 'sync_ts': FieldValue.serverTimestamp()});
        return true;

      case 'CIERRE':
        await _col('cierres').doc(uuid).set({...data, 'sync_ts': FieldValue.serverTimestamp()});
        return true;

      case 'CLIENTE':
        final payload = <String, dynamic>{
          'uuid': uuid,
          'nombre': data['nombre'],
          'telefono': data['telefono'],
          'direccion': data['direccion'],
          'cupo_credito': data['cupo_credito'] ?? 0,
          'esta_activo': data['esta_activo'] ?? 1,
          'actualizado_epoch': data['actualizado_epoch'],
          'dispositivo_uuid': data['dispositivo_uuid'],
          'sync_ts': FieldValue.serverTimestamp(),
        };
        if (data['deuda_seed'] == true) {
          payload['deuda_actual'] = data['deuda_actual'];
        }
        await _col('clientes').doc(uuid).set(
              payload,
              SetOptions(merge: true),
            );
        return true;

      case 'CARTERA':
        // Igual que el stock: la deuda del cliente nunca se suma dos veces.
        final op = data;
        final cp = (op['cliente_uuid'] ?? '').toString();
        await _f.runTransaction((tx) async {
          final ref = _col('cartera').doc(uuid);
          if ((await tx.get(ref)).exists) return;
          tx.set(ref, {
            'cliente_uuid': op['cliente_uuid'],
            'tipo': op['tipo'],
            'monto': op['monto'],
            'deuda_cambio': op['deuda_cambio'],
            'venta_uuid': op['venta_uuid'],
            'fecha_epoch': op['fecha_epoch'],
            'usuario_uid': op['usuario_uid'],
            'dispositivo_uuid': op['dispositivo_uuid'],
            'sync_ts': FieldValue.serverTimestamp(),
          });
          if (op['sin_deuda'] != true && cp.isNotEmpty) {
            tx.update(_col('clientes').doc(cp), {
              'deuda_actual': FieldValue.increment(
                (op['deuda_cambio'] as num?)?.toDouble() ?? 0,
              ),
            });
          }
        });
        return true;

      case 'COMPRA':
        await _col('compras').doc(uuid).set({...data, 'sync_ts': FieldValue.serverTimestamp()});
        return true;

      case 'PROMOCION':
        await _col('promociones').doc(uuid).set({...data, 'sync_ts': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        return true;

      case 'PROMOCION_ELIMINAR':
        // Se marca y no se borra: un borrado no les llega a las otras cajas
        // (seguían aplicando la promoción eliminada).
        await _col('promociones').doc(uuid).set({
          'eliminada': 1,
          'esta_activa': 0,
          'actualizado_epoch': data['actualizado_epoch'],
          'sync_ts': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;

      default:
        return false;
    }
  }

  Future<void> sincronizarAhora() => _subirPendientes();

  Future<void> _refrescarEstado() async {
    try {
      final pendientes = await _db.obtenerPendientes();
      estado.value = SyncEstado(
        activo: activo,
        pendientes: pendientes.length,
        ultimaSincro:
            DateTime.now().toIso8601String(),
      );
    } catch (e) {
      estado.value = const SyncEstado();
    }
  }
}