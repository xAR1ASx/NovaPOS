import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/screens/asistente_inicio_screen.dart';
import 'package:novapos/services/balanza_service.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/role_permissions.dart';
import 'package:novapos/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DBHelper db;

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

  Future<void> esperar(WidgetTester t) async {
    for (var i = 0; i < 15; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 80)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('El asistente guía los 5 pasos y guarda todo', (t) async {
    t.view.physicalSize = const Size(900, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    expect(await t.runAsync(AsistenteInicioScreen.debeMostrarse), isTrue);
    await t.pumpWidget(const MaterialApp(home: AsistenteInicioScreen(siguiente: Text('INICIO'))));
    await esperar(t);

    await t.tap(find.text('Empezar'));
    await esperar(t);
    // Sin nombre no deja seguir
    await t.tap(find.text('Siguiente'));
    await esperar(t);
    expect(find.textContaining('Escribe el nombre del negocio'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextField, 'Nombre del negocio *'), 'Fruver La Esperanza');
    await t.enterText(find.widgetWithText(TextField, 'Nombre de esta caja'), 'Caja 2');
    await t.tap(find.text('Siguiente'));
    await esperar(t);

    expect(find.text('¿Cómo pesas los productos?'), findsOneWidget);
    await t.tap(find.text('Escribo el peso a mano'));
    await t.tap(find.text('Siguiente'));
    await esperar(t);

    expect(find.text('Impresora de tickets'), findsOneWidget);
    await t.tap(find.text('Siguiente'));
    await esperar(t);

    expect(find.text('¡Listo para vender!'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('Ir a vender'));
    await esperar(t);
    expect(find.text('INICIO'), findsOneWidget);

    final cfg = (await t.runAsync(() => db.obtenerConfiguracion()))!;
    expect(cfg['empresa_nombre'], 'Fruver La Esperanza');
    expect(cfg['caja_nombre'], 'Caja 2');
    expect(cfg['balanza_modo'], BalanzaService.modoManual);
    expect(cfg['asistente_inicio_hecho'], '1');
    expect(await t.runAsync(AsistenteInicioScreen.debeMostrarse), isFalse);
  });

  testWidgets('A un cajero no se le muestra', (t) async {
    await SessionService.login({'id': 2, 'nombre': 'Juan', 'rol': 'CAJERO'});
    expect(await t.runAsync(AsistenteInicioScreen.debeMostrarse), isFalse);
  });
}
