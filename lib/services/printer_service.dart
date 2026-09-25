import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class PrinterService {
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  String _formatearMetodoPagoTicket(Map<String, dynamic> venta) {
    final metodo = venta['metodo_pago']?.toString() ?? 'EFECTIVO';
    if (metodo == 'MIXTO') {
      final detalle = venta['metodo_pago_detalle']?.toString();
      if (detalle != null && detalle.isNotEmpty) {
        try {
          final m = jsonDecode(detalle);
          if (m is Map) {
            final ef = (m['efectivo'] as num?)?.toDouble() ?? 0;
            final dig = (m['digital'] as num?)?.toDouble() ?? 0;
            final nomDig = m['metodo_digital']?.toString() ?? 'DIGITAL';
            return "Metodo Pago: MIXTO\n  Efectivo: ${formater.format(ef)}\n  $nomDig: ${formater.format(dig)}";
          }
        } catch (_) {}
      }
    }
    return "Metodo Pago: $metodo";
  }

  Future<void> imprimirTicket(
    Map<String, dynamic> venta,
    List<Map<String, dynamic>> productos,
  ) async {
    // 1. Datos del Negocio
    final config = await DBHelper().obtenerConfiguracion();
    String empresa = (config['empresa_nombre'] ?? '').trim();
    if (empresa.isEmpty) empresa = "NovaPOS";

    String nit = (config['empresa_nit'] ?? '').trim();
    String regimen = (config['empresa_regimen'] ?? '').trim();
    String dir = (config['empresa_direccion'] ?? '').trim();
    String ciudad = (config['empresa_ciudad'] ?? '').trim();
    String tel = (config['empresa_telefono'] ?? '').trim();
    String mensajePie = (config['ticket_mensaje_pie'] ?? '').trim();
    if (mensajePie.isEmpty) mensajePie = "¡Gracias por su compra!";
    String leyenda = (config['ticket_leyenda'] ?? '').trim();

    // 2. Crear Documento PDF (Formato Ticket)
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Rollo estándar de 80mm
        margin: const pw.EdgeInsets.all(5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // ENCABEZADO
              pw.Text(
                empresa,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (nit.isNotEmpty)
                pw.Text(nit, style: const pw.TextStyle(fontSize: 10)),
              if (regimen.isNotEmpty)
                pw.Text(regimen, style: const pw.TextStyle(fontSize: 9)),
              if (dir.isNotEmpty)
                pw.Text(
                  dir,
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              if (ciudad.isNotEmpty)
                pw.Text(ciudad, style: const pw.TextStyle(fontSize: 9)),
              if (tel.isNotEmpty)
                pw.Text(tel, style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),

              // INFO VENTA
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Ticket #${venta['id']}",
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Divider(),

              // PRODUCTOS - Encabezados
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      "Prod",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  pw.Text(
                    "Cant",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    "Total",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),

              // Lista de Productos
              ...productos.map((p) {
                return pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        p['nombre']?.toString() ?? '',
                        style: const pw.TextStyle(fontSize: 9),
                        maxLines: 2,
                      ),
                    ),
                    pw.Text(
                      "${p['cantidad']} ",
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      formater.format(p['subtotal'] ?? 0),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ],
                );
              }),

              pw.Divider(),

              // TOTALES
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "TOTAL:",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  pw.Text(
                    formater.format(venta['total']),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                _formatearMetodoPagoTicket(venta),
                style: const pw.TextStyle(fontSize: 10),
              ),

              pw.SizedBox(height: 12),
              pw.Text(
                mensajePie,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (leyenda.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  leyenda,
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              pw.SizedBox(height: 15),
            ],
          );
        },
      ),
    );

    // 3. Imprimir
    final directa = config['impresion_directa'] == '1';
    final impresoraNombre = config['impresora_nombre'] ?? '';

    if (directa && impresoraNombre.isNotEmpty) {
      await _imprimirDirecto(
        impresoras: await obtenerImpresoras(),
        impresoraNombre: impresoraNombre,
        doc: doc,
        nombreTicket: 'Ticket_${venta['id']}',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Ticket_${venta['id']}',
      );
    }
  }

  /// Imprime un borrador de prueba para que el comerciante verifique
  /// el encabezado, los datos tributarios, la alineación y el corte de papel.
  Future<void> imprimirTicketPrueba({
    Map<String, String>? datosPersonalizados,
  }) async {
    final config = await DBHelper().obtenerConfiguracion();

    String empresa = datosPersonalizados?['empresa_nombre']?.trim().isNotEmpty == true
        ? datosPersonalizados!['empresa_nombre']!
        : (config['empresa_nombre']?.trim().isNotEmpty == true
            ? config['empresa_nombre']!
            : "MI FRUVER & MINIMARKET");

    String nit = datosPersonalizados?['empresa_nit']?.trim().isNotEmpty == true
        ? datosPersonalizados!['empresa_nit']!
        : (config['empresa_nit']?.trim().isNotEmpty == true
            ? config['empresa_nit']!
            : "NIT: 900.123.456-7");

    String regimen = datosPersonalizados?['empresa_regimen']?.trim().isNotEmpty == true
        ? datosPersonalizados!['empresa_regimen']!
        : (config['empresa_regimen']?.trim().isNotEmpty == true
            ? config['empresa_regimen']!
            : "No Responsable de IVA (Régimen Simplificado)");

    String dir = datosPersonalizados?['empresa_direccion']?.trim().isNotEmpty == true
        ? datosPersonalizados!['empresa_direccion']!
        : (config['empresa_direccion']?.trim().isNotEmpty == true
            ? config['empresa_direccion']!
            : "Carrera 15 # 45-20 Barrio Centro");

    String ciudad = datosPersonalizados?['empresa_ciudad']?.trim().isNotEmpty == true
        ? datosPersonalizados!['empresa_ciudad']!
        : (config['empresa_ciudad']?.trim().isNotEmpty == true
            ? config['empresa_ciudad']!
            : "Bogotá D.C., Colombia");

    String tel = datosPersonalizados?['empresa_telefono']?.trim().isNotEmpty == true
        ? datosPersonalizados!['empresa_telefono']!
        : (config['empresa_telefono']?.trim().isNotEmpty == true
            ? config['empresa_telefono']!
            : "Tel / WhatsApp: 310 123 4567");

    String mensajePie = datosPersonalizados?['ticket_mensaje_pie']?.trim().isNotEmpty == true
        ? datosPersonalizados!['ticket_mensaje_pie']!
        : (config['ticket_mensaje_pie']?.trim().isNotEmpty == true
            ? config['ticket_mensaje_pie']!
            : "¡Gracias por su compra! Vuelva pronto");

    String leyenda = datosPersonalizados?['ticket_leyenda']?.trim().isNotEmpty == true
        ? datosPersonalizados!['ticket_leyenda']!
        : (config['ticket_leyenda']?.trim().isNotEmpty == true
            ? config['ticket_leyenda']!
            : "Documento equivalente POS - Sistema NovaPOS");

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                empresa,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (nit.isNotEmpty)
                pw.Text(nit, style: const pw.TextStyle(fontSize: 10)),
              if (regimen.isNotEmpty)
                pw.Text(regimen, style: const pw.TextStyle(fontSize: 9)),
              if (dir.isNotEmpty)
                pw.Text(
                  dir,
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              if (ciudad.isNotEmpty)
                pw.Text(ciudad, style: const pw.TextStyle(fontSize: 9)),
              if (tel.isNotEmpty)
                pw.Text(tel, style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Ticket #0001 (BORRADOR DE PRUEBA)",
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  "Cajero: Administrador | Caja: 01",
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Divider(),

              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      "Producto",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                  ),
                  pw.Text(
                    "Cant",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    "Total",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),

              // Renglones de prueba representativos de Fruver
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text("Tomate Chonto Limpio", style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Text("2.50 kg ", style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(width: 10),
                  pw.Text(formater.format(8000), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text("Manzana Royal Gala", style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Text("1.80 kg ", style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(width: 10),
                  pw.Text(formater.format(4500), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text("Aguacate Hass Maduro", style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Text("2.00 un ", style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(width: 10),
                  pw.Text(formater.format(5000), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.Divider(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text(formater.format(17500), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "Metodo Pago: EFECTIVO\n  Recibido: ${formater.format(20000)}\n  Cambio: ${formater.format(2500)}",
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 12),

              pw.Text(
                mensajePie,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (leyenda.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  leyenda,
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              pw.SizedBox(height: 15),
            ],
          );
        },
      ),
    );

    final directa = config['impresion_directa'] == '1';
    final impresoraNombre = config['impresora_nombre'] ?? '';

    if (directa && impresoraNombre.isNotEmpty) {
      await _imprimirDirecto(
        impresoras: await obtenerImpresoras(),
        impresoraNombre: impresoraNombre,
        doc: doc,
        nombreTicket: 'Ticket_Borrador_Prueba',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Ticket_Borrador_Prueba',
      );
    }
  }

  Future<void> imprimirArqueo(Map<String, dynamic> cierre) async {
    final config = await DBHelper().obtenerConfiguracion();
    String empresa = config['empresa_nombre'] ?? "NovaPOS";

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                empresa,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              pw.Text(
                "ARQUEO DE CAJA",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              pw.Text(
                DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Divider(),
              _filaArqueo("Base", (cierre['base'] ?? 0)),
              _filaArqueo("Ventas turno", (cierre['ventas_turno'] ?? 0)),
              _filaArqueo("Ventas global", (cierre['ventas_turno_global'] ?? 0)),
              _filaArqueo("Ingresos", (cierre['ingresos_turno'] ?? 0)),
              _filaArqueo("Gastos", (cierre['gastos_turno'] ?? 0)),
              _filaArqueo("Total sistema", (cierre['total_sistema'] ?? 0)),
              _filaArqueo("Real contado", (cierre['real_contado'] ?? 0)),
              _filaArqueo("Diferencia", (cierre['diferencia'] ?? 0)),
              pw.Divider(),
              pw.Text(
                "Estado: ${cierre['estado'] ?? ''}",
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    final directa = config['impresion_directa'] == '1';
    final impresoraNombre = config['impresora_nombre'] ?? '';
    final nombreDoc = 'Arqueo_${DateTime.now().millisecondsSinceEpoch}';

    if (directa && impresoraNombre.isNotEmpty) {
      await _imprimirDirecto(
        impresoras: await obtenerImpresoras(),
        impresoraNombre: impresoraNombre,
        doc: doc,
        nombreTicket: nombreDoc,
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: nombreDoc,
      );
    }
  }

  pw.Widget _filaArqueo(String label, dynamic valor) {
    double v = (valor as num?)?.toDouble() ?? 0;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(
            formater.format(v),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Lista los nombres de impresoras disponibles en Windows.
  Future<List<String>> obtenerImpresoras() async {
    try {
      final printers = await Printing.listPrinters();
      return printers.map((p) => p.name).where((n) => n.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  /// Imprime sin dialogo hacia la impresora elegida.
  Future<void> _imprimirDirecto({
    required List<String> impresoras,
    required String impresoraNombre,
    required pw.Document doc,
    required String nombreTicket,
  }) async {
    try {
      final printers = await Printing.listPrinters();
      if (printers.isEmpty) {
        throw Exception('No hay impresoras instaladas');
      }
      final printer = printers.firstWhere(
        (p) => p.name == impresoraNombre,
        // Si la impresora configurada no existe, no imprimir a otra en silencio
        orElse: () => throw Exception(
          'Impresora "$impresoraNombre" no encontrada',
        ),
      );

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: nombreTicket,
      );
    } catch (e) {
      // Si falla la impresion directa, caer al dialogo del sistema para que el
      // usuario elija la impresora correcta
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: nombreTicket,
      );
    }
  }
}
