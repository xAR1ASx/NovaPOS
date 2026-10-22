import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../database/db_helper.dart';

/// Inicio de sesión sin internet para usuarios que ya entraron con internet
/// en este equipo. Se guarda una huella cifrada del PIN (con sal propia y
/// muchas vueltas de SHA-256), nunca el PIN.
class LoginOfflineService {
  LoginOfflineService._();

  /// Días que se puede entrar sin internet desde el último ingreso con
  /// internet. Después hay que conectarse (así un usuario desactivado o con
  /// PIN cambiado no sigue entrando para siempre).
  static const int diasMaximos = 7;
  static const int _vueltas = 20000;

  static String _clave(String email) => 'login_offline_${email.trim().toLowerCase()}';

  static String _huella(String pin, String sal) {
    final salBytes = utf8.encode(sal);
    List<int> h = utf8.encode('$sal:$pin');
    for (var i = 0; i < _vueltas; i++) {
      h = sha256.convert([...h, ...salBytes]).bytes;
    }
    return base64Encode(h);
  }

  static String _salNueva() {
    final r = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// Después de un ingreso con internet: guarda la huella y el perfil.
  static Future<void> recordar({
    required String email,
    required String pin,
    required Map<String, dynamic> perfil,
  }) async {
    final sal = _salNueva();
    await DBHelper().guardarConfiguracion(_clave(email), jsonEncode({
      'sal': sal,
      'huella': _huella(pin, sal),
      'ultimo_online_ms': DateTime.now().millisecondsSinceEpoch,
      'perfil': {
        'uid': perfil['uid'],
        'id': perfil['id'],
        'nombre': perfil['nombre'],
        'email': perfil['email'] ?? email.trim(),
        'rol': perfil['rol'],
        'negocio_id': perfil['negocio_id'],
        'esta_activo': perfil['esta_activo'],
      },
    }));
  }

  static Future<void> olvidar(String email) async {
    await DBHelper().guardarConfiguracion(_clave(email), '');
  }

  /// Resultado de intentar entrar sin internet.
  static Future<ResultadoOffline> entrar(String email, String pin) async {
    final cfg = await DBHelper().obtenerConfiguracion();
    final crudo = (cfg[_clave(email)] ?? '').trim();
    if (crudo.isEmpty) return const ResultadoOffline(ResultadoOffline.sinCredencial);
    Map<String, dynamic> datos;
    try {
      datos = Map<String, dynamic>.from(jsonDecode(crudo) as Map);
    } catch (_) {
      return const ResultadoOffline(ResultadoOffline.sinCredencial);
    }
    final ultimo = (datos['ultimo_online_ms'] as num?)?.toInt() ?? 0;
    final ahora = DateTime.now().millisecondsSinceEpoch;
    // Reloj atrasado (antes del último ingreso con internet) o demasiado
    // tiempo sin conexión: hay que conectarse.
    if (ahora < ultimo || ahora - ultimo > const Duration(days: diasMaximos).inMilliseconds) {
      return const ResultadoOffline(ResultadoOffline.vencido);
    }
    if (_huella(pin, (datos['sal'] ?? '').toString()) != datos['huella']) {
      return const ResultadoOffline(ResultadoOffline.pinIncorrecto);
    }
    final perfil = Map<String, dynamic>.from(datos['perfil'] as Map);
    perfil['offline'] = true;
    return ResultadoOffline(ResultadoOffline.ok, perfil: perfil);
  }
}

class ResultadoOffline {
  static const ok = 'OK';
  static const sinCredencial = 'SIN_CREDENCIAL';
  static const vencido = 'VENCIDO';
  static const pinIncorrecto = 'PIN';

  final String codigo;
  final Map<String, dynamic>? perfil;
  const ResultadoOffline(this.codigo, {this.perfil});
}
