import 'package:flutter/material.dart';
import '../services/printer_service.dart';
import '../services/reporte_z.dart';

/// Vista previa del Reporte Z: dibuja exactamente las mismas líneas que se
/// imprimen (ReporteZ.lineas), sobre un "papel" del ancho elegido.
class ReporteZVista extends StatelessWidget {
  final DatosZ datos;
  final int anchoMm;
  const ReporteZVista({super.key, required this.datos, required this.anchoMm});

  @override
  Widget build(BuildContext context) {
    final columnas = ReporteZ.columnasPara(anchoMm);
    final lineas = ReporteZ.lineas(ReporteZ.renglones(datos), columnas);
    const tam = 13.0;
    TextStyle estilo(LineaZ l) => TextStyle(
          fontFamily: 'Courier',
          fontFamilyFallback: const ['Consolas', 'Courier New', 'Menlo', 'monospace'],
          fontSize: l.grande ? tam * 2 : tam,
          height: 1.25,
          fontWeight: l.negrita ? FontWeight.bold : FontWeight.normal,
          color: Colors.black,
        );
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lineas) Text(l.texto, style: estilo(l), softWrap: false),
          ],
        ),
      ),
    );
  }
}

/// Muestra la vista previa del Reporte Z con el botón para imprimirlo.
Future<void> mostrarReporteZ(BuildContext context, DatosZ datos) async {
  var ancho = await PrinterService.anchoPapelMm();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long),
            const SizedBox(width: 8),
            Expanded(child: Text(datos.cierre == null ? 'Reporte Z (turno abierto)' : 'Reporte Z')),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 80, label: Text('80 mm')),
                ButtonSegment(value: 58, label: Text('58 mm')),
              ],
              selected: {ancho},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => ancho = s.first),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
            child: SingleChildScrollView(child: ReporteZVista(datos: datos, anchoMm: ancho)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          FilledButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Imprimir'),
            onPressed: () async {
              try {
                await PrinterService().imprimirReporteZ(datos, anchoMm: ancho);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('No se pudo imprimir: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    ),
  );
}
