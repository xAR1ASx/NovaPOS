import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/locale_service.dart';
import '../services/session_service.dart';
import 'purchase_history_screen.dart';
import '../utils/numero.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Ingreso de Pedidos (Factura de Compra)': 'Order Entry (Purchase Invoice)',
  'Ver Historial de Facturas': 'View Invoice History',
  'Proveedor (ej: Corabastos, Mayorista...)': 'Supplier (e.g. Wholesale...)',
  'Total Factura en Papel (\$)': 'Invoice Total on Paper (\$)',
  'Buscar producto por nombre o código PLU (ej: 101)...': 'Search product by name or PLU (e.g. 101)...',
  'Stock:': 'Stock:',
  'Costo actual:': 'Current cost:',
  '📦 Productos en esta Factura': '📦 Products in this Invoice',
  'Aún no has agregado productos a esta factura.': 'You have not added products to this invoice yet.',
  'Usa el buscador arriba para agregar el primer producto del pedido.': 'Use the search bar above to add the first product of the order.',
  '¿Pagar con dinero de Caja?': 'Pay with cash register money?',
  'Se restará del efectivo del turno actual en caja': 'It will be deducted from the current shift cash',
  'Se registra como crédito de proveedor o pago bancario': 'Recorded as supplier credit or bank payment',
  'TOTAL FACTURA:': 'INVOICE TOTAL:',
  'FINALIZAR FACTURA': 'FINALIZE INVOICE',
  'Editar Ítem:': 'Edit Item:',
  'Ingresar a Factura:': 'Enter to Invoice:',
  'Costo actual en BD:': 'Current DB cost:',
  '📦 CANTIDAD ENTRANTE': '📦 INCOMING QUANTITY',
  'Bultos / Cajas / Paquetes': 'Bales / Boxes / Packages',
  'Kilos o Unds por Bulto (1 si es directo)': 'Kg or Units per Bale (1 if direct)',
  'Total Entrante:': 'Total Incoming:',
  '💰 COSTO DE ESTE PRODUCTO EN LA FACTURA': '💰 COST OF THIS PRODUCT IN INVOICE',
  'Total a Pagar por esta línea (\$)': 'Total to Pay for this line (\$)',
  'Costo Unitario Factura (\$)': 'Invoice Unit Cost (\$)',
  'NUEVO COSTO PROM. PONDERADO:': 'NEW WEIGHTED AVG COST:',
  '📈 PRECIO DE VENTA Y MARGEN': '📈 SALE PRICE AND MARGIN',
  '% Ganancia sugerido': '% Suggested profit',
  'Nuevo Precio de Venta Público': 'New Public Sale Price',
  'Cancelar': 'Cancel',
  'ACTUALIZAR ÍTEM': 'UPDATE ITEM',
  'AGREGAR A FACTURA': 'ADD TO INVOICE',
  '¡FONDOS INSUFICIENTES!': 'INSUFFICIENT FUNDS!',
  'En caja solo hay:': 'There is only in cash:',
  'Faltan:': 'Missing:',
  '📢 LLAMA AL ENCARGADO PARA QUE TRAIGA DINERO.': '📢 CALL THE MANAGER TO BRING MONEY.',
  'ENTENDIDO': 'UNDERSTOOD',
  '✅ Factura registrada con éxito': '✅ Invoice successfully registered',
  '⚠️ Diferencia con el Papel': '⚠️ Difference with Paper Invoice',
  '¿Deseas finalizar la factura de todas formas?': 'Do you want to finalize the invoice anyway?',
  'CONTINUAR Y GUARDAR': 'CONTINUE AND SAVE',
};

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
  final TextEditingController _totalFacturaPapelCtrl = TextEditingController();
  bool _pagoConCaja = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _proveedorCtrl.dispose();
    _totalFacturaPapelCtrl.dispose();
    super.dispose();
  }

  void _cargarProductos() async {
    final data = await DBHelper().getProducts();
    if (!mounted) return;
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
    final q = query.toLowerCase().trim();
    setState(() {
      _filteredProducts = _products.where((p) {
        final nombre = p['nombre'].toString().toLowerCase();
        final plu = (p['codigo_plu'] ?? '').toString().toLowerCase();
        final barras = (p['codigo_barras'] ?? '').toString().toLowerCase();
        final cat = (p['categoria'] ?? '').toString().toLowerCase();
        return nombre.contains(q) || plu.contains(q) || barras.contains(q) || cat.contains(q);
      }).toList();
    });
  }

  double get _sumaSubtotales => _incomingItems.fold(
        0.0,
        (sum, item) => sum + (item['subtotal_compra'] as num).toDouble(),
      );

  // --- 📝 MODAL DE INGRESO Y EDICIÓN DE CADA PRODUCTO EN LA FACTURA ---
  void _mostrarDialogoIngreso(
    Map<String, dynamic> producto, {
    int? indiceEdicion,
  }) {
    final bool esEdicion = indiceEdicion != null;
    final itemExistente = esEdicion ? _incomingItems[indiceEdicion] : null;

    final cantidadCajasCtrl = TextEditingController(
      text: itemExistente != null
          ? (itemExistente['bultos'] ?? itemExistente['cantidad']).toString()
          : "1",
    );
    final unidadesPorCajaCtrl = TextEditingController(
      text: itemExistente != null
          ? (itemExistente['unidades_por_bulto'] ?? 1).toString()
          : "1",
    );
    final costoTotalCtrl = TextEditingController(
      text: itemExistente != null
          ? (itemExistente['subtotal_compra'] as num).toInt().toString()
          : "",
    );
    final costoUnitarioCtrl = TextEditingController(
      text: itemExistente != null
          ? (itemExistente['costo_unitario_factura'] as num).toInt().toString()
          : "",
    );
    final porcentajeGananciaCtrl = TextEditingController(
      text: itemExistente != null
          ? (itemExistente['porcentaje_ganancia'] ?? 30).toString()
          : "30",
    );
    final precioVentaFinalCtrl = TextEditingController(
      text: itemExistente != null
          ? (itemExistente['nuevo_precio_venta'] as num).toInt().toString()
          : (producto['precio_venta'] as num?)?.toInt().toString() ?? "",
    );

    double costoActualBD = (producto['precio_costo'] as num?)?.toDouble() ?? 0.0;
    double stockActualBD = (producto['stock_actual'] as num?)?.toDouble() ?? 0.0;
    if (stockActualBD < 0) stockActualBD = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          double cajas = parseNumero(cantidadCajasCtrl.text) ?? 0;
          double unids = parseNumero(unidadesPorCajaCtrl.text) ?? 1;
          double cantidadEntrante = cajas * unids;
          double costoTotalFactura = parseNumero(costoTotalCtrl.text) ?? 0;

          // Cálculo del costo unitario entrante
          double costoUnitarioEntrante = cantidadEntrante > 0
              ? costoTotalFactura / cantidadEntrante
              : (parseNumero(costoUnitarioCtrl.text) ?? 0);

          // Cálculo del Costo Promedio Ponderado
          double totalUnidadesFinal = stockActualBD + cantidadEntrante;
          double costoPromedioPonderado = 0;
          if (totalUnidadesFinal > 0) {
            double valorInventarioActual = stockActualBD * costoActualBD;
            double valorEntrada = costoTotalFactura;
            costoPromedioPonderado =
                (valorInventarioActual + valorEntrada) / totalUnidadesFinal;
          } else {
            costoPromedioPonderado = costoActualBD > 0 ? costoActualBD : costoUnitarioEntrante;
          }

          // Sugerir precio de venta con el margen
          void recalcularPrecioPorMargen([double? margenNuevo]) {
            if (margenNuevo != null) {
              porcentajeGananciaCtrl.text = margenNuevo.toStringAsFixed(0);
            }
            double pct = parseNumero(porcentajeGananciaCtrl.text) ?? 30;
            double baseCosto = costoPromedioPonderado > 0 ? costoPromedioPonderado : costoUnitarioEntrante;
            double sugerido = baseCosto * (1 + (pct / 100));
            double redondeado = (sugerido / 50).ceil() * 50;
            if (redondeado <= 0) redondeado = sugerido;
            precioVentaFinalCtrl.text = redondeado.toInt().toString();
            setStateModal(() {});
          }

          // Si el usuario escribe directamente el precio final, ajustar margen
          void onPrecioFinalModificado(String val) {
            double pFinal = parseNumero(val) ?? 0;
            double baseCosto = costoPromedioPonderado > 0 ? costoPromedioPonderado : costoUnitarioEntrante;
            if (baseCosto > 0 && pFinal > 0) {
              double pct = ((pFinal - baseCosto) / baseCosto) * 100;
              porcentajeGananciaCtrl.text = pct.toStringAsFixed(0);
            }
            setStateModal(() {});
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (producto['es_pesable'] == 1 ? Colors.green : Colors.orange).withOpacity(0.15),
                  child: Icon(
                    producto['es_pesable'] == 1 ? Icons.scale : Icons.shopping_basket,
                    color: producto['es_pesable'] == 1 ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esEdicion
                            ? "${_t('Editar Ítem:')} ${producto['nombre']}"
                            : "${_t('Ingresar a Factura:')} ${producto['nombre']}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${_t('Stock:')} ${stockActualBD.toStringAsFixed(1)} | ${_t('Costo actual en BD:')} ${formater.format(costoActualBD)}",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    // 1. CANTIDADES
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.all_inbox, size: 16, color: Colors.blue),
                              const SizedBox(width: 6),
                              Text(
                                _t('📦 CANTIDAD ENTRANTE'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: cantidadCajasCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: _t('Bultos / Cajas'),
                                    hintText: 'Ej: 2',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (_) {
                                    setStateModal(() {});
                                    recalcularPrecioPorMargen();
                                  },
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text("×", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: unidadesPorCajaCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: _t('Kg / Und x Bulto'),
                                    hintText: '1 si es directo',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (_) {
                                    setStateModal(() {});
                                    recalcularPrecioPorMargen();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "${_t('Total Entrante:')} ${cantidadEntrante.toStringAsFixed(1)} ${producto['es_pesable'] == 1 ? 'Kg' : 'Unds'}",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. COSTO EN FACTURA
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long, size: 16, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                _t('💰 COSTO DE ESTE PRODUCTO EN LA FACTURA'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green[900]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: TextField(
                                  controller: costoTotalCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: _t('Total a Pagar por esta línea (\$)'),
                                    prefixIcon: const Icon(Icons.attach_money),
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (v) {
                                    double tot = parseNumero(v) ?? 0;
                                    if (cantidadEntrante > 0) {
                                      costoUnitarioCtrl.text = (tot / cantidadEntrante).toStringAsFixed(0);
                                    }
                                    setStateModal(() {});
                                    recalcularPrecioPorMargen();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: TextField(
                                  controller: costoUnitarioCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: _t('Costo Unitario (\$)'),
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (v) {
                                    double unit = parseNumero(v) ?? 0;
                                    costoTotalCtrl.text = (unit * cantidadEntrante).toStringAsFixed(0);
                                    setStateModal(() {});
                                    recalcularPrecioPorMargen();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_t('NUEVO COSTO PROM. PONDERADO:'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(
                                  formater.format(costoPromedioPonderado),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[800]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 3. MARGEN Y PRECIO DE VENTA
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.trending_up, size: 16, color: Colors.orange),
                              const SizedBox(width: 6),
                              Text(
                                _t('📈 PRECIO DE VENTA Y MARGEN'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange[900]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Botones rápidos de margen
                          Wrap(
                            spacing: 6,
                            children: [20, 25, 30, 35, 40, 50].map((p) {
                              return InkWell(
                                onTap: () => recalcularPrecioPorMargen(p.toDouble()),
                                child: Chip(
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  label: Text("+$p%", style: const TextStyle(fontSize: 11)),
                                  backgroundColor: porcentajeGananciaCtrl.text == p.toString()
                                      ? Colors.orange[200]
                                      : Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: porcentajeGananciaCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: _t('% Gan.'),
                                    suffixText: '%',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => recalcularPrecioPorMargen(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: precioVentaFinalCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: _t('Nuevo Precio de Venta Público'),
                                    prefixIcon: const Icon(Icons.sell),
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: onPrecioFinalModificado,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_t('Cancelar')),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  double precioVentaFinal = parseNumero(precioVentaFinalCtrl.text) ?? 0;
                  if (cantidadEntrante > 0 && costoTotalFactura > 0 && precioVentaFinal > 0) {
                    final itemData = {
                      'id': producto['id'],
                      'nombre': producto['nombre'],
                      'cantidad': cantidadEntrante,
                      'nuevo_costo': costoPromedioPonderado,
                      'nuevo_precio_venta': precioVentaFinal,
                      'subtotal_compra': costoTotalFactura,
                      'bultos': cajas,
                      'unidades_por_bulto': unids,
                      'porcentaje_ganancia': parseNumero(porcentajeGananciaCtrl.text) ?? 30,
                      'costo_unitario_factura': costoUnitarioEntrante,
                      'categoria': producto['categoria'] ?? 'General',
                      'imagen_path': producto['imagen_path'],
                      'es_pesable': producto['es_pesable'] ?? 0,
                    };

                    setState(() {
                      if (esEdicion) {
                        _incomingItems[indiceEdicion] = itemData;
                      } else {
                        // Si ya estaba en la factura, lo reemplaza
                        final existIdx = _incomingItems.indexWhere((it) => it['id'] == producto['id']);
                        if (existIdx >= 0) {
                          _incomingItems[existIdx] = itemData;
                        } else {
                          _incomingItems.add(itemData);
                        }
                      }
                      _searchController.clear();
                      _filteredProducts = [];
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(esEdicion
                            ? "🔄 ${producto['nombre']} actualizado en la factura"
                            : "✅ ${producto['nombre']} agregado a la factura"),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t('⚠️ Revisa los valores (Costo y Precio)')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: esEdicion ? Colors.blue[800] : Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: Icon(esEdicion ? Icons.save : Icons.add_shopping_cart),
                label: Text(esEdicion ? _t('ACTUALIZAR ÍTEM') : _t('AGREGAR A FACTURA')),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 🏁 CONFIRMAR Y FINALIZAR FACTURA ---
  void _finalizarFactura() async {
    if (_incomingItems.isEmpty) return;
    final double totalSuma = _sumaSubtotales;
    final double? totalPapel = parseNumero(_totalFacturaPapelCtrl.text);

    // Si el usuario ingresó un total papel diferente al calculado, alertar
    if (totalPapel != null && (totalPapel - totalSuma).abs() > 1) {
      final bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(_t('⚠️ Diferencia con el Papel')),
            ],
          ),
          content: Text(
            "La suma de los productos cargados es ${formater.format(totalSuma)},\n"
            "pero en el papel indicaste ${formater.format(totalPapel)}.\n\n"
            "Diferencia: ${formater.format((totalPapel - totalSuma).abs())}\n\n"
            "${_t('¿Deseas finalizar la factura de todas formas?')}",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(_t('Cancelar')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
              child: Text(_t('CONTINUAR Y GUARDAR')),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    // Validación de efectivo en caja si se paga con caja
    if (_pagoConCaja) {
      final resumen = await DBHelper().obtenerResumenCaja();
      double dineroEnCaja = resumen['total_en_caja'] ?? 0;
      if (totalSuma > dineroEnCaja) {
        if (!mounted) return;
        final bool? pagarExterno = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Colors.orange, size: 28),
                const SizedBox(width: 10),
                const Text('Fondo de Caja Insuficiente'),
              ],
            ),
            content: Text(
              "En el cajón de la caja hoy solo hay: ${formater.format(dineroEnCaja)},\n"
              "pero la factura total es de: ${formater.format(totalSuma)}.\n\n"
              "¿Cómo se pagó este pedido?\n\n"
              "• Si el dueño pagó con su propio dinero, transferencia (Nequi/Bancolombia) o quedó a crédito, "
              "selecciona 'Pago Externo / Banco' para no afectar el cuadre de caja de hoy.\n"
              "• Si vas a meter el dinero físico a la caja, cancela y haz primero un 'Ingreso de Dinero' en Control de Caja.",
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.account_balance),
                label: const Text('REGISTRAR COMO PAGO EXTERNO / BANCO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(c, true),
              ),
            ],
          ),
        );

        if (pagarExterno == true) {
          _pagoConCaja = false;
        } else {
          return;
        }
      }
    }

    // Registrar en BD
    final res = await DBHelper().registrarCompra(
      _incomingItems,
      totalSuma,
      _pagoConCaja,
      _proveedorCtrl.text.trim(),
      usuarioId: SessionService.userId() ?? 1,
    );

    if (!mounted) return;

    if (res['exito'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${_t(res['mensaje'] ?? 'Error')}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Factura de compra registrada con éxito (${_incomingItems.length} referencias actualizadas)"),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ),
    );

    setState(() {
      _incomingItems.clear();
      _proveedorCtrl.clear();
      _totalFacturaPapelCtrl.clear();
      _searchController.clear();
      _filteredProducts = [];
    });
    _cargarProductos();
  }

  Widget _buildCuadreBanner() {
    final double suma = _sumaSubtotales;
    final double? papel = parseNumero(_totalFacturaPapelCtrl.text);

    if (papel == null || papel <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: Colors.brown[50],
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Colors.brown),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Suma acumulada de productos: ${formater.format(suma)} (${_incomingItems.length} ítems)",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.brown),
              ),
            ),
          ],
        ),
      );
    }

    final double diff = papel - suma;
    final bool cuadrado = diff.abs() < 1;
    final bool falta = diff > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: cuadrado ? Colors.green[100] : (falta ? Colors.orange[100] : Colors.red[100]),
      child: Row(
        children: [
          Icon(
            cuadrado ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 20,
            color: cuadrado ? Colors.green[800] : (falta ? Colors.orange[900] : Colors.red[900]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cuadrado
                  ? "✅ ¡Factura Cuadrada con el Papel! (${formater.format(papel)})"
                  : falta
                      ? "⚠️ Faltan ${formater.format(diff)} por cargar (Papel: ${formater.format(papel)} | Suma: ${formater.format(suma)})"
                      : "⚠️ La suma supera el papel por ${formater.format(diff.abs())} (Papel: ${formater.format(papel)} | Suma: ${formater.format(suma)})",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cuadrado ? Colors.green[900] : (falta ? Colors.orange[900] : Colors.red[900]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductThumbnail(Map<String, dynamic> p) {
    final imgPath = (p['imagen_path'] ?? '').toString();
    if (imgPath.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imgPath,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24, color: Colors.grey),
        ),
      );
    }
    if (imgPath.isNotEmpty && File(imgPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imgPath),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24, color: Colors.grey),
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: (p['es_pesable'] == 1 ? Colors.green : Colors.orange).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        p['es_pesable'] == 1 ? Icons.scale : Icons.shopping_basket,
        color: p['es_pesable'] == 1 ? Colors.green[800] : Colors.orange[800],
        size: 22,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalSuma = _sumaSubtotales;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Ingreso de Pedidos (Factura de Compra)')),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 28),
            tooltip: _t('Ver Historial de Facturas'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const PurchaseHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. CABECERA DE LA FACTURA
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _proveedorCtrl,
                    decoration: InputDecoration(
                      labelText: _t('Proveedor (ej: Corabastos, Mayorista...)'),
                      prefixIcon: const Icon(Icons.local_shipping_outlined),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _totalFacturaPapelCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _t('Total Factura en Papel (\$)'),
                      prefixIcon: const Icon(Icons.receipt_outlined),
                      hintText: 'Opcional para cuadre',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),

          // Banner de Cuadre en tiempo real
          _buildCuadreBanner(),

          // 2. BUSCADOR RÁPIDO DE PRODUCTOS
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarProductos,
              decoration: InputDecoration(
                hintText: _t('Buscar producto por nombre o código PLU (ej: 101)...'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filtrarProductos("");
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[100],
                isDense: true,
              ),
            ),
          ),

          // Menú desplegable de resultados de búsqueda
          if (_searchController.text.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final prod = _filteredProducts[index];
                  final double costoSeguro = (prod['precio_costo'] as num?)?.toDouble() ?? 0.0;
                  final plu = prod['codigo_plu'] ?? '';

                  return ListTile(
                    dense: true,
                    leading: _buildProductThumbnail(prod),
                    title: Text(
                      prod['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${plu.isNotEmpty ? 'PLU: $plu | ' : ''}${_t('Stock:')} ${prod['stock_actual']} | ${_t('Costo actual:')} ${formater.format(costoSeguro)}",
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () {
                        final idx = _incomingItems.indexWhere((it) => it['id'] == prod['id']);
                        _mostrarDialogoIngreso(prod, indiceEdicion: idx >= 0 ? idx : null);
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Ingresar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  );
                },
              ),
            ),

          const Divider(height: 10),

          // 3. ENCABEZADO DE LA LISTA DE PRODUCTOS CARGADOS EN ESTA FACTURA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_t('📦 Productos en esta Factura')} (${_incomingItems.length})",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown[900], fontSize: 13),
                ),
                if (_incomingItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _incomingItems.clear());
                    },
                    icon: const Icon(Icons.clear_all, size: 16, color: Colors.red),
                    label: const Text("Limpiar todo", style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),

          // 4. LISTADO DE PRODUCTOS CARGADOS (EDITABLES UNO POR UNO)
          Expanded(
            child: _incomingItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[350]),
                        const SizedBox(height: 10),
                        Text(
                          _t('Aún no has agregado productos a esta factura.'),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t('Usa el buscador arriba para agregar el primer producto del pedido.'),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _incomingItems.length,
                    itemBuilder: (context, index) {
                      final item = _incomingItems[index];
                      final double subtotal = (item['subtotal_compra'] as num).toDouble();
                      final double nuevoPrecio = (item['nuevo_precio_venta'] as num).toDouble();
                      final double cant = (item['cantidad'] as num).toDouble();
                      final double unitCosto = (item['costo_unitario_factura'] as num?)?.toDouble() ?? (subtotal / (cant > 0 ? cant : 1));

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: InkWell(
                          onTap: () {
                            final prodBD = _products.firstWhere(
                              (p) => p['id'] == item['id'],
                              orElse: () => item,
                            );
                            _mostrarDialogoIngreso(prodBD, indiceEdicion: index);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                _buildProductThumbnail(item),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['nombre'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                                            child: Text(
                                              "Entran: ${cant.toStringAsFixed(1)} ${item['es_pesable'] == 1 ? 'Kg' : 'Und'}",
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                                            child: Text(
                                              "Costo: ${formater.format(subtotal)} (${formater.format(unitCosto)}/u)",
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[900]),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                                            child: Text(
                                              "+${item['porcentaje_ganancia']}% ➔ Venta: ${formater.format(nuevoPrecio)}",
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 22),
                                      tooltip: "Modificar precio, cantidad o margen",
                                      onPressed: () {
                                        final prodBD = _products.firstWhere(
                                          (p) => p['id'] == item['id'],
                                          orElse: () => item,
                                        );
                                        _mostrarDialogoIngreso(prodBD, indiceEdicion: index);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                                      tooltip: "Quitar de esta factura",
                                      onPressed: () => setState(() => _incomingItems.removeAt(index)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 5. BARRA INFERIOR DE TOTAL Y FINALIZAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _t('TOTAL FACTURA:'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formater.format(totalSuma),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.brown[900]),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Switch(
                            value: _pagoConCaja,
                            activeColor: Colors.green[700],
                            onChanged: (v) => setState(() => _pagoConCaja = v),
                          ),
                          Expanded(
                            child: Text(
                              _pagoConCaja
                                  ? _t('¿Pagar con dinero de Caja?')
                                  : _t('Se registra como crédito de proveedor o pago bancario'),
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _incomingItems.isEmpty ? null : _finalizarFactura,
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: Text(
                    "${_t('FINALIZAR FACTURA')} (${_incomingItems.length})",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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