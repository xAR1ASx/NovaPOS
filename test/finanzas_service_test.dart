import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/finanzas_service.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/session_service.dart';
import 'package:novapos/services/role_permissions.dart';

/// Un día de operación completo y lo que debe mostrar el Centro Financiero.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DBHelper db;
  late FinanzasService fin;
  final hoy = Periodo(DateTime.now(), DateTime.now());

  setUp(() async {
    db = DBHelper();
    await db.initMemoryDBForTesting();
    fin = FinanzasService(db);
    await SessionService.login({'id': 1, 'nombre': 'Admin Test', 'rol': 'ADMIN'});
    await PermissionService.loadPermissions(RolePermissions.permisosPara('ADMIN'));
    final d = await db.database;
    await d.insert('usuarios', {'id': 1, 'usuario': 'admin', 'nombre_completo': 'Ana Admin', 'rol': 'ADMIN'});
  });

  tearDown(() async {
    final d = await db.database;
    await d.close();
    DBHelper.setDatabaseForTesting(null);
    await SessionService.logout();
    await PermissionService.clear();
  });

  Future<int> vender(int prodId, String nombre, double cant, double precio, double costo, String metodo) async {
    final r = await db.registrarVenta(cant * precio, metodo, [
      {'id': prodId, 'nombre': nombre, 'cantidad': cant, 'precio': precio, 'subtotal': cant * precio, 'costo_unitario': costo}
    ], usuarioId: 1);
    expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
    return r['venta_id'] as int;
  }

  /// Ventas 30.000 (papa 20.000 con costo 12.000; tomate 10.000 con costo
  /// 9.500), devolución de 1 kg de papa (2.000), anulación de una venta de
  /// 4.000, arriendo 5.000, préstamo 3.000, merma 1.000 y faltante 500.
  Future<void> diaCompleto() async {
    await db.registrarMovimientoCaja('APERTURA', 50000, 'Base', 1);
    final papa = await db.insertProduct(
        {'nombre': 'Papa', 'precio_costo': 1200, 'precio_venta': 2000, 'stock_actual': 100, 'categoria': 'Verduras'});
    final tomate = await db.insertProduct(
        {'nombre': 'Tomate', 'precio_costo': 1900, 'precio_venta': 2000, 'stock_actual': 100, 'categoria': 'Frutas'});
    final v1 = await vender(papa, 'Papa', 10, 2000, 1200, 'EFECTIVO');
    await vender(tomate, 'Tomate', 5, 2000, 1900, 'NEQUI');
    final v3 = await vender(papa, 'Papa', 2, 2000, 1200, 'EFECTIVO');

    final d = await db.database;
    final l1 = (await d.query('detalle_ventas', where: 'venta_id = ?', whereArgs: [v1])).first;
    await db.devolverArticulo(l1['id'] as int, papa, v1, 10, 0, cantidadADevolver: 1, usuarioId: 1, motivo: 'Dañada');
    await db.anularVenta(v3, usuarioId: 1, motivo: 'Cliente se arrepintió');

    await db.registrarMovimientoCaja('GASTO', 5000, 'Arriendo', 1, categoria: 'ARRIENDO');
    await db.registrarMovimientoCaja('GASTO', 3000, 'Préstamo a Juan', 1, categoria: 'PRESTAMO');
    await db.registrarMerma(productoId: tomate, cantidad: 0.5, motivo: 'Maduró', usuarioId: 1);

    // Cierre con 500 de faltante (el descuadre queda en el cierre)
    final esperado = (await db.obtenerResumenCaja())['total_en_caja']!;
    await db.cerrarTurno(
      realContado: esperado - 500,
      fechaInicio: (await db.obtenerFechaAperturaActual())!,
      usuarioId: 1,
    );
  }

  test('Estado de resultados del día', () async {
    await diaCompleto();
    final r = await fin.resultados(hoy);
    expect(r.ventas, 28000); // 18.000 papa + 10.000 tomate
    expect(r.cantidadVentas, 2);
    expect(r.costoVentas, 9 * 1200 + 5 * 1900);
    expect(r.utilidadBruta, 28000 - 20300);
    expect(r.gastos, 5000); // el préstamo no es gasto
    expect(r.prestamos, 3000);
    expect(r.mermas, 950);
    expect(r.faltantesCaja, 500);
    expect(r.utilidadNeta, 7700 - 5000 - 950 - 500);
    expect(r.devoluciones, 2000);
    expect(r.cantidadAnuladas, 1);
    expect(r.anuladas, 4000);
    expect(r.diario.length, 1);
    expect(r.diario.first.ventas, 28000);
  });

  test('Gastos, compras y flujo de efectivo', () async {
    await diaCompleto();
    final g = await fin.gastosCompras(hoy);
    expect(g.gastosPorCategoria.map((x) => x.clave), ['ARRIENDO']); // el faltante no es un gasto
    expect(g.salidasNoGasto.single.clave, 'PRESTAMO');
    expect(g.entroVentas, 24000); // 20.000 + 4.000 cobrados en efectivo
    expect(g.salioDevoluciones, 6000); // 2.000 devolución + 4.000 anulación
    expect(g.metodosPago.firstWhere((m) => m.clave == 'NEQUI').total, 10000);
  });

  test('Rentabilidad: detecta el producto con margen bajo', () async {
    await diaCompleto();
    final r = await fin.rentabilidad(hoy);
    final tomate = r.productos.firstWhere((p) => p.nombre == 'Tomate');
    expect(tomate.margen, closeTo(5, 0.01));
    expect(r.margenBajo.map((p) => p.nombre), contains('Tomate'));
    expect(r.categorias.first.nombre, 'Verduras');
  });

  test('Control: anulación, devolución, merma y descuadre con quién', () async {
    await diaCompleto();
    final c = await fin.control(hoy);
    expect(c.cantidad('ANULACION'), 1);
    expect(c.cantidad('DEVOLUCION'), 1);
    expect(c.cantidad('MERMA'), 1);
    expect(c.cantidad('DESCUADRE'), 1);
    final anul = c.eventos.firstWhere((e) => e.tipo == 'ANULACION');
    expect(anul.usuario, 'Ana Admin');
    expect(anul.motivo, 'Cliente se arrepintió');
    expect(c.porPersona.single.usuario, 'Ana Admin');
  });

  test('Cierres: faltante por cajero y lo que esperaba el sistema', () async {
    await diaCompleto();
    final c = await fin.cierresDe(hoy);
    expect(c.cierres.length, 1);
    final cierre = c.cierres.single;
    expect(cierre.estado, 'FALTANTE');
    expect(cierre.diferencia, -500);
    expect(cierre.esperado - cierre.contado!, 500);
    expect(c.totalFaltante, 500);
    expect(c.porCajero.single.cajero, 'Ana Admin');
    final movs = await fin.movimientosDeTurno(cierre);
    expect(movs.any((m) => m.categoria == 'ARRIENDO'), isTrue);
  });

  test('Turno abierto aparece en curso', () async {
    await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
    final c = await fin.cierresDe(hoy);
    expect(c.cierres.single.estado, 'ABIERTO');
    expect(c.cierres.single.esperado, 10000);
  });

  test('Período anterior y comparación', () async {
    final p = Periodo(DateTime(2026, 10, 8), DateTime(2026, 10, 14));
    expect(p.dias, 7);
    expect(p.anterior.desde, DateTime(2026, 10, 1));
    expect(p.anterior.hasta, DateTime(2026, 10, 7));
  });

  test('Tirilla Z coherente: esperado real, gastos sin el faltante y diferencia exacta', () async {
    await db.registrarMovimientoCaja('APERTURA', 100000, 'Base', 1);
    await db.registrarMovimientoCaja('GASTO', 5000, 'Bolsas', 1, categoria: 'INSUMOS');
    final r = await db.cerrarTurno(
      realContado: 94000, // faltan 1.000
      diferencia: 0, // lo que diga la pantalla ya no manda: se calcula
      estado: 'OK',
      fechaInicio: (await db.obtenerFechaAperturaActual())!,
      usuarioId: 1,
    );
    final c = r['cierre'] as Map<String, dynamic>;
    expect(c['total_sistema'], 95000);
    expect(c['gastos_turno'], 5000);
    expect(c['real_contado'], 94000);
    expect(c['diferencia'], -1000);
    expect(c['estado'], 'FALTA');
    // Base + ventas + ingresos − gastos = esperado
    expect((c['base'] as num) + (c['ventas_turno'] as num) + (c['ingresos_turno'] as num) - (c['gastos_turno'] as num),
        c['total_sistema']);
    final res = await fin.resultados(hoy);
    expect(res.faltantesCaja, 1000);
    expect(res.gastos, 5000);
  });
}
