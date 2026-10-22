import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/session_service.dart';
import 'package:novapos/services/role_permissions.dart';

/// Devoluciones, anulaciones y cuadre de caja como flujo de efectivo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DBHelper db;

  setUp(() async {
    db = DBHelper();
    await db.initMemoryDBForTesting();
    await SessionService.login({'id': 1, 'nombre': 'Admin Test', 'rol': 'ADMIN'});
    await PermissionService.loadPermissions(RolePermissions.permisosPara('ADMIN'));
  });

  tearDown(() async {
    final d = await db.database;
    await d.close();
    DBHelper.setDatabaseForTesting(null);
    await SessionService.logout();
    await PermissionService.clear();
  });

  Future<int> producto({double stock = 100, double precio = 2500, double costo = 1500}) {
    return db.insertProduct({
      'nombre': 'Papa',
      'precio_costo': costo,
      'precio_venta': precio,
      'stock_actual': stock,
      'categoria': 'Verduras',
    });
  }

  Future<int> vender(int prodId, double cantidad, String metodo,
      {double precio = 2500, double? subtotal, String? detalle, int clienteId = 0, double pack = 1}) async {
    final sub = subtotal ?? cantidad * precio;
    final r = await db.registrarVenta(
      sub,
      metodo,
      [
        {
          'id': prodId,
          'nombre': 'Papa',
          'cantidad': cantidad,
          'precio': precio,
          'subtotal': sub,
          'costo_unitario': 1500,
          'contenido_pack': pack,
        }
      ],
      usuarioId: 1,
      clienteId: clienteId,
      metodoPagoDetalle: detalle,
    );
    expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
    return r['venta_id'] as int;
  }

  Future<Map<String, dynamic>> linea(int ventaId) async {
    final d = await db.database;
    return (await d.query('detalle_ventas', where: 'venta_id = ?', whereArgs: [ventaId])).first;
  }

  Future<double> stock(int prodId) async {
    final d = await db.database;
    final r = await d.query('productos', where: 'id = ?', whereArgs: [prodId]);
    return (r.first['stock_actual'] as num).toDouble();
  }

  Future<void> cerrarCuadrado() async {
    final total = (await db.obtenerResumenCaja())['total_en_caja']!;
    await db.cerrarTurno(
      realContado: total,
      fechaInicio: (await db.obtenerFechaAperturaActual())!,
      usuarioId: 1,
    );
  }

  group('Devoluciones', () {
    test('Parcial en efectivo del mismo turno: baja ventas, stock y línea', () async {
      await db.registrarMovimientoCaja('APERTURA', 50000, 'Base', 1);
      final p = await producto();
      final v = await vender(p, 4, 'EFECTIVO');
      final l = await linea(v);

      final r = await db.devolverArticulo(l['id'] as int, p, v, 4, 0, cantidadADevolver: 1, usuarioId: 1);
      expect(r['exito'], isTrue);
      expect(r['monto'], 2500);
      expect(r['efectivo'], 2500);

      final res = await db.obtenerResumenCaja();
      expect(res['ventas_efectivo'], 7500);
      expect(res['gastos'], 0);
      expect(res['total_en_caja'], 57500);
      expect(await stock(p), 97);
      final l2 = await linea(v);
      expect(l2['cantidad'], 3);
      expect(l2['subtotal'], 7500);
    });

    test('Total devuelve exactamente lo cobrado aunque hubo descuento', () async {
      await db.registrarMovimientoCaja('APERTURA', 50000, 'Base', 1);
      final p = await producto();
      // 4 kg con promoción: se cobraron 9.000 y no 10.000
      final v = await vender(p, 4, 'EFECTIVO', precio: 2250, subtotal: 9000);
      final l = await linea(v);
      final r = await db.devolverArticulo(l['id'] as int, p, v, 4, 10000, usuarioId: 1);
      expect(r['exito'], isTrue);
      expect(r['monto'], 9000);
      expect((await db.obtenerResumenCaja())['total_en_caja'], 50000);
    });

    test('Venta de un turno anterior: el efectivo sale del turno abierto', () async {
      await db.registrarMovimientoCaja('APERTURA', 20000, 'Base', 1);
      final p = await producto();
      final v = await vender(p, 4, 'EFECTIVO'); // 10.000
      await cerrarCuadrado();
      final cierreAntes = (await db.obtenerHistorialCierres()).first;
      expect(cierreAntes['total_sistema'], 30000);

      await db.registrarMovimientoCaja('APERTURA', 50000, 'Base día 2', 1);
      final l = await linea(v);
      final r = await db.devolverArticulo(l['id'] as int, p, v, 4, 0, usuarioId: 1);
      expect(r['exito'], isTrue);

      final res = await db.obtenerResumenCaja();
      expect(res['ventas_efectivo'], 0);
      expect(res['gastos'], 10000); // aparece como salida del turno
      expect(res['devoluciones_otros_turnos'], 10000);
      expect(res['total_en_caja'], 40000);

      // El cierre anterior no cambia
      final cierres = await db.obtenerHistorialCierres();
      expect(cierres.last['total_sistema'], 30000);

      // El cierre del día 2 cuadra con lo que hay
      final cierre = await db.cerrarTurno(
        realContado: 40000,
        fechaInicio: (await db.obtenerFechaAperturaActual())!,
        usuarioId: 1,
      );
      expect(cierre['total_sistema'], 40000);
      expect((cierre['cierre'] as Map)['gastos_turno'], 10000);
    });

    test('Efectivo sin caja abierta se bloquea; digital no necesita caja', () async {
      await db.registrarMovimientoCaja('APERTURA', 20000, 'Base', 1);
      final p = await producto();
      final vEf = await vender(p, 2, 'EFECTIVO');
      final vNq = await vender(p, 2, 'NEQUI');
      await cerrarCuadrado();

      final lEf = await linea(vEf);
      final r1 = await db.devolverArticulo(lEf['id'] as int, p, vEf, 2, 0, usuarioId: 1);
      expect(r1['exito'], isFalse);
      expect(r1['mensaje'], contains('Abra la caja'));
      expect(await stock(p), 96); // no tocó nada

      final lNq = await linea(vNq);
      final r2 = await db.devolverArticulo(lNq['id'] as int, p, vNq, 2, 0, usuarioId: 1);
      expect(r2['exito'], isTrue);
      expect(r2['efectivo'], 0);
      expect(await stock(p), 98);
    });

    test('Fondos insuficientes no deja devolver ni descuadra', () async {
      await db.registrarMovimientoCaja('APERTURA', 20000, 'Base', 1);
      final p = await producto();
      final v = await vender(p, 4, 'EFECTIVO');
      await cerrarCuadrado();
      await db.registrarMovimientoCaja('APERTURA', 3000, 'Base corta', 1);

      final l = await linea(v);
      final r = await db.devolverArticulo(l['id'] as int, p, v, 4, 0, usuarioId: 1);
      expect(r['exito'], isFalse);
      expect(r['mensaje'], contains('Fondos insuficientes'));
      expect((await db.obtenerResumenCaja())['total_en_caja'], 3000);
      expect((await linea(v))['cantidad'], 4);
    });

    test('Mixto: el excedente fue cambio y se devuelve primero el efectivo', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      final p = await producto();
      // Total 10.000: pagó 8.000 en efectivo y 4.000 por Nequi → 2.000 de cambio
      final v = await vender(p, 4, 'MIXTO',
          detalle: jsonEncode({'efectivo': 8000, 'digital': 4000, 'metodo_digital': 'NEQUI'}));
      var res = await db.obtenerResumenCaja();
      expect(res['ventas_efectivo'], 6000);
      expect(res['total_en_caja'], 16000);

      // Devuelve 3 kg = 7.500: 6.000 en efectivo y 1.500 por Nequi
      final l = await linea(v);
      final r = await db.devolverArticulo(l['id'] as int, p, v, 4, 0, cantidadADevolver: 3, usuarioId: 1);
      expect(r['exito'], isTrue);
      expect(r['efectivo'], 6000);
      res = await db.obtenerResumenCaja();
      expect(res['ventas_efectivo'], 0);
      expect(res['total_en_caja'], 10000);

      final d = await db.database;
      final venta = (await d.query('ventas', where: 'id = ?', whereArgs: [v])).first;
      final pago = jsonDecode(venta['metodo_pago_detalle'] as String);
      expect(pago['efectivo'], 0);
      expect(pago['digital'], 2500);
      expect(venta['total'], 2500);
    });

    test('Paquete: devolver 1 paquete de 6 devuelve 6 unidades al inventario', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      final p = await producto(stock: 100, precio: 1000);
      final v = await vender(p, 2, 'EFECTIVO', precio: 6000, pack: 6); // 2 paquetes = 12 und
      expect(await stock(p), 88);
      final l = await linea(v);
      final r = await db.devolverArticulo(l['id'] as int, p, v, 2, 0, cantidadADevolver: 1, usuarioId: 1);
      expect(r['exito'], isTrue);
      expect(r['monto'], 6000);
      expect(await stock(p), 94);
      final l2 = await linea(v);
      expect(l2['cantidad'], 1);
      expect(l2['cantidad_descontada'], 6);
    });

    test('Fiado: la devolución baja la deuda y no toca la caja', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      final c = await db.crearCliente({'nombre': 'Doña Rosa', 'cupo_credito': 100000, 'deuda_actual': 0});
      final p = await producto();
      final v = await vender(p, 4, 'CREDITO', clienteId: c);
      final l = await linea(v);
      final r = await db.devolverArticulo(l['id'] as int, p, v, 4, 0, cantidadADevolver: 2, usuarioId: 1);
      expect(r['exito'], isTrue);
      expect((await db.obtenerCliente(c))!['deuda_actual'], 5000);
      expect((await db.obtenerResumenCaja())['total_en_caja'], 10000);
    });

    test('Combo: devolver el combo devuelve sus componentes', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      final arroz = await producto(stock: 10);
      final aceite = await producto(stock: 10);
      final combo = await db.crearCombo(
        {'nombre': 'Arroz + Aceite', 'precio_venta': 9000, 'precio_costo': 0, 'stock_actual': 0},
        [
          {'producto_id': arroz, 'cantidad': 2},
          {'producto_id': aceite, 'cantidad': 1},
        ],
      );
      final v = await vender(combo, 1, 'EFECTIVO', precio: 9000);
      expect(await stock(arroz), 8);
      expect(await stock(aceite), 9);
      final l = await linea(v);
      final r = await db.devolverArticulo(l['id'] as int, combo, v, 1, 0, usuarioId: 1);
      expect(r['exito'], isTrue);
      expect(await stock(arroz), 10);
      expect(await stock(aceite), 10);

      // Lo que viaja a las otras cajas es el stock de los componentes
      final d = await db.database;
      final ops = await d.query('sync_pendientes', where: "tipo = 'STOCK_OP'");
      final comboUuid = (await d.query('productos', where: 'id = ?', whereArgs: [combo])).first['uuid'];
      expect(ops.any((o) => (o['datos'] as String).contains(comboUuid as String)), isFalse);
    });

    test('Deja registro, venta actualizada y movimiento para sincronizar', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      final p = await producto();
      final v = await vender(p, 4, 'EFECTIVO');
      final l = await linea(v);
      await db.devolverArticulo(l['id'] as int, p, v, 4, 0,
          cantidadADevolver: 1, usuarioId: 1, motivo: 'Llegó dañado');
      final d = await db.database;
      final devs = await d.query('devoluciones');
      expect(devs.length, 1);
      expect(devs.first['motivo'], 'Llegó dañado');
      final tipos = (await d.query('sync_pendientes')).map((e) => e['tipo']).toSet();
      expect(tipos, containsAll(['VENTA_ACTUALIZA', 'DEVOLUCION', 'CAJA_MOV']));
    });
  });

  group('Anulaciones', () {
    test('Del mismo turno: la caja vuelve a la base y queda quién anuló', () async {
      await db.registrarMovimientoCaja('APERTURA', 30000, 'Base', 1);
      final p = await producto();
      final v = await vender(p, 4, 'EFECTIVO');
      final r = await db.anularVenta(v, usuarioId: 1, motivo: 'Error de digitación');
      expect(r['exito'], isTrue);
      final res = await db.obtenerResumenCaja();
      expect(res['ventas_efectivo'], 0);
      expect(res['total_en_caja'], 30000);
      final d = await db.database;
      final venta = (await d.query('ventas', where: 'id = ?', whereArgs: [v])).first;
      expect(venta['anulada'], 1);
      expect(venta['anulada_por'], 1);
      expect(venta['motivo_anulacion'], 'Error de digitación');
      expect(await stock(p), 100);
    });

    test('De un turno anterior: sale del cajón actual', () async {
      await db.registrarMovimientoCaja('APERTURA', 30000, 'Base', 1);
      final p = await producto();
      final v = await vender(p, 4, 'EFECTIVO');
      await cerrarCuadrado();
      await db.registrarMovimientoCaja('APERTURA', 25000, 'Base 2', 1);
      final r = await db.anularVenta(v, usuarioId: 1);
      expect(r['exito'], isTrue);
      expect((await db.obtenerResumenCaja())['total_en_caja'], 15000);
      expect((await db.anularVenta(v, usuarioId: 1))['exito'], isFalse);
    });

    test('Una devolución previa no se devuelve dos veces al anular', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      final p = await producto();
      final v = await vender(p, 4, 'EFECTIVO');
      final l = await linea(v);
      await db.devolverArticulo(l['id'] as int, p, v, 4, 0, cantidadADevolver: 1, usuarioId: 1);
      final r = await db.anularVenta(v, usuarioId: 1);
      expect(r['efectivo'], 7500);
      expect((await db.obtenerResumenCaja())['total_en_caja'], 10000);
      expect(await stock(p), 100);
    });
  });

  group('Caja', () {
    test('Compra pagada con caja sin fondos se rechaza', () async {
      await db.registrarMovimientoCaja('APERTURA', 5000, 'Base', 1);
      final p = await producto();
      final r = await db.registrarCompra(
        [
          {'id': p, 'nombre': 'Papa', 'cantidad': 10.0, 'costo_unitario': 1500.0, 'subtotal_compra': 15000.0}
        ],
        15000,
        true,
        'Mayorista',
        usuarioId: 1,
      );
      expect(r['exito'], isFalse);
      expect(r['mensaje'], contains('Fondos insuficientes'));
      expect((await db.obtenerResumenCaja())['total_en_caja'], 5000);
    });

    test('Los movimientos de otra caja no entran al cuadre de esta', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      final d = await db.database;
      await d.insert('caja_movimientos', {
        'fecha': DateTime.now().toIso8601String(),
        'tipo': 'GASTO',
        'monto': 7000,
        'descripcion': 'Gasto en la caja 2',
        'usuario_id': 1,
        'dispositivo_uuid': 'otra-caja',
        'uuid': 'x1',
      });
      await d.insert('caja_movimientos', {
        'fecha': DateTime.now().toIso8601String(),
        'tipo': 'APERTURA',
        'monto': 99000,
        'descripcion': 'Apertura caja 2',
        'usuario_id': 1,
        'dispositivo_uuid': 'otra-caja',
        'uuid': 'x2',
      });
      final res = await db.obtenerResumenCaja();
      expect(res['base'], 10000);
      expect(res['gastos'], 0);
      expect(await db.verificarCajaAbiertaHoy(), isTrue);
    });

    test('Gasto con categoría queda guardado', () async {
      await db.registrarMovimientoCaja('APERTURA', 100000, 'Base', 1);
      await db.registrarMovimientoCaja('GASTO', 40000, 'Arriendo octubre', 1, categoria: 'ARRIENDO');
      final movs = await db.obtenerMovimientosTurnoActual();
      expect(movs.firstWhere((m) => m['tipo'] == 'GASTO')['categoria'], 'ARRIENDO');
    });
  });

  group('Entre cajas y sincronización', () {
    test('Devolver aquí una venta de otra caja: sale de este cajón y no cambia lo cobrado allá', () async {
      await db.registrarMovimientoCaja('APERTURA', 30000, 'Base', 1);
      final p = await producto();
      final d = await db.database;
      // Venta que llegó por sincronización desde la caja 2
      final vId = await d.insert('ventas', {
        'fecha': DateTime.now().toIso8601String(),
        'total': 10000,
        'metodo_pago': 'EFECTIVO',
        'usuario_id': 1,
        'anulada': 0,
        'uuid': 'venta-remota',
        'dispositivo_uuid': 'caja-2',
        'efectivo_cobrado': 10000,
      });
      final lId = await d.insert('detalle_ventas', {
        'venta_id': vId, 'producto_id': p, 'nombre_producto': 'Papa', 'cantidad': 4,
        'cantidad_descontada': 4, 'precio_unitario': 2500, 'subtotal': 10000, 'costo_unitario': 1500,
      });
      expect((await db.obtenerResumenCaja())['total_en_caja'], 30000); // no es de esta caja

      final r = await db.devolverArticulo(lId, p, vId, 4, 0, cantidadADevolver: 2, usuarioId: 1);
      expect(r['exito'], isTrue);
      final res = await db.obtenerResumenCaja();
      expect(res['total_en_caja'], 25000);
      expect(res['devoluciones_otros_turnos'], 5000);
      final venta = (await d.query('ventas', where: 'id = ?', whereArgs: [vId])).first;
      expect(venta['total'], 5000);
      expect(venta['efectivo_cobrado'], 10000); // la caja 2 sigue cuadrando
    });

    test('Lo que viaja a la nube trae el estado completo de la venta', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      final p = await producto();
      final v = await vender(p, 4, 'EFECTIVO');
      final l = await linea(v);
      await db.devolverArticulo(l['id'] as int, p, v, 4, 0, cantidadADevolver: 1, usuarioId: 1);
      final d = await db.database;
      final act = (await d.query('sync_pendientes', where: "tipo = 'VENTA_ACTUALIZA'")).single;
      final datos = jsonDecode(act['datos'] as String) as Map;
      expect(datos['total'], 7500);
      expect(datos['actualizado_epoch'], greaterThan(0));
      final det = (datos['detalle'] as List).single as Map;
      expect(det['cantidad'], 3);
      expect(det['producto_uuid'], isNotEmpty);
      final venta = jsonDecode((await d.query('sync_pendientes', where: "tipo = 'VENTA'")).single['datos'] as String);
      expect(venta['efectivo_cobrado'], 10000);
    });

    test('Cierre y movimientos quedan listos para subir con su caja', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      await db.registrarMovimientoCaja('GASTO', 2000, 'Bolsas', 1, categoria: 'INSUMOS');
      await cerrarCuadrado();
      final d = await db.database;
      final disp = await db.obtenerDispositivoUuid();
      final cierre = jsonDecode((await d.query('sync_pendientes', where: "tipo = 'CIERRE'")).single['datos'] as String);
      expect(cierre['dispositivo_uuid'], disp);
      expect(cierre['total_sistema'], 8000);
      final movs = (await d.query('sync_pendientes', where: "tipo = 'CAJA_MOV'"))
          .map((m) => jsonDecode(m['datos'] as String))
          .toList();
      expect(movs.map((m) => m['tipo']), containsAll(['APERTURA', 'GASTO', 'CIERRE']));
      expect(movs.firstWhere((m) => m['tipo'] == 'GASTO')['categoria'], 'INSUMOS');
    });

    test('Abono de cliente entra al cajón con su categoría', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      final c = await db.crearCliente({'nombre': 'Don José', 'cupo_credito': 50000, 'deuda_actual': 20000});
      final r = await db.registrarAbonoCliente(c, 'Don José', 5000, usuarioId: 1);
      expect(r['exito'], isTrue);
      expect((await db.obtenerResumenCaja())['total_en_caja'], 15000);
      final mov = (await db.obtenerMovimientosTurnoActual()).firstWhere((m) => m['tipo'] == 'INGRESO');
      expect(mov['categoria'], 'ABONO_CLIENTE');
    });

    test('Refuerzo y pago atómico guardan sus categorías', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      await db.registrarIngresoYGasto(
        ingreso: 50000, gasto: 55000, descripcionIngreso: 'Refuerzo', descripcionGasto: 'Pedido',
        usuarioId: 1, categoriaIngreso: 'BASE_EXTRA', categoriaGasto: 'PROVEEDOR',
      );
      final movs = await db.obtenerMovimientosTurnoActual();
      expect(movs.firstWhere((m) => m['tipo'] == 'INGRESO')['categoria'], 'BASE_EXTRA');
      expect(movs.firstWhere((m) => m['tipo'] == 'GASTO')['categoria'], 'PROVEEDOR');
      expect((await db.obtenerResumenCaja())['total_en_caja'], 5000);
    });

    test('Cerrar con conteo inválido se rechaza', () async {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      expect(
        () async => db.cerrarTurno(
            realContado: -1, fechaInicio: (await db.obtenerFechaAperturaActual())!, usuarioId: 1),
        throwsA(isA<Exception>()),
      );
      expect(await db.verificarCajaAbiertaHoy(), isTrue);
    });
  });
}
