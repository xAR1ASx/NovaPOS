import '../services/printer_service.dart'; // 🔥 Importamos el servicio de impresión
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import 'inventory_screen.dart';
import 'cash_control_screen.dart';
import 'clients_screen.dart';
import 'dart:io';
import '../services/permission_service.dart';
import '../utils/numero.dart';
import '../services/sales_service.dart';
import '../services/balanza_service.dart';
import '../services/locale_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Nueva Categoría': 'New Category',
  'Nombre (Ej: Helados)': 'Name (e.g.: Ice Cream)',
  'Cancelar': 'Cancel',
  'GUARDAR': 'SAVE',
  '¿Cancelar Venta?': 'Cancel Sale?',
  'Se borrarán todos los productos de este pedido.': 'All products in this order will be deleted.',
  'No': 'No',
  'SÍ, BORRAR': 'YES, DELETE',
  '¡STOP! CAJA CERRADA 🛑': 'STOP! REGISTER CLOSED 🛑',
  '⚠️ No puedes vender si no has hecho la Apertura de Caja.\n\nPor favor, registra la base inicial.': '⚠️ You cannot sell if you have not opened the Register.\n\nPlease, register the starting cash.',
  '🔙 Volver': '🔙 Back',
  'IR A ABRIR CAJA': 'GO OPEN REGISTER',
  '🔌 Cajón Abierto': '🔌 Cash Drawer Open',
  '¿Cómo vas a vender': 'How are you selling',
  'Unidad Individual': 'Single Unit',
  'Precio': 'Price',
  'Contiene': 'Contains',
  'unds': 'units',
  'Cantidad': 'Quantity',
  'Pesando': 'Weighing',
  'Coloca el producto en la balanza...': 'Place the product on the scale...',
  'Sin balanza conectada. Usa la simulacion.': 'No scale connected. Use the simulation.',
  'Esperando peso estable...': 'Waiting for stable weight...',
  'USAR PESO': 'USE WEIGHT',
  'ESPERANDO...': 'WAITING...',
  'SIMULAR PESO (1.5 Kg)': 'SIMULATE WEIGHT (1.5 Kg)',
  'Devolver': 'Change',
  'Faltan': 'Missing',
  'Resumen de Pago': 'Payment Summary',
  'Efectivo': 'Cash',
  'Nequi': 'Nequi',
  'Fiado': 'Credit',
  'Seleccione Cliente': 'Select Customer',
  '(Toque Fiado otra vez para buscar)': '(Tap Credit again to search)',
  'DINERO RECIBIDO': 'CASH RECEIVED',
  'CAMBIO / VUELTAS': 'CHANGE',
  'ESTADO': 'STATUS',
  'CANCELAR': 'CANCEL',
  'No tienes permiso para realizar ventas.': 'You do not have permission to make sales.',
  '⚠️ Selecciona un cliente para fiar': '⚠️ Select a customer for credit',
  '⚠️ Falta dinero para completar el pago': '⚠️ Not enough money to complete the payment',
  '⚠️ No se pudo registrar la venta': '⚠️ The sale could not be registered',
  'Error desconocido': 'Unknown error',
  '✅ VENTA': '✅ SALE',
  'REGISTRADA': 'RECORDED',
  '❌ Error al Guardar': '❌ Save Error',
  'No se pudo registrar la venta.': 'The sale could not be registered.',
  'Detalle técnico:': 'Technical detail:',
  'FINALIZAR VENTA': 'COMPLETE SALE',
  'Seleccionar Cliente': 'Select Customer',
  'Nuevo Cliente': 'New Customer',
  '¿Qué es eso? 🤔': 'What is that? 🤔',
  'El código': 'The code',
  'no existe': 'does not exist',
  '¿Quieres registrar este producto? 📦': 'Do you want to register this product? 📦',
  'SÍ, CREARLO': 'YES, CREATE IT',
  'x unit': 'per unit',
  'Escanear o buscar...': 'Scan or search...',
  'Inventario': 'Inventory',
  'Cajón': 'Drawer',
  'Crear Categoría': 'Create Category',
  'Stock': 'Stock',
  'Cliente': 'Customer',
  'Carrito': 'Cart',
  'Carrito Vacío': 'Empty Cart',
  'COD:': 'CODE:',
  'TOTAL:': 'TOTAL:',
  'COBRAR': 'CHARGE',
  'OK': 'OK',
  'Debe abrir la caja antes de vender': 'You must open the register before selling',
  'Debe seleccionar un cliente válido': 'You must select a valid customer',
  'El cliente seleccionado ya no existe': 'The selected customer no longer exists',
  'El cliente está inactivo': 'The customer is inactive',
  'Excede el cupo de crédito del cliente': 'Exceeds the customer credit limit',
};

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _favoritos = [];
  bool _mostrarBarraFavoritos = true;
  final List<List<Map<String, dynamic>>> _sessions = [[]];
  int _currentSessionIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SalesService _salesService = SalesService();
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  String _codigoTeclado = "";
  Timer? _debounceBuscador;
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _clienteSeleccionadoGlobal;
  double _pesoActualBalanza = 0;

  // Categorías
  List<String> _categorias = ["TODO", "⭐ FAVORITOS"];
  String _categoriaActual = "TODO";

  @override
  void initState() {
    super.initState();
    _verificarCaja();
    _cargarCategorias();
    _cargarProductos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _cargarCategorias() async {
    final cats = await DBHelper().obtenerCategorias();
    if (mounted) {
      setState(() {
        _categorias = ["TODO", "⭐ FAVORITOS", ...cats];
      });
    }
  }

  void _agregarNuevaCategoria() {
    final txtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_t("Nueva Categoría")),
        content: TextField(
          controller: txtCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _t("Nombre (Ej: Helados)"),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(_t("Cancelar")),
          ),
          ElevatedButton(
            onPressed: () async {
              if (txtCtrl.text.isNotEmpty) {
                await DBHelper().guardarNuevaCategoria(txtCtrl.text.trim());
                _cargarCategorias();
                Navigator.pop(c);
              }
            },
            child: Text(_t("GUARDAR")),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE CARRITO Y SESIONES ---
  List<Map<String, dynamic>> get _currentCart =>
      _sessions[_currentSessionIndex];

  void _crearNuevaSesion() {
    setState(() {
      _sessions.add([]);
      _currentSessionIndex = _sessions.length - 1;
    });
  }

  void _cambiarSesion(int index) {
    setState(() {
      _currentSessionIndex = index;
    });
  }

  void _cerrarSesion(int index) {
    if (_sessions.length <= 1) {
      _cancelarVentaActual();
      return;
    }
    setState(() {
      _sessions.removeAt(index);
      if (_currentSessionIndex >= index && _currentSessionIndex > 0) {
        _currentSessionIndex--;
      }
    });
  }

  void _cancelarVentaActual() {
    if (_currentCart.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t("¿Cancelar Venta?")),
        content: Text(_t("Se borrarán todos los productos de este pedido.")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t("No")),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _sessions[_currentSessionIndex].clear();
              });
              Navigator.pop(ctx);
              _searchFocusNode.requestFocus();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(_t("SÍ, BORRAR")),
          ),
        ],
      ),
    );
  }

  void _verificarCaja() async {
    bool abierta = await DBHelper().verificarCajaAbiertaHoy();
    if (!abierta && mounted) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              const Icon(Icons.lock_person, color: Colors.red, size: 60),
              const SizedBox(height: 10),
              Text(
                _t("¡STOP! CAJA CERRADA 🛑"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            _t("⚠️ No puedes vender si no has hecho la Apertura de Caja.\n\nPor favor, registra la base inicial."),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(c);
              },
              child: Text(
                _t("🔙 Volver"),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(c);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const CashControlScreen()),
                );
              },
              icon: const Icon(Icons.key),
              label: Text(_t("IR A ABRIR CAJA")),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _cargarProductos() async {
    final data = await DBHelper().getProducts();
    final favs = await DBHelper().obtenerProductosFavoritos(limit: 12);
    if (mounted) {
      setState(() {
        _products = data;
        _favoritos = favs;
        if (_categoriaActual == "⭐ FAVORITOS") {
          _filteredProducts = favs;
        } else if (_categoriaActual == "TODO") {
          _filteredProducts = data;
        } else {
          _filteredProducts =
              data.where((p) => p['categoria'] == _categoriaActual).toList();
        }
      });
    }
  }

  String _limpiarTexto(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  // 🔥 1. FUNCIÓN INTELIGENTE DE BÚSQUEDA 🔥
  void _procesarEntradaBuscador(String query, {bool inmediato = false}) {
    if (!inmediato) {
      // Debounce: evita agregar productos cuando el escáner emite tramas parciales
      _debounceBuscador?.cancel();
      _debounceBuscador = Timer(const Duration(milliseconds: 400), () {
        _procesarEntradaBuscador(query, inmediato: true);
      });
      return;
    }
    _debounceBuscador?.cancel();
    String codigoLimpio = query.trim();

    if (codigoLimpio.isEmpty) {
      _filtrar("");
      return;
    }

    Map<String, dynamic>? exactMatch;
    for (var p in _products) {
      final barras = (p['codigo_barras'] ?? '').toString().trim();
      final plu = (p['codigo_plu'] ?? '').toString().trim();
      if (barras == codigoLimpio || plu == codigoLimpio) {
        exactMatch = p;
        break;
      }
    }

    if (exactMatch != null) {
      _onSelect(exactMatch);
      _searchController.clear();
      _filtrar("");
      _searchFocusNode.requestFocus();
    } else {
      _filtrar(codigoLimpio);
    }
  }

  void _filtrar(String q) {
    setState(() {
      final base = (_categoriaActual == "⭐ FAVORITOS") ? _favoritos : _products;
      _filteredProducts = base.where((p) {
        String textoBusqueda = _limpiarTexto(q);
        String nombreProd = _limpiarTexto(p['nombre'].toString());

        bool matchTexto =
            textoBusqueda.isEmpty ||
            nombreProd.contains(textoBusqueda) ||
            p['id'].toString() == textoBusqueda ||
            (p['codigo_plu'] ?? '').toString() == textoBusqueda ||
            (p['codigo_barras'] ?? '').toString() == textoBusqueda;

        bool matchCategoria =
            _categoriaActual == "TODO" ||
            _categoriaActual == "⭐ FAVORITOS" ||
            (p['categoria'] ?? 'Otros') == _categoriaActual;

        return matchTexto && matchCategoria;
      }).toList();
    });
  }

  void _seleccionarCategoria(String cat) {
    setState(() {
      _categoriaActual = cat;
      _filtrar(_searchController.text);
    });
  }

  double _calcularTotalPagar() {
    double total = 0;
    for (var item in _currentCart) {
      total += item['subtotal'];
    }
    return total;
  }

  void _abrirCajonMonedero() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.point_of_sale, color: Colors.white),
            const SizedBox(width: 10),
            Text(_t("🔌 Cajón Abierto")),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _eliminarDelCarrito(int index) {
    setState(() {
      _currentCart.removeAt(index);
    });
  }

  void _modificarCantidadItem(int index, double cambio) {
    setState(() {
      double n = _currentCart[index]['cantidad'] + cambio;
      if (n <= 0.01) {
        _eliminarDelCarrito(index);
      } else {
        _currentCart[index]['cantidad'] = n;
        _currentCart[index]['subtotal'] = n * _currentCart[index]['precio'];
      }
    });
  }

  void _agregar(
    Map<String, dynamic> p, {
    double cantidad = 1.0,
    double? precioEspecial,
    String? nombreEspecial,
    double packSize = 1.0,
  }) {
    double precioFinal = precioEspecial ?? p['precio_venta'];
    String nombreFinal = nombreEspecial ?? p['nombre'];
    setState(() {
      int idx = _currentCart.indexWhere(
        (i) => i['id'] == p['id'] && i['nombre'] == nombreFinal,
      );
      if (idx != -1) {
        double n = _currentCart[idx]['cantidad'] + cantidad;
        _currentCart[idx]['cantidad'] = n;
        _currentCart[idx]['subtotal'] = n * precioFinal;
      } else {
        if (cantidad > 0) {
          _currentCart.add({
            'id': p['id'],
            'nombre': nombreFinal,
            'precio': precioFinal,
            'cantidad': cantidad,
            'subtotal': cantidad * precioFinal,
            'es_pesable': p['es_pesable'],
            'contenido_pack': packSize,
            'costo_unitario': p['precio_costo'] ?? 0,
          });
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _onSelect(Map<String, dynamic> p) async {
    final packs = await DBHelper().obtenerPresentaciones(p['id']);
    if (packs.isEmpty) {
      if (p['es_pesable'] == 1) {
        _dialogoBalanza(p);
      } else {
        _agregar(p, cantidad: 1.0);
      }
    } else {
      if (!mounted) return;
      _mostrarOpcionesPack(p, packs);
    }
  }

  void _mostrarOpcionesPack(
    Map<String, dynamic> p,
    List<Map<String, dynamic>> packs,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${_t('¿Cómo vas a vender')} ${p['nombre']}?",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(Icons.circle, size: 15, color: Colors.blue),
              title: Text(_t("Unidad Individual")),
              subtitle: Text("${_t('Precio')}: ${formater.format(p['precio_venta'])}"),
              onTap: () {
                Navigator.pop(ctx);
                _dialogoCantidad(p);
              },
            ),
            const Divider(),
            ...packs.map(
              (pack) => ListTile(
                leading: const Icon(Icons.inventory_2, color: Colors.orange),
                title: Text(pack['nombre']),
                subtitle: Text(
                  "${_t('Contiene')} ${pack['cantidad']} ${_t('unds')} | ${_t('Precio')}: ${formater.format(pack['precio'])}",
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _agregar(
                    p,
                    cantidad: 1,
                    precioEspecial: pack['precio'],
                    nombreEspecial: "${p['nombre']} (${pack['nombre']})",
                    packSize: pack['cantidad'],
                  );
                  _searchFocusNode.requestFocus();
                },
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _searchFocusNode.requestFocus());
  }

  void _dialogoCantidad(Map<String, dynamic> p) {
    String c = "";
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, st) {
          Widget btn(String v) => Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                onPressed: () {
                  st(() {
                    if (v == 'C') {
                      c = "";
                    } else if (v == 'OK') {
                      double n = double.tryParse(c) ?? 1;
                      _agregar(p, cantidad: n);
                      Navigator.pop(ctx);
                    } else if (c.length < 4)
                      c += v;
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: v == 'OK'
                      ? Colors.green
                      : (v == 'C' ? Colors.red[100] : Colors.white),
                  foregroundColor: v == 'OK' ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: v == "OK"
                    ? const Icon(Icons.check_circle, size: 30)
                    : (v == "C"
                          ? const Icon(Icons.backspace)
                          : Text(
                              v,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
              ),
            ),
          );
          return AlertDialog(
            backgroundColor: Colors.grey[100],
            title: Text(
              "${_t('Cantidad')}: ${p['nombre']}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Text(
                    c.isEmpty ? "1" : c,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                SizedBox(
                  height: 280,
                  width: 250,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(children: [btn("1"), btn("2"), btn("3")]),
                      ),
                      Expanded(
                        child: Row(children: [btn("4"), btn("5"), btn("6")]),
                      ),
                      Expanded(
                        child: Row(children: [btn("7"), btn("8"), btn("9")]),
                      ),
                      Expanded(
                        child: Row(children: [btn("C"), btn("0"), btn("OK")]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _dialogoBalanza(Map<String, dynamic> p) {
    _pesoActualBalanza = 0;
    StateSetter? stSet;
    final sub = BalanzaService.pesoStream.listen((v) {
      if (v != null && v > 0) {
        _pesoActualBalanza = v;
        stSet?.call(() {});
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, st) {
          stSet = st;
          final peso = _pesoActualBalanza;
          final hayBalanza = BalanzaService.estaConectada;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.scale, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(child: Text("${_t('Pesando')}: ${p['nombre']}")),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hayBalanza
                      ? _t("Coloca el producto en la balanza...")
                      : _t("Sin balanza conectada. Usa la simulacion."),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                if (hayBalanza) ...[
                  Text(
                    peso > 0
                        ? "${peso.toStringAsFixed(3)} Kg"
                        : _t("Esperando peso estable..."),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: peso > 0
                        ? () {
                            _agregar(p, cantidad: peso);
                            Navigator.pop(ctx);
                          }
                        : null,
                    icon: const Icon(Icons.check),
                    label: Text(
                      peso > 0
                          ? "${_t('USAR PESO')} (${peso.toStringAsFixed(3)} Kg)"
                          : _t("ESPERANDO..."),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ElevatedButton.icon(
                  onPressed: () {
                    _agregar(p, cantidad: 1.5);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.download),
                  label: Text(_t("SIMULAR PESO (1.5 Kg)")),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[900],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      sub.cancel();
      _searchFocusNode.requestFocus();
    });
  }

  void _seleccionarCliente(StateSetter st) async {
    final clientes = await DBHelper().obtenerClientes();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(_t("Seleccionar Cliente")),
        content: SizedBox(
          width: 320,
          height: 320,
          child: clientes.isEmpty
              ? Center(child: Text(_t("No hay clientes registrados")))
              : ListView.builder(
                  itemCount: clientes.length,
                  itemBuilder: (c, i) {
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(clientes[i]['nombre'] ?? ''),
                      subtitle: Text(clientes[i]['telefono'] ?? ''),
                      onTap: () {
                        Navigator.pop(ctx, clientes[i]);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const ClientsScreen()),
              );
            },
            child: Text(_t("Nuevo Cliente")),
          ),
        ],
      ),
    ).then((val) {
      if (val != null) {
        _clienteSeleccionadoGlobal = val;
        st(() {});
      }
    });
  }

  void _mostrarPago() {
    final double total = _calcularTotalPagar();
    final pagoCtrl = TextEditingController();
    final pagoMixtoEfectivoCtrl = TextEditingController();
    final pagoMixtoDigitalCtrl = TextEditingController();
    String metodo = "EFECTIVO";
    String tipoDigitalMixto = "NEQUI";
    _clienteSeleccionadoGlobal = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, st) {
          double dineroEntregado = 0;
          double cambio = 0;

          if (metodo == "EFECTIVO") {
            dineroEntregado = parseNumero(pagoCtrl.text) ?? 0;
            cambio = dineroEntregado - total;
          } else if (metodo == "MIXTO") {
            final ef = parseNumero(pagoMixtoEfectivoCtrl.text) ?? 0;
            final dig = parseNumero(pagoMixtoDigitalCtrl.text) ?? 0;
            dineroEntregado = ef + dig;
            cambio = dineroEntregado - total;
          }

          Color colorCambio = Colors.grey;
          String textoCambio = "---";

          if (dineroEntregado > 0) {
            if (cambio >= 0) {
              colorCambio = Colors.green;
              textoCambio = "${_t('Devolver')}: ${formater.format(cambio)}";
            } else {
              colorCambio = Colors.red;
              textoCambio = "${_t('Faltan')}: ${formater.format(cambio.abs())}";
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              children: [
                Text(
                  _t("Resumen de Pago"),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 5),
                Text(
                  formater.format(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                    color: Color(0xFF1A1F2B),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.attach_money, size: 18),
                          label: Text(_t("Efectivo")),
                          selected: metodo == "EFECTIVO",
                          onSelected: (v) => st(() => metodo = "EFECTIVO"),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.phone_android, size: 18),
                          label: const Text("Nequi"),
                          selected: metodo == "NEQUI",
                          onSelected: (v) => st(() {
                            metodo = "NEQUI";
                            pagoCtrl.text = total.toInt().toString();
                          }),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.account_balance_wallet, size: 18),
                          label: const Text("Daviplata"),
                          selected: metodo == "DAVIPLATA",
                          onSelected: (v) => st(() {
                            metodo = "DAVIPLATA";
                            pagoCtrl.text = total.toInt().toString();
                          }),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.credit_card, size: 18),
                          label: const Text("Tarjeta / Datáfono"),
                          selected: metodo == "TARJETA",
                          onSelected: (v) => st(() {
                            metodo = "TARJETA";
                            pagoCtrl.text = total.toInt().toString();
                          }),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.assignment_ind, size: 18),
                          label: Text(_t("Fiado")),
                          selected: metodo == "CREDITO",
                          onSelected: (v) {
                            st(() => metodo = "CREDITO");
                            _seleccionarCliente(st);
                          },
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.call_split, size: 18),
                          label: const Text("Pago Mixto"),
                          selected: metodo == "MIXTO",
                          onSelected: (v) => st(() {
                            metodo = "MIXTO";
                            pagoMixtoEfectivoCtrl.clear();
                            pagoMixtoDigitalCtrl.text = total.toInt().toString();
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // CUERPO SEGÚN MÉTODO DE PAGO
                    if (metodo == "CREDITO")
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.person, size: 44, color: Colors.orange),
                            const SizedBox(height: 6),
                            Text(
                              _clienteSeleccionadoGlobal != null
                                  ? _clienteSeleccionadoGlobal!['nombre']
                                  : _t("Seleccione Cliente"),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _seleccionarCliente(st),
                              icon: const Icon(Icons.search, size: 18),
                              label: Text(_clienteSeleccionadoGlobal != null ? _t("Cambiar Cliente") : _t("Buscar Cliente")),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (metodo == "MIXTO")
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text("Método digital:", style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 10),
                                DropdownButton<String>(
                                  value: tipoDigitalMixto,
                                  isDense: true,
                                  items: const [
                                    DropdownMenuItem(value: "NEQUI", child: Text("Nequi")),
                                    DropdownMenuItem(value: "DAVIPLATA", child: Text("Daviplata")),
                                    DropdownMenuItem(value: "TARJETA", child: Text("Tarjeta / Datáfono")),
                                    DropdownMenuItem(value: "TRANSFERENCIA", child: Text("Transferencia Bancaria")),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) st(() => tipoDigitalMixto = val);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: pagoMixtoEfectivoCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Efectivo Recibido",
                                prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (val) {
                                final ef = parseNumero(val) ?? 0;
                                final resto = (total - ef).clamp(0, total);
                                pagoMixtoDigitalCtrl.text = resto > 0 ? resto.toInt().toString() : '0';
                                st(() {});
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: pagoMixtoDigitalCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Monto $tipoDigitalMixto",
                                prefixIcon: const Icon(Icons.phone_android, color: Colors.blue),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (val) => st(() {}),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorCambio.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colorCambio, width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    cambio >= 0 ? _t("CAMBIO / VUELTAS") : _t("ESTADO"),
                                    style: TextStyle(color: colorCambio, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    textoCambio,
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorCambio),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (metodo == "NEQUI" || metodo == "DAVIPLATA" || metodo == "TARJETA")
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              metodo == "TARJETA" ? Icons.credit_card : Icons.phone_android,
                              size: 44,
                              color: Colors.blue[800],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Cobro por $metodo",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue[900]),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Verifique en su celular o terminal el ingreso de ${formater.format(total)} antes de finalizar la venta.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // EFECTIVO
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          ActionChip(
                            label: const Text("Exacto"),
                            backgroundColor: Colors.green[50],
                            onPressed: () {
                              pagoCtrl.text = total.toInt().toString();
                              st(() {});
                            },
                          ),
                          ActionChip(
                            label: const Text("\$10.000"),
                            onPressed: () {
                              pagoCtrl.text = "10000";
                              st(() {});
                            },
                          ),
                          ActionChip(
                            label: const Text("\$20.000"),
                            onPressed: () {
                              pagoCtrl.text = "20000";
                              st(() {});
                            },
                          ),
                          ActionChip(
                            label: const Text("\$50.000"),
                            onPressed: () {
                              pagoCtrl.text = "50000";
                              st(() {});
                            },
                          ),
                          ActionChip(
                            label: const Text("\$100.000"),
                            onPressed: () {
                              pagoCtrl.text = "100000";
                              st(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pagoCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: _t("DINERO RECIBIDO"),
                          hintText: "\$ 0",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          prefixIcon: const Icon(Icons.attach_money),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onChanged: (val) => st(() {}),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: colorCambio.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: colorCambio, width: 2),
                        ),
                        child: Column(
                          children: [
                            Text(
                              cambio >= 0 ? _t("CAMBIO / VUELTAS") : _t("ESTADO"),
                              style: TextStyle(
                                color: colorCambio,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              textoCambio,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: colorCambio,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_t("CANCELAR"), style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: () async {
                  if (!PermissionService.can("VENTAS_CREAR")) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t("No tienes permiso para realizar ventas.")),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (metodo == "CREDITO" && _clienteSeleccionadoGlobal == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t("⚠️ Selecciona un cliente para fiar")),
                        backgroundColor: Colors.orange[800],
                      ),
                    );
                    return;
                  }
                  if (metodo == "EFECTIVO" && cambio < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t("⚠️ Falta dinero para completar el pago")),
                        backgroundColor: Colors.red[800],
                      ),
                    );
                    return;
                  }

                  String? detalleJson;
                  double efectivoCajon = 0;
                  if (metodo == "MIXTO") {
                    final ef = parseNumero(pagoMixtoEfectivoCtrl.text) ?? 0;
                    final dig = parseNumero(pagoMixtoDigitalCtrl.text) ?? 0;
                    if ((ef + dig) < total) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_t("⚠️ La suma de efectivo y digital no cubre el total de la venta")),
                          backgroundColor: Colors.red[800],
                        ),
                      );
                      return;
                    }
                    efectivoCajon = ef;
                    detalleJson = jsonEncode({
                      'efectivo': ef,
                      'digital': dig,
                      'metodo_digital': tipoDigitalMixto,
                    });
                  } else if (metodo == "EFECTIVO") {
                    efectivoCajon = total;
                  }

                  try {
                    final resultado = await _salesService.registrarVenta(
                      total: total,
                      metodoPago: metodo,
                      items: _currentCart,
                      clienteId: _clienteSeleccionadoGlobal != null
                          ? _clienteSeleccionadoGlobal!['id']
                          : 0,
                      metodoPagoDetalle: detalleJson,
                    );

                    if (resultado['exito'] != true) {
                      if (!ctx.mounted) return;
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(_t("⚠️ No se pudo registrar la venta")),
                          content: Text(
                            resultado['mensaje']?.toString() ?? "Error desconocido",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: Text(_t("OK")),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    int ventaId = resultado['venta_id'] as int;

                    Map<String, dynamic> datosVenta = {
                      'id': ventaId,
                      'total': total,
                      'metodo_pago': metodo,
                      'metodo_pago_detalle': detalleJson,
                    };
                    List<Map<String, dynamic>> itemsImpresion = List.from(_currentCart);

                    if (metodo == "EFECTIVO" || (metodo == "MIXTO" && efectivoCajon > 0)) {
                      _abrirCajonMonedero();
                    }

                    if (mounted) {
                      setState(() {
                        _currentCart.clear();
                        _codigoTeclado = "";
                      });
                      Navigator.pop(ctx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("${_t('✅ VENTA')} #$ventaId ${_t('REGISTRADA')}"),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 3),
                        ),
                      );

                      _cargarProductos();
                      _searchFocusNode.requestFocus();

                      try {
                        await PrinterService().imprimirTicket(datosVenta, itemsImpresion);
                      } catch (e) {
                        debugPrint("Error imprimiendo: $e");
                      }
                    }
                  } catch (e) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(_t("❌ Error al Guardar")),
                        content: Text(
                          "${_t('No se pudo registrar la venta.')}\n\n${_t('Detalle técnico:')} $e",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text(_t("OK")),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: Text(
                  _t("FINALIZAR VENTA"),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) => _searchFocusNode.requestFocus());
  }

  void _onTeclado(String v) {
    setState(() {
      if (v == 'C' && _codigoTeclado.isNotEmpty) {
        _codigoTeclado = _codigoTeclado.substring(0, _codigoTeclado.length - 1);
      } else if (v == 'ENTER') {
        _buscarCodigo();
      } else if (_codigoTeclado.length < 14) {
        _codigoTeclado += v;
      }
    });
  }

  void _buscarCodigo() {
    if (_codigoTeclado.isEmpty) return;
    final codigoLimpio = _codigoTeclado.trim();
    Map<String, dynamic>? p;
    for (var x in _products) {
      final barras = (x['codigo_barras'] ?? '').toString().trim();
      final plu = (x['codigo_plu'] ?? '').toString().trim();
      if (x['id'].toString() == codigoLimpio ||
          plu == codigoLimpio ||
          barras == codigoLimpio) {
        p = x;
        break;
      }
    }
    if (p != null) {
      _onSelect(p);
      _codigoTeclado = "";
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.help_outline, color: Colors.orange, size: 30),
              const SizedBox(width: 10),
              Text(_t("¿Qué es eso? 🤔")),
            ],
          ),
          content: Text(
            "${_t('El código')} '$_codigoTeclado' ${_t('no existe')}.\n\n${_t('¿Quieres registrar este producto? 📦')}",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t("Cancelar")),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) =>
                        InventoryScreen(codigoPrellenado: _codigoTeclado),
                  ),
                );
                setState(() => _codigoTeclado = "");
              },
              icon: const Icon(Icons.add),
              label: Text(_t("SÍ, CREARLO")),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ).then((_) => _searchFocusNode.requestFocus());
    }
  }

  Widget _btn(String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: InkWell(
          onTap: () => _onTeclado(label),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1F2B),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 WIDGET CORREGIDO PARA EL CARRITO 🔥
  Widget _buildCartItem(int index, Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['nombre'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${formater.format(item['precio'])} ${_t('x unit')}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                  size: 24,
                ),
                onPressed: () => _modificarCantidadItem(index, -1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 35),
                alignment: Alignment.center,
                child: Text(
                  "${item['cantidad']}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.green,
                  size: 24,
                ),
                onPressed: () => _modificarCantidadItem(index, 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formater.format(item['subtotal']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 5),
              InkWell(
                onTap: () => _eliminarDelCarrito(index),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ⭐ BARRA DE ACCESO RÁPIDO (TOP 12 FAVORITOS)
  Widget _buildBarraFavoritos() {
    if (_favoritos.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título y toggle de la barra
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 6),
                const Text(
                  "FAVORITOS DE ACCESO RÁPIDO (TOP 12)",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: Color(0xFF1A1F2B),
                  ),
                ),
                const Spacer(),
                Text(
                  "${_favoritos.length} productos",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() {
                      _mostrarBarraFavoritos = !_mostrarBarraFavoritos;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      _mostrarBarraFavoritos
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_mostrarBarraFavoritos) ...[
            const Divider(height: 1, thickness: 0.8),
            SizedBox(
              height: 98,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: _favoritos.length,
                itemBuilder: (ctx, idx) {
                  final p = _favoritos[idx];
                  final imgPath = (p['imagen_path'] ?? '').toString();
                  final bool esAsset = imgPath.startsWith('assets/');
                  final bool tieneFoto = imgPath.isNotEmpty &&
                      (esAsset || File(imgPath).existsSync());
                  final double precio =
                      (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
                  final bool esPesable = (p['es_pesable'] == 1);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onSelect(p),
                        onLongPress: () => _mostrarMenuFavorito(p),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 88,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: tieneFoto
                                      ? (esAsset
                                          ? Image.asset(
                                              imgPath,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.star,
                                                      size: 18,
                                                      color: Colors.amber),
                                            )
                                          : Image.file(
                                              File(imgPath),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.star,
                                                      size: 18,
                                                      color: Colors.amber),
                                            ))
                                      : Icon(
                                          esPesable
                                              ? Icons.scale
                                              : Icons.shopping_basket,
                                          size: 18,
                                          color: Colors.amber.shade800,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                p['nombre'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: Color(0xFF1A1F2B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                "${formater.format(precio)}${esPesable ? '/Kg' : ''}",
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade800,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _mostrarMenuFavorito(Map<String, dynamic> p) {
    final esFav = (p['es_favorito'] == 1);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(esFav ? Icons.star : Icons.star_border, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(p['nombre'] ?? '')),
          ],
        ),
        content: Text(esFav
            ? "¿Deseas quitar este producto de tus Favoritos rápidos?"
            : "¿Deseas agregar este producto a tus Favoritos (Top 12)?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: esFav ? Colors.red : Colors.amber.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await DBHelper().toggleFavorito(p['id'], !esFav);
              _cargarProductos();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(!esFav
                        ? "⭐ '${p['nombre']}' marcado como favorito."
                        : "'${p['nombre']}' quitado de favoritos."),
                  ),
                );
              }
            },
            child: Text(esFav ? "QUITAR DE FAVORITOS" : "MARCAR FAVORITO"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalPagar = _calcularTotalPagar();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(
        children: [
          // PANEL IZQUIERDO (PRODUCTOS)
          Expanded(
            flex: 65,
            child: Column(
              children: [
                // HEADER + BUSCADOR
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 5),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFF1A1F2B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,

                          // 🔥 1. DETECCIÓN INSTANTÁNEA (PARA LECTORES RÁPIDOS)
                          onChanged: (text) => _procesarEntradaBuscador(text),

                          // 🔥 2. DETECCIÓN POR ENTER (PARA LECTORES CON SUFIJO ENTER)
                          onSubmitted: (text) =>
                              _procesarEntradaBuscador(text, inmediato: true),

                          decoration: InputDecoration(
                            hintText: _t("Escanear o buscar..."),
                            isDense: true,
                            prefixIcon: const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.blueGrey,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _filtrar("");
                                _searchFocusNode.requestFocus();
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const InventoryScreen(),
                            ),
                          );
                          _cargarProductos();
                        },
                        icon: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.orange,
                        ),
                        tooltip: _t("Inventario"),
                      ),
                      IconButton(
                        onPressed: () => _abrirCajonMonedero(),
                        icon: const Icon(
                          Icons.point_of_sale_outlined,
                          color: Colors.blueGrey,
                        ),
                        tooltip: _t("Cajón"),
                      ),
                    ],
                  ),
                ),

                // ⭐ BARRA DE ACCESO RÁPIDO (TOP 12 FAVORITOS)
                _buildBarraFavoritos(),

                // BARRA DE CATEGORÍAS
                Container(
                  height: 50,
                  width: double.infinity,
                  color: Colors.white,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    itemCount: _categorias.length + 1,
                    itemBuilder: (ctx, index) {
                      if (index == _categorias.length) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.blue,
                            ),
                            tooltip: _t("Crear Categoría"),
                            onPressed: _agregarNuevaCategoria,
                          ),
                        );
                      }
                      final cat = _categorias[index];
                      bool isSelected = _categoriaActual == cat;
                      bool isFav = cat == "⭐ FAVORITOS";

                      Color fondoColor = isSelected
                          ? (isFav ? Colors.amber.shade800 : const Color(0xFF1A1F2B))
                          : (isFav ? Colors.amber.shade50 : (Colors.grey[100] ?? Colors.grey));
                      Color bordeColor = isSelected
                          ? Colors.transparent
                          : (isFav ? Colors.amber.shade300 : (Colors.grey[300] ?? Colors.grey));
                      Color textoColor = isSelected
                          ? Colors.white
                          : (isFav ? Colors.amber.shade900 : Colors.black87);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () => _seleccionarCategoria(cat),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: fondoColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: bordeColor,
                                width: isFav ? 1.4 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: textoColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 🔥 GRILLA PRODUCTOS 🔥
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(15),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.80,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (c, i) {
                      final p = _filteredProducts[i];
                      double stock =
                          (p['stock_actual'] as num?)?.toDouble() ?? 0;
                      bool stockBajo = stock <= 5;
                      String stockTexto = stock % 1 == 0
                          ? stock.toInt().toString()
                          : stock.toString();
                      final imgPath = (p['imagen_path'] ?? '').toString();
                      final bool esAsset = imgPath.startsWith('assets/');
                      final bool tieneFoto = imgPath.isNotEmpty &&
                          (esAsset || File(imgPath).existsSync());

                      return InkWell(
                        onTap: () => _onSelect(p),
                        onLongPress: () => _mostrarMenuFavorito(p),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: stockBajo
                                  ? Colors.red.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.1),
                              width: stockBajo ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color:
                                      (p['es_pesable'] == 1
                                              ? Colors.green
                                              : Colors.orange)
                                          .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: tieneFoto
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(50),
                                        child: esAsset
                                            ? Image.asset(
                                                imgPath,
                                                fit: BoxFit.cover,
                                                cacheWidth: 150,
                                                errorBuilder:
                                                    (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons.broken_image,
                                                    size: 20,
                                                    color: Colors.grey,
                                                  );
                                                },
                                              )
                                            : Image.file(
                                                File(imgPath),
                                                fit: BoxFit.cover,
                                                cacheWidth: 150,
                                                errorBuilder:
                                                    (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons.broken_image,
                                                    size: 20,
                                                    color: Colors.grey,
                                                  );
                                                },
                                              ),
                                      )
                                    : Icon(
                                        p['es_pesable'] == 1
                                            ? Icons.scale
                                            : Icons.local_grocery_store,
                                        color: p['es_pesable'] == 1
                                            ? Colors.green
                                            : Colors.orange,
                                        size: 24,
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (p['es_favorito'] == 1) ...[
                                      const Icon(
                                        Icons.star,
                                        size: 13,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 2),
                                    ],
                                    Flexible(
                                      child: Text(
                                        p['nombre'],
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: stockBajo
                                      ? Colors.red[50]
                                      : Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "${_t('Stock')}: $stockTexto",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: stockBajo
                                        ? Colors.red
                                        : Colors.blue[800],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                formater.format(p['precio_venta']),
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // PANEL DERECHO (CARRITO)
          Expanded(
            flex: 35,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(-5, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 50,
                    color: const Color(0xFFF0F2F5),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _sessions.length + 1,
                      itemBuilder: (ctx, index) {
                        if (index == _sessions.length) {
                          return IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.green,
                            ),
                            onPressed: _crearNuevaSesion,
                          );
                        }
                        bool isActive = index == _currentSessionIndex;
                        double totalTab = _sessions[index].fold(
                          0,
                          (sum, item) => sum + item['subtotal'],
                        );
                        return GestureDetector(
                          onTap: () => _cambiarSesion(index),
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 1),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : Colors.grey[200],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Cliente ${index + 1}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: isActive
                                              ? Colors.black
                                              : Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        formater.format(totalTab),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isActive
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive)
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: InkWell(
                                      onTap: () => _cerrarSesion(index),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.red,
                                      ),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.green[50],
                    width: double.infinity,
                    child: Text(
                      "🛒 ${_t('Carrito')} (${_t('Cliente')} ${_currentSessionIndex + 1})",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _currentCart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 50,
                                  color: Colors.grey[300],
                                ),
                                Text(
                                  _t("Carrito Vacío"),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            itemCount: _currentCart.length,
                            separatorBuilder: (c, i) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _currentCart[index];
                              return _buildCartItem(index, item);
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _t("COD:"),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _codigoTeclado.isEmpty ? "---" : _codigoTeclado,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 180,
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    "1",
                                    "2",
                                    "3",
                                  ].map((e) => _btn(e)).toList(),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    "4",
                                    "5",
                                    "6",
                                  ].map((e) => _btn(e)).toList(),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    "7",
                                    "8",
                                    "9",
                                  ].map((e) => _btn(e)).toList(),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: InkWell(
                                          onTap: () => _onTeclado("C"),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.red[50],
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              border: Border.all(
                                                color: Colors.red.withOpacity(
                                                  0.2,
                                                ),
                                              ),
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.backspace_outlined,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    _btn("0"),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: InkWell(
                                          onTap: () => _onTeclado("ENTER"),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green
                                                      .withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.check,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _t("TOTAL:"),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              formater.format(totalPagar),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: Color(0xFF1A1F2B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: ElevatedButton(
                                onPressed: totalPagar > 0
                                    ? _cancelarVentaActual
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                      color: Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: const Icon(Icons.delete_outline),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed: totalPagar > 0 ? _mostrarPago : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A1F2B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 5,
                                  shadowColor: Colors.black45,
                                ),
                                child: Text(
                                  _t("COBRAR"),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
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
        ],
      ),
    );
  }
}
