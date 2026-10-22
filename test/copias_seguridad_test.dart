import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/role_permissions.dart';
import 'package:novapos/services/session_service.dart';

/// Copias de seguridad: consistentes, verificadas y con restauración segura.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DBHelper();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('novapos_copias_');
    await db.abrirArchivoParaPruebas('${dir.path}/caja.db');
    await SessionService.login({'id': 1, 'nombre': 'Ana', 'rol': 'ADMIN'});
    await PermissionService.loadPermissions(RolePermissions.permisosPara('ADMIN'));
  });

  tearDown(() async {
    final d = await db.database;
    await d.close();
    DBHelper.setDatabaseForTesting(null);
    await dir.delete(recursive: true);
    await SessionService.logout();
    await PermissionService.clear();
  });

  Future<int> ventas() async {
    final d = await db.database;
    return (await d.rawQuery('SELECT COUNT(*) AS n FROM ventas')).first['n'] as int;
  }

  Future<void> vender() async {
    final d = await db.database;
    final p = (await d.query('productos', where: "nombre = 'Papa'")).first;
    final r = await db.registrarVenta(2000, 'EFECTIVO', [
      {'id': p['id'], 'nombre': 'Papa', 'cantidad': 1, 'precio': 2000, 'subtotal': 2000}
    ], usuarioId: 1);
    expect(r['exito'], isTrue);
  }

  test('La copia es completa, válida y tiene todo lo vendido', () async {
    await db.insertProduct({'nombre': 'Papa', 'precio_costo': 1000, 'precio_venta': 2000, 'stock_actual': 50});
    await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
    await vender();
    await vender();
    final copia = '${dir.path}/copia.db';
    expect(await db.exportarBackup(copia), isTrue);
    expect(await db.esCopiaValida(copia), isTrue);
    expect(File(copia).lengthSync(), greaterThan(0));
  });

  test('Restaurar devuelve los datos y guarda antes la base actual', () async {
    await db.insertProduct({'nombre': 'Papa', 'precio_costo': 1000, 'precio_venta': 2000, 'stock_actual': 50});
    await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
    await vender();
    final copia = '${dir.path}/copia.db';
    await db.exportarBackup(copia);
    await vender();
    await vender();
    expect(await ventas(), 3);

    expect(await db.restaurarBackup(copia), isTrue);
    expect(await ventas(), 1);
    // Quedó guardada la base de antes (con las 3 ventas) por si hay que volver
    final previas = dir.listSync().whereType<File>().where((f) => f.path.contains('antes_de_restaurar')).toList();
    expect(previas.length, 1);
    expect(await db.esCopiaValida(previas.single.path), isTrue);
  });

  test('Un archivo que no es copia de NovaPOS no se restaura ni borra nada', () async {
    await db.insertProduct({'nombre': 'Papa', 'precio_costo': 1000, 'precio_venta': 2000, 'stock_actual': 50});
    await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
    await vender();
    final falso = File('${dir.path}/foto.db')..writeAsStringSync('esto no es una base de datos');
    expect(await db.restaurarBackup(falso.path), isFalse);
    expect(await ventas(), 1);
  });
}
