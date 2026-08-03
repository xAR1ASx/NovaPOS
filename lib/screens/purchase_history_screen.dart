import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  List<Map<String, dynamic>> _compras = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  void _cargarHistorial() async {
    final data = await DBHelper().obtenerHistorialCompras();
    if (mounted) {
      setState(() {
        _compras = data;
        _cargando = false;
      });
    }
  }

  void _verDetalle(Map<String, dynamic> compra) async {
    final detalles = await DBHelper().obtenerDetalleCompra(compra['id']);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ENCABEZADO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Compra #${compra['id']}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          compra['proveedor'] != null &&
                                  compra['proveedor'].toString().isNotEmpty
                              ? "Prov: ${compra['proveedor']}"
                              : "Proveedor: General",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),

              // LISTA DE PRODUCTOS
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: detalles.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final d = detalles[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "+${(d['cantidad'] as num).toInt()}", // Aseguramos que sea entero visualmente
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ),
                      title: Text(
                        d['nombre_producto'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Costo Unit: ${formater.format(d['costo_unitario'])}",
                      ),
                      trailing: Text(
                        formater.format(d['subtotal']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Divider(),

              // TOTAL
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.brown[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TOTAL PAGADO:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formater.format(compra['total']),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial de Compras"),
        backgroundColor: Colors.brown[800],
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _compras.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_edu, // Icono diferente para variar
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "No hay compras registradas aún",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _compras.length,
              itemBuilder: (context, index) {
                final c = _compras[index];

                // Lógica para saber si se pagó con caja
                bool pagadoConCaja = (c['pago_con_caja'] == 1);

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 5,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.brown[100],
                      child: Icon(Icons.inventory_2, color: Colors.brown[800]),
                    ),
                    title: Text(
                      "Compra #${c['id']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'dd/MM/yyyy - hh:mm a',
                          ).format(DateTime.parse(c['fecha'])),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Etiqueta de método de pago (Corregida)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: pagadoConCaja
                                ? Colors.red[50]
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: pagadoConCaja ? Colors.red : Colors.blue,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            pagadoConCaja ? "SALIDA DE CAJA" : "OTRO MEDIO",
                            style: TextStyle(
                              fontSize: 10,
                              color: pagadoConCaja ? Colors.red : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (c['proveedor'] != null &&
                            c['proveedor'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Prov: ${c['proveedor']}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formater.format(c['total']),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    onTap: () => _verDetalle(c),
                  ),
                );
              },
            ),
    );
  }
}
