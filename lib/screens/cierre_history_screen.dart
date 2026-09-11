import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/printer_service.dart';
import '../services/locale_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Detalle del Cierre': 'Closure Details',
  'Fecha': 'Date',
  'Estado': 'Status',
  'Base': 'Base',
  'Ventas turno': 'Shift Sales',
  'Ingresos turno': 'Shift Income',
  'Gastos turno': 'Shift Expenses',
  'Total sistema': 'System Total',
  'Real contado': 'Cash Counted',
  'Sobrante/Faltante': 'Surplus/Missing',
  'Detalle': 'Details',
  'IMPRIMIR ARQUEO': 'PRINT CASH COUNT',
  'Historial de Cierres': 'Closure History',
  'No hay cierres registrados': 'No closures recorded',
  'Real': 'Counted',
};

class CierreHistoryScreen extends StatefulWidget {
  const CierreHistoryScreen({super.key});

  @override
  State<CierreHistoryScreen> createState() => _CierreHistoryScreenState();
}

class _CierreHistoryScreenState extends State<CierreHistoryScreen> {
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  late Future<List<Map<String, dynamic>>> _cierres;

  @override
  void initState() {
    super.initState();
    _cierres = DBHelper().obtenerHistorialCierres();
  }

  void _verDetalle(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t("Detalle del Cierre"),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            _filaDetalle(
              _t("Fecha"),
              DateFormat('dd/MM/yyyy hh:mm a').format(
                DateTime.parse(c['fecha'] ?? DateTime.now().toIso8601String()),
              ),
            ),
            _filaDetalle(_t("Estado"), c['estado']?.toString() ?? ''),
            const Divider(),
            _filaDetalle(_t("Base"), formater.format(c['base'] ?? 0)),
            _filaDetalle(
              _t("Ventas turno"),
              formater.format(c['ventas_turno'] ?? 0),
            ),
            _filaDetalle(
              _t("Ingresos turno"),
              formater.format(c['ingresos_turno'] ?? 0),
            ),
            _filaDetalle(
              _t("Gastos turno"),
              formater.format(c['gastos_turno'] ?? 0),
            ),
            _filaDetalle(
              _t("Total sistema"),
              formater.format(c['total_sistema'] ?? 0),
            ),
            _filaDetalle(
              _t("Real contado"),
              formater.format(c['real_contado'] ?? 0),
            ),
            _filaDetalle(
              _t("Sobrante/Faltante"),
              formater.format(c['diferencia'] ?? 0),
            ),
            if (c['detalle'] != null && (c['detalle'] as String).isNotEmpty) ...[
              const SizedBox(height: 5),
              _filaDetalle(_t("Detalle"), c['detalle'].toString()),
            ],
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print, size: 18),
                label: Text(_t("IMPRIMIR ARQUEO")),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await PrinterService().imprimirArqueo(c);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaDetalle(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[700]),
          ),
          Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t("Historial de Cierres")),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cierres,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data ?? [];
          if (lista.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t("No hay cierres registrados"),
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final c = lista[index];
              double diferencia = (c['diferencia'] as num?)?.toDouble() ?? 0;
              String estado = c['estado']?.toString() ?? '';
              Color colorEstado = estado == "OK"
                  ? Colors.green
                  : (estado == "SOBRA" ? Colors.blue : Colors.red);

              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorEstado.withOpacity(0.1),
                    child: Icon(
                      estado == "OK"
                          ? Icons.check_circle
                          : (estado == "SOBRA"
                                ? Icons.trending_up
                                : Icons.warning),
                      color: colorEstado,
                    ),
                  ),
                  title: Text(
                    DateFormat('dd/MM/yyyy hh:mm a').format(
                      DateTime.parse(
                        c['fecha'] ?? DateTime.now().toIso8601String(),
                      ),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${_t('Base')}: ${formater.format(c['base'] ?? 0)}   "
                    "${_t('Real')}: ${formater.format(c['real_contado'] ?? 0)}",
                  ),
                  trailing: Text(
                    "${_t('Sobrante/Faltante')}: ${formater.format(diferencia)}",
                    style: TextStyle(
                      color: colorEstado,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => _verDetalle(c),
                ),
              );
            },
          );
        },
      ),
    );
  }
}