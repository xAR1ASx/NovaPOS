import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
// Importamos todas las pantallas
import 'pos_screen.dart';
import 'inventory_screen.dart';
import 'cash_control_screen.dart';
import 'sales_history_screen.dart';
import 'clients_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'purchases_screen.dart';
import '../services/session_service.dart';
import '../services/permission_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  // Variables del Dashboard
  double _ventasHoy = 0;
  int _cantidadVentasHoy = 0;
  int _productosBajosStock = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosDashboard();
  }

  void _cargarDatosDashboard() async {
    final db = await DBHelper().database;
    String hoy = DateTime.now().toIso8601String().substring(0, 10);

    final ventasRes = await db.rawQuery(
      "SELECT SUM(total) as total, COUNT(*) as cantidad FROM ventas WHERE fecha LIKE '$hoy%'",
    );
    final stockRes = await db.rawQuery(
      "SELECT COUNT(*) as cantidad FROM productos WHERE stock_actual <= 5 AND esta_activo = 1",
    );

    if (!mounted) return;
    setState(() {
      _ventasHoy = (ventasRes.first['total'] as num?)?.toDouble() ?? 0;
      _cantidadVentasHoy = (ventasRes.first['cantidad'] as num?)?.toInt() ?? 0;
      _productosBajosStock = (stockRes.first['cantidad'] as num?)?.toInt() ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = SessionService.currentUser();
    Text(SessionService.userRole());
    Text(SessionService.userRole());
    Text(SessionService.userId().toString());
    debugPrint("===== USUARIO =====");
    debugPrint(usuario.toString());
    debugPrint("===================");
    return Scaffold(
      // Fondo gris azulado moderno (Tech Background)
      backgroundColor: const Color(0xFFF0F2F5),

      appBar: AppBar(
        title: const Text(
          "MI FRUVER POS",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        backgroundColor: const Color(0xFF1A1F2B), // Dark Navy
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            tooltip: "Salir",
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ENCABEZADO DE BIENVENIDA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bienvenido ${SessionService.userName()}",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      "Panel de Control",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1F2B),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('MMMM').format(DateTime.now()).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('d').format(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // 2. TARJETAS DE RESUMEN (KPIs)
            Row(
              children: [
                _kpiCard(
                  "Ventas Hoy",
                  formater.format(_ventasHoy),
                  Icons.attach_money,
                  Colors.green,
                ),
                const SizedBox(width: 15),
                _kpiCard(
                  "Movimientos",
                  _cantidadVentasHoy.toString(),
                  Icons.receipt_long,
                  Colors.blue,
                ),
                const SizedBox(width: 15),
                _kpiCard(
                  "Stock Bajo",
                  _productosBajosStock.toString(),
                  Icons.warning_amber_rounded,
                  Colors.orange,
                  isAlert: _productosBajosStock > 0,
                ),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              "ACCESOS DIRECTOS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 15),

            // 3. GRILLA DE BOTONES FUTURISTA
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Fila 1
                _menuButton(
                  "NUEVA VENTA",
                  Icons.point_of_sale,
                  Colors.green,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const PosScreen()),
                    );
                    _cargarDatosDashboard();
                  },
                ),
                _menuButton(
                  "CAJA",
                  Icons.account_balance_wallet,
                  Colors.cyan,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const CashControlScreen(),
                      ),
                    );
                    _cargarDatosDashboard();
                  },
                ),
                _menuButton(
                  "INVENTARIO",
                  Icons.inventory_2,
                  Colors.orange,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const InventoryScreen(),
                      ),
                    );
                    _cargarDatosDashboard();
                  },
                ),

                // Fila 2
                _menuButton("HISTORIAL", Icons.history, Colors.teal, () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const SalesHistoryScreen(),
                    ),
                  );
                  _cargarDatosDashboard();
                }),
                _menuButton("CLIENTES", Icons.people, Colors.purple, () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const ClientsScreen()),
                  );
                  _cargarDatosDashboard();
                }),
                _menuButton(
                  "INGRESAR\nPEDIDO",
                  Icons.local_shipping,
                  Colors.brown,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const PurchasesScreen(),
                      ),
                    );
                    _cargarDatosDashboard();
                  },
                ),

                // Fila 3
                _menuButton(
                  "REPORTES",
                  Icons.bar_chart,
                  Colors.indigo,
                  () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const ReportsScreen()),
                    );
                  },
                ),
                _menuButton(
                  "CONFIGURACIÓN",
                  Icons.settings,
                  Colors.blueGrey,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 💎 WIDGET: TARJETA DE ESTADÍSTICAS (KPI)
  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isAlert = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isAlert
              ? Border.all(color: Colors.red.withOpacity(0.5), width: 1.5)
              : Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: isAlert
                  ? Colors.red.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.grey[800],
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 💎 WIDGET: BOTÓN FUTURISTA CON LUZ (GLOW)
  Widget _menuButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          // Borde sutil del color del icono
          border: Border.all(color: color.withOpacity(0.15), width: 1.5),
          // Sombra "Glow" del color del icono
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15), // Luz de color
              blurRadius: 12,
              offset: const Offset(0, 6),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Burbuja del icono con degradado
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800, // Letra más gruesa
                color: Colors.grey[700],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
