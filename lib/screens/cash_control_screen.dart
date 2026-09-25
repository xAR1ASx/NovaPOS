import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/cash_service.dart';
import '../services/session_service.dart';
import '../services/auto_backup_service.dart';
import '../utils/numero.dart';
import '../services/locale_service.dart';
import 'cierre_history_screen.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Iniciar Turno': 'Start Shift',
  'Registrar Salida': 'Register Expense',
  'Disponible': 'Available',
  'Monto': 'Amount',
  'Detalle / Motivo': 'Detail / Reason',
  'Base inicial': 'Initial base',
  'Ej: Pago Domicilio': 'E.g.: Home Delivery',
  'Cancelar': 'Cancel',
  '🚫 Fondos insuficientes en caja': '🚫 Insufficient funds in cash drawer',
  'GUARDAR': 'SAVE',
  '📝 Anotar Gasto Olvidado': '📝 Record Forgotten Expense',
  'Detalle': 'Detail',
  'REGISTRAR': 'REGISTER',
  'Cierre de Turno': 'Shift Close',
  'El sistema espera:': 'The system expects:',
  '¿Cuánto contaste?': 'How much did you count?',
  '¡PERFECTO! 😎': 'PERFECT! 😎',
  'SOBRANTE 🤑': 'SURPLUS 🤑',
  'FALTANTE 😱': 'MISSING 😱',
  '¿Se te olvidó anotar alguna salida?': 'Did you forget to record any expense?',
  'PAGO PEDIDO': 'ORDER PAYMENT',
  'GASTO VARIO': 'MISC. EXPENSE',
  '✅ Turno Cerrado Correctamente': '✅ Shift Closed Successfully',
  'Error al cerrar el turno': 'Error closing the shift',
  'CONFIRMAR Y CERRAR': 'CONFIRM AND CLOSE',
  'ABIERTA 🟢': 'OPEN 🟢',
  'CERRADA 🔴': 'CLOSED 🔴',
  'Gestión de Efectivo': 'Cash Management',
  'DINERO EN CAJA': 'CASH IN DRAWER',
  'TURNO CERRADO': 'SHIFT CLOSED',
  'Base': 'Base',
  'Ventas': 'Sales',
  'Ventas caja': 'This register Sales',
  'Ventas globales (todas las cajas)': 'Global Sales (all registers)',
  'Global (todas las cajas)': 'Global (all registers)',
  'Gastos': 'Expenses',
  'ABRIR': 'OPEN',
  'GASTO': 'EXPENSE',
  'CERRAR TURNO': 'CLOSE SHIFT',
  'VER HISTORIAL DE CIERRES': 'VIEW CLOSURE HISTORY',
  'La caja ya está abierta': 'The cash drawer is already open',
  'No hay un turno abierto para cerrar': 'There is no open shift to close',
  'El turno ya fue cerrado': 'The shift was already closed',
  'Debe abrir la caja antes de vender': 'You must open the cash drawer before selling',
  'Abono excede la deuda': 'Payment exceeds the debt',
  'No tienes permiso para realizar esta operación de caja.': 'You do not have permission to perform this cash operation.',
  'No hay un usuario autenticado.': 'There is no authenticated user.',
};

class CashControlScreen extends StatefulWidget {
  const CashControlScreen({super.key});

  @override
  State<CashControlScreen> createState() => _CashControlScreenState();
}

class _CashControlScreenState extends State<CashControlScreen> {
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  final CashService _cashService = CashService();
  // Variables de Estado
  double _base = 0;
  double _ventas = 0;
  double _ventasGlobal = 0;
  double _gastos = 0;
  double _totalEnCajaSistema = 0;

  List<Map<String, dynamic>> _movimientos = [];
  bool _cajaAbierta = false;

  // Variable de carga
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosCaja();
  }

  void _cargarDatosCaja() async {
    // Activamos carga
    if (mounted) setState(() => _cargando = true);

    final db = DBHelper();
    final resumen = await db.obtenerResumenCaja();
    final lista = await db.obtenerMovimientosTurnoActual();

    bool estaAbierta = await db.verificarCajaAbiertaHoy();

    if (!mounted) return;
    setState(() {
      _base = resumen['base']!;
      _ventas = resumen['ventas_efectivo']!;
      _ventasGlobal = resumen['ventas_global']!;
      _gastos = resumen['gastos']!;
      _totalEnCajaSistema = resumen['total_en_caja']!;
      _movimientos = lista;
      _cajaAbierta = estaAbierta;
      _cargando = false; // Desactivamos carga
    });
  }

  // --- LOGICA: APERTURA Y GASTOS ---
  void _mostrarDialogoMovimiento(String tipo) {
    final TextEditingController montoCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    bool esApertura = tipo == 'APERTURA';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: esApertura ? Colors.blue[100] : Colors.red[100],
              child: Icon(
                esApertura ? Icons.wb_sunny : Icons.money_off,
                color: esApertura ? Colors.blue : Colors.red,
              ),
            ),
            const SizedBox(width: 10),
            Text(esApertura ? _t("Iniciar Turno") : _t("Registrar Salida")),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!esApertura)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.red, size: 16),
                    const SizedBox(width: 5),
                    Expanded(
child: Text(
                          '${_t("Disponible")}: ${formater.format(_totalEnCajaSistema)}',
                          style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: _t("Monto"),
                prefixIcon: const Icon(Icons.attach_money),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: _t("Detalle / Motivo"),
                hintText: esApertura ? _t("Base inicial") : _t("Ej: Pago Domicilio"),
                prefixIcon: const Icon(Icons.description),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t("Cancelar"), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Aceptamos punto de miles y coma decimal (formato colombiano)
              double? m = parseNumero(montoCtrl.text);

              if (m != null && m > 0) {
                if (!esApertura && m > _totalEnCajaSistema) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_t("🚫 Fondos insuficientes en caja")),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                try {
                  await _cashService.registrarMovimiento(
                    tipo: tipo,
                    monto: m,
                    descripcion: descCtrl.text,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🚫 ${_t(e.toString())}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }
                Navigator.pop(ctx);
                _cargarDatosCaja();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: esApertura ? Colors.blue[800] : Colors.red[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(_t("GUARDAR")),
          ),
        ],
      ),
    );
  }

  // --- LOGICA: CIERRE DE CAJA INTELIGENTE ---
  void _mostrarCierreCaja() {
    final TextEditingController realController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Cálculos
            double dineroReal = parseNumero(realController.text) ?? 0;
            double diferencia = dineroReal - _totalEnCajaSistema;

            // Sub-función para registrar gasto olvidado
            void registrarGastoOlvidado(String concepto) async {
              final montoCtrl = TextEditingController(
                text: diferencia.abs().toInt().toString(),
              );
              final descCtrl = TextEditingController(text: concepto);

              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(_t("📝 Anotar Gasto Olvidado")),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: montoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _t("Monto"),
                          prefixIcon: const Icon(Icons.money_off),
                        ),
                      ),
                      TextField(
                        controller: descCtrl,
                        decoration: InputDecoration(
                          labelText: _t("Detalle"),
                          prefixIcon: const Icon(Icons.description),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () async {
                        double? m = parseNumero(montoCtrl.text);
                        if (m != null) {
                          await _cashService.registrarMovimiento(
                            tipo: 'GASTO',
                            monto: m,
                            descripcion: descCtrl.text,
                          );
                          Navigator.pop(ctx);
                          final nuevo = await DBHelper().obtenerResumenCaja();
                          setState(() {
                            _totalEnCajaSistema = nuevo['total_en_caja']!;
                            _gastos = nuevo['gastos']!;
                          });
                          setStateDialog(() {});
                        }
                      },
                      child: Text(_t("REGISTRAR")),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.grey[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              // Aquí quité el 'const' para solucionar el error de constante inválida
              title: Column(
                children: [
                  const Icon(Icons.lock_clock, size: 50, color: Colors.purple),
                  Text(
                    _t("Cierre de Turno"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                // Usamos SingleChildScrollView para evitar desbordamiento con el teclado
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.indigo[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _t("Ventas globales (todas las cajas)"),
                              style: TextStyle(
                                color: Colors.indigo[800],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              formater.format(_ventasGlobal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _t("El sistema espera:"),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Text(
                              formater.format(_totalEnCajaSistema),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller:
                            realController, // Aquí usamos la variable que definimos arriba
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: "\$ 0",
                          labelText: _t("¿Cuánto contaste?"),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.money),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (val) => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 20),

                      // SEMÁFORO DE CUADRE
                      if (realController.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(15),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: differenceColorBg(diferencia),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: differenceColorText(diferencia),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                diferencia == 0
                                    ? Icons.check_circle
                                    : (diferencia > 0
                                          ? Icons.trending_up
                                          : Icons.warning),
                                color: differenceColorText(diferencia),
                                size: 40,
                              ),
                              Text(
                                diferencia == 0
                                    ? _t("¡PERFECTO! 😎")
                                    : (diferencia > 0
                                          ? _t("SOBRANTE 🤑")
                                          : _t("FALTANTE 😱")),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: differenceColorText(diferencia),
                                ),
                              ),
                              Text(
                                formater.format(diferencia),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: differenceColorText(diferencia),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // BOTONES DE AYUDA (Solo si falta dinero)
                      if (diferencia < 0) ...[
                        const SizedBox(height: 15),
                        Text(
                          _t("¿Se te olvidó anotar alguna salida?"),
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.local_shipping,
                                  size: 16,
                                ),
                                label: Text(
                                  _t("PAGO PEDIDO"),
                                  style: const TextStyle(fontSize: 10),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.red,
                                ),
                                onPressed: () => registrarGastoOlvidado(
                                  "Pago Pedido Proveedor",
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.fastfood, size: 16),
                                label: Text(
                                  _t("GASTO VARIO"),
                                  style: const TextStyle(fontSize: 10),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.red,
                                ),
                                onPressed: () =>
                                    registrarGastoOlvidado("Gasto Vario Local"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _cargarDatosCaja();
                    Navigator.pop(context);
                  },
                  child: Text(_t("Cancelar")),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final dbHelper = DBHelper();
                    try {
                      // Ajustes automáticos de sobrantes/faltantes
                      if (diferencia > 0) {
                        await _cashService.registrarMovimiento(
                          tipo: 'INGRESO',
                          monto: diferencia,
                          descripcion: "Ajuste Sobrante Automático",
                        );
                      } else if (diferencia < 0) {
                        await _cashService.registrarMovimiento(
                          tipo: 'GASTO',
                          monto: diferencia.abs(),
                          descripcion: "Pérdida / Descuadre Cierre",
                        );
                      }

                      String estado = diferencia == 0
                          ? "OK"
                          : (diferencia > 0 ? "SOBRA" : "FALTA");
                      String desc =
                          "Cierre: Sistema ${_totalEnCajaSistema.toInt()} | Real ${dineroReal.toInt()} | Global ${_ventasGlobal.toInt()} | Estado: $estado";

                      // CIERRE TRANSACCIONAL: movimiento CIERRE + registro formal
                      await dbHelper.cerrarTurno(
                        base: 0,
                        realContado: dineroReal,
                        diferencia: diferencia,
                        estado: estado,
                        detalle: desc,
                        fechaInicio:
                            await dbHelper.obtenerFechaAperturaActual() ??
                            DateTime.now().toIso8601String(),
                        usuarioId: SessionService.userId() ?? 1,
                      );

                      // 💾 Disparo de Copia de Seguridad Automática si está configurada
                      unawaited(AutoBackupService().ejecutarBackupSiCorresponde(motivo: 'cierre_caja'));

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _cargarDatosCaja();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_t("✅ Turno Cerrado Correctamente")),
                          backgroundColor: Colors.purple,
                        ),
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🚫 ${_t("Error al cerrar el turno")}: ${_t(e.toString())}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        _cargarDatosCaja();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: Text(_t("CONFIRMAR Y CERRAR")),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helpers de Color
  Color differenceColorBg(double diff) {
    if (diff == 0) return Colors.green[50]!;
    if (diff > 0) return Colors.blue[50]!;
    return Colors.red[50]!;
  }

  Color differenceColorText(double diff) {
    if (diff == 0) return Colors.green[800]!;
    if (diff > 0) return Colors.blue[800]!;
    return Colors.red[800]!;
  }

  @override
  Widget build(BuildContext context) {
    String estadoTexto = _cajaAbierta
        ? _t("ABIERTA 🟢")
        : _t("CERRADA 🔴");
    Color estadoColor = _cajaAbierta ? Colors.green : Colors.red;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_t("Gestión de Efectivo")),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Chip(
              label: Text(
                estadoTexto,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: estadoColor,
            ),
          ),
        ],
      ),
      // AQUÍ USAMOS _cargando PARA EVITAR LA ADVERTENCIA AMARILLA
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // TARJETA
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _cajaAbierta
                          ? [Colors.blue.shade900, Colors.blue.shade600]
                          : [Colors.grey.shade800, Colors.grey.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _cajaAbierta
                            ? _t("DINERO EN CAJA")
                            : _t("TURNO CERRADO"),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _cajaAbierta
                            ? formater.format(_totalEnCajaSistema)
                            : "---",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      if (_cajaAbierta)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _miniResumen(
                              _t("Base"),
                              _base,
                              Colors.blueAccent,
                            ),
                            _miniResumen(
                              _t("Ventas caja"),
                              _ventas,
                              Colors.greenAccent,
                            ),
                            _miniResumen(
                              _t("Gastos"),
                              _gastos,
                              Colors.orangeAccent,
                            ),
                          ],
                        ),
                      if (_cajaAbierta) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_t("Global (todas las cajas)")}: '
                          '${formater.format(_ventasGlobal)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // BOTONES
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: !_cajaAbierta
                              ? () => _mostrarDialogoMovimiento('APERTURA')
                              : null,
                          icon: const Icon(Icons.wb_sunny),
                          label: Text(_t("ABRIR")),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _cajaAbierta
                              ? () => _mostrarDialogoMovimiento('GASTO')
                              : null,
                          icon: const Icon(Icons.output),
                          label: Text(_t("GASTO")),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_cajaAbierta)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _mostrarCierreCaja,
                        icon: const Icon(Icons.lock),
                        label: Text(_t("CERRAR TURNO")),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),

                if (SessionService.userRole() == 'ADMIN')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => const CierreHistoryScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.history),
                        label: Text(_t("VER HISTORIAL DE CIERRES")),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo[800],
                          side: BorderSide(color: Colors.indigo[800]!),
                        ),
                      ),
                    ),
                  ),

                const Divider(),

                // LISTA DE MOVIMIENTOS MEJORADA
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _movimientos.length,
                    itemBuilder: (context, index) {
                      final mov = _movimientos[index];

                      // LÓGICA DE COLORES E ICONOS
                      bool esIngreso =
                          mov['tipo'] == 'APERTURA' || mov['tipo'] == 'INGRESO';
                      bool esGasto = mov['tipo'] == 'GASTO';
                      bool esCredito =
                          mov['tipo'] == 'COMPRA_CREDITO';
                      bool esCierre = mov['tipo'] == 'CIERRE';
                      bool esAnulacion = mov['tipo'] == 'ANULACION';
                      bool esDevolucion = mov['tipo'] == 'DEVOLUCION';

                      Color colorItem = Colors.grey; // Por defecto
                      IconData iconItem = Icons.info;

                      if (esIngreso) {
                        colorItem = Colors.green;
                        iconItem = Icons.arrow_downward;
                      }
                      if (esGasto) {
                        colorItem = Colors.red;
                        iconItem = Icons.arrow_upward;
                      }
                      if (esCierre) {
                        colorItem = Colors.indigo;
                        iconItem = Icons.lock;
                      }
                      if (esCredito) {
                        colorItem = Colors.blueGrey;
                        iconItem = Icons.credit_card;
                      }
                      if (esAnulacion) {
                        colorItem = Colors.deepOrange;
                        iconItem = Icons.cancel;
                      }
                      if (esDevolucion) {
                        colorItem = Colors.brown;
                        iconItem = Icons.replay;
                      }

                      if (mov['tipo'] == 'APERTURA') {
                        colorItem = Colors.blue;
                        iconItem = Icons.wb_sunny;
                      }

                      return Card(
                        elevation: esCredito
                            ? 0
                            : 2, // Menos sombra si es crédito (menos importante)
                        color: esCredito
                            ? Colors.grey[100]
                            : Colors.white, // Fondo grisáceo si es crédito
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorItem.withOpacity(0.1),
                            child: Icon(iconItem, color: colorItem),
                          ),
                          title: Text(
                            mov['tipo'].toString().replaceAll(
                              '_',
                              ' ',
                            ), // Quita el guion bajo visualmente
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(mov['descripcion'] ?? ""),
                          trailing: Text(
                            formater.format(mov['monto']),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              // Si es crédito, tachamos el precio visualmente o lo ponemos gris para indicar que no salió de caja
                              decoration: esCredito
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: colorItem,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _miniResumen(String label, double valor, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
        Text(
          formater.format(valor),
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
