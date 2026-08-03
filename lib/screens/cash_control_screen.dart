import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

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

  // Variables de Estado
  double _base = 0;
  double _ventas = 0;
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

    bool estaAbierta = resumen['base']! > 0;

    if (!mounted) return;
    setState(() {
      _base = resumen['base']!;
      _ventas = resumen['ventas_efectivo']!;
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
            Text(esApertura ? "Iniciar Turno" : "Registrar Salida"),
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
                        "Disponible: ${formater.format(_totalEnCajaSistema)}",
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
              decoration: const InputDecoration(
                labelText: "Monto",
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: "Detalle / Motivo",
                hintText: esApertura ? "Base inicial" : "Ej: Pago Domicilio",
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
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Limpiamos comas y puntos para evitar errores numéricos
              String montoLimpio = montoCtrl.text.replaceAll(',', '.');
              double? m = double.tryParse(montoLimpio);

              if (m != null && m > 0) {
                if (!esApertura && m > _totalEnCajaSistema) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("🚫 Fondos insuficientes en caja"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                await DBHelper().registrarMovimientoCaja(
                  tipo,
                  m,
                  descCtrl.text,
                );
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
            child: const Text("GUARDAR"),
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
            double dineroReal =
                double.tryParse(realController.text.replaceAll(',', '.')) ?? 0;
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
                  title: const Text("📝 Anotar Gasto Olvidado"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: montoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Monto",
                          prefixIcon: Icon(Icons.money_off),
                        ),
                      ),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: "Detalle",
                          prefixIcon: Icon(Icons.description),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () async {
                        double? m = double.tryParse(
                          montoCtrl.text.replaceAll(',', '.'),
                        );
                        if (m != null) {
                          await DBHelper().registrarMovimientoCaja(
                            'GASTO',
                            m,
                            descCtrl.text,
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
                      child: const Text("REGISTRAR"),
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
              title: const Column(
                children: [
                  Icon(Icons.lock_clock, size: 50, color: Colors.purple),
                  Text(
                    "Cierre de Turno",
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                            const Text(
                              "El sistema espera:",
                              style: TextStyle(color: Colors.grey),
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
                        decoration: const InputDecoration(
                          hintText: "\$ 0",
                          labelText: "¿Cuánto contaste?",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.money),
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
                                    ? "¡PERFECTO! 😎"
                                    : (diferencia > 0
                                          ? "SOBRANTE 🤑"
                                          : "FALTANTE 😱"),
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
                        const Text(
                          "¿Se te olvidó anotar alguna salida?",
                          style: TextStyle(
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
                                label: const Text(
                                  "PAGO PEDIDO",
                                  style: TextStyle(fontSize: 10),
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
                                label: const Text(
                                  "GASTO VARIO",
                                  style: TextStyle(fontSize: 10),
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
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Ajustes automáticos
                    if (diferencia > 0) {
                      await DBHelper().registrarMovimientoCaja(
                        'INGRESO',
                        diferencia,
                        "Ajuste Sobrante Automático",
                      );
                    } else if (diferencia < 0) {
                      await DBHelper().registrarMovimientoCaja(
                        'GASTO',
                        diferencia.abs(),
                        "Pérdida / Descuadre Cierre",
                      );
                    }

                    // AQUI USAMOS LA VARIABLE 'estado' (Solución a la advertencia amarilla)
                    String estado = diferencia == 0
                        ? "OK"
                        : (diferencia > 0 ? "SOBRA" : "FALTA");
                    String desc =
                        "Cierre: Sistema ${_totalEnCajaSistema.toInt()} | Real ${dineroReal.toInt()} | Estado: $estado";

                    await DBHelper().registrarMovimientoCaja(
                      'CIERRE',
                      dineroReal,
                      desc,
                    );
                    Navigator.pop(context);
                    _cargarDatosCaja();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("✅ Turno Cerrado Correctamente"),
                        backgroundColor: Colors.purple,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text("CONFIRMAR Y CERRAR"),
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
    String estadoTexto = _cajaAbierta ? "ABIERTA 🟢" : "CERRADA 🔴";
    Color estadoColor = _cajaAbierta ? Colors.green : Colors.red;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Gestión de Efectivo"),
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
                        _cajaAbierta ? "DINERO EN CAJA" : "TURNO CERRADO",
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
                            _miniResumen("Base", _base, Colors.blueAccent),
                            _miniResumen("Ventas", _ventas, Colors.greenAccent),
                            _miniResumen(
                              "Gastos",
                              _gastos,
                              Colors.orangeAccent,
                            ),
                          ],
                        ),
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
                          label: const Text("ABRIR"),
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
                          label: const Text("GASTO"),
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
                        label: const Text("CERRAR TURNO"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
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
                          mov['tipo'] == 'COMPRA_CREDITO'; // El nuevo tipo
                      bool esCierre = mov['tipo'] == 'CIERRE';

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
                      } // Color diferente para crédito

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
