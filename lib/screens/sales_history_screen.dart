import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/locale_service.dart';
import '../services/permission_service.dart';
import '../services/session_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Hoy': 'Today',
  'Ayer': 'Yesterday',
  '7 Días': '7 Days',
  'Venta #': 'Sale #',
  'TOTAL:': 'TOTAL:',
  'ANULAR VENTA': 'VOID SALE',
  'Anular Venta': 'Void Sale',
  '¿Seguro que quieres anular esta venta?': 'Are you sure you want to void this sale?',
  'Total:': 'Total:',
  'Cancelar': 'Cancel',
  'SÍ, ANULAR': 'YES, VOID',
  'Resultado': 'Result',
  'Historial de Ventas': 'Sales History',
  'Ventas': 'Sales',
  'No hay ventas en este rango': 'No sales in this range',
  'ANULADA': 'VOIDED',
  'Calendario': 'Calendar',
  'Venta anulada correctamente': 'Sale voided successfully',
  'La venta ya está anulada': 'The sale is already voided',
  'Venta no encontrada': 'Sale not found',
};

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
                  "${_t('Venta #')}${venta['id']}",
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
                Text(
                  _t('TOTAL:'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            if (PermissionService.can("VENTAS_ANULAR") &&
                (venta['anulada'] ?? 0) != 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cancel, size: 18),
                    label: Text(_t('ANULAR VENTA')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(_t('Anular Venta')),
                          content: Text(
                            "${_t('¿Seguro que quieres anular esta venta?')}\n\n"
                            "${_t('Total:')} ${formater.format(venta['total'])}",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text(
                                _t('Cancelar'),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(_t('SÍ, ANULAR')),
                            ),
                          ],
                        ),
                      );
                      if (confirmar != true) return;

                      final res = await DBHelper().anularVenta(
                        venta['id'],
                        usuarioId: SessionService.userId() ?? 1,
                      );
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _t(res['mensaje']?.toString() ?? "Resultado"),
                          ),
                          backgroundColor: res['exito'] == true
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                      if (res['exito'] == true) _cargarVentas();
                    },
                  ),
                ),
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
      (sum, item) =>
          sum +
          (((item['anulada'] ?? 0) == 1)
              ? 0
              : (item['total'] as num).toDouble()),
    );
    int ventasValidas = _ventas.fold(
      0,
      (c, item) => c + (((item['anulada'] ?? 0) == 1) ? 0 : 1),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Historial de Ventas')),
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
                  tooltip: _t('Calendario'),
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
                  "$ventasValidas ${_t('Ventas')}",
                  style: TextStyle(
                    color: Colors.teal[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${_t('Total:')} ${formater.format(totalPeriodo)}",
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
                          _t('No hay ventas en este rango'),
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _ventas.length,
                    itemBuilder: (context, index) {
                      final v = _ventas[index];
                      bool anulada = (v['anulada'] ?? 0) == 1;
                      IconData iconPago = Icons.attach_money;
                      Color colorPago = Colors.green;
                      if (anulada) {
                        iconPago = Icons.cancel;
                        colorPago = Colors.red;
                      } else if (v['metodo_pago'] == 'NEQUI') {
                        iconPago = Icons.phone_android;
                        colorPago = Colors.purple;
                      } else if (v['metodo_pago'] == 'CREDITO') {
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
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formater.format(v['total']),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: anulada
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              if (anulada)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _t('ANULADA'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
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
          _t(label),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}