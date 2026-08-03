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
    String empresa = config['empresa_nombre'] ?? "MI FRUVER POS";
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
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Ticket_${venta['id']}',
    );
  }
}
