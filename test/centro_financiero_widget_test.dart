import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/screens/reports_screen.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/role_permissions.dart';
import 'package:novapos/services/session_service.dart';

/// Recorre las secciones del Centro Financiero con datos reales, en pantalla
/// de computador y de tablet, buscando errores de dibujo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DBHelper db;

  setUpAll(() async {
    await initializeDateFormatting('es_CO', null);
  });

  setUp(() async {
    db = DBHelper();
    await db.initMemoryDBForTesting();
    await SessionService.login({'id': 1, 'nombre': 'Ana', 'rol': 'ADMIN'});
    await PermissionService.loadPermissions(RolePermissions.permisosPara('ADMIN'));
  });

  tearDown(() async {
    final d = await db.database;
    await d.close();
    DBHelper.setDatabaseForTesting(null);
    await SessionService.logout();
    await PermissionService.clear();
  });

  Future<void> datos() async {
    final d = await db.database;
    await d.insert('usuarios', {'id': 1, 'usuario': 'ana', 'nombre_completo': 'Ana', 'rol': 'ADMIN', 'esta_activo': 1});
    await db.registrarMovimientoCaja('APERTURA', 50000, 'Base', 1);
    final p = await db.insertProduct(
        {'nombre': 'Papa pastusa', 'precio_costo': 1200, 'precio_venta': 2000, 'stock_actual': 100, 'categoria': 'Verduras'});
    final q = await db.insertProduct(
        {'nombre': 'Banano', 'precio_costo': 0, 'precio_venta': 1500, 'stock_actual': 100, 'categoria': 'Frutas'});
    for (final m in ['EFECTIVO', 'NEQUI', 'EFECTIVO']) {
      await db.registrarVenta(4000, m, [
        {'id': p, 'nombre': 'Papa pastusa', 'cantidad': 2, 'precio': 2000, 'subtotal': 4000, 'costo_unitario': 1200}
      ], usuarioId: 1);
    }
    final v = await db.registrarVenta(3000, 'EFECTIVO', [
      {'id': q, 'nombre': 'Banano', 'cantidad': 2, 'precio': 1500, 'subtotal': 3000, 'costo_unitario': 0}
    ], usuarioId: 1);
    await db.anularVenta(v['venta_id'] as int, usuarioId: 1, motivo: 'Prueba');
    await db.registrarMovimientoCaja('GASTO', 3000, 'Arriendo', 1, categoria: 'ARRIENDO');
    await db.registrarMerma(productoId: p, cantidad: 1, motivo: 'Daño', usuarioId: 1);
    final total = (await db.obtenerResumenCaja())['total_en_caja']!;
    await db.cerrarTurno(
        realContado: total - 500,
        fechaInicio: (await db.obtenerFechaAperturaActual())!, usuarioId: 1);
    // Un turno abierto, para "Cajas en vivo" y el Reporte Z parcial
    await db.registrarMovimientoCaja('APERTURA', 20000, 'Base', 1);
    await db.registrarVenta(6000, 'TRANSFERENCIA', [
      {'id': p, 'nombre': 'Papa pastusa', 'cantidad': 3, 'precio': 2000, 'subtotal': 6000, 'costo_unitario': 1200}
    ], usuarioId: 1);
  }

  const secciones = ['Panorama', 'Cajas en vivo', 'Resultados', 'Gastos y compras', 'Rentabilidad', 'Ventas', 'Control', 'Cierres de caja'];

  for (final tam in [const Size(1440, 900), const Size(800, 1280)]) {
    testWidgets('Todas las secciones se dibujan sin errores (${tam.width.toInt()}x${tam.height.toInt()})', (tester) async {
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(datos);
      await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));

      Future<void> esperar() async {
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 250));
        }
      }

      await esperar();
      Future<void> abrir(String s) async {
        // En tablet la barra de secciones se desliza de lado.
        final barra = find.byKey(const ValueKey('barra_secciones'));
        if (barra.evaluate().isEmpty) {
          await tester.tap(find.text(s).first); // menú lateral
          return;
        }
        final chip = find.widgetWithText(ChoiceChip, s);
        final desliza = find.descendant(of: barra, matching: find.byType(Scrollable));
        try {
          await tester.scrollUntilVisible(chip, 150, scrollable: desliza, maxScrolls: 20);
        } catch (_) {
          await tester.scrollUntilVisible(chip, -150, scrollable: desliza, maxScrolls: 20);
        }
        await tester.ensureVisible(chip);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(chip);
      }

      for (final s in secciones) {
        await abrir(s);
        await esperar();
        expect(tester.takeException(), isNull, reason: 'Sección $s');
        expect(find.textContaining('No se pudo cargar'), findsNothing, reason: 'Sección $s');
      }
      // Cajas en vivo: abrir el Reporte Z del turno (vista previa)
      await abrir('Cajas en vivo');
      await esperar();
      final verZ = find.text('Ver Reporte Z del turno');
      expect(verZ, findsOneWidget);
      await tester.ensureVisible(verZ);
      await tester.tap(verZ);
      await esperar();
      expect(find.textContaining('CIERRE DE CAJA - REPORTE Z'), findsOneWidget);
      await tester.tap(find.text('58 mm').last);
      await esperar();
      expect(tester.takeException(), isNull, reason: 'Vista previa del Reporte Z');
      await tester.tap(find.text('Cerrar').last);
      await esperar();
      // Cambiar el período y volver a Resultados
      await abrir('Resultados');
      await esperar();
      await tester.tap(find.text('30 días'));
      await esperar();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Ganancia').evaluate().isNotEmpty || find.textContaining('Pérdida').evaluate().isNotEmpty,
          isTrue);
    });
  }
}
