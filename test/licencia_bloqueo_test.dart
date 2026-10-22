import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/license_monitor.dart';

/// Bloqueo por falta de pago cuando el equipo no tiene internet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DBHelper db;
  final lic = LicenseMonitor.instance;

  setUp(() async {
    db = DBHelper();
    await db.initMemoryDBForTesting();
  });

  tearDown(() async {
    final d = await db.database;
    await d.close();
    DBHelper.setDatabaseForTesting(null);
  });

  String haceHoras(int h) =>
      DateTime.now().subtract(Duration(hours: h)).millisecondsSinceEpoch.toString();

  test('Bloqueada en la nube: sigue bloqueada sin internet', () async {
    await db.guardarConfiguracion('licencia_bloqueada', '1');
    final r = await lic.revisarSinConexion();
    expect(r.estado, LicenciaEstado.bloqueada);
  });

  test('Licencia vencida: se bloquea sin internet', () async {
    await db.guardarConfiguracion('licencia_fin_iso', '2026-01-01');
    final r = await lic.revisarSinConexion();
    expect(r.estado, LicenciaEstado.vencida);
  });

  test('Financiado: 72 horas sin internet suspenden la caja', () async {
    await db.guardarConfiguracion('licencia_financiado', '1');
    await db.guardarConfiguracion('ultimo_sync_exitoso_epoch', haceHoras(73));
    expect((await lic.revisarSinConexion()).estado, LicenciaEstado.bloqueada);
    await db.guardarConfiguracion('ultimo_sync_exitoso_epoch', haceHoras(10));
    expect((await lic.revisarSinConexion()).estado, LicenciaEstado.ok);
  });

  test('Financiado: borrar la marca de conexión bloquea (no se puede saltar)', () async {
    await db.guardarConfiguracion('licencia_financiado', '1');
    final r = await lic.revisarSinConexion();
    expect(r.estado, LicenciaEstado.bloqueada);
  });

  test('Restablecer de fábrica no quita el bloqueo', () async {
    await db.guardarConfiguracion('licencia_bloqueada', '1');
    await db.guardarConfiguracion('licencia_financiado', '1');
    await db.guardarConfiguracion('ultimo_sync_exitoso_epoch', haceHoras(80));
    await db.resetFactory();
    expect((await lic.revisarSinConexion()).estado, LicenciaEstado.bloqueada);
  });

  test('Al día y con internet reciente: puede trabajar', () async {
    final fin = DateTime.now().add(const Duration(days: 30));
    await db.guardarConfiguracion('licencia_fin_iso',
        '${fin.year}-${fin.month.toString().padLeft(2, '0')}-${fin.day.toString().padLeft(2, '0')}');
    final r = await lic.revisarSinConexion();
    expect(r.estado, LicenciaEstado.ok);
    expect(r.diasRestantes, inInclusiveRange(29, 30));
  });
}
