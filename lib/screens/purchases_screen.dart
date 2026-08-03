import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import 'purchase_history_screen.dart'; // ✅ IMPORTANTE: CONECTA CON EL HISTORIAL

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final List<Map<String, dynamic>> _incomingItems = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _proveedorCtrl = TextEditingController();
  bool _pagoConCaja = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  void _cargarProductos() async {
    final data = await DBHelper().getProducts();
    setState(() {
      _products = data;
      _filteredProducts = [];
    });
  }

  void _filtrarProductos(String query) {
    if (query.isEmpty) {
      setState(() => _filteredProducts = []);
      return;
    }
    setState(() {
      _filteredProducts = _products.where((p) {
        return p['nombre'].toString().toLowerCase().contains(
              query.toLowerCase(),
            ) ||
            (p['codigo_barras'] ?? '').toString().contains(query);
      }).toList();
    });
  }

  // --- REEMPLAZA TU FUNCIÓN _mostrarDialogoIngreso CON ESTA LÓGICA CONTABLE ---
  void _mostrarDialogoIngreso(Map<String, dynamic> producto) {
    final cantidadCajasCtrl = TextEditingController(text: "1");
    final unidadesPorCajaCtrl = TextEditingController(text: "1");
    final costoTotalCtrl = TextEditingController();

    final porcentajeGananciaCtrl = TextEditingController(text: "30");
    final precioVentaFinalCtrl = TextEditingController();

    // 1. DATOS ACTUALES DEL INVENTARIO
    double costoActualBD =
        (producto['precio_costo'] as num?)?.toDouble() ?? 0.0;
    double stockActualBD =
        (producto['stock_actual'] as num?)?.toDouble() ?? 0.0;
    // Si el stock es negativo (por ventas sin stock), lo tratamos como 0 para el promedio
    if (stockActualBD < 0) stockActualBD = 0;

    double precioVentaActualBD =
        (producto['precio_venta'] as num?)?.toDouble() ?? 0.0;
    precioVentaFinalCtrl.text = precioVentaActualBD.toInt().toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          // 2. DATOS DE LA ENTRADA
          double cajas = double.tryParse(cantidadCajasCtrl.text) ?? 0;
          double unids = double.tryParse(unidadesPorCajaCtrl.text) ?? 1;
          double cantidadEntrante = cajas * unids;
          double costoTotalFactura =
              double.tryParse(costoTotalCtrl.text.replaceAll(',', '.')) ?? 0;

          // 3. 🔥 CÁLCULO DE COSTO PROMEDIO PONDERADO 🔥
          double costoUnitarioEntrante = cantidadEntrante > 0
              ? costoTotalFactura / cantidadEntrante
              : 0;

          double costoPromedioPonderado = 0;
          double totalUnidadesFinal = stockActualBD + cantidadEntrante;

          if (totalUnidadesFinal > 0) {
            double valorInventarioActual = stockActualBD * costoActualBD;
            double valorEntrada =
                costoTotalFactura; // (cantidadEntrante * costoUnitarioEntrante)
            costoPromedioPonderado =
                (valorInventarioActual + valorEntrada) / totalUnidadesFinal;
          } else {
            costoPromedioPonderado = costoActualBD;
          }

          // Función para sugerir precio basado en el NUEVO costo promedio
          void calcularPrecioVenta() {
            double porcentaje =
                double.tryParse(porcentajeGananciaCtrl.text) ?? 0;
            double precioSugerido =
                costoPromedioPonderado * (1 + (porcentaje / 100));
            // Redondeo a la cincuentena más cercana (ej: 1230 -> 1250)
            double precioRedondeado = (precioSugerido / 50).ceil() * 50;
            precioVentaFinalCtrl.text = precioRedondeado.toInt().toString();
          }

          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ingresar: ${producto['nombre']}",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 5),
                Text(
                  "Stock actual: ${formater.format(stockActualBD)} u | Costo: ${formater.format(costoActualBD)}",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "📦 CANTIDADES ENTRANTES",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: cantidadCajasCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Bultos",
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) {
                                  setStateModal(() {});
                                  calcularPrecioVenta();
                                },
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: TextField(
                                controller: unidadesPorCajaCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Und x Bulto",
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) {
                                  setStateModal(() {});
                                  calcularPrecioVenta();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Entran: ${cantidadEntrante.toStringAsFixed(1)} Unidades",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "💰 COSTO DE ESTA FACTURA",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  TextField(
                    controller: costoTotalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Valor Total a Pagar (\$)",
                      prefixIcon: Icon(Icons.attach_money),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      setStateModal(() {});
                      calcularPrecioVenta();
                    },
                  ),

                  // RESUMEN DE CAMBIO DE COSTO
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Costo Unit. Factura:",
                              style: TextStyle(fontSize: 11),
                            ),
                            Text(
                              formater.format(costoUnitarioEntrante),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "NUEVO COSTO PROM:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              formater.format(costoPromedioPonderado),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(),
                  const Text(
                    "📈 PRECIO DE VENTA PÚBLICO",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: porcentajeGananciaCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "% Gan.",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              setStateModal(() => calcularPrecioVenta()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: precioVentaFinalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Precio Final",
                            prefixIcon: Icon(Icons.sell),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () {
                  double precioVentaFinal =
                      double.tryParse(
                        precioVentaFinalCtrl.text.replaceAll(',', '.'),
                      ) ??
                      0;
                  if (cantidadEntrante > 0 &&
                      costoTotalFactura > 0 &&
                      precioVentaFinal > 0) {
                    // AQUÍ ENVIAMOS EL COSTO PROMEDIO YA CALCULADO
                    _agregarALista(
                      producto,
                      cantidadEntrante,
                      costoPromedioPonderado,
                      costoTotalFactura,
                      precioVentaFinal,
                    );
                    Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("⚠️ Revisa los valores (Costo y Precio)"),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                ),
                child: const Text("AGREGAR"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _agregarALista(
    Map<String, dynamic> producto,
    double cantidad,
    double costoUnitario,
    double costoTotal,
    double nuevoPrecioVenta,
  ) {
    setState(() {
      _incomingItems.add({
        'id': producto['id'],
        'nombre': producto['nombre'],
        'cantidad': cantidad,
        'nuevo_costo': costoUnitario,
        'nuevo_precio_venta': nuevoPrecioVenta,
        'subtotal_compra': costoTotal,
      });
    });
  }

  void _finalizarIngreso() {
    if (_incomingItems.isEmpty) return;
    double totalFactura = _incomingItems.fold(
      0,
      (sum, item) => sum + item['subtotal_compra'],
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          return AlertDialog(
            title: const Text("Finalizar Pedido"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Total Factura: ${formater.format(totalFactura)}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _proveedorCtrl,
                  decoration: const InputDecoration(
                    labelText: "Proveedor (Opcional)",
                    prefixIcon: Icon(Icons.local_shipping),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text("¿Pagar con Caja?"),
                  subtitle: const Text("Se restará del efectivo disponible."),
                  value: _pagoConCaja,
                  activeThumbColor: Colors.red,
                  onChanged: (val) => setSt(() => _pagoConCaja = val),
                ),
                const SizedBox(height: 10),
                const Text(
                  "⚠️ Al confirmar, se actualizarán los precios de venta.",
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  // 🛑 VERIFICACIÓN DE FONDOS 🛑
                  if (_pagoConCaja) {
                    final resumen = await DBHelper().obtenerResumenCaja();
                    double dineroEnCaja = resumen['total_en_caja'] ?? 0;

                    if (totalFactura > dineroEnCaja) {
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.money_off, color: Colors.red),
                              SizedBox(width: 10),
                              Text("¡FONDOS INSUFICIENTES!"),
                            ],
                          ),
                          content: Text(
                            "En caja solo hay: ${formater.format(dineroEnCaja)}\n\nFaltan: ${formater.format(totalFactura - dineroEnCaja)}\n\n📢 LLAMA AL ENCARGADO PARA QUE TRAIGA DINERO.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text("ENTENDIDO"),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                  }

                  await DBHelper().registrarCompra(
                    _incomingItems,
                    totalFactura,
                    _pagoConCaja,
                    _proveedorCtrl.text,
                  );
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Inventario y Precios actualizados"),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle),
                label: const Text("CONFIRMAR INGRESO"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ingreso de Pedidos"),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        // ✅ BOTÓN DE HISTORIAL AGREGADO AQUÍ
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 30),
            tooltip: "Ver Historial de Facturas",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => const PurchaseHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarProductos,
              decoration: InputDecoration(
                hintText: "Buscar producto para ingresar...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filtrarProductos("");
                    FocusScope.of(context).unfocus();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),

          if (_searchController.text.isNotEmpty)
            Container(
              height: 200,
              color: Colors.white,
              child: ListView.builder(
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final prod = _filteredProducts[index];
                  double costoSeguro =
                      (prod['precio_costo'] as num?)?.toDouble() ?? 0.0;

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.add_box, color: Colors.green),
                    title: Text(
                      prod['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      // 🔥 AQUÍ USAMOS LA VARIABLE costoSeguro QUE DABA ERROR
                      "Stock: ${prod['stock_actual']} | Costo: ${formater.format(costoSeguro)}",
                    ),
                    onTap: () {
                      _mostrarDialogoIngreso(prod);
                      _searchController.clear();
                      _filtrarProductos("");
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ),

          const Divider(thickness: 5),

          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.brown[50],
            width: double.infinity,
            child: const Text(
              "📦 Productos a Ingresar (Con nuevos precios)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
          ),
          Expanded(
            child: _incomingItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 50,
                          color: Colors.grey[300],
                        ),
                        const Text("Carrito de compras vacío"),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _incomingItems.length,
                    itemBuilder: (context, index) {
                      final item = _incomingItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: ListTile(
                          title: Text(
                            item['nombre'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "Nuevas: +${item['cantidad']} | Nuevo Precio Venta: ${formater.format(item['nuevo_precio_venta'])}",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formater.format(item['subtotal_compra']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => setState(
                                  () => _incomingItems.removeAt(index),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TOTAL FACTURA:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        formater.format(
                          _incomingItems.fold(
                            0.0,
                            (sum, item) => sum + item['subtotal_compra'],
                          ),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.brown,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _incomingItems.isEmpty ? null : _finalizarIngreso,
                  icon: const Icon(Icons.save_alt),
                  label: const Text("FINALIZAR"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
