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
import '../widgets/permission_gate.dart';
import '../services/permission_service.dart';
import '../services/pin_auth_service.dart';
import 'pin_login_screen.dart';
import 'users_screen.dart';
import '../services/locale_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Cambiar mi PIN': 'Change my PIN',
  'PIN actual': 'Current PIN',
  'PIN nuevo (6 dígitos)': 'New PIN (6 digits)',
  'Confirmar PIN nuevo': 'Confirm new PIN',
  'Cancelar': 'Cancel',
  'GUARDAR': 'SAVE',
  'Los PIN nuevos no coinciden o no tienen 6 dígitos':
      'New PINs do not match or are not 6 digits',
  'Resultado': 'Result',
  'Cerrar sesion': 'Log out',
  'Deseas cerrar sesion?': 'Do you want to log out?',
  'Salir': 'Exit',
  'Bienvenido': 'Welcome',
  'Panel de Control': 'Control Panel',
  'Ventas Hoy': "Today's Sales",
  'Movimientos': 'Movements',
  'Stock Bajo': 'Low Stock',
  'ACCESOS DIRECTOS': 'QUICK ACCESS',
  'NUEVA VENTA': 'NEW SALE',
  'CAJA': 'CASH',
  'INVENTARIO': 'INVENTORY',
  'HISTORIAL': 'HISTORY',
  'CLIENTES': 'CUSTOMERS',
  'INGRESAR\nPEDIDO': 'ADD\nORDER',
  'REPORTES': 'REPORTS',
  'CONFIGURACIÓN': 'SETTINGS',
  'USUARIOS': 'USERS',
};

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
      "SELECT SUM(total) as total, COUNT(*) as cantidad FROM ventas WHERE fecha LIKE '$hoy%' AND anulada = 0",
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

  void _cambiarPinPropio() {
    final pinActual = TextEditingController();
    final pinNuevo = TextEditingController();
    final pinConfirmar = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Cambiar mi PIN')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinActual,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(labelText: _t('PIN actual')),
            ),
            TextField(
              controller: pinNuevo,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(labelText: _t('PIN nuevo (6 dígitos)')),
            ),
            TextField(
              controller: pinConfirmar,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(labelText: _t('Confirmar PIN nuevo')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Cancelar'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pinNuevo.text.length != 6 ||
                  pinNuevo.text != pinConfirmar.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_t('Los PIN nuevos no coinciden o no tienen 6 dígitos')),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final res = await PinAuthService.cambiarPinPropio(
                pinActual.text,
                pinNuevo.text,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res['mensaje']?.toString() ?? _t('Resultado')),
                  backgroundColor:
                      res['exito'] == true ? Colors.green : Colors.red,
                ),
              );
            },
            child: Text(_t('GUARDAR')),
          ),
        ],
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Cerrar sesion')),
        content: Text(_t('Deseas cerrar sesion?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_t('Cerrar sesion'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    await SessionService.logout();
    await PermissionService.clear();
    await PinAuthService.cerrarSesion();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PinLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),

      appBar: AppBar(
        title: const Text(
          "NovaPOS",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        backgroundColor: const Color(0xFF1A1F2B), // Dark Navy
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_reset, color: Colors.white, size: 22),
            tooltip: _t('Cambiar mi PIN'),
            onPressed: _cambiarPinPropio,
          ),
          TextButton.icon(
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            label: Text(
              _t('Salir'),
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
            onPressed: _cerrarSesion,
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
                      "${_t('Bienvenido')} ${SessionService.userName()}",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      _t('Panel de Control'),
                      style: const TextStyle(
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
                  _t('Ventas Hoy'),
                  formater.format(_ventasHoy),
                  Icons.attach_money,
                  Colors.green,
                ),
                const SizedBox(width: 15),
                _kpiCard(
                  _t('Movimientos'),
                  _cantidadVentasHoy.toString(),
                  Icons.receipt_long,
                  Colors.blue,
                ),
                const SizedBox(width: 15),
                _kpiCard(
                  _t('Stock Bajo'),
                  _productosBajosStock.toString(),
                  Icons.warning_amber_rounded,
                  Colors.orange,
                  isAlert: _productosBajosStock > 0,
                ),
              ],
            ),

            const SizedBox(height: 30),

            Text(
              _t('ACCESOS DIRECTOS'),
              style: const TextStyle(
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
                PermissionGate(
                  permission: "VENTAS_CREAR",
                  child: _menuButton(
                    _t('NUEVA VENTA'),
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
                ),
                PermissionGate(
                  permission: "CAJA_ABRIR",
                  child: _menuButton(
                    _t('CAJA'),
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
                ),
                PermissionGate(
                  permission: "INVENTARIO_VER",
                  child: _menuButton(
                    _t('INVENTARIO'),
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
                ),

                // Fila 2
                PermissionGate(
                  permission: "VENTAS_VER",
                  child: _menuButton(
                    _t('HISTORIAL'),
                    Icons.history,
                    Colors.teal,
                    () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const SalesHistoryScreen(),
                        ),
                      );
                      _cargarDatosDashboard();
                    },
                  ),
                ),
                PermissionGate(
                  permission: "CLIENTES_VER",
                  child: _menuButton(
                    _t('CLIENTES'),
                    Icons.people,
                    Colors.purple,
                    () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => const ClientsScreen()),
                      );
                      _cargarDatosDashboard();
                    },
                  ),
                ),
                PermissionGate(
                  permission: "COMPRAS_CREAR",
                  child: _menuButton(
                    _t('INGRESAR\nPEDIDO'),
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
                ),

                // Fila 3
                PermissionGate(
                  permission: "REPORTES_VER",
                  child: _menuButton(
                    _t('REPORTES'),
                    Icons.bar_chart,
                    Colors.indigo,
                    () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => const ReportsScreen()),
                      );
                    },
                  ),
                ),
                PermissionGate(
                  permission: "CONFIGURACION_GENERAL",
                  child: _menuButton(
                    _t('CONFIGURACIÓN'),
                    Icons.settings,
                    Colors.blueGrey,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                PermissionGate(
                  permission: "USUARIOS_GESTIONAR",
                  child: _menuButton(
                    _t('USUARIOS'),
                    Icons.people_alt,
                    Colors.deepPurple,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const UsersScreen(),
                        ),
                      );
                    },
                  ),
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
