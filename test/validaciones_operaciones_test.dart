import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/role_permissions.dart';
import 'package:novapos/services/session_service.dart';

/// Regresión de la auditoría de Antigravity (1.8.1): la base rechaza ventas,
/// mermas y compras con datos imposibles, aunque la pantalla los mande.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DBHelper();
  late Directory dir;
  late int papa;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('novapos_validaciones_');
    await db.abrirArchivoParaPruebas('${dir.path}/caja.db');
    await SessionService.login({'id': 1, 'nombre': 'Ana', 'rol': 'ADMIN'});
    await PermissionService.loadPermissions(RolePermissions.permisosPara('ADMIN'));
    papa = await db.insertProduct({'nombre': 'Papa', 'precio_costo': 1000, 'precio_venta': 2000, 'stock_actual': 10});
    await db.registrarMovimientoCaja('APERTURA', 50000, 'Base', 1);
  });

  tearDown(() async {
    final d = await db.database;
    await d.close();
    DBHelper.setDatabaseForTesting(null);
    await dir.delete(recursive: true);
    await SessionService.logout();
    await PermissionService.clear();
  });

  Future<double> stock() async {
    final d = await db.database;
    return ((await d.query('productos', where: 'id = ?', whereArgs: [papa])).single['stock_actual'] as num).toDouble();
  }

  Future<double> enCaja() async => (await db.obtenerResumenCaja())['total_en_caja']!;

  Future<int> contar(String tabla) async {
    final d = await db.database;
    return (await d.rawQuery('SELECT COUNT(*) AS n FROM $tabla')).first['n'] as int;
  }

  Map<String, dynamic> linea(num cantidad, {num precio = 2000, num? subtotal}) => {
        'id': papa,
        'nombre': 'Papa',
        'cantidad': cantidad,
        'precio': precio,
        'subtotal': subtotal ?? cantidad * precio,
        'costo_unitario': 1000,
      };

  group('Venta (hallazgos 1 y 4)', () {
    Future<void> rechazada(double total, List<Map<String, dynamic>> items, String contiene) async {
      final cajaAntes = await enCaja();
      final r = await db.registrarVenta(total, 'EFECTIVO', items, usuarioId: 1);
      expect(r['exito'], isFalse);
      expect(r['mensaje'], contains(contiene));
      expect(await stock(), 10, reason: 'el stock no cambia');
      expect(await enCaja(), cajaAntes, reason: 'la caja no cambia');
      expect(await contar('ventas'), 0);
      expect(await db.obtenerPendientes(), everyElement(isNot(containsPair('tipo', 'VENTA'))));
    }

    test('Cantidad negativa o cero se rechaza (antes sumaba stock y restaba caja)', () async {
      await rechazada(-2000, [linea(-1)], 'Cantidad no válida');
      await rechazada(0, [linea(0)], 'Cantidad no válida');
    });

    test('Carrito vacío se rechaza', () async {
      await rechazada(0, [], 'carrito está vacío');
    });

    test('NaN e infinito se rechazan', () async {
      await rechazada(double.nan, [linea(double.nan)], 'Cantidad no válida');
      await rechazada(double.infinity, [linea(1, precio: double.infinity)], 'Precio no válido');
    });

    test('Subtotal que no es cantidad × precio se rechaza (5 × 2000 por \$1)', () async {
      await rechazada(1, [linea(5, subtotal: 1)], 'no coincide con cantidad × precio');
    });

    test('Total distinto de la suma de las líneas se rechaza', () async {
      await rechazada(5000, [linea(1)], 'total no coincide');
    });

    test('Una venta normal sigue funcionando, también por peso y con promoción', () async {
      final r = await db.registrarVenta(5100, 'EFECTIVO', [
        linea(1.5, precio: 1800), // 2.700 por peso con descuento
        linea(1.2), // 2.400
      ], usuarioId: 1);
      expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
      expect(await stock(), closeTo(7.3, 0.0001));
    });

    test('Con diferencia de centavos, venta, nube y fiado usan la suma de las líneas', () async {
      final cid = await db.crearCliente({'nombre': 'Doña Rosa', 'telefono': '1', 'direccion': 'x'});
      expect(await db.actualizarClienteCupo(cid, 100000), isTrue);
      // La pantalla manda 4000,6 y las líneas suman 4000
      final r = await db.registrarVenta(4000.6, 'CREDITO', [linea(2)], usuarioId: 1, clienteId: cid);
      expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
      final d = await db.database;
      expect((await d.query('ventas')).single['total'], 4000);
      expect((await d.query('clientes', where: 'id = ?', whereArgs: [cid])).single['deuda_actual'], 4000);
      expect((await d.query('movimientos_cartera')).single['monto'], 4000);
      final pend = await db.obtenerPendientes();
      final venta = jsonDecode(pend.firstWhere((p) => p['tipo'] == 'VENTA')['datos'] as String);
      expect(venta['total'], 4000);
      final cartera = jsonDecode(pend.firstWhere((p) => p['tipo'] == 'CARTERA')['datos'] as String);
      expect(cartera['deuda_cambio'], 4000);
    });
  });

  group('Merma (hallazgo 2)', () {
    test('Cantidad negativa o cero se rechaza (antes -5 sumaba stock)', () async {
      for (final c in [-5.0, 0.0, double.nan]) {
        await expectLater(
          db.registrarMerma(productoId: papa, cantidad: c, motivo: 'Dañada', usuarioId: 1),
          throwsA(isA<OperacionInvalida>()),
        );
      }
      expect(await stock(), 10);
      expect(await contar('mermas'), 0);
    });

    test('Más de lo que hay se rechaza si no se permite stock negativo (antes dejaba -90)', () async {
      await expectLater(
        db.registrarMerma(productoId: papa, cantidad: 100, motivo: 'Dañada', usuarioId: 1),
        throwsA(isA<OperacionInvalida>().having((e) => e.mensaje, 'mensaje', contains('hay 10'))),
      );
      expect(await stock(), 10);
      expect(await contar('mermas'), 0);
      expect(await db.obtenerPendientes(), everyElement(isNot(containsPair('tipo', 'MERMA'))));
    });

    test('Con stock negativo permitido sí deja, y una merma normal funciona', () async {
      await db.registrarMerma(productoId: papa, cantidad: 2.5, motivo: 'Dañada', usuarioId: 1);
      expect(await stock(), 7.5);
      await db.registrarMerma(productoId: papa, cantidad: 7.5, motivo: 'Dañada', usuarioId: 1);
      expect(await stock(), 0, reason: 'dar de baja exactamente lo que hay');
      await db.guardarConfiguracion('permitir_stock_negativo', '1');
      await db.registrarMerma(productoId: papa, cantidad: 3, motivo: 'Dañada', usuarioId: 1);
      expect(await stock(), -3);
      expect(await contar('mermas'), 3);
    });
  });

  group('Compra (hallazgo 3)', () {
    Map<String, dynamic> item(num cant, num subtotal) =>
        {'id': papa, 'nombre': 'Papa', 'cantidad': cant, 'subtotal_compra': subtotal};

    test('Total negativo pagado con caja se rechaza (antes la caja subía)', () async {
      final antes = await enCaja();
      final r = await db.registrarCompra([item(1, -30000)], -30000, true, 'X', usuarioId: 1);
      expect(r['exito'], isFalse);
      expect(await enCaja(), antes);
      expect(await stock(), 10);
    });

    test('Total distinto de la suma de los productos se rechaza (caja bajaba 30.000 por 1.000)', () async {
      final antes = await enCaja();
      final r = await db.registrarCompra([item(1, 1000)], 30000, true, 'X', usuarioId: 1);
      expect(r['exito'], isFalse);
      expect(r['mensaje'], contains('no coincide'));
      expect(await enCaja(), antes);
      expect(await contar('compras'), 0);
    });

    test('Compra sin productos se rechaza y una compra normal funciona', () async {
      expect((await db.registrarCompra([], 0, false, 'X', usuarioId: 1))['exito'], isFalse);
      final antes = await enCaja();
      final r = await db.registrarCompra([item(5, 5000), item(2, 2000)], 7000, true, 'Andes', usuarioId: 1);
      expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
      expect(await stock(), 17);
      expect(await enCaja(), antes - 7000);
    });
  });
}
