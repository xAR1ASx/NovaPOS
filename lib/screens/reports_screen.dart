import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  // --- VARIABLES PESTAÑA 1 (COMPARATIVA) ---
  Map<String, double> _hoy = {};
  Map<String, double> _mes = {};
  Map<String, double> _anio = {};
  double _inventarioValor = 0;
  double _cartera = 0;
  bool _cargandoGeneral = true;

  // --- VARIABLES PESTAÑA 2 (DETALLADO) ---
  String _rangoSeleccionado = "Hoy";
  DateTime _fechaInicioDetalle = DateTime.now();
  DateTime _fechaFinDetalle = DateTime.now();
  Map<String, double> _finanzasDetalle = {};
  List<Map<String, dynamic>> _topProductos = [];
  List<Map<String, dynamic>> _ventasCategoria = [];
  List<Map<String, dynamic>> _metodosPago = [];
  bool _cargandoDetalle = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarInformeGeneral();
    _aplicarFiltroDetalle("Hoy"); // Carga inicial del detallado
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================
  // 📥 LOGICA DE CARGA DE DATOS
  // ==========================================

  void _cargarInformeGeneral() async {
    setState(() => _cargandoGeneral = true);
    final db = DBHelper();
    DateTime now = DateTime.now();

    // Fechas mágicas
    String hoyI = "${DateFormat('yyyy-MM-dd').format(now)}T00:00:00";
    String hoyF = "${DateFormat('yyyy-MM-dd').format(now)}T23:59:59";
    String mesI = "${DateFormat('yyyy-MM-01').format(now)}T00:00:00";
    String mesF =
        "${DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0))}T23:59:59";
    String anioI = "${DateFormat('yyyy-01-01').format(now)}T00:00:00";
    String anioF = "${DateFormat('yyyy-12-31').format(now)}T23:59:59";

    final rHoy = await db.obtenerReporteFinanciero(hoyI, hoyF);
    final rMes = await db.obtenerReporteFinanciero(mesI, mesF);
    final rAnio = await db.obtenerReporteFinanciero(anioI, anioF);
    final vInv = await db.obtenerValorInventario();
    final vCart = await db.obtenerTotalCuentasPorCobrar();

    if (!mounted) return;
    setState(() {
      _hoy = rHoy;
      _mes = rMes;
      _anio = rAnio;
      _inventarioValor = vInv;
      _cartera = vCart;
      _cargandoGeneral = false;
    });
  }

  void _aplicarFiltroDetalle(String tipo) {
    DateTime now = DateTime.now();
    DateTime inicio;
    DateTime fin = now;

    if (tipo == "Hoy") {
      inicio = now;
    } else if (tipo == "Ayer") {
      inicio = now.subtract(const Duration(days: 1));
      fin = inicio;
    } else if (tipo == "Esta Semana") {
      inicio = now.subtract(Duration(days: now.weekday - 1));
    } else if (tipo == "Este Mes") {
      inicio = DateTime(now.year, now.month, 1);
    } else if (tipo == "Este Año") {
      inicio = DateTime(now.year, 1, 1);
    } else {
      inicio = now; // Fallback
    }

    setState(() {
      _rangoSeleccionado = tipo;
      _fechaInicioDetalle = inicio;
      _fechaFinDetalle = fin;
    });
    _cargarInformeDetallado();
  }

  void _seleccionarRangoManual() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1A1F2B)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _rangoSeleccionado = "Rango";
        _fechaInicioDetalle = picked.start;
        _fechaFinDetalle = picked.end;
      });
      _cargarInformeDetallado();
    }
  }

  void _cargarInformeDetallado() async {
    setState(() => _cargandoDetalle = true);
    final db = DBHelper();

    String iStr =
        "${DateFormat('yyyy-MM-dd').format(_fechaInicioDetalle)}T00:00:00";
    String fStr =
        "${DateFormat('yyyy-MM-dd').format(_fechaFinDetalle)}T23:59:59";

    final finanzas = await db.obtenerReporteFinanciero(iStr, fStr);
    final top = await db.obtenerTopProductosPorRango(iStr, fStr);
    final cats = await db.obtenerVentasPorCategoria(iStr, fStr);
    final pagos = await db.obtenerMetodosPagoPorRango(iStr, fStr);

    if (!mounted) return;
    setState(() {
      _finanzasDetalle = finanzas;
      _topProductos = top;
      _ventasCategoria = cats;
      _metodosPago = pagos;
      _cargandoDetalle = false;
    });
  }

  // ==========================================
  // 🖥️ INTERFAZ GRÁFICA
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Inteligencia de Negocio"),
        backgroundColor: const Color(0xFF1A1F2B),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: "PANORAMA GENERAL"),
            Tab(icon: Icon(Icons.analytics), text: "ANALIZADOR DETALLADO"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabGeneral(), // Tab 1: Lo que ya tenías mejorado
          _buildTabDetalle(), // Tab 2: Lo nuevo y potente
        ],
      ),
    );
  }

  // --- TAB 1: PANORAMA GENERAL ---
  Widget _buildTabGeneral() {
    if (_cargandoGeneral) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ESTADO DE RESULTADOS",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          "Concepto",
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "HOY",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "MES",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "AÑO",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      _filaTabla(
                        "Ventas",
                        _hoy['ventas']!,
                        _mes['ventas']!,
                        _anio['ventas']!,
                        esNegrita: true,
                        color: Colors.blue[700],
                      ),
                      const Divider(),
                      _filaTabla(
                        "(-) Costos",
                        _hoy['costos']!,
                        _mes['costos']!,
                        _anio['costos']!,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 5),
                      _filaTabla(
                        "= Utilidad Bruta",
                        _hoy['utilidad_bruta']!,
                        _mes['utilidad_bruta']!,
                        _anio['utilidad_bruta']!,
                        esNegrita: true,
                        color: Colors.green[700],
                      ),
                      const Divider(),
                      _filaTabla(
                        "(-) Gastos",
                        _hoy['gastos']!,
                        _mes['gastos']!,
                        _anio['gastos']!,
                        color: Colors.orange[800],
                      ),
                      const Divider(thickness: 2),
                      _filaTabla(
                        "= UTILIDAD NETA",
                        _hoy['utilidad_neta']!,
                        _mes['utilidad_neta']!,
                        _anio['utilidad_neta']!,
                        esNegrita: true,
                        color: Colors.black,
                        fontSize: 15,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  "INVENTARIO",
                  _inventarioValor,
                  Icons.inventory_2,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  "CARTERA",
                  _cartera,
                  Icons.groups,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 2: EXPLORADOR DETALLADO ---
  Widget _buildTabDetalle() {
    return Column(
      children: [
        // Selector de Fechas
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              _filtroChip("Hoy"),
              _filtroChip("Ayer"),
              _filtroChip("Esta Semana"),
              _filtroChip("Este Mes"),
              _filtroChip("Este Año"),
              ActionChip(
                label: const Text("Rango"),
                avatar: const Icon(Icons.calendar_month, size: 16),
                backgroundColor: _rangoSeleccionado == "Rango"
                    ? Colors.orange[100]
                    : Colors.grey[100],
                onPressed: _seleccionarRangoManual,
              ),
            ],
          ),
        ),
        if (_cargandoDetalle)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen Financiero del Periodo
                  Card(
                    elevation: 0,
                    color: const Color(0xFF1A1F2B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            "RESULTADOS: $_rangoSeleccionado",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _datoResumenBlanco(
                                "Ventas",
                                _finanzasDetalle['ventas']!,
                                Colors.green,
                              ),
                              _datoResumenBlanco(
                                "Gastos",
                                _finanzasDetalle['gastos']!,
                                Colors.red,
                              ),
                              _datoResumenBlanco(
                                "Ganancia Neta",
                                _finanzasDetalle['utilidad_neta']!,
                                Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // TOP PRODUCTOS
                  const Text(
                    "🏆 Productos Más Vendidos",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: _topProductos.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text("Sin ventas en este periodo"),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _topProductos.length,
                            separatorBuilder: (c, i) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final p = _topProductos[index];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue[50],
                                  child: Text(
                                    "${index + 1}",
                                    style: TextStyle(
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  p['nombre_producto'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text("${p['cantidad_total']} Unds"),
                                trailing: Text(
                                  formater.format(p['dinero_total']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 20),

                  // VENTAS POR CATEGORÍA
                  const Text(
                    "📦 Ventas por Categoría",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: _ventasCategoria.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: Text("Sin datos")),
                          )
                        : Column(
                            children: _ventasCategoria.map((c) {
                              double totalVentas =
                                  _finanzasDetalle['ventas']! > 0
                                  ? _finanzasDetalle['ventas']!
                                  : 1;
                              double porcentaje = (c['total'] / totalVentas);
                              return Column(
                                children: [
                                  ListTile(
                                    title: Text(c['categoria']),
                                    trailing: Text(formater.format(c['total'])),
                                    subtitle: LinearProgressIndicator(
                                      value: porcentaje,
                                      backgroundColor: Colors.grey[200],
                                      color: Colors.orange,
                                      minHeight: 5,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                  ),

                  const SizedBox(height: 20),

                  // MÉTODOS DE PAGO
                  const Text(
                    "💳 Métodos de Pago",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _metodosPago.map((m) {
                      IconData icon = Icons.money;
                      Color color = Colors.green;
                      if (m['metodo_pago'] == 'NEQUI') {
                        icon = Icons.phone_android;
                        color = Colors.purple;
                      }
                      if (m['metodo_pago'] == 'CREDITO') {
                        icon = Icons.people;
                        color = Colors.orange;
                      }

                      return Expanded(
                        child: Card(
                          color: color.withOpacity(0.1),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              children: [
                                Icon(icon, color: color),
                                const SizedBox(height: 5),
                                Text(
                                  m['metodo_pago'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                Text(
                                  formater.format(m['total']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _filtroChip(String label) {
    bool selected = _rangoSeleccionado == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: const Color(0xFF1A1F2B),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
        onSelected: (v) => _aplicarFiltroDetalle(label),
      ),
    );
  }

  Widget _datoResumenBlanco(
    String titulo,
    double valor,
    Color colorImportante,
  ) {
    return Column(
      children: [
        Text(
          titulo,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(
          formater.format(valor),
          style: TextStyle(
            color: colorImportante,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _filaTabla(
    String label,
    double v1,
    double v2,
    double v3, {
    bool esNegrita = false,
    Color? color,
    double fontSize = 13,
  }) {
    TextStyle estilo = TextStyle(
      fontSize: fontSize,
      fontWeight: esNegrita ? FontWeight.w900 : FontWeight.normal,
      color: color ?? Colors.black87,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: estilo.copyWith(color: Colors.black87)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formater.format(v1),
              textAlign: TextAlign.right,
              style: estilo,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formater.format(v2),
              textAlign: TextAlign.right,
              style: estilo,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formater.format(v3),
              textAlign: TextAlign.right,
              style: estilo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String titulo, double valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formater.format(valor),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
