import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../database/db_helper.dart';

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
/// central. Las cajas comparten productos/stock, ventas, compras, clientes
/// y cartera. La caja física (movimientos y cierres) queda local.
class SyncService {
  SyncService._();

  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;

  final FirebaseFirestore _f = FirebaseFirestore.instance;
  final DBHelper _db = DBHelper();

  String? _negocioId;
  String? _usuarioUid;
  String _dispositivoUuid = '';
  bool _subiendo = false;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs =
      [];
  Timer? _timerImagenes;

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
      } else {
        await _descargaInicial();
        await _subirPendientes();
      }
      await _instalarListeners();
      _timerImagenes = Timer.periodic(
        const Duration(seconds: 45),
        (_) => _retrabajarImagenes(),
      );
      _refrescarEstado();
    } catch (e) {
      debugPrint('SyncService iniciar error: $e');
      await _refrescarEstado();
      return;
    }
  }

  Future<void> detener() async {
    _timerImagenes?.cancel();
    _timerImagenes = null;
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

  Future<void> _instalarListeners() async {
    _subs.add(_col('productos').snapshots().listen(
          (s) => _procesarSnapshot(s, 'PRODUCTO'),
          onError: (e) {},
        ));
    _subs.add(_col('stock_ops').snapshots().listen(
          (s) => _procesarSnapshot(s, 'STOCK_OP'),
          onError: (e) {},
        ));
    _subs.add(_col('ventas').snapshots().listen(
          (s) => _procesarSnapshot(s, 'VENTA'),
          onError: (e) {},
        ));
    _subs.add(_col('compras').snapshots().listen(
          (s) => _procesarSnapshot(s, 'COMPRA'),
          onError: (e) {},
        ));
    _subs.add(_col('clientes').snapshots().listen(
          (s) => _procesarSnapshot(s, 'CLIENTE'),
          onError: (e) {},
        ));
    _subs.add(_col('cartera').snapshots().listen(
          (s) => _procesarSnapshot(s, 'CARTERA'),
          onError: (e) {},
        ));
  }

  void _procesarSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
    String tipo,
  ) {
    for (final dc in snap.docChanges) {
      if (dc.type == DocumentChangeType.removed) continue;
      try {
        switch (tipo) {
          case 'PRODUCTO':
            _aplicarProducto(dc.doc);
            break;
          case 'STOCK_OP':
            _aplicarStockOp(dc.doc);
            break;
          case 'VENTA':
            _aplicarVenta(dc.doc);
            break;
          case 'COMPRA':
            _aplicarCompra(dc.doc);
            break;
          case 'CLIENTE':
            _aplicarCliente(dc.doc, bootstrap: false);
            break;
          case 'CARTERA':
            _aplicarCartera(dc.doc, bootstrap: false);
            break;
        }
      } catch (e) {
        debugPrint('SyncService aplicar $tipo: $e');
      }
    }
  }

  // ======================= DESCARGA INICIAL (equipo nuevo) =======================

  Future<void> _descargaInicial() async {
    final productos = await _col('productos').get();
    for (final doc in productos.docs) {
      await _aplicarProducto(doc, bootstrap: true);
    }

    final stockOps = await _col('stock_ops').get();
    for (final doc in stockOps.docs) {
      final data = doc.data();
      await _db.guardarAplicado(
        'STOCK_OP',
        doc.id,
        (data['fecha_epoch'] as num?)?.toInt() ?? 0,
      );
    }

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
      'esta_activo': data['esta_activo'] ?? 1,
    };
    if (bootstrap) {
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
      final bytes = await FirebaseStorage.instance
          .refFromURL(url)
          .getData(10 * 1024 * 1024);
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
          await _col('productos').doc(uuid).update({'imagen_url': url});
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
    final epoch = (data['fecha_epoch'] as num?)?.toInt() ?? 0;
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

    if (existente.isNotEmpty) {
      final vId = existente.first['id'] as int;
      await db.update(
        'ventas',
        {
          'fecha': data['fecha'],
          'total': data['total'],
          'metodo_pago': data['metodo_pago'],
          'anulada': (data['anulada'] ?? 0) == 1 ? 1 : 0,
          'dispositivo_uuid': data['dispositivo_uuid'],
          'usuario_id': usuarioIdHelper ?? 0,
          'cliente_id': clienteId ?? 0,
        },
        where: 'id = ?',
        whereArgs: [vId],
      );
    } else {
      final vId = await db.insert('ventas', {
        'uuid': uuid,
        'fecha': data['fecha'],
        'total': data['total'],
        'metodo_pago': data['metodo_pago'],
        'usuario_id': usuarioIdHelper ?? 0,
        'cliente_id': clienteId ?? 0,
        'anulada': (data['anulada'] ?? 0) == 1 ? 1 : 0,
        'dispositivo_uuid': data['dispositivo_uuid'],
      });
      final detalle = (data['detalle'] as List?) ?? [];
      for (final item in detalle) {
        final pm = item as Map<String, dynamic>;
        final pId = await _db.idProductoPorUuid(
          (pm['producto_uuid'] ?? '').toString(),
        );
        await db.insert('detalle_ventas', {
          'venta_id': vId,
          'producto_id': pId,
          'nombre_producto': pm['nombre_producto'],
          'cantidad': pm['cantidad'],
          'cantidad_descontada': pm['cantidad_descontada'],
          'precio_unitario': pm['precio_unitario'],
          'costo_unitario': pm['costo_unitario'] ?? 0,
          'subtotal': pm['subtotal'],
        });
      }
    }
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
          'esta_activo': data['esta_activo'] ?? 1,
          'actualizado_epoch': data['actualizado_epoch'],
          'dispositivo_uuid': data['dispositivo_uuid'],
        };
        if (data.containsKey('stock_recon')) {
          payload['stock_recon'] = data['stock_recon'];
        }
        final imgLocal = (data['imagen_path_local'] ?? '').toString();
        if (imgLocal.isNotEmpty && await File(imgLocal).exists()) {
          try {
            payload['imagen_url'] = await _subirImagen(uuid, imgLocal);
          } catch (e) {
            // Si falla, la meta se sube igual y la imagen queda en cola de retry.
            _imagenesPorSubir.add('$uuid\u0000$imgLocal');
            debugPrint('SyncService imagen upload $uuid: $e');
          }
        }
        await _col('productos').doc(uuid).set(
              payload,
              SetOptions(merge: true),
            );
        return true;

      case 'STOCK_OP':
        final batch = _f.batch();
        batch.set(
          _col('stock_ops').doc(uuid),
          {
            'producto_uuid': data['producto_uuid'],
            'cantidad': data['cantidad'],
            'fecha_epoch': data['fecha_epoch'],
            'dispositivo_uuid': data['dispositivo_uuid'],
          },
        );
        final pu = (data['producto_uuid'] ?? '').toString();
        if (pu.isNotEmpty) {
          batch.update(
            _col('productos').doc(pu),
            {'stock_recon': FieldValue.increment(data['cantidad'] ?? 0)},
          );
        }
        await batch.commit();
        return true;

      case 'VENTA':
        await _col('ventas').doc(uuid).set(data);
        return true;

      case 'VENTA_ANULA':
        await _col('ventas').doc(uuid).update({
          'anulada': 1,
          'actualizado_epoch': data['actualizado_epoch'],
        });
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
        await _col('cartera').doc(uuid).set({
          'cliente_uuid': data['cliente_uuid'],
          'tipo': data['tipo'],
          'monto': data['monto'],
          'deuda_cambio': data['deuda_cambio'],
          'venta_uuid': data['venta_uuid'],
          'fecha_epoch': data['fecha_epoch'],
          'usuario_uid': data['usuario_uid'],
          'dispositivo_uuid': data['dispositivo_uuid'],
        });
        final cp = (data['cliente_uuid'] ?? '').toString();
        if (data['sin_deuda'] != true && cp.isNotEmpty) {
          await _col('clientes').doc(cp).update({
            'deuda_actual': FieldValue.increment(
              (data['deuda_cambio'] as num?)?.toDouble() ?? 0,
            ),
          });
        }
        return true;

      case 'COMPRA':
        await _col('compras').doc(uuid).set(data);
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