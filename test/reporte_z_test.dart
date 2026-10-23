import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/printer_service.dart';
import 'package:novapos/services/reporte_z.dart';
import 'package:novapos/services/role_permissions.dart';
import 'package:novapos/services/session_service.dart';

/// Reporte Z: la regla de oro cuadra con el turno abierto y cerrado, la
/// reimpresión es idéntica, el detalle y los avisos son los correctos y
/// cada línea cabe exacta en 80 mm (42) y 58 mm (32).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DBHelper();
  late Directory dir;
  late int papa;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('novapos_z_');
    await db.abrirArchivoParaPruebas('${dir.path}/caja.db');
    await SessionService.login({'id': 1, 'nombre': 'Ana', 'rol': 'ADMIN'});
    await PermissionService.loadPermissions(RolePermissions.permisosPara('ADMIN'));
    await db.guardarConfiguracion('empresa_nombre', 'Fruver La Cosecha');
    papa = await db.insertProduct({
      'nombre': 'Papa', 'categoria': 'Verduras', 'precio_costo': 1000, 'precio_venta': 2000, 'stock_actual': 500,
    });
  });

  tearDown(() async {
    final d = await db.database;
    await d.close();
    DBHelper.setDatabaseForTesting(null);
    await dir.delete(recursive: true);
    await SessionService.logout();
    await PermissionService.clear();
  });

  Future<Map<String, dynamic>> vender(double cant, String metodo, {String? detalle}) async {
    final r = await db.registrarVenta(cant * 2000, metodo, [
      {'id': papa, 'nombre': 'Papa', 'cantidad': cant, 'precio': 2000, 'subtotal': cant * 2000, 'costo_unitario': 1000}
    ], usuarioId: 1, metodoPagoDetalle: detalle);
    expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
    return r;
  }

  Future<void> devolver(int ventaId, double cant) async {
    final d = await db.database;
    final linea = (await d.query('detalle_ventas', where: 'venta_id = ?', whereArgs: [ventaId])).first;
    final r = await db.devolverArticulo(linea['id'] as int, papa, ventaId, cant, 0,
        cantidadADevolver: cant, usuarioId: 1, motivo: 'Dañada');
    expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
  }

  void reglaDeOro(DatosZ z) {
    final suma = z.base + z.ventasTotal - z.ventasNoEfectivo + z.otrasEntradas - z.compras - z.gastos - z.devoluciones;
    expect(suma, closeTo(z.esperado, 0.001), reason: 'el papel debe cuadrar');
  }

  /// Turno anterior con una venta en efectivo; turno actual con todo lo que
  /// pide el reporte. Devuelve el id de la venta del turno anterior.
  Future<void> armarTurno() async {
    await db.registrarMovimientoCaja('APERTURA', 50000, 'Base', 1);
    final anterior = await vender(3, 'EFECTIVO'); // 6.000
    await db.cerrarTurno(realContado: 56000, fechaInicio: '', usuarioId: 1);

    await db.registrarMovimientoCaja('APERTURA', 100000, 'Base', 1);
    final efectivo = await vender(5, 'EFECTIVO'); // 10.000
    await vender(4, 'TRANSFERENCIA'); // 8.000
    await vender(1, 'NEQUI'); // 2.000
    final c = await db.registrarCompra([
      {'id': papa, 'nombre': 'Papa', 'cantidad': 10, 'subtotal_compra': 5000}
    ], 5000, true, 'Proveedor Andes', usuarioId: 1);
    expect(c['exito'], isTrue, reason: c['mensaje']?.toString());
    await db.registrarMovimientoCaja('GASTO', 3000, 'Aseo del local y bolsas para la entrega de domicilios del sector norte', 1);
    await db.registrarMovimientoCaja('INGRESO', 2000, 'Préstamo devuelto', 1);
    await devolver(efectivo['venta_id'] as int, 1); // mismo turno: 2.000
    await devolver(anterior['venta_id'] as int, 1); // turno anterior: 2.000
  }

  test('Regla de oro con el turno abierto y después de cerrarlo; reimpresión idéntica', () async {
    await armarTurno();

    final abierto = (await db.datosZTurnoAbierto(usuarioId: 1))!;
    reglaDeOro(abierto);
    expect(abierto.esperado, closeTo((await db.obtenerResumenCaja())['total_en_caja']!, 0.001));
    expect(abierto.base, 100000, reason: 'solo la base de la apertura');
    expect(abierto.ventasEfectivo, 8000, reason: '10.000 - 2.000 devueltos en el mismo turno');
    expect(abierto.ventasPorMedio['Transferencia'], 8000);
    expect(abierto.ventasPorMedio['Nequi'], 2000);
    expect(abierto.ventasTotal, 18000);
    expect(abierto.ventasNoEfectivo, 10000);
    expect(abierto.pedidos, 3);
    expect(abierto.otrasEntradas, 2000);
    expect(abierto.compras, 5000);
    expect(abierto.gastos, 3000);
    expect(abierto.devoluciones, 2000, reason: 'solo la del turno anterior');
    expect(abierto.declarado, isNull);
    expect(abierto.turno, 2);
    // 100.000 + 8.000 + 2.000 - 5.000 - 3.000 - 2.000
    expect(abierto.esperado, 100000);

    final res = await db.cerrarTurno(realContado: 99000, fechaInicio: '', usuarioId: 1);
    final cierre = Map<String, dynamic>.from(res['cierre'] as Map);
    final cerrado = await db.datosZDeCierre(cierre);
    reglaDeOro(cerrado);
    expect(cerrado.esperado, cierre['total_sistema']);
    expect(cerrado.declarado, 99000);
    expect(cerrado.diferencia, -1000);
    expect(cerrado.ventasTotal, abierto.ventasTotal);

    final antes = ReporteZ.lineas(ReporteZ.renglones(cerrado), 42).map((l) => l.texto).toList();
    // Después cambian datos: otra categoría, nuevas deudas, otro turno...
    final d = await db.database;
    await d.update('productos', {'categoria': 'Tubérculos'}, where: 'id = ?', whereArgs: [papa]);
    await d.update('clientes', {'deuda_actual': 77777});
    await db.registrarMovimientoCaja('APERTURA', 1000, 'Base', 1);
    await vender(2, 'EFECTIVO');
    final guardado = (await d.query('cierres_caja', where: 'id = ?', whereArgs: [cierre['id']])).single;
    final reimpreso = await db.datosZDeCierre(guardado);
    final despues = ReporteZ.lineas(ReporteZ.renglones(reimpreso), 42).map((l) => l.texto).toList();
    expect(despues, antes, reason: 'reimprimir un cierre viejo da exactamente lo mismo');
    // Los reportes que leen el desglose al final del detalle siguen funcionando
    expect(guardado['detalle'].toString(), contains('|METODOS:{'));
  });

  test('El detalle lista compras y gastos con su concepto y no incluye devoluciones', () async {
    await armarTurno();
    final z = (await db.datosZTurnoAbierto(usuarioId: 1))!;
    expect(z.detalle.length, 2);
    expect(z.detalle[0].esCompra, isTrue);
    expect(z.detalle[0].concepto, contains('Proveedor Andes'));
    expect(z.detalle[1].esCompra, isFalse);
    expect(z.detalle[1].concepto, startsWith('Aseo del local'));
    final texto = ReporteZ.lineas(ReporteZ.renglones(z), 42).map((l) => l.texto).join('\n');
    final i = texto.indexOf('DETALLE DE COMPRAS Y GASTOS');
    final f = texto.indexOf('OTROS DATOS');
    // Los conceptos largos van partidos en varios renglones: se leen juntos.
    final detalle = texto.substring(i, f).replaceAll(RegExp(r'\s+'), ' ');
    expect(detalle, contains('Compra: Mercancía (Proveedor Andes) \$5.000'));
    expect(detalle, contains('Gasto: Aseo del local y bolsas para la entrega de domicilios del sector norte \$3.000'));
    expect(detalle, contains('Gasto: Aseo del local'));
    expect(detalle.toLowerCase(), isNot(contains('devoluc')));
    expect(detalle, isNot(contains('Dañada')));
  });

  test('FALTANTE, SOBRANTE, CAJA CUADRADA y sin efectivo declarado', () {
    DatosZ z({double? declarado}) => DatosZ(
          negocio: 'X', caja: 'Caja 1', cajero: 'Ana', turno: 1, apertura: DateTime(2026, 10, 23, 7),
          cierre: declarado == null ? null : DateTime(2026, 10, 23, 19), base: 50000, pedidos: 1,
          ventasPorMedio: const {'Efectivo': 10000}, otrasEntradas: 0, compras: 0, gastos: 0,
          esperado: 60000, declarado: declarado, detalle: const [], ventaPorCategoria: const {},
          fiadoTurno: 0, saldoPorCobrar: 0,
        );
    List<String> grandes(DatosZ d) => ReporteZ.lineas(ReporteZ.renglones(d), 42)
        .where((l) => l.grande)
        .map((l) => l.texto.trim())
        .toList();
    expect(grandes(z(declarado: 55000)), ['FALTANTE DE \$5.000']);
    expect(grandes(z(declarado: 61500)), ['SOBRANTE DE \$1.500']);
    expect(grandes(z(declarado: 60000)), ['CAJA CUADRADA']);
    expect(grandes(z()), ['Sin efectivo', 'declarado']);
    final texto = ReporteZ.lineas(ReporteZ.renglones(z(declarado: 55000)), 42).map((l) => l.texto).join('\n');
    expect(texto, contains('-\$5.000'));
    final sinArqueo = ReporteZ.lineas(ReporteZ.renglones(z()), 42).map((l) => l.texto).join('\n');
    expect(sinArqueo, isNot(contains('DIFERENCIA')), reason: 'nunca una diferencia inventada');
  });

  test('Cada línea cabe exacta en 80 y 58 mm; los conceptos largos no se cortan', () async {
    await armarTurno();
    final z = (await db.datosZTurnoAbierto(usuarioId: 1))!;
    for (final ancho in [80, 58]) {
      final cols = ReporteZ.columnasPara(ancho);
      final lineas = ReporteZ.lineas(ReporteZ.renglones(z), cols);
      for (final l in lineas) {
        expect(l.texto.length, l.grande ? cols ~/ 2 : cols, reason: '"${l.texto}"');
      }
      final texto = lineas.map((l) => l.texto.trim()).join(' ');
      expect(texto, contains('Aseo del local y bolsas para la entrega de domicilios del sector norte'.split(' ').last));
      // El valor del gasto largo queda solo, a la derecha, en el renglón de abajo
      final idx = lineas.indexWhere((l) => l.texto.contains('norte'));
      expect(lineas[idx + 1].texto.trimLeft(), '\$3.000');
      expect(lineas[idx + 1].texto.endsWith('\$3.000'), isTrue);
      // Desglose con sangría de 4 espacios; Efectivo, Transferencia y Tarjeta siempre
      expect(lineas.any((l) => l.texto.startsWith('    Tarjeta') && l.texto.endsWith('\$0')), isTrue);
      expect(lineas.any((l) => l.texto.startsWith('    Nequi')), isTrue);
      expect(lineas.any((l) => l.texto.startsWith('    Daviplata')), isFalse, reason: 'solo si hubo');
      // El PDF se arma sin errores con esas líneas
      expect(PrinterService.pdfReporteZ(lineas, ancho), isNotNull);
    }
  });

  test('Montos: sin decimales, separador de miles y negativos con signo', () {
    expect(ReporteZ.pesos(0), '\$0');
    expect(ReporteZ.pesos(1500), '\$1.500');
    expect(ReporteZ.pesos(1234567.6), '\$1.234.568');
    expect(ReporteZ.pesos(-5000), '-\$5.000');
  });

  test('Un cierre de antes de esta versión (sin datos congelados) también cuadra', () async {
    await armarTurno();
    final res = await db.cerrarTurno(realContado: 100000, fechaInicio: '', usuarioId: 1);
    final cierre = Map<String, dynamic>.from(res['cierre'] as Map)
      ..['detalle'] = 'AJUSTE:NO|METODOS:{"EFECTIVO":8000}';
    final z = await db.datosZDeCierre(cierre);
    reglaDeOro(z);
    expect(z.esperado, cierre['total_sistema']);
    expect(z.declarado, 100000);
    expect(ReporteZ.lineas(ReporteZ.renglones(z), 42).where((l) => l.grande).single.texto.trim(), 'CAJA CUADRADA');
  });
}
