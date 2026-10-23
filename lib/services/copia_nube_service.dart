import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../database/db_helper.dart';
import 'sync_service.dart';

/// Datos de la copia que está en la nube (documento respaldos/indice).
class InfoCopiaNube {
  final String copiaId;
  final int partes;
  final int bytes;
  final String sha256;
  final int fotoEpoch;
  final String cajaNombre;
  final String dispositivoUuid;
  final int versionBd;
  final bool multicaja;

  const InfoCopiaNube({
    required this.copiaId,
    required this.partes,
    required this.bytes,
    required this.sha256,
    required this.fotoEpoch,
    required this.cajaNombre,
    required this.dispositivoUuid,
    required this.versionBd,
    required this.multicaja,
  });

  DateTime get fecha => DateTime.fromMillisecondsSinceEpoch(fotoEpoch);

  static InfoCopiaNube? desde(Map<String, dynamic>? d) {
    if (d == null) return null;
    final id = (d['copia_id'] ?? '').toString();
    final partes = (d['partes'] as num?)?.toInt() ?? 0;
    if (id.isEmpty || partes <= 0) return null;
    var foto = (d['foto_epoch'] as num?)?.toInt() ?? 0;
    // La hora del servidor manda si el reloj de la caja estaba adelantado.
    final ts = d['creado_ts'];
    if (ts is Timestamp && (foto == 0 || ts.millisecondsSinceEpoch < foto)) {
      foto = ts.millisecondsSinceEpoch;
    }
    return InfoCopiaNube(
      copiaId: id,
      partes: partes,
      bytes: (d['bytes_comprimidos'] as num?)?.toInt() ?? 0,
      sha256: (d['sha256'] ?? '').toString(),
      fotoEpoch: foto,
      cajaNombre: (d['caja_nombre'] ?? '').toString(),
      dispositivoUuid: (d['dispositivo_uuid'] ?? '').toString(),
      versionBd: (d['version_bd'] as num?)?.toInt() ?? 0,
      multicaja: d['multicaja'] == true,
    );
  }
}

/// Copia diaria de la base del negocio en Firestore (plan gratuito).
///
/// Al cerrar caja la base se comprime y se sube en pedazos de ~900 KB (un
/// documento de Firestore admite 1 MB): son pocas escrituras al día en vez
/// de una por cada venta. En la nube queda solo la copia más reciente: los
/// pedazos de la anterior se borran cuando la nueva ya está completa, así
/// nunca hay un momento sin copia. Está en `negocios/<id>/respaldos`, y las
/// reglas de Firestore solo dejan leerla a los usuarios de ese negocio.
class CopiaNubeService {
  CopiaNubeService._()
      : _fInyectado = null,
        _carpetaInyectada = null,
        _tamParte = tamParte;

  /// Para pruebas: nube simulada, carpeta de trabajo propia y pedazos
  /// pequeños (para probar copias de varios pedazos con una base chica).
  @visibleForTesting
  CopiaNubeService.paraPruebas(FirebaseFirestore nube, Directory carpeta,
      {int tamanoParte = tamParte})
      : _fInyectado = nube,
        _carpetaInyectada = carpeta,
        _tamParte = tamanoParte;

  static final CopiaNubeService _instance = CopiaNubeService._();
  factory CopiaNubeService() => _instance;

  final FirebaseFirestore? _fInyectado;
  final Directory? _carpetaInyectada;
  final int _tamParte;
  FirebaseFirestore get _f => _fInyectado ?? FirebaseFirestore.instance;
  final DBHelper _db = DBHelper();

  /// Tamaño de cada pedazo (deja margen al límite de 1 MB por documento).
  static const int tamParte = 900 * 1024;

  /// ~45 MB comprimidos: una base de un solo negocio no llega a tanto.
  static const int maxPartes = 50;

  static const Duration _espera = Duration(seconds: 60);

  bool _enCurso = false;

  /// Avisa a la pantalla de ajustes cuando cambia el estado de la copia.
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);

  DocumentReference<Map<String, dynamic>> _indice(String negocioId) =>
      _f.collection('negocios').doc(negocioId).collection('respaldos').doc('indice');

  Future<Directory> _carpeta() async {
    if (_carpetaInyectada != null) return _carpetaInyectada;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(join(base.path, 'copia_nube_tmp'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String?> _negocio(String? negocioId) async {
    final nid = negocioId ?? SyncService().negocioId ??
        (await _db.obtenerConfiguracion())['sync_negocio_id'];
    return (nid == null || nid.isEmpty) ? null : nid;
  }

  /// Sube una copia nueva y, ya completa, borra la anterior. Devuelve null
  /// si todo salió bien o el mensaje del problema.
  Future<String?> subir({String motivo = 'manual', String? negocioId}) async {
    if (_enCurso) return 'Ya se está subiendo una copia';
    _enCurso = true;
    File? tmp;
    String? error;
    try {
      final nid = await _negocio(negocioId);
      if (nid == null) return error = 'Inicia sesión con internet para subir la copia';
      await _db.guardarConfiguracion('copia_nube_pendiente', '1');

      // Sin internet falla rápido aquí (y no deja pedazos a medio subir).
      final previo = await _indice(nid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      final anterior = InfoCopiaNube.desde(previo.data());

      final cfg = await _db.obtenerConfiguracion();
      final disp = await _db.obtenerDispositivoUuid();
      final aplicado = cfg['modo_sync_aplicado'] ?? SyncService.normalizarModo(cfg['modo_sync']);
      // La caja nueva que traiga esta copia puede sincronizar desde ella
      // solo si esta caja tiene la nube al día (varias cajas en vivo).
      final multicaja = aplicado == SyncService.modoMulticaja && cfg['sync_activo'] != '0';

      final fotoEpoch = DateTime.now().millisecondsSinceEpoch;
      tmp = File(join((await _carpeta()).path, 'novapos_copia_nube_$fotoEpoch.db'));
      if (!await _db.exportarCopiaParaNube(tmp.path)) {
        return error = 'No se pudo generar la copia de la base';
      }
      final crudo = await tmp.readAsBytes();
      final comprimido = Uint8List.fromList(gzip.encode(crudo));
      final partes = (comprimido.length / _tamParte).ceil();
      if (partes > maxPartes) {
        return error = 'La copia es demasiado grande para la nube (${(comprimido.length / 1048576).toStringAsFixed(1)} MB)';
      }
      final copiaId = '${fotoEpoch}_${disp.length >= 8 ? disp.substring(0, 8) : disp}';
      // Si se corta a mitad, la próxima vez se borran estos pedazos sueltos.
      await _db.guardarConfiguracion('copia_nube_intento', '$copiaId|$partes');

      final ref = _indice(nid);
      for (var i = 0; i < partes; i++) {
        final ini = i * _tamParte;
        final fin = min(ini + _tamParte, comprimido.length);
        await ref.collection('partes').doc('${copiaId}_$i').set({
          'copia_id': copiaId,
          'parte': i,
          'total': partes,
          'datos': Blob(Uint8List.sublistView(comprimido, ini, fin)),
        }).timeout(_espera);
      }
      // Solo con todos los pedazos arriba la copia nueva pasa a ser la vigente.
      await ref.set({
        'copia_id': copiaId,
        'partes': partes,
        'bytes': crudo.length,
        'bytes_comprimidos': comprimido.length,
        'sha256': sha256.convert(comprimido).toString(),
        'foto_epoch': fotoEpoch,
        'creado_ts': FieldValue.serverTimestamp(),
        'dispositivo_uuid': disp,
        'caja_nombre': (cfg['caja_nombre'] ?? '').toString(),
        'version_bd': DBHelper.versionBaseDatos,
        'multicaja': multicaja,
        'motivo': motivo,
      }).timeout(_espera);

      // Recién ahora se borra la copia anterior (y lo que haya quedado de
      // un intento cortado).
      final viejos = <String>{};
      if (anterior != null && anterior.copiaId != copiaId) {
        for (var i = 0; i < anterior.partes; i++) {
          viejos.add('${anterior.copiaId}_$i');
        }
      }
      // Un intento cortado y la copia anterior de esta misma caja (si otra
      // caja subió la suya al mismo tiempo, la nube no la dejaría borrar si
      // fuera la vigente).
      for (final clave in ['copia_nube_intento', 'copia_nube_mia']) {
        final previa = (cfg[clave] ?? '').split('|');
        if (previa.length == 2 && previa[0].isNotEmpty && previa[0] != copiaId) {
          for (var i = 0; i < (int.tryParse(previa[1]) ?? 0); i++) {
            viejos.add('${previa[0]}_$i');
          }
        }
      }
      for (final id in viejos) {
        try {
          await ref.collection('partes').doc(id).delete().timeout(_espera);
        } catch (e) {
          debugPrint('CopiaNube: no se borró $id: $e');
        }
      }

      await _db.guardarConfiguracion('copia_nube_intento', '');
      await _db.guardarConfiguracion('copia_nube_mia', '$copiaId|$partes');
      await _db.guardarConfiguracion('copia_nube_pendiente', '0');
      await _db.guardarConfiguracion('copia_nube_error', '');
      await _db.guardarConfiguracion('copia_nube_ultima', DateTime.now().toIso8601String());
      await _db.guardarConfiguracion('copia_nube_kb', (comprimido.length / 1024).toStringAsFixed(0));
      debugPrint('CopiaNube: subida $copiaId ($partes partes, ${comprimido.length} bytes)');
      return null;
    } catch (e) {
      debugPrint('CopiaNube: error al subir: $e');
      return error = _mensaje(e);
    } finally {
      if (error != null) {
        try {
          await _db.guardarConfiguracion('copia_nube_error', error);
        } catch (_) {}
      }
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } catch (_) {}
      _enCurso = false;
      cambios.value++;
    }
  }

  /// Si la última copia no se pudo subir (sin internet), se intenta otra vez.
  Future<void> reintentarSiQuedoPendiente() async {
    final cfg = await _db.obtenerConfiguracion();
    if (cfg['copia_nube_pendiente'] != '1') return;
    await subir(motivo: 'reintento');
  }

  /// La copia vigente del negocio, o null si no hay (o no hay internet).
  Future<InfoCopiaNube?> leerIndice(String negocioId) async {
    final doc = await _indice(negocioId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    return InfoCopiaNube.desde(doc.data());
  }

  /// Baja la copia, revisa que esté completa y sin daños, y la deja en un
  /// archivo temporal. Devuelve la ruta.
  Future<String> descargar(String negocioId, InfoCopiaNube info) async {
    final ref = _indice(negocioId);
    final datos = BytesBuilder(copy: false);
    for (var i = 0; i < info.partes; i++) {
      final p = await ref
          .collection('partes')
          .doc('${info.copiaId}_$i')
          .get(const GetOptions(source: Source.server))
          .timeout(_espera);
      final d = p.data();
      final blob = d?['datos'];
      if (d == null || d['copia_id'] != info.copiaId || blob is! Blob) {
        throw const CopiaNubeException('La copia de la nube está incompleta. Pide a la caja principal que suba una nueva (Ajustes → Copia en la nube).');
      }
      datos.add(blob.bytes);
    }
    final comprimido = datos.takeBytes();
    if (info.sha256.isNotEmpty && sha256.convert(comprimido).toString() != info.sha256) {
      throw const CopiaNubeException('La copia de la nube llegó dañada. Intenta otra vez.');
    }
    final List<int> crudo;
    try {
      crudo = gzip.decode(comprimido);
    } catch (_) {
      throw const CopiaNubeException('La copia de la nube llegó dañada. Intenta otra vez.');
    }
    final ruta = join((await _carpeta()).path, 'novapos_desde_nube_${info.copiaId}.db');
    await File(ruta).writeAsBytes(crudo, flush: true);
    if (!await _db.esCopiaValida(ruta)) {
      await File(ruta).delete();
      throw const CopiaNubeException('La copia de la nube no es una base válida de NovaPOS.');
    }
    return ruta;
  }

  /// Trae la copia de la nube a este equipo.
  ///
  /// [cajaNueva]: el equipo se suma como otra caja (varias cajas). Si es
  /// false, reemplaza a la caja de la copia (por ejemplo, el PC se dañó).
  /// La base que había queda guardada al lado ("..._antes_de_restaurar").
  Future<InfoCopiaNube> restaurar({
    required String negocioId,
    required bool cajaNueva,
    required String modoSync,
    String? nombreCaja,
  }) async {
    final info = await leerIndice(negocioId);
    if (info == null) {
      throw const CopiaNubeException('Este negocio todavía no tiene copia en la nube.');
    }
    if (info.versionBd > DBHelper.versionBaseDatos) {
      throw const CopiaNubeException('La copia es de una versión más nueva de NovaPOS. Actualiza este equipo e intenta otra vez.');
    }
    final ruta = await descargar(negocioId, info);
    try {
      await SyncService().detener();
      if (!await _db.restaurarBackup(ruta)) {
        throw const CopiaNubeException('No se pudo cargar la copia en este equipo.');
      }
      await _db.prepararCopiaRestaurada(
        cajaNueva: cajaNueva,
        copiaEpoch: info.fotoEpoch,
        modoSync: modoSync,
        nombreCaja: nombreCaja,
      );
    } finally {
      try {
        await File(ruta).delete();
      } catch (_) {}
    }
    cambios.value++;
    return info;
  }

  String _mensaje(Object e) {
    if (e is CopiaNubeException) return e.mensaje;
    final s = e.toString();
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'La nube no dejó guardar la copia (permisos). Contacta a soporte';
    }
    if (e is FirebaseException && e.code == 'resource-exhausted') {
      return 'Se acabó la cuota gratuita de hoy en la nube; se reintenta más tarde';
    }
    if (s.contains('TimeoutException') || s.contains('unavailable') || s.contains('network')) {
      return 'Sin conexión a internet; se reintenta más tarde';
    }
    return 'No se pudo subir la copia: $s';
  }
}

class CopiaNubeException implements Exception {
  final String mensaje;
  const CopiaNubeException(this.mensaje);
  @override
  String toString() => mensaje;
}
