import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/license_monitor.dart';
import 'package:novapos/services/login_offline_service.dart';

/// Inicio de sesión sin internet con la huella del PIN guardada en el equipo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DBHelper();
  const email = 'Cajero@Fruver.com';
  final perfil = {'uid': 'u1', 'id': 3, 'nombre': 'Juan', 'rol': 'CAJERO', 'negocio_id': 'n1', 'esta_activo': true};

  setUp(() async => db.initMemoryDBForTesting());
  tearDown(() async {
    await (await db.database).close();
    DBHelper.setDatabaseForTesting(null);
  });

  test('Con el PIN correcto entra sin internet y devuelve su perfil', () async {
    await LoginOfflineService.recordar(email: email, pin: '481537', perfil: perfil);
    final r = await LoginOfflineService.entrar('cajero@fruver.com', '481537');
    expect(r.codigo, ResultadoOffline.ok);
    expect(r.perfil!['rol'], 'CAJERO');
    expect(r.perfil!['negocio_id'], 'n1');
    expect(r.perfil!['offline'], isTrue);
  });

  test('PIN incorrecto no entra', () async {
    await LoginOfflineService.recordar(email: email, pin: '481537', perfil: perfil);
    expect((await LoginOfflineService.entrar(email, '481538')).codigo, ResultadoOffline.pinIncorrecto);
  });

  test('El PIN nunca se guarda en texto', () async {
    await LoginOfflineService.recordar(email: email, pin: '481537', perfil: perfil);
    final cfg = await db.obtenerConfiguracion();
    final guardado = cfg.values.join('|');
    expect(guardado.contains('481537'), isFalse);
  });

  test('Quien nunca entró con internet en este equipo no puede entrar sin internet', () async {
    expect((await LoginOfflineService.entrar('otro@fruver.com', '481537')).codigo, ResultadoOffline.sinCredencial);
  });

  test('Más de 7 días sin internet o reloj atrasado: pide conexión', () async {
    await LoginOfflineService.recordar(email: email, pin: '481537', perfil: perfil);
    final clave = 'login_offline_${email.toLowerCase()}';
    final datos = jsonDecode((await db.obtenerConfiguracion())[clave]!) as Map<String, dynamic>;
    datos['ultimo_online_ms'] = DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch;
    await db.guardarConfiguracion(clave, jsonEncode(datos));
    expect((await LoginOfflineService.entrar(email, '481537')).codigo, ResultadoOffline.vencido);
    datos['ultimo_online_ms'] = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
    await db.guardarConfiguracion(clave, jsonEncode(datos));
    expect((await LoginOfflineService.entrar(email, '481537')).codigo, ResultadoOffline.vencido);
  });

  test('Olvidar (usuario desactivado) y restablecer de fábrica quitan el acceso', () async {
    await LoginOfflineService.recordar(email: email, pin: '481537', perfil: perfil);
    await LoginOfflineService.olvidar(email);
    expect((await LoginOfflineService.entrar(email, '481537')).codigo, ResultadoOffline.sinCredencial);
    await LoginOfflineService.recordar(email: email, pin: '481537', perfil: perfil);
    await db.resetFactory();
    expect((await LoginOfflineService.entrar(email, '481537')).codigo, ResultadoOffline.sinCredencial);
  });

  test('Sin internet la licencia guardada se sigue respetando', () async {
    await LoginOfflineService.recordar(email: email, pin: '481537', perfil: perfil);
    await db.guardarConfiguracion('licencia_bloqueada', '1');
    expect((await LoginOfflineService.entrar(email, '481537')).codigo, ResultadoOffline.ok);
    // La pantalla de entrada revisa la licencia después: queda bloqueada
    expect((await LicenseMonitor.instance.revisarSinConexion()).estado, LicenciaEstado.bloqueada);
  });
}
