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

  Future<void> imprimirTicket(
    Map<String, dynamic> venta,
    List<Map<String, dynamic>> productos,
  ) async {
    // 1. Datos del Negocio
    final config = await DBHelper().obtenerConfiguracion();
    String empresa = config['empresa_nombre'] ?? "NovaPOS";
    String nit = config['empresa_nit'] ?? "NIT: 000000000";
    String dir = config['empresa_direccion'] ?? "Ciudad";

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
              ),
              pw.Text(nit, style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                dir,
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.center,
              ),
              pw.Divider(),

              // INFO VENTA
              pw.Row(
                // 🔥 CORRECCIÓN 1: Usamos MainAxisAlignment en lugar de RowAlignment
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Ticket #${venta['id']}",
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    DateFormat('dd/MM HH:mm').format(DateTime.now()),
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
                        p['nombre'],
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
                      formater.format(p['subtotal']),
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
                // 🔥 CORRECCIÓN 2: MainAxisAlignment aquí también
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
                "Metodo Pago: ${venta['metodo_pago']}",
                style: const pw.TextStyle(fontSize: 10),
              ),

              pw.SizedBox(height: 15),
              // 🔥 CORRECCIÓN 3: Quitamos el 'const' para evitar el error de expresión
              pw.Text(
                "¡Gracias por su compra!",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.SizedBox(height: 20),
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
