import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/permission_service.dart';
import '../services/locale_service.dart';
import '../services/excel_export_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Inteligencia de Negocio': 'Business Intelligence',
  'No tienes permiso para ver los reportes':
      "You don't have permission to view reports",
  'PANORAMA GENERAL': 'GENERAL OVERVIEW',
  'ANALIZADOR DETALLADO': 'DETAILED ANALYZER',
  'ESTADO DE RESULTADOS': 'INCOME STATEMENT',
  'Concepto': 'Concept',
  'HOY': 'TODAY',
  'MES': 'MONTH',
  'AÑO': 'YEAR',
  'Ventas': 'Sales',
  '(-) Costos': '(-) Costs',
  '= Utilidad Bruta': '= Gross Profit',
  '(-) Gastos': '(-) Expenses',
  '(-) Mermas': '(-) Waste / Shrinkage',
  '= UTILIDAD NETA': '= NET PROFIT',
  'INVENTARIO': 'INVENTORY',
  'CARTERA': 'RECEIVABLES',
  'Hoy': 'Today',
  'Ayer': 'Yesterday',
  'Esta Semana': 'This Week',
  'Este Mes': 'This Month',
  'Este Año': 'This Year',
  'Rango': 'Range',
  'Todos los cajeros': 'All cashiers',
  'Cajero': 'Cashier',
  'RESULTADOS': 'RESULTS',
  'Gastos': 'Expenses',
  'Ganancia Neta': 'Net Profit',
  '🏆 Productos Más Vendidos': '🏆 Best Selling Products',
  'Sin ventas en este periodo': 'No sales in this period',
  'Unds': 'Units',
  '📦 Ventas por Categoría': '📦 Sales by Category',
  'Sin datos': 'No data',
  '💳 Métodos de Pago': '💳 Payment Methods',
  'No se pudo cargar el informe': 'Could not load the report',
};

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
  List<Map<String, dynamic>> _cajeros = [];
  int _cajeroIdFiltro = -1; // -1 = todos los cajeros
  bool _cargandoDetalle = true;
  String? _errorDetalle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarInformeGeneral();
    _cargarCajeros();
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

  void _cargarCajeros() async {
    final data = await DBHelper().obtenerCajeros();
    if (!mounted) return;
    setState(() => _cajeros = data);
  }

  void _cargarInformeDetallado() async {
    setState(() {
      _cargandoDetalle = true;
      _errorDetalle = null;
    });
    try {
      final db = DBHelper();

      String iStr =
          "${DateFormat('yyyy-MM-dd').format(_fechaInicioDetalle)}T00:00:00";
      String fStr =
          "${DateFormat('yyyy-MM-dd').format(_fechaFinDetalle)}T23:59:59";

      final finanzas = await db.obtenerReporteFinanciero(
        iStr,
        fStr,
        usuarioId: _cajeroIdFiltro == -1 ? null : _cajeroIdFiltro,
      );
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoDetalle = false;
        _errorDetalle = "${_t('No se pudo cargar el informe')}: $e";
      });
    }
  }

  // ==========================================
  // 🖥️ INTERFAZ GRÁFICA
  // ==========================================

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.can('REPORTES_VER')) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_t('Inteligencia de Negocio')),
          backgroundColor: const Color(0xFF1A1F2B),
        ),
        body: Center(
          child: Text(_t('No tienes permiso para ver los reportes')),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(_t('Inteligencia de Negocio')),
        backgroundColor: const Color(0xFF1A1F2B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: "Exportar Reportes a Excel",
            onPressed: () {
              ExcelExportService().mostrarModalExportacion(
                context,
                hoy: _hoy,
                mes: _mes,
                anio: _anio,
                inventarioValor: _inventarioValor,
                cartera: _cartera,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              icon: const Icon(Icons.dashboard),
              text: _t('PANORAMA GENERAL'),
            ),
            Tab(
              icon: const Icon(Icons.analytics),
              text: _t('ANALIZADOR DETALLADO'),
            ),
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
          Text(
            _t('ESTADO DE RESULTADOS'),
            style: const TextStyle(
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
                          _t('Concepto'),
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _t('HOY'),
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
                          _t('MES'),
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
                          _t('AÑO'),
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
                        _t('Ventas'),
                        _hoy['ventas']!,
                        _mes['ventas']!,
                        _anio['ventas']!,
                        esNegrita: true,
                        color: Colors.blue[700],
                      ),
                      const Divider(),
                      _filaTabla(
                        _t('(-) Costos'),
                        _hoy['costos']!,
                        _mes['costos']!,
                        _anio['costos']!,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 5),
                      _filaTabla(
                        _t('= Utilidad Bruta'),
                        _hoy['utilidad_bruta']!,
                        _mes['utilidad_bruta']!,
                        _anio['utilidad_bruta']!,
                        esNegrita: true,
                        color: Colors.green[700],
                      ),
                      const Divider(),
                      _filaTabla(
                        _t('(-) Gastos'),
                        _hoy['gastos']!,
                        _mes['gastos']!,
                        _anio['gastos']!,
                        color: Colors.orange[800],
                      ),
                      const SizedBox(height: 5),
                      _filaTabla(
                        _t('(-) Mermas'),
                        _hoy['mermas'] ?? 0,
                        _mes['mermas'] ?? 0,
                        _anio['mermas'] ?? 0,
                        color: Colors.purple[700],
                      ),
                      const Divider(thickness: 2),
                      _filaTabla(
                        _t('= UTILIDAD NETA'),
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
                  _t('INVENTARIO'),
                  _inventarioValor,
                  Icons.inventory_2,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  _t('CARTERA'),
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
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filtroChip("Hoy", Icons.today),
              _filtroChip("Ayer", Icons.arrow_back),
              _filtroChip("Esta Semana", Icons.calendar_view_week),
              _filtroChip("Este Mes", Icons.calendar_month),
              _filtroChip("Este Año", Icons.event),
              ActionChip(
                label: Text(_t('Rango')),
                avatar: const Icon(Icons.date_range, size: 16),
                backgroundColor: _rangoSeleccionado == "Rango"
                    ? Colors.orange[100]
                    : Colors.grey[100],
                onPressed: _seleccionarRangoManual,
              ),
              if (_cajeros.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 2),
                  child: DropdownButton<int>(
                    value: _cajeroIdFiltro,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem<int>(
                        value: -1,
                        child: Text(_t('Todos los cajeros')),
                      ),
                      ..._cajeros.map(
                        (u) => DropdownMenuItem<int>(
                          value: u['id'] as int,
                          child: Text(u['nombre'] ?? _t('Cajero')),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _cajeroIdFiltro = v);
                      _cargarInformeDetallado();
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_cargandoDetalle)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_errorDetalle != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _errorDetalle ?? "",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ),
          )
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
                            "${_t('RESULTADOS')}: $_rangoSeleccionado",
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
                                _t('Ventas'),
                                _finanzasDetalle['ventas'] ?? 0,
                                Colors.green,
                              ),
                              _datoResumenBlanco(
                                _t('Gastos'),
                                _finanzasDetalle['gastos'] ?? 0,
                                Colors.red,
                              ),
                              _datoResumenBlanco(
                                _t('Ganancia Neta'),
                                _finanzasDetalle['utilidad_neta'] ?? 0,
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
                  Text(
                    _t('🏆 Productos Más Vendidos'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: _topProductos.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(_t('Sin ventas en este periodo')),
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
                                subtitle: Text("${p['cantidad_total']} ${_t('Unds')}"),
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
                  Text(
                    _t('📦 Ventas por Categoría'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: _ventasCategoria.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(child: Text(_t('Sin datos'))),
                          )
                        : Column(
                            children: _ventasCategoria.map((c) {
                              double totalVentas =
                                  (_finanzasDetalle['ventas'] ?? 0) > 0
                                  ? _finanzasDetalle['ventas'] ?? 0
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
                  Text(
                    _t('💳 Métodos de Pago'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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

  Widget _filtroChip(String label, IconData icon) {
    bool selected = _rangoSeleccionado == label;
    return ChoiceChip(
      label: Text(_t(label)),
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? Colors.orangeAccent : Colors.grey[600],
      ),
      selected: selected,
      selectedColor: const Color(0xFF1A1F2B),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (v) => _aplicarFiltroDetalle(label),
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
