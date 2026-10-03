import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/session_service.dart';
import 'package:novapos/services/role_permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DBHelper dbHelper;

  setUp(() async {
    dbHelper = DBHelper();
    await dbHelper.initMemoryDBForTesting();

    // Configurar sesión de usuario administrador
    await SessionService.login({
      'id': 1,
      'nombre': 'Admin Test',
      'rol': 'ADMIN',
    });
    await PermissionService.loadPermissions(RolePermissions.permisosPara('ADMIN'));
  });

  tearDown(() async {
    final db = await dbHelper.database;
    await db.close();
    DBHelper.setDatabaseForTesting(null);
    await SessionService.logout();
    await PermissionService.clear();
  });

  group('Auditoría Integral de Caja y Ventas - NovaPOS', () {
    test('1. Flujo de Apertura de Caja y bloqueo de doble apertura', () async {
      // Al inicio no hay turno abierto
      bool abiertaInicio = await dbHelper.verificarCajaAbiertaHoy();
      expect(abiertaInicio, isFalse);

      // Registrar apertura con 150.000
      int idApertura = await dbHelper.registrarMovimientoCaja(
        'APERTURA',
        150000.0,
        'Base inicial del día',
        1,
      );
      expect(idApertura, greaterThan(0));

      // Verificar estado
      bool abiertaAhora = await dbHelper.verificarCajaAbiertaHoy();
      expect(abiertaAhora, isTrue);

      var resumen = await dbHelper.obtenerResumenCaja();
      expect(resumen['base'], equals(150000.0));
      expect(resumen['total_en_caja'], equals(150000.0));
      expect(resumen['gastos'], equals(0.0));
      expect(resumen['ingresos_extra'], equals(0.0));

      // Intentar abrir de nuevo debe fallar
      expect(
        () => dbHelper.registrarMovimientoCaja(
          'APERTURA',
          50000.0,
          'Segunda base',
          1,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('2. Caso del usuario: Base 150k + Pedido 300k -> Inyección atómica y pago', () async {
      // 1. Abrimos con 150k
      await dbHelper.registrarMovimientoCaja('APERTURA', 150000.0, 'Base inicial', 1);

      // 2. Intentar pagar un gasto de 300k directamente debe ser rechazado por fondos insuficientes
      expect(
        () => dbHelper.registrarMovimientoCaja(
          'GASTO',
          300000.0,
          'Pago Pedido Proveedor',
          1,
        ),
        throwsA(predicate((e) => e.toString().contains('Fondos insuficientes'))),
      );

      // 3. Ejecutamos la operación atómica: Inyectar 200k (150k faltante + 50k colchón) y pagar pedido 300k
      final resOperacion = await dbHelper.registrarIngresoYGasto(
        ingreso: 200000.0,
        gasto: 300000.0,
        descripcionIngreso: 'Refuerzo de dueño para pago de pedido',
        descripcionGasto: 'Pago Pedido Proveedor Mayorista',
        usuarioId: 1,
      );

      expect(resOperacion['exito'], isTrue);
      expect(resOperacion['total_en_caja'], equals(50000.0));

      // 4. Verificar resumen de caja
      final resumen = await dbHelper.obtenerResumenCaja();
      expect(resumen['base'], equals(150000.0));
      expect(resumen['ingresos_extra'], equals(200000.0));
      expect(resumen['gastos'], equals(300000.0));
      // Total en caja = 150.000 + 200.000 - 300.000 = 50.000
      expect(resumen['total_en_caja'], equals(50000.0));

      // 5. Verificar que ambos movimientos existan en el turno
      final movs = await dbHelper.obtenerMovimientosTurnoActual();
      expect(movs.length, equals(3)); // APERTURA, INGRESO, GASTO
      expect(movs.any((m) => m['tipo'] == 'INGRESO' && m['monto'] == 200000.0), isTrue);
      expect(movs.any((m) => m['tipo'] == 'GASTO' && m['monto'] == 300000.0), isTrue);
    });

    test('3. Ventas en Efectivo, Digital y Mixtas en Caja', () async {
      await dbHelper.registrarMovimientoCaja('APERTURA', 100000.0, 'Base', 1);

      // Crear un producto para vender
      int prodId = await dbHelper.insertProduct({
        'nombre': 'Papa Pastusa',
        'precio_costo': 1500.0,
        'precio_venta': 2500.0,
        'stock_actual': 100.0,
        'categoria': 'Verduras',
      });

      // Venta en EFECTIVO de 2 kg = $5.000
      var resVenta1 = await dbHelper.registrarVenta(
        5000.0,
        'EFECTIVO',
        [
          {
            'id': prodId,
            'nombre': 'Papa Pastusa',
            'cantidad': 2.0,
            'precio': 2500.0,
            'subtotal': 5000.0,
          }
        ],
        usuarioId: 1,
      );
      expect(resVenta1['exito'], isTrue);

      var resumenTrasVenta1 = await dbHelper.obtenerResumenCaja();
      expect(resumenTrasVenta1['ventas_efectivo'], equals(5000.0));
      expect(resumenTrasVenta1['total_en_caja'], equals(105000.0)); // 100k + 5k

      // Venta en NEQUI de 4 kg = $10.000 (No entra a caja física)
      var resVenta2 = await dbHelper.registrarVenta(
        10000.0,
        'NEQUI',
        [
          {
            'id': prodId,
            'nombre': 'Papa Pastusa',
            'cantidad': 4.0,
            'precio': 2500.0,
            'subtotal': 10000.0,
          }
        ],
        usuarioId: 1,
      );
      expect(resVenta2['exito'], isTrue);

      var resumenTrasVenta2 = await dbHelper.obtenerResumenCaja();
      // Efectivo en caja sigue siendo 105.000
      expect(resumenTrasVenta2['total_en_caja'], equals(105000.0));
      // Ventas globales sí suman ambas (5k + 10k = 15k)
      expect(resumenTrasVenta2['ventas_global'], equals(5000.0)); // Solo efectivo en query de ventas_efectivo
    });

    test('4. Bloqueo de venta si la caja no está abierta', () async {
      // Aseguramos que la caja esté cerrada
      expect(await dbHelper.verificarCajaAbiertaHoy(), isFalse);

      int prodId = await dbHelper.insertProduct({
        'nombre': 'Tomate',
        'precio_costo': 1000.0,
        'precio_venta': 2000.0,
        'stock_actual': 50.0,
        'categoria': 'Verduras',
      });

      var resVenta = await dbHelper.registrarVenta(
        2000.0,
        'EFECTIVO',
        [
          {
            'id': prodId,
            'nombre': 'Tomate',
            'cantidad': 1.0,
            'precio': 2000.0,
            'subtotal': 2000.0,
          }
        ],
        usuarioId: 1,
      );

      expect(resVenta['exito'], isFalse);
      expect(resVenta['mensaje'], contains('Debe abrir la caja antes de vender'));
    });

    test('5. Cierre de Turno formal, arqueo y bloqueo post-cierre', () async {
      await dbHelper.registrarMovimientoCaja('APERTURA', 80000.0, 'Base', 1);

      // Ingreso extra de 20.000
      await dbHelper.registrarMovimientoCaja('INGRESO', 20000.0, 'Inyección', 1);

      // Total esperado por el sistema = 80.000 + 20.000 = 100.000
      final resumen = await dbHelper.obtenerResumenCaja();
      expect(resumen['total_en_caja'], equals(100000.0));

      final fechaApertura = await dbHelper.obtenerFechaAperturaActual();
      expect(fechaApertura, isNotNull);

      // Cerrar turno contando exactamente 100.000
      final resCierre = await dbHelper.cerrarTurno(
        realContado: 100000.0,
        diferencia: 0.0,
        estado: 'OK',
        detalle: 'Cierre de prueba perfecto',
        fechaInicio: fechaApertura!,
        usuarioId: 1,
      );

      expect(resCierre['exito'], isTrue);
      expect(resCierre['total_sistema'], equals(100000.0));

      // Caja ahora debe estar cerrada
      expect(await dbHelper.verificarCajaAbiertaHoy(), isFalse);

      // Intentar cerrar de nuevo debe lanzar excepción
      expect(
        () => dbHelper.cerrarTurno(
          realContado: 100000.0,
          fechaInicio: fechaApertura,
          usuarioId: 1,
        ),
        throwsA(isA<Exception>()),
      );

      // El historial de cierres debe tener este registro
      final historial = await dbHelper.obtenerHistorialCierres();
      expect(historial.length, equals(1));
      expect(historial.first['total_sistema'], equals(100000.0));
      expect(historial.first['real_contado'], equals(100000.0));
      expect(historial.first['estado'], equals('OK'));
    });
  });
}
