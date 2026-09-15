import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../screens/licencia_bloqueo_screen.dart';
import 'pin_auth_service.dart';
import 'sync_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

enum LicenciaEstado { ok, vencida, bloqueada }

class LicenciaResult {
  final LicenciaEstado estado;
  final int diasRestantes; // -1 = indefinida
  final String? mensaje;
  final bool online;
  const LicenciaResult({
    required this.estado,
    this.diasRestantes = -1,
    this.mensaje,
    this.online = true,
  });

  bool get valida => estado == LicenciaEstado.ok;
  bool get indefinida => diasRestantes < 0;
}

/// Valida la licencia en la nube cada intervalo y, si no hay internet,
/// hace el conteo local de los días restantes guardados en el dispositivo.
class LicenseMonitor {
  LicenseMonitor._internal();
  static final LicenseMonitor instance = LicenseMonitor._internal();
  static LicenseMonitor call() => instance;

  final ValueNotifier<LicenciaResult?> info =
      ValueNotifier<LicenciaResult?>(null);

  Timer? _timer;
  String? _negocioId;
  bool _bloqueado = false;

  static const List<int> _avisoDias = [15, 7, 3, 1, 0];

  String? get negocioId => _negocioId;

  static String _fechaKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Guarda en el dispositivo (config) el estado de licencia obtenido en la
  /// nube, dejando el conteo local listo para usarse sin internet.
  Future<void> guardarCacheLocal(String negocioId) async {
    try {
      final r = await _verificarNube(negocioId)
          .timeout(const Duration(seconds: 8));
      info.value = r;
    } catch (_) {
      info.value = await _verificarLocal();
    }
  }

  Future<void> iniciar(String negocioId) async {
    await detener();
    _negocioId = negocioId;
    _bloqueado = false;
    await _comprobar();
    _timer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _comprobar(),
    );
  }

  Future<void> detener() async {
    _timer?.cancel();
    _timer = null;
  }

  /// Revisa la licencia: primero en la nube (con timeout) y, si falla,
  /// usa el conteo local guardado (funciona sin internet).
  Future<LicenciaResult> revisar(String negocioId) async {
    try {
      return await _verificarNube(negocioId)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return _verificarLocal();
    }
  }

  Future<LicenciaResult> _verificarNube(String negocioId) async {
    final doc = await FirebaseFirestore.instance
        .collection('negocios')
        .doc(negocioId)
        .get();
    if (!doc.exists) {
      return const LicenciaResult(
        estado: LicenciaEstado.vencida,
        diasRestantes: 0,
        mensaje: 'Negocio no encontrado',
      );
    }
    final data = doc.data() ?? {};
    await _guardarCache(data);
    final estado = (data['estado'] ?? '').toString();
    if (estado == 'bloqueada') {
      return const LicenciaResult(
        estado: LicenciaEstado.bloqueada,
        diasRestantes: 0,
        mensaje: 'Licencia bloqueada. Contacte al administrador.',
      );
    }
    final fin = data['licencia_fin'];
    if (fin == null) {
      return const LicenciaResult(
        estado: LicenciaEstado.ok,
        diasRestantes: -1,
      );
    }
    final fechaFin =
        fin is Timestamp ? fin.toDate() : DateTime.parse(fin.toString());

    // Ancora el reloj al servidor: escribe un timestamp de Firestore (ServerTimestamp)
    // y lo relee del servidor, guardando el desfase con el reloj local.
    final serverNow = await _servidorAhora(negocioId);
    if (serverNow != null) {
      await DBHelper().guardarConfiguracion(
        'licencia_off_ms',
        serverNow.difference(DateTime.now()).inMilliseconds.toString(),
      );
      return _resultadoDesdeFecha(fechaFin, ahora: serverNow);
    }
    return _resultadoDesdeFecha(fechaFin);
  }

  /// Obtiene la hora real del servidor de Firestore para anclar el reloj local.
  Future<DateTime?> _servidorAhora(String negocioId) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('negocios')
          .doc(negocioId);
      await ref.set(
        {'licencia_sync': FieldValue.serverTimestamp()},
        SetOptions(mergeFields: ['licencia_sync']),
      );
      final snap = await ref.get(GetOptions(source: Source.server));
      final v = snap.data()?['licencia_sync'];
      return v is Timestamp ? v.toDate() : null;
    } catch (_) {
      return null;
    }
  }

  LicenciaResult _resultadoDesdeFecha(
    DateTime fechaFin, {
    DateTime? ahora,
  }) {
    final ref = ahora ?? DateTime.now();
    final a = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
    final b = DateTime(ref.year, ref.month, ref.day);
    final dias = a.difference(b).inDays;
    if (dias < 0) {
      return const LicenciaResult(
        estado: LicenciaEstado.vencida,
        diasRestantes: 0,
        mensaje: 'Tu licencia de NovaPOS ha vencido. Renueva para continuar.',
      );
    }
    return LicenciaResult(estado: LicenciaEstado.ok, diasRestantes: dias);
  }

  DateTime _ahoraCorregido(Map<String, dynamic> cfg) {
    final offMs =
        int.tryParse((cfg['licencia_off_ms'] ?? '0').toString()) ?? 0;
    return DateTime.now().add(Duration(milliseconds: offMs));
  }

  Future<LicenciaResult> _verificarLocal() async {
    final cfg = await DBHelper().obtenerConfiguracion();
    if ((cfg['licencia_bloqueada'] ?? '').toString() == '1') {
      return const LicenciaResult(
        estado: LicenciaEstado.bloqueada,
        diasRestantes: 0,
        mensaje: 'Licencia bloqueada. Contacte al administrador.',
        online: false,
      );
    }
    final iso = (cfg['licencia_fin_iso'] ?? '').toString();
    if (iso.isEmpty) {
      return const LicenciaResult(
        estado: LicenciaEstado.ok,
        diasRestantes: -1,
        online: false,
      );
    }
    final fechaFin = DateTime.tryParse(iso);
    if (fechaFin == null) {
      return const LicenciaResult(
        estado: LicenciaEstado.ok,
        diasRestantes: -1,
        online: false,
      );
    }
    final r = _resultadoDesdeFecha(
      fechaFin,
      ahora: _ahoraCorregido(cfg),
    );
    return LicenciaResult(
      estado: r.estado,
      diasRestantes: r.diasRestantes,
      mensaje: r.mensaje,
      online: false,
    );
  }

  Future<void> _guardarCache(Map<String, dynamic> data) async {
    final db = DBHelper();
    final fin = data['licencia_fin'];
    var iso = '';
    if (fin != null) {
      final f = fin is Timestamp
          ? fin.toDate()
          : DateTime.tryParse(fin.toString());
      if (f != null) iso = _fechaKey(f);
    }
    await db.guardarConfiguracion('licencia_fin_iso', iso);
    await db.guardarConfiguracion(
      'licencia_bloqueada',
      ((data['estado'] ?? '').toString() == 'bloqueada') ? '1' : '0',
    );
  }

  Future<void> _comprobar() async {
    final nid = _negocioId;
    if (nid == null) return;

    // Detecta manipulación del reloj: si la hora corregida retrocede más de
    // 4 horas respecto a la última vista guardada, se bloquea.
    final db = DBHelper();
    final cfg = await db.obtenerConfiguracion();
    final nowT = _ahoraCorregido(cfg);
    final prevS = (cfg['licencia_ultima_vista'] ?? '').toString();
    final prev = DateTime.tryParse(prevS);
    if (prev != null &&
        nowT.isBefore(prev.subtract(const Duration(hours: 4)))) {
      info.value = const LicenciaResult(
        estado: LicenciaEstado.bloqueada,
        diasRestantes: 0,
        mensaje:
            'El reloj del sistema fue modificado. Conecta el equipo a internet para verificar la licencia.',
        online: false,
      );
      await _bloquear(
        'El reloj del sistema fue modificado. Conecta el equipo a internet para verificar la licencia.',
      );
      return;
    }
    await db.guardarConfiguracion(
      'licencia_ultima_vista',
      nowT.toIso8601String(),
    );

    final r = await revisar(nid);
    info.value = r;
    if (!r.valida) {
      await _bloquear(r.mensaje ?? 'Licencia no valida');
      return;
    }
    await _avisarVencimiento(r);
  }

  Future<void> _avisarVencimiento(LicenciaResult r) async {
    if (r.indefinida) return;
    final db = DBHelper();
    final hoy = DateTime.now();
    final key = _fechaKey(hoy);
    final cfg = await db.obtenerConfiguracion();
    if ((cfg['licencia_aviso_dia'] ?? '').toString() == key) return;
    if (!_avisoDias.contains(r.diasRestantes)) return;

    await db.guardarConfiguracion('licencia_aviso_dia', key);

    final ctx = appNavigatorKey.currentState?.overlay?.context ??
        appNavigatorKey.currentContext;
    if (ctx == null) return;
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.event_busy, color: Colors.orange, size: 40),
        title: Text(
          r.diasRestantes == 0
              ? 'Tu licencia vence HOY'
              : 'Tu licencia vence en ${r.diasRestantes} días',
        ),
        content: const Text(
          'Renueva tu licencia para que el sistema no se bloquee al vencer. '
          'Incluso sin internet, el conteo local de días continuará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _bloquear(String mensaje) async {
    if (_bloqueado) return;
    _bloqueado = true;
    await detener();
    try {
      await PinAuthService.cerrarSesion();
    } catch (_) {}
    try {
      await SyncService().detener();
    } catch (_) {}
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LicenciaBloqueoScreen(mensaje: mensaje),
      ),
      (route) => false,
    );
  }
}