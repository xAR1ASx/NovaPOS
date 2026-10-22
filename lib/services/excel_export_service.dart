import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import '../database/db_helper.dart';
import 'finanzas_service.dart';

class ExcelExportService {
  ExcelExportService._();
  static final ExcelExportService _instance = ExcelExportService._();
  factory ExcelExportService() => _instance;

  /// Obtiene la carpeta oficial de exportación dentro de Documentos del usuario
  Future<Directory> obtenerCarpetaReportes() async {
    String rutaBase;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final docs = await getApplicationDocumentsDirectory();
      rutaBase = docs.path;
    } else {
      rutaBase = "/storage/emulated/0/Download";
      if (!Directory(rutaBase).existsSync()) {
        final ext = await getExternalStorageDirectory();
        rutaBase = ext?.path ?? "";
      }
    }
    final dir = Directory(p.join(rutaBase, 'NovaPOS_Reportes'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Guarda el archivo Excel en disco y retorna la ruta completa
  Future<String> _guardarArchivoExcel(Excel excel, String prefijo) async {
    final dir = await obtenerCarpetaReportes();
    final timeStamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final nombreArchivo = 'NovaPOS_${prefijo}_$timeStamp.xlsx';
    final rutaCompleta = p.join(dir.path, nombreArchivo);
    final file = File(rutaCompleta);
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return rutaCompleta;
  }

  /// Abre la carpeta en el explorador de Windows resaltando el archivo generado
  Future<void> abrirCarpetaEnExplorador(String rutaArchivo) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', rutaArchivo]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', rutaArchivo]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [p.dirname(rutaArchivo)]);
      }
    } catch (e) {
      debugPrint('Error abriendo explorador de archivos: $e');
    }
  }

  // ==============================================================
  // 1. EXPORTAR INVENTARIO VALORIZADO COMPLETO
  // ==============================================================
  Future<String> exportarInventario() async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Inventario';
    final sheet = excel[sheetName];

    // Encabezados
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Producto'),
      TextCellValue('Código PLU'),
      TextCellValue('Código Barras'),
      TextCellValue('Categoría'),
      TextCellValue('Tipo Venta'),
      TextCellValue('Stock Actual'),
      TextCellValue('Costo Unitario (\$)'),
      TextCellValue('Precio Venta (\$)'),
      TextCellValue('Margen (%)'),
      TextCellValue('Valor Costo Total (\$)'),
      TextCellValue('Valor Venta Total (\$)'),
      TextCellValue('Favorito Top 12'),
      TextCellValue('Estado'),
    ]);

    final productos = await DBHelper().obtenerTodoElInventario();
    double totalStock = 0;
    double totalValorCosto = 0;
    double totalValorVenta = 0;

    for (final p in productos) {
      final stock = (p['stock_actual'] as num?)?.toDouble() ?? 0.0;
      final costo = (p['precio_costo'] as num?)?.toDouble() ?? 0.0;
      final venta = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
      final esPesable = (p['es_pesable'] == 1) ? 'Báscula (Kg)' : 'Unidad';
      final esFavorito = (p['es_favorito'] == 1) ? 'SÍ' : 'NO';
      final estado = (p['esta_activo'] == 1) ? 'ACTIVO' : 'INACTIVO';

      final margen = venta > 0 ? ((venta - costo) / venta) * 100 : 0.0;
      final valorCostoItem = stock * costo;
      final valorVentaItem = stock * venta;

      totalStock += stock;
      totalValorCosto += valorCostoItem;
      totalValorVenta += valorVentaItem;

      sheet.appendRow([
        IntCellValue(p['id'] as int? ?? 0),
        TextCellValue(p['nombre']?.toString() ?? ''),
        TextCellValue(p['codigo_plu']?.toString() ?? ''),
        TextCellValue(p['codigo_barras']?.toString() ?? ''),
        TextCellValue(p['categoria']?.toString() ?? 'General'),
        TextCellValue(esPesable),
        DoubleCellValue(stock),
        DoubleCellValue(costo),
        DoubleCellValue(venta),
        DoubleCellValue(double.parse(margen.toStringAsFixed(1))),
        DoubleCellValue(valorCostoItem),
        DoubleCellValue(valorVentaItem),
        TextCellValue(esFavorito),
        TextCellValue(estado),
      ]);
    }

    // Fila resumen
    sheet.appendRow([
      TextCellValue('TOTALES'),
      TextCellValue('${productos.length} referencias'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalStock),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalValorCosto),
      DoubleCellValue(totalValorVenta),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    return await _guardarArchivoExcel(excel, 'Inventario_Valorizado');
  }

  // ==============================================================
  // 2. EXPORTAR VENTAS DETALLADAS ÍTEM POR ÍTEM
  // ==============================================================
  Future<String> exportarVentasDetalladas() async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Ventas_Detalladas';
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('ID Venta'),
      TextCellValue('Fecha y Hora'),
      TextCellValue('Método de Pago'),
      TextCellValue('Producto'),
      TextCellValue('Cantidad / Kilos'),
      TextCellValue('Precio Unitario (\$)'),
      TextCellValue('Subtotal (\$)'),
    ]);

    final data = await DBHelper().obtenerVentasDetalladasExportar();
    double totalCantidad = 0;
    double totalVentas = 0;

    for (final v in data) {
      final cant = (v['cantidad'] as num?)?.toDouble() ?? 0.0;
      final precio = (v['precio_unitario'] as num?)?.toDouble() ?? 0.0;
      final subtotal = (v['subtotal'] as num?)?.toDouble() ?? 0.0;

      totalCantidad += cant;
      totalVentas += subtotal;

      sheet.appendRow([
        IntCellValue(v['venta_id'] as int? ?? 0),
        TextCellValue(v['fecha']?.toString() ?? ''),
        TextCellValue(v['metodo_pago']?.toString() ?? 'EFECTIVO'),
        TextCellValue(v['nombre_producto']?.toString() ?? ''),
        DoubleCellValue(cant),
        DoubleCellValue(precio),
        DoubleCellValue(subtotal),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('${data.length} líneas'),
      DoubleCellValue(totalCantidad),
      TextCellValue(''),
      DoubleCellValue(totalVentas),
    ]);

    return await _guardarArchivoExcel(excel, 'Ventas_Detalladas');
  }

  // ==============================================================
  // 3. EXPORTAR COMPRAS DETALLADAS
  // ==============================================================
  Future<String> exportarCompras() async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Compras';
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('ID Compra'),
      TextCellValue('Fecha y Hora'),
      TextCellValue('Proveedor / Central'),
      TextCellValue('Producto'),
      TextCellValue('Cantidad / Kilos'),
      TextCellValue('Costo Unitario (\$)'),
      TextCellValue('Subtotal (\$)'),
    ]);

    final data = await DBHelper().obtenerComprasDetalladasExportar();
    double totalCosto = 0;

    for (final c in data) {
      final cant = (c['cantidad'] as num?)?.toDouble() ?? 0.0;
      final costo = (c['costo_unitario'] as num?)?.toDouble() ?? 0.0;
      final subtotal = (c['subtotal'] as num?)?.toDouble() ?? 0.0;
      totalCosto += subtotal;

      sheet.appendRow([
        IntCellValue(c['compra_id'] as int? ?? 0),
        TextCellValue(c['fecha']?.toString() ?? ''),
        TextCellValue(c['proveedor']?.toString() ?? 'General'),
        TextCellValue(c['nombre_producto']?.toString() ?? ''),
        DoubleCellValue(cant),
        DoubleCellValue(costo),
        DoubleCellValue(subtotal),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('${data.length} compras'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalCosto),
    ]);

    return await _guardarArchivoExcel(excel, 'Compras_Proveedores');
  }

  // ==============================================================
  // 4. EXPORTAR MERMAS Y PÉRDIDAS DE INVENTARIO
  // ==============================================================
  Future<String> exportarMermas() async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Mermas';
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Fecha y Hora'),
      TextCellValue('Producto'),
      TextCellValue('Cantidad de Baja (Kg/Und)'),
      TextCellValue('Costo Unitario (\$)'),
      TextCellValue('Total Pérdida (\$)'),
      TextCellValue('Motivo'),
    ]);

    final mermas = await DBHelper().obtenerMermas();
    double totalPerdidas = 0;
    double totalCantidad = 0;

    for (final m in mermas) {
      final cant = (m['cantidad'] as num?)?.toDouble() ?? 0.0;
      final costo = (m['costo_unitario'] as num?)?.toDouble() ?? 0.0;
      final perdida = (m['total_perdida'] as num?)?.toDouble() ?? 0.0;
      totalCantidad += cant;
      totalPerdidas += perdida;

      sheet.appendRow([
        IntCellValue(m['id'] as int? ?? 0),
        TextCellValue(m['fecha']?.toString() ?? ''),
        TextCellValue(m['nombre_producto']?.toString() ?? ''),
        DoubleCellValue(cant),
        DoubleCellValue(costo),
        DoubleCellValue(perdida),
        TextCellValue(m['motivo']?.toString() ?? 'Desperdicio'),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTALES'),
      TextCellValue(''),
      TextCellValue('${mermas.length} registros'),
      DoubleCellValue(totalCantidad),
      TextCellValue(''),
      DoubleCellValue(totalPerdidas),
      TextCellValue(''),
    ]);

    return await _guardarArchivoExcel(excel, 'Mermas_Desperdicios');
  }

  // ==============================================================
  // 5. EXPORTAR RESUMEN FINANCIERO Y ESTADO DE RESULTADOS
  // ==============================================================
  Future<String> exportarResumenFinanciero({
    required Map<String, double> hoy,
    required Map<String, double> mes,
    required Map<String, double> anio,
    required double inventarioValor,
    required double cartera,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Estado_Resultados';
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('Concepto Financiero'),
      TextCellValue('HOY (\$)'),
      TextCellValue('ESTE MES (\$)'),
      TextCellValue('ESTE AÑO (\$)'),
    ]);

    void agregarFila(String concepto, String key) {
      sheet.appendRow([
        TextCellValue(concepto),
        DoubleCellValue(hoy[key] ?? 0.0),
        DoubleCellValue(mes[key] ?? 0.0),
        DoubleCellValue(anio[key] ?? 0.0),
      ]);
    }

    agregarFila('Ventas Brutas', 'ventas');
    agregarFila('(-) Costo de Mercancía Vendida', 'costos');
    agregarFila('(=) Utilidad Bruta', 'utilidad_bruta');
    agregarFila('(-) Gastos Operativos', 'gastos');
    agregarFila('(-) Mermas y Desperdicios', 'mermas');
    agregarFila('(=) UTILIDAD NETA REAL', 'utilidad_neta');

    sheet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('Indicadores de Balance'),
      TextCellValue('Valor (\$)'),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('Inventario Total Valorizado al Costo'),
      DoubleCellValue(inventarioValor),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('Cartera / Cuentas por Cobrar (Fiados)'),
      DoubleCellValue(cartera),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    return await _guardarArchivoExcel(excel, 'Resumen_Financiero');
  }

  // ==============================================================
  // 5B. INFORME FINANCIERO MULTI-HOJA DEL PERÍODO
  // ==============================================================
  Future<Excel> construirInformePeriodoExcel({
    required FinanzasService fin,
    required Periodo periodo,
    int? usuarioId,
    String? nombreCajero,
  }) async {
    final res = await fin.resultados(periodo, usuarioId: usuarioId);
    final gas = await fin.gastosCompras(periodo, usuarioId: usuarioId);
    final rent = await fin.rentabilidad(periodo, usuarioId: usuarioId);
    final ctrl = await fin.control(periodo, usuarioId: usuarioId);
    final cierres = await fin.cierresDe(periodo, usuarioId: usuarioId);
    final top = await fin.topProductos(periodo, usuarioId: usuarioId, limite: 30);

    final excel = Excel.createExcel();
    final fFecha = DateFormat('yyyy-MM-dd');
    final fFechaHora = DateFormat('yyyy-MM-dd HH:mm');
    final def = excel.getDefaultSheet() ?? 'Sheet1';
    if (def != 'Resultados') {
      excel.rename(def, 'Resultados');
    }

    // 1. Hoja Resultados
    final sRes = excel['Resultados'];
    sRes.appendRow([
      TextCellValue('Período'),
      TextCellValue('${fFecha.format(periodo.desde)} a ${fFecha.format(periodo.hasta)} (${periodo.dias} días)'),
      TextCellValue('Cajero'),
      TextCellValue(nombreCajero ?? 'Todos los cajeros'),
    ]);
    sRes.appendRow([TextCellValue('')]);
    sRes.appendRow([
      TextCellValue('Concepto'),
      TextCellValue('Valor (\$)'),
      TextCellValue('Detalle'),
    ]);
    void filaRes(String c, double v, [String det = '']) {
      sRes.appendRow([TextCellValue(c), DoubleCellValue(v), TextCellValue(det)]);
    }

    filaRes('Ventas netas', res.ventas, '${res.cantidadVentas} ventas · ticket promedio \$${res.ticketPromedio.round()}');
    filaRes('(-) Costo de lo vendido', res.costoVentas);
    filaRes('(=) Utilidad bruta', res.utilidadBruta, 'Margen bruto ${res.margenBruto.toStringAsFixed(1)} %');
    filaRes('(-) Gastos operativos', res.gastos);
    filaRes('(-) Mermas y desperdicios', res.mermas);
    filaRes('(-) Faltantes de caja', res.faltantesCaja);
    filaRes('(+) Sobrantes de caja', res.sobrantesCaja);
    filaRes('(=) UTILIDAD NETA', res.utilidadNeta, 'Margen neto ${res.margenNeto.toStringAsFixed(1)} %');
    filaRes('Ventas período anterior', res.ventasAnterior);
    filaRes('Utilidad neta período anterior', res.utilidadAnterior);

    sRes.appendRow([TextCellValue('')]);
    sRes.appendRow([
      TextCellValue('Otros movimientos (no restan utilidad directamente)'),
      TextCellValue('Valor (\$)'),
      TextCellValue('Detalle'),
    ]);
    filaRes('Compras de mercancía', res.compras, '${res.cantidadCompras} facturas');
    filaRes('Vendido fiado (crédito)', res.ventasFiadas);
    filaRes('Abonos de clientes', res.abonosClientes);
    filaRes('Devoluciones', res.devoluciones, '${res.cantidadDevoluciones} artículos');
    filaRes('Ventas anuladas', res.anuladas, '${res.cantidadAnuladas} ventas');
    filaRes('Préstamos desde caja', res.prestamos);
    filaRes('Retiros del dueño', res.retiros);
    filaRes('Ventas sin costo registrado', res.ventasSinCosto);

    sRes.appendRow([TextCellValue('')]);
    sRes.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Ventas (\$)'),
      TextCellValue('Costo (\$)'),
      TextCellValue('Gastos (\$)'),
      TextCellValue('Mermas (\$)'),
      TextCellValue('Utilidad (\$)'),
    ]);
    for (final d in res.diario) {
      sRes.appendRow([
        TextCellValue(fFecha.format(d.fecha)),
        DoubleCellValue(d.ventas),
        DoubleCellValue(d.costo),
        DoubleCellValue(d.gastos),
        DoubleCellValue(d.mermas),
        DoubleCellValue(d.utilidad),
      ]);
    }

    // 2. Hoja Gastos y Compras
    final sGas = excel['Gastos_y_Compras'];
    sGas.appendRow([TextCellValue('Flujo de efectivo'), TextCellValue('Monto (\$)')]);
    sGas.appendRow([TextCellValue('(+) Ventas cobradas en efectivo'), DoubleCellValue(gas.entroVentas)]);
    sGas.appendRow([TextCellValue('(+) Abonos de clientes'), DoubleCellValue(gas.entroAbonos)]);
    sGas.appendRow([TextCellValue('(+) Bases extra, aportes y otros ingresos'), DoubleCellValue(gas.entroOtros)]);
    sGas.appendRow([TextCellValue('(=) Total entradas'), DoubleCellValue(gas.totalEntradas)]);
    sGas.appendRow([TextCellValue('(-) Gastos operativos'), DoubleCellValue(gas.salioGastos)]);
    sGas.appendRow([TextCellValue('(-) Compras pagadas con caja'), DoubleCellValue(gas.salioCompras)]);
    sGas.appendRow([TextCellValue('(-) Devoluciones y anulaciones en efectivo'), DoubleCellValue(gas.salioDevoluciones)]);
    sGas.appendRow([TextCellValue('(-) Préstamos y retiros'), DoubleCellValue(gas.salioPrestamosRetiros)]);
    sGas.appendRow([TextCellValue('(=) Total salidas'), DoubleCellValue(gas.totalSalidas)]);
    sGas.appendRow([TextCellValue('(=) FLUJO NETO DE EFECTIVO'), DoubleCellValue(gas.flujoNeto)]);

    sGas.appendRow([TextCellValue('')]);
    sGas.appendRow([TextCellValue('Medio de pago'), TextCellValue('Operaciones'), TextCellValue('Total (\$)')]);
    for (final m in gas.metodosPago) {
      sGas.appendRow([TextCellValue(m.nombre), IntCellValue(m.cantidad), DoubleCellValue(m.total)]);
    }

    sGas.appendRow([TextCellValue('')]);
    sGas.appendRow([TextCellValue('Categoría de gasto'), TextCellValue('Movimientos'), TextCellValue('Total (\$)')]);
    for (final c in gas.gastosPorCategoria) {
      sGas.appendRow([TextCellValue(c.nombre), IntCellValue(c.cantidad), DoubleCellValue(c.total)]);
    }

    sGas.appendRow([TextCellValue('')]);
    sGas.appendRow([TextCellValue('Proveedor'), TextCellValue('Facturas'), TextCellValue('Total compras (\$)')]);
    for (final p in gas.comprasPorProveedor) {
      sGas.appendRow([TextCellValue(p.nombre), IntCellValue(p.cantidad), DoubleCellValue(p.total)]);
    }

    sGas.appendRow([TextCellValue('')]);
    sGas.appendRow([
      TextCellValue('Fecha y Hora'),
      TextCellValue('Categoría'),
      TextCellValue('Descripción'),
      TextCellValue('Registró'),
      TextCellValue('Monto (\$)'),
    ]);
    for (final g in gas.gastos) {
      sGas.appendRow([
        TextCellValue(g.fecha == null ? '' : fFechaHora.format(g.fecha!)),
        TextCellValue(g.categoria),
        TextCellValue(g.descripcion),
        TextCellValue(g.usuario),
        DoubleCellValue(g.monto),
      ]);
    }

    // 3. Hoja Rentabilidad y Ventas
    final sRent = excel['Rentabilidad'];
    sRent.appendRow([
      TextCellValue('Categoría'),
      TextCellValue('Cantidad'),
      TextCellValue('Ventas (\$)'),
      TextCellValue('Costo (\$)'),
      TextCellValue('Utilidad (\$)'),
      TextCellValue('Margen (%)'),
      TextCellValue('Estado costo'),
    ]);
    for (final c in rent.categorias) {
      sRent.appendRow([
        TextCellValue(c.nombre),
        DoubleCellValue(c.cantidad),
        DoubleCellValue(c.ventas),
        DoubleCellValue(c.costo),
        DoubleCellValue(c.utilidad),
        DoubleCellValue(double.parse(c.margen.toStringAsFixed(1))),
        TextCellValue(c.sinCosto ? 'Costo incompleto' : 'OK'),
      ]);
    }

    sRent.appendRow([TextCellValue('')]);
    sRent.appendRow([
      TextCellValue('Producto'),
      TextCellValue('Cantidad'),
      TextCellValue('Ventas (\$)'),
      TextCellValue('Costo (\$)'),
      TextCellValue('Utilidad (\$)'),
      TextCellValue('Margen (%)'),
      TextCellValue('Estado costo'),
    ]);
    final prodsOrdenados = List.of(rent.productos)..sort((a, b) => b.utilidad.compareTo(a.utilidad));
    for (final p in prodsOrdenados) {
      sRent.appendRow([
        TextCellValue(p.nombre),
        DoubleCellValue(p.cantidad),
        DoubleCellValue(p.ventas),
        DoubleCellValue(p.costo),
        DoubleCellValue(p.utilidad),
        DoubleCellValue(double.parse(p.margen.toStringAsFixed(1))),
        TextCellValue(p.sinCosto ? 'Sin costo registrado' : 'OK'),
      ]);
    }

    if (top.isNotEmpty) {
      sRent.appendRow([TextCellValue('')]);
      sRent.appendRow([
        TextCellValue('#'),
        TextCellValue('Más vendidos'),
        TextCellValue('Cantidad'),
        TextCellValue('Ventas (\$)'),
      ]);
      for (var i = 0; i < top.length; i++) {
        final t = top[i];
        sRent.appendRow([
          IntCellValue(i + 1),
          TextCellValue((t['nombre_producto'] ?? '').toString()),
          DoubleCellValue((t['cantidad_total'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((t['dinero_total'] as num?)?.toDouble() ?? 0),
        ]);
      }
    }

    // 4. Hoja Control
    final sCtrl = excel['Control'];
    sCtrl.appendRow([
      TextCellValue('Persona'),
      TextCellValue('Anulaciones'),
      TextCellValue('Devoluciones'),
      TextCellValue('Mermas'),
      TextCellValue('Descuadres'),
      TextCellValue('Monto Total (\$)'),
    ]);
    for (final p in ctrl.porPersona) {
      sCtrl.appendRow([
        TextCellValue(p.usuario),
        IntCellValue(p.porTipo['ANULACION'] ?? 0),
        IntCellValue(p.porTipo['DEVOLUCION'] ?? 0),
        IntCellValue(p.porTipo['MERMA'] ?? 0),
        IntCellValue(p.porTipo['DESCUADRE'] ?? 0),
        DoubleCellValue(p.monto),
      ]);
    }

    sCtrl.appendRow([TextCellValue('')]);
    sCtrl.appendRow([
      TextCellValue('Fecha y Hora'),
      TextCellValue('Tipo'),
      TextCellValue('Título'),
      TextCellValue('Detalle'),
      TextCellValue('Persona'),
      TextCellValue('Motivo'),
      TextCellValue('Monto (\$)'),
      TextCellValue('Efectivo (\$)'),
    ]);
    for (final e in ctrl.eventos) {
      sCtrl.appendRow([
        TextCellValue(e.fecha == null ? '' : fFechaHora.format(e.fecha!)),
        TextCellValue(e.tipo),
        TextCellValue(e.titulo),
        TextCellValue(e.detalle),
        TextCellValue(e.usuario),
        TextCellValue(e.motivo),
        DoubleCellValue(e.monto),
        DoubleCellValue(e.efectivo),
      ]);
    }

    // 5. Hoja Cierres
    final sCie = excel['Cierres'];
    sCie.appendRow([
      TextCellValue('Cajero'),
      TextCellValue('Turnos'),
      TextCellValue('Cuadrados'),
      TextCellValue('Faltante (\$)'),
      TextCellValue('Sobrante (\$)'),
      TextCellValue('Neto (\$)'),
      TextCellValue('Ventas Efectivo (\$)'),
    ]);
    for (final p in cierres.porCajero) {
      sCie.appendRow([
        TextCellValue(p.cajero),
        IntCellValue(p.turnos),
        IntCellValue(p.cuadrados),
        DoubleCellValue(p.faltante),
        DoubleCellValue(p.sobrante),
        DoubleCellValue(p.neto),
        DoubleCellValue(p.ventas),
      ]);
    }

    sCie.appendRow([TextCellValue('')]);
    sCie.appendRow([
      TextCellValue('ID'),
      TextCellValue('Cajero'),
      TextCellValue('Caja'),
      TextCellValue('Apertura'),
      TextCellValue('Cierre'),
      TextCellValue('Estado'),
      TextCellValue('Base (\$)'),
      TextCellValue('Ventas Efectivo (\$)'),
      TextCellValue('Ingresos (\$)'),
      TextCellValue('Gastos (\$)'),
      TextCellValue('Esperado (\$)'),
      TextCellValue('Contado (\$)'),
      TextCellValue('Diferencia (\$)'),
    ]);
    for (final c in cierres.cierres) {
      sCie.appendRow([
        IntCellValue(c.id),
        TextCellValue(c.cajero),
        TextCellValue(c.caja),
        TextCellValue(c.apertura == null ? '' : fFechaHora.format(c.apertura!)),
        TextCellValue(c.cierre == null ? 'En curso' : fFechaHora.format(c.cierre!)),
        TextCellValue(c.estado),
        DoubleCellValue(c.base),
        DoubleCellValue(c.ventas),
        DoubleCellValue(c.ingresos),
        DoubleCellValue(c.gastos),
        DoubleCellValue(c.esperado),
        DoubleCellValue(c.contado ?? 0),
        DoubleCellValue(c.diferencia ?? 0),
      ]);
    }

    return excel;
  }

  Future<String> exportarInformePeriodo({
    required FinanzasService fin,
    required Periodo periodo,
    int? usuarioId,
    String? nombreCajero,
  }) async {
    final excel = await construirInformePeriodoExcel(
      fin: fin,
      periodo: periodo,
      usuarioId: usuarioId,
      nombreCajero: nombreCajero,
    );
    return await _guardarArchivoExcel(excel, 'Informe_Periodo');
  }

  // ==============================================================
  // 6. MODAL INTERACTIVO DE EXPORTACIÓN (Para Reportes y Ajustes)
  // ==============================================================
  Future<void> mostrarModalExportacion(
    BuildContext context, {
    Map<String, double>? hoy,
    Map<String, double>? mes,
    Map<String, double>? anio,
    double? inventarioValor,
    double? cartera,
  }) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.table_chart_rounded,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Exportar a Microsoft Excel (.xlsx)",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1F2B),
                          ),
                        ),
                        Text(
                          "Selecciona el reporte oficial que deseas generar",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _opcionExportar(
                context: ctx,
                icono: Icons.inventory_2_outlined,
                colorIcono: Colors.blue,
                titulo: "Inventario Valorizado",
                subtitulo: "Stock actual, costos, precios, márgenes y valor total",
                onTap: () async {
                  Navigator.pop(ctx);
                  _ejecutarExportacion(
                    context,
                    titulo: "Inventario Valorizado",
                    accion: () => exportarInventario(),
                  );
                },
              ),
              _opcionExportar(
                context: ctx,
                icono: Icons.point_of_sale_outlined,
                colorIcono: Colors.green,
                titulo: "Ventas Detalladas",
                subtitulo: "Desglose ítem por ítem con método de pago y fecha",
                onTap: () async {
                  Navigator.pop(ctx);
                  _ejecutarExportacion(
                    context,
                    titulo: "Ventas Detalladas",
                    accion: () => exportarVentasDetalladas(),
                  );
                },
              ),
              if (hoy != null && mes != null && anio != null)
                _opcionExportar(
                  context: ctx,
                  icono: Icons.analytics_outlined,
                  colorIcono: Colors.purple,
                  titulo: "Estado de Resultados y Utilidades",
                  subtitulo: "P&L comparativo (Hoy, Mes, Año) restando mermas y gastos",
                  onTap: () async {
                    Navigator.pop(ctx);
                    _ejecutarExportacion(
                      context,
                      titulo: "Resumen Financiero",
                      accion: () => exportarResumenFinanciero(
                        hoy: hoy,
                        mes: mes,
                        anio: anio,
                        inventarioValor: inventarioValor ?? 0,
                        cartera: cartera ?? 0,
                      ),
                    );
                  },
                ),
              _opcionExportar(
                context: ctx,
                icono: Icons.delete_sweep_outlined,
                colorIcono: Colors.deepOrange,
                titulo: "Mermas y Pérdidas",
                subtitulo: "Historial de fruta y verdura dada de baja por daño o madurez",
                onTap: () async {
                  Navigator.pop(ctx);
                  _ejecutarExportacion(
                    context,
                    titulo: "Mermas y Pérdidas",
                    accion: () => exportarMermas(),
                  );
                },
              ),
              _opcionExportar(
                context: ctx,
                icono: Icons.local_shipping_outlined,
                colorIcono: Colors.teal,
                titulo: "Compras a Proveedores",
                subtitulo: "Registro de ingresos de mercancía por proveedor y costo",
                onTap: () async {
                  Navigator.pop(ctx);
                  _ejecutarExportacion(
                    context,
                    titulo: "Compras a Proveedores",
                    accion: () => exportarCompras(),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _opcionExportar({
    required BuildContext context,
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: colorIcono.withOpacity(0.12),
          child: Icon(icono, color: colorIcono, size: 22),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitulo,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  Future<void> ejecutarExportacion(
    BuildContext context, {
    required String titulo,
    required Future<String> Function() accion,
  }) =>
      _ejecutarExportacion(context, titulo: titulo, accion: accion);

  Future<void> _ejecutarExportacion(
    BuildContext context, {
    required String titulo,
    required Future<String> Function() accion,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(width: 20),
            Expanded(child: Text("Generando Excel de $titulo...")),
          ],
        ),
      ),
    );

    try {
      final ruta = await accion();
      if (!context.mounted) return;
      Navigator.pop(context); // Cierra diálogo progreso

      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text("¡Reporte Generado!"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "El archivo Excel de $titulo se guardó exitosamente.",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  ruta,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Color(0xFF1A1F2B),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("CERRAR"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text("ABRIR CARPETA"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(c);
                abrirCarpetaEnExplorador(ruta);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Error exportando"),
          content: Text("Ocurrió un error al generar el archivo: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }
}
