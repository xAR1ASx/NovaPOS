import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/cash_service.dart';
import '../services/session_service.dart';
import '../services/auto_backup_service.dart';
import '../services/printer_service.dart';
import '../utils/numero.dart';
import '../services/locale_service.dart';
import 'cierre_history_screen.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Iniciar Turno': 'Start Shift',
  'Registrar Salida': 'Register Expense',
  'Registrar Salida / Gasto': 'Register Expense',
  'Ingresar Dinero / Base Extra': 'Add Cash / Extra Base',
  'Ingresar Dinero': 'Add Cash',
  'INGRESAR': 'ADD CASH',
  'INGRESAR DINERO': 'ADD CASH',
  'Ingresos': 'Income / Injections',
  'Disponible': 'Available',
  'Monto': 'Amount',
  'Detalle / Motivo': 'Detail / Reason',
  'Base inicial': 'Initial base',
  'Ej: Pago Domicilio': 'E.g.: Home Delivery',
  'Ej: Base adicional, pago pedido, préstamo': 'E.g.: Additional base, order payment, loan',
  'Cancelar': 'Cancel',
  '🚫 Fondos insuficientes en caja': '🚫 Insufficient funds in cash drawer',
  'GUARDAR': 'SAVE',
  'INICIAR TURNO / ABRIR CAJA': 'START SHIFT / OPEN CASH DRAWER',
  'REGISTRAR GASTO': 'REGISTER EXPENSE',
  'IMPRIMIR TIRILLA DE CIERRE (Z)': 'PRINT CLOSURE RECEIPT (Z)',
  'Tirilla de Cierre': 'Closure Receipt',
  'LISTO / SALIR': 'DONE / EXIT',
  'Total Ventas Turno:': 'Total Shift Sales:',
  'Efectivo Contado:': 'Cash Counted:',
  'Estado del Cuadre:': 'Balance Status:',
  '⚠️ Fondos Insuficientes para este Pago': '⚠️ Insufficient Funds for this Payment',
  'En caja solo hay:': 'Cash in drawer is only:',
  'Monto del pedido / gasto:': 'Order / expense amount:',
  'Faltante para cubrir el gasto:': 'Missing amount to cover expense:',
  'Dinero a ingresar (refuerzo)': 'Cash to inject (reinforcement)',
  'Saldo final estimado en caja:': 'Estimated final cash drawer balance:',
  'Motivo del refuerzo / ingreso': 'Reason for cash reinforcement',
  'INGRESAR Y PAGAR PEDIDO': 'INJECT CASH & PAY ORDER',
  'El ingreso debe ser al menos de:': 'Cash injection must be at least:',
  '✅ Refuerzo y pago de pedido registrados correctamente': '✅ Cash reinforcement and order payment registered successfully',
  '✅ Movimiento registrado correctamente': '✅ Movement registered successfully',
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
  double _ingresosExtra = 0;
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
      _base = resumen['base'] ?? 0;
      _ventas = resumen['ventas_efectivo'] ?? 0;
      _ventasGlobal = resumen['ventas_global'] ?? 0;
      _gastos = resumen['gastos'] ?? 0;
      _ingresosExtra = resumen['ingresos_extra'] ?? 0;
      _totalEnCajaSistema = resumen['total_en_caja'] ?? 0;
      _movimientos = lista;
      _cajaAbierta = estaAbierta;
      _cargando = false; // Desactivamos carga
    });
  }

  // --- LOGICA: APERTURA, INGRESOS Y GASTOS ---
  void _mostrarDialogoMovimiento(String tipo) {
    final TextEditingController montoCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    final bool esApertura = tipo == 'APERTURA';
    final bool esIngreso = tipo == 'INGRESO';

    String titulo;
    IconData icono;
    Color colorPrimario;
    Color colorFondoAvatar;
    String hintTexto;

    if (esApertura) {
      titulo = _t("Iniciar Turno");
      icono = Icons.wb_sunny;
      colorPrimario = Colors.blue.shade800;
      colorFondoAvatar = Colors.blue.shade100;
      hintTexto = _t("Base inicial");
    } else if (esIngreso) {
      titulo = _t("Ingresar Dinero / Base Extra");
      icono = Icons.add_circle;
      colorPrimario = Colors.green.shade800;
      colorFondoAvatar = Colors.green.shade100;
      hintTexto = _t("Ej: Base adicional, pago pedido, préstamo");
    } else {
      titulo = _t("Registrar Salida / Gasto");
      icono = Icons.money_off;
      colorPrimario = Colors.orange.shade800;
      colorFondoAvatar = Colors.orange.shade100;
      hintTexto = _t("Ej: Pago Domicilio");
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorFondoAvatar,
              child: Icon(icono, color: colorPrimario),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
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
                  color: esIngreso ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (esIngreso ? Colors.green : Colors.orange).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: esIngreso ? Colors.green[800] : Colors.orange[800],
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${_t("Disponible")}: ${formater.format(_totalEnCajaSistema)}',
                        style: TextStyle(
                          color: esIngreso ? Colors.green[800] : Colors.orange[800],
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
                hintText: hintTexto,
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
              double? m = parseNumero(montoCtrl.text);

              if (m != null && m > 0) {
                // Caso: Salida de dinero superior al saldo disponible
                if (!esApertura && !esIngreso && m > _totalEnCajaSistema) {
                  Navigator.pop(ctx);
                  _mostrarDialogoInyectarYPagar(
                    gastoMonto: m,
                    gastoDescripcion: descCtrl.text.trim().isEmpty
                        ? _t("Pago de Pedido / Gasto")
                        : descCtrl.text.trim(),
                  );
                  return;
                }

                try {
                  await _cashService.registrarMovimiento(
                    tipo: tipo,
                    monto: m,
                    descripcion: descCtrl.text.trim().isEmpty
                        ? (esIngreso ? 'Ingreso de Efectivo' : (esApertura ? 'Base inicial' : 'Gasto de caja'))
                        : descCtrl.text.trim(),
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
                if (ctx.mounted) Navigator.pop(ctx);
                _cargarDatosCaja();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ ${_t("Movimiento registrado correctamente")}'),
                      backgroundColor: Colors.green.shade700,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorPrimario,
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

  /// Asistente inteligente para cuando llega un pedido/gasto mayor al dinero en caja.
  /// Permite inyectar la cantidad faltante (o más) y pagar el pedido en una sola operación atómica.
  void _mostrarDialogoInyectarYPagar({
    required double gastoMonto,
    required String gastoDescripcion,
  }) {
    final double faltanteMinimo = (gastoMonto - _totalEnCajaSistema).clamp(0, double.infinity);
    final TextEditingController ingresoCtrl = TextEditingController(
      text: faltanteMinimo.toInt().toString(),
    );
    final TextEditingController motivoIngresoCtrl = TextEditingController(
      text: "Inyección para pago: $gastoDescripcion",
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          double ingresoIngresado = parseNumero(ingresoCtrl.text) ?? 0;
          double saldoFinalEstimado = (_totalEnCajaSistema + ingresoIngresado) - gastoMonto;
          bool esValido = (_totalEnCajaSistema + ingresoIngresado + 0.005) >= gastoMonto && ingresoIngresado > 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  child: Icon(Icons.account_balance_wallet, color: Colors.amber.shade900),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t("⚠️ Fondos Insuficientes para este Pago"),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_t("En caja solo hay:"), style: const TextStyle(fontSize: 13, color: Colors.black87)),
                              Text(formater.format(_totalEnCajaSistema), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_t("Monto del pedido / gasto:"), style: const TextStyle(fontSize: 13, color: Colors.black87)),
                              Text(formater.format(gastoMonto), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_t("Faltante para cubrir el gasto:"), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.brown)),
                              Text(formater.format(faltanteMinimo), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown.shade800, fontSize: 15)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Para no quedar sin saldo en caja, ingresa la cantidad faltante más un colchón para continuar operando:",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ingresoCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                      decoration: InputDecoration(
                        labelText: _t("Dinero a ingresar (refuerzo)"),
                        prefixIcon: const Icon(Icons.add_circle, color: Colors.green),
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        filled: true,
                        fillColor: Colors.green.shade50.withOpacity(0.5),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: motivoIngresoCtrl,
                      decoration: InputDecoration(
                        labelText: _t("Motivo del refuerzo / ingreso"),
                        prefixIcon: const Icon(Icons.description),
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: saldoFinalEstimado >= 0 ? Colors.green.shade100.withOpacity(0.5) : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: saldoFinalEstimado >= 0 ? Colors.green.shade300 : Colors.red.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _t("Saldo final estimado en caja:"),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: saldoFinalEstimado >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                          Text(
                            formater.format(saldoFinalEstimado),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: saldoFinalEstimado >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!esValido)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "${_t('El ingreso debe ser al menos de:')} ${formater.format(faltanteMinimo)}",
                          style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_t("Cancelar"), style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 18),
                label: Text(_t("INGRESAR Y PAGAR PEDIDO")),
                onPressed: esValido
                    ? () async {
                        try {
                          await _cashService.registrarIngresoYGasto(
                            ingreso: ingresoIngresado,
                            gasto: gastoMonto,
                            descripcionIngreso: motivoIngresoCtrl.text.trim().isEmpty
                                ? "Inyección para pago de pedido"
                                : motivoIngresoCtrl.text.trim(),
                            descripcionGasto: gastoDescripcion,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _cargarDatosCaja();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_t("✅ Refuerzo y pago de pedido registrados correctamente")),
                                backgroundColor: Colors.green.shade700,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🚫 ${_t(e.toString())}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
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
                      final resCierre = await dbHelper.cerrarTurno(
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

                      final cierreCreado = resCierre['cierre'] as Map<String, dynamic>?;
                      if (cierreCreado != null && mounted) {
                        _mostrarDialogoExitoCierre(cierreCreado);
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_t("✅ Turno Cerrado Correctamente")),
                            backgroundColor: Colors.purple,
                          ),
                        );
                      }
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

  /// Diálogo modal tras el cierre de turno que permite imprimir la tirilla Z
  void _mostrarDialogoExitoCierre(Map<String, dynamic> cierre) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Colors.purple,
              child: Icon(Icons.check, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              _t("✅ Turno Cerrado Correctamente"),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t("Total Ventas Turno:"), style: const TextStyle(fontSize: 13)),
                      Text(
                        formater.format(cierre['ventas_turno_global'] ?? cierre['ventas_turno'] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t("Efectivo Contado:"), style: const TextStyle(fontSize: 13)),
                      Text(
                        formater.format(cierre['real_contado'] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t("Estado del Cuadre:"), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        cierre['estado'] ?? 'OK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: cierre['estado'] == 'OK' ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print, size: 20),
                label: Text(
                  _t("IMPRIMIR TIRILLA DE CIERRE (Z)"),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await PrinterService().imprimirArqueo(cierre);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _t("LISTO / SALIR"),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
        ],
      ),
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
                              _t("Ventas"),
                              _ventas,
                              Colors.greenAccent,
                            ),
                            _miniResumen(
                              _t("Ingresos"),
                              _ingresosExtra,
                              Colors.tealAccent,
                            ),
                            _miniResumen(
                              _t("Gastos"),
                              _gastos,
                              Colors.orangeAccent,
                            ),
                          ],
                        ),
                      if (_cajaAbierta) ...[
                        const SizedBox(height: 8),
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

                // BOTONES PRINCIPALES DE CAJA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: !_cajaAbierta
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _mostrarDialogoMovimiento('APERTURA'),
                            icon: const Icon(Icons.wb_sunny, size: 22),
                            label: Text(
                              _t("INICIAR TURNO / ABRIR CAJA"),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue.shade800,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _mostrarDialogoMovimiento('INGRESO'),
                                icon: const Icon(Icons.add_circle, size: 20),
                                label: Text(
                                  _t("INGRESAR DINERO"),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _mostrarDialogoMovimiento('GASTO'),
                                icon: const Icon(Icons.money_off, size: 20),
                                label: Text(
                                  _t("REGISTRAR GASTO"),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Colors.orange.shade800,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
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
