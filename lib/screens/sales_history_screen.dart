import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  List<Map<String, dynamic>> _ventas = [];
  bool _cargando = true;

  // Fechas del filtro
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now();
  String _filtroActual = "Hoy";

  @override
  void initState() {
    super.initState();
    _aplicarFiltroHoy();
  }

  // --- LÓGICA DE FECHAS CORREGIDA ---
  void _cargarVentas() async {
    setState(() => _cargando = true);

    // 🔥 CORRECCIÓN CLAVE: Usamos el formato con 'T' para que coincida con la BD
    String fechaBaseInicio = DateFormat('yyyy-MM-dd').format(_fechaInicio);
    String fechaBaseFin = DateFormat('yyyy-MM-dd').format(_fechaFin);

    // Armamos la cadena ISO manual para asegurar la coincidencia
    String inicioStr = "${fechaBaseInicio}T00:00:00";
    String finStr = "${fechaBaseFin}T23:59:59";

    final data = await DBHelper().obtenerVentasPorRango(inicioStr, finStr);

    if (!mounted) return;
    setState(() {
      _ventas = data;
      _cargando = false;
    });
  }

  void _aplicarFiltroHoy() {
    setState(() {
      _fechaInicio = DateTime.now();
      _fechaFin = DateTime.now();
      _filtroActual = "Hoy";
    });
    _cargarVentas();
  }

  void _aplicarFiltroAyer() {
    setState(() {
      _fechaInicio = DateTime.now().subtract(const Duration(days: 1));
      _fechaFin = DateTime.now().subtract(const Duration(days: 1));
      _filtroActual = "Ayer";
    });
    _cargarVentas();
  }

  void _aplicarFiltroSemana() {
    setState(() {
      _fechaInicio = DateTime.now().subtract(
        const Duration(days: 6),
      ); // 7 días contando hoy
      _fechaFin = DateTime.now();
      _filtroActual = "7 Días";
    });
    _cargarVentas();
  }

  void _seleccionarRangoManual() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.teal,
            colorScheme: const ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
        _filtroActual = "Rango";
      });
      _cargarVentas();
    }
  }

  // --- VER DETALLE DE UNA VENTA ---
  void _verDetalleVenta(Map<String, dynamic> venta) async {
    final db = await DBHelper().database;
    final detalles = await db.query(
      'detalle_ventas',
      where: 'venta_id = ?',
      whereArgs: [venta['id']],
    );

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 450, // Un poco más alto
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Venta #${venta['id']}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Text(
              DateFormat(
                'dd MMM yyyy - hh:mm a',
              ).format(DateTime.parse(venta['fecha'])),
              style: TextStyle(color: Colors.grey[600]),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: detalles.length,
                itemBuilder: (c, i) {
                  final d = detalles[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      d['nombre_producto'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${d['cantidad']} x ${formater.format(d['precio_unitario'])}",
                    ),
                    trailing: Text(
                      formater.format(d['subtotal']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TOTAL:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  formater.format(venta['total']),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalPeriodo = _ventas.fold(
      0,
      (sum, item) => sum + (item['total'] as num).toDouble(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial de Ventas"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. BARRA DE FILTROS
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _filtroBtn("Hoy", _aplicarFiltroHoy),
                _filtroBtn("Ayer", _aplicarFiltroAyer),
                _filtroBtn("7 Días", _aplicarFiltroSemana),
                IconButton(
                  onPressed: _seleccionarRangoManual,
                  icon: Icon(
                    Icons.calendar_month,
                    color: _filtroActual == "Rango" ? Colors.teal : Colors.grey,
                  ),
                  tooltip: "Calendario",
                ),
              ],
            ),
          ),

          // 2. RESUMEN
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            color: Colors.teal[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_ventas.length} Ventas",
                  style: TextStyle(
                    color: Colors.teal[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Total: ${formater.format(totalPeriodo)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.teal[900],
                  ),
                ),
              ],
            ),
          ),

          // 3. LISTA
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _ventas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "No hay ventas en este rango",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _ventas.length,
                    itemBuilder: (context, index) {
                      final v = _ventas[index];
                      IconData iconPago = Icons.attach_money;
                      Color colorPago = Colors.green;
                      if (v['metodo_pago'] == 'NEQUI') {
                        iconPago = Icons.phone_android;
                        colorPago = Colors.purple;
                      }
                      if (v['metodo_pago'] == 'CREDITO') {
                        iconPago = Icons.people;
                        colorPago = Colors.orange;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        elevation: 1,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorPago.withOpacity(0.1),
                            child: Icon(iconPago, color: colorPago, size: 20),
                          ),
                          title: Text(
                            formater.format(v['total']),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat(
                              'EEEE d, hh:mm a',
                              'es_CO',
                            ).format(DateTime.parse(v['fecha'])),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: () => _verDetalleVenta(v),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filtroBtn(String label, VoidCallback onTap) {
    bool isSelected = _filtroActual == label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
