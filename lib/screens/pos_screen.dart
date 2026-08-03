import '../services/printer_service.dart'; // 🔥 Importamos el servicio de impresión
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import 'inventory_screen.dart';
import 'cash_control_screen.dart';
import 'clients_screen.dart';
import 'dart:io';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final List<List<Map<String, dynamic>>> _sessions = [[]];
  int _currentSessionIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  String _codigoTeclado = "";
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _clienteSeleccionadoGlobal;

  // Categorías
  List<String> _categorias = ["TODO"];
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
        _categorias = ["TODO", ...cats];
      });
    }
  }

  void _agregarNuevaCategoria() {
    final txtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Nueva Categoría"),
        content: TextField(
          controller: txtCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: "Nombre (Ej: Helados)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (txtCtrl.text.isNotEmpty) {
                await DBHelper().guardarNuevaCategoria(txtCtrl.text.trim());
                _cargarCategorias();
                Navigator.pop(c);
              }
            },
            child: const Text("GUARDAR"),
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
        title: const Text("¿Cancelar Venta?"),
        content: const Text("Se borrarán todos los productos de este pedido."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("No"),
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
            child: const Text("SÍ, BORRAR"),
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
          title: const Column(
            children: [
              Icon(Icons.lock_person, color: Colors.red, size: 60),
              SizedBox(height: 10),
              Text(
                "¡STOP! CAJA CERRADA 🛑",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            "⚠️ No puedes vender si no has hecho la Apertura de Caja.\n\nPor favor, registra la base inicial.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(c);
              },
              child: const Text(
                "🔙 Volver",
                style: TextStyle(color: Colors.grey),
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
              label: const Text("IR A ABRIR CAJA"),
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
    setState(() {
      _products = data;
      _filteredProducts = data;
    });
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
  void _procesarEntradaBuscador(String query) {
    String codigoLimpio = query.trim();

    if (codigoLimpio.isEmpty) {
      _filtrar("");
      return;
    }

    final exactMatch = _products.firstWhere(
      (p) =>
          (p['codigo_barras'] ?? '') == codigoLimpio ||
          (p['codigo_plu'] ?? '') == codigoLimpio,
      orElse: () => {},
    );

    if (exactMatch.isNotEmpty) {
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
      _filteredProducts = _products.where((p) {
        String textoBusqueda = _limpiarTexto(q);
        String nombreProd = _limpiarTexto(p['nombre'].toString());

        bool matchTexto =
            nombreProd.contains(textoBusqueda) ||
            p['id'].toString() == textoBusqueda ||
            (p['codigo_plu'] ?? '').toString() == textoBusqueda ||
            (p['codigo_barras'] ?? '').toString() == textoBusqueda;

        bool matchCategoria =
            _categoriaActual == "TODO" ||
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
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.point_of_sale, color: Colors.white),
            SizedBox(width: 10),
            Text("🔌 Cajón Abierto"),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        duration: Duration(milliseconds: 500),
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
              "¿Cómo vas a vender ${p['nombre']}?",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(Icons.circle, size: 15, color: Colors.blue),
              title: const Text("Unidad Individual"),
              subtitle: Text("Precio: ${formater.format(p['precio_venta'])}"),
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
                  "Contiene ${pack['cantidad']} unds | Precio: ${formater.format(pack['precio'])}",
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
              "Cantidad: ${p['nombre']}",
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.scale, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(child: Text("Pesando: ${p['nombre']}")),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Coloca el producto en la balanza... ⚖️",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _agregar(p, cantidad: 1.5);
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.download),
              label: const Text("SIMULAR PESO (1.5 Kg)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue[900],
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _searchFocusNode.requestFocus());
  }

  void _mostrarPago() {
    double total = _calcularTotalPagar();
    final pagoCtrl = TextEditingController();
    String metodo = "EFECTIVO";
    _clienteSeleccionadoGlobal = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, st) {
          double dineroEntregado =
              double.tryParse(pagoCtrl.text.replaceAll(',', '.')) ?? 0;
          double cambio = dineroEntregado - total;

          Color colorCambio = Colors.grey;
          String textoCambio = "---";

          if (dineroEntregado > 0) {
            if (cambio >= 0) {
              colorCambio = Colors.green;
              textoCambio = "Devolver: ${formater.format(cambio)}";
            } else {
              colorCambio = Colors.red;
              textoCambio = "Faltan: ${formater.format(cambio.abs())}";
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              children: [
                const Text(
                  "Resumen de Pago",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Efectivo"),
                          selected: metodo == "EFECTIVO",
                          onSelected: (v) => st(() => metodo = "EFECTIVO"),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Nequi"),
                          selected: metodo == "NEQUI",
                          onSelected: (v) => st(() {
                            metodo = "NEQUI";
                            pagoCtrl.text = total.toInt().toString();
                          }),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("Fiado"),
                          selected: metodo == "CREDITO",
                          onSelected: (v) {
                            st(() => metodo = "CREDITO");
                            _seleccionarCliente(st);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (metodo == "CREDITO")
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _clienteSeleccionadoGlobal != null
                                ? _clienteSeleccionadoGlobal!['nombre']
                                : "Seleccione Cliente",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (_clienteSeleccionadoGlobal == null)
                            const Text(
                              "(Toque Fiado otra vez para buscar)",
                              style: TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    )
                  else
                    TextField(
                      controller: pagoCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: "DINERO RECIBIDO",
                        hintText: "\$ 0",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: (val) => st(() {}),
                    ),

                  const SizedBox(height: 20),

                  if (metodo == "EFECTIVO")
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: colorCambio.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: colorCambio, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            cambio >= 0 ? "CAMBIO / VUELTAS" : "ESTADO",
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
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "CANCELAR",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
                onPressed: () async {
                  if (metodo == "CREDITO" &&
                      _clienteSeleccionadoGlobal == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("⚠️ Selecciona un cliente para fiar"),
                      ),
                    );
                    return;
                  }
                  if (metodo == "EFECTIVO" && cambio < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("⚠️ Falta dinero para completar el pago"),
                      ),
                    );
                    return;
                  }

                  try {
                    // 🔥 1. GUARDAMOS Y OBTENEMOS EL ID (Tu BD debe devolver 'int')
                    int ventaId = await DBHelper().registrarVenta(
                      total,
                      metodo,
                      _currentCart,
                      clienteId: _clienteSeleccionadoGlobal != null
                          ? _clienteSeleccionadoGlobal!['id']
                          : 0,
                    );

                    // 2. PREPARAR DATOS PARA EL TICKET
                    Map<String, dynamic> datosVenta = {
                      'id': ventaId,
                      'total': total,
                      'metodo_pago': metodo,
                    };
                    List<Map<String, dynamic>> itemsImpresion = List.from(
                      _currentCart,
                    );

                    if (metodo != "CREDITO") _abrirCajonMonedero();

                    if (mounted) {
                      setState(() {
                        _currentCart.clear();
                        _codigoTeclado = "";
                      });
                      Navigator.pop(ctx); // Cierra el modal de pago

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("✅ VENTA #$ventaId REGISTRADA"),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 3),
                        ),
                      );

                      _cargarProductos();
                      _searchFocusNode.requestFocus();

                      // 🔥 3. IMPRIMIR AUTOMÁTICAMENTE
                      try {
                        await PrinterService().imprimirTicket(
                          datosVenta,
                          itemsImpresion,
                        );
                      } catch (e) {
                        debugPrint("Error imprimiendo: $e");
                      }
                    }
                  } catch (e) {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text("❌ Error al Guardar"),
                        content: Text(
                          "No se pudo registrar la venta.\n\nDetalle técnico: $e",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: const Text(
                  "FINALIZAR VENTA",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) => _searchFocusNode.requestFocus());
  }

  void _seleccionarCliente(StateSetter st) async {
    final clientes = await DBHelper().obtenerClientes();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Seleccionar Cliente"),
        content: SizedBox(
          width: 300,
          height: 300,
          child: ListView.builder(
            itemCount: clientes.length,
            itemBuilder: (c, i) {
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(clientes[i]['nombre']),
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
            child: const Text("Nuevo Cliente"),
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

  void _onTeclado(String v) {
    setState(() {
      if (v == 'C' && _codigoTeclado.isNotEmpty) {
        _codigoTeclado = _codigoTeclado.substring(0, _codigoTeclado.length - 1);
      } else if (v == 'ENTER')
        _buscarCodigo();
      else if (_codigoTeclado.length < 12)
        _codigoTeclado += v;
    });
  }

  void _buscarCodigo() {
    if (_codigoTeclado.isEmpty) return;
    final p = _products.firstWhere(
      (x) =>
          x['id'].toString() == _codigoTeclado ||
          (x['codigo_plu'] ?? '').toString() == _codigoTeclado ||
          (x['codigo_barras'] ?? '').toString() == _codigoTeclado,
      orElse: () => {},
    );
    if (p.isNotEmpty) {
      _onSelect(p);
      _codigoTeclado = "";
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.help_outline, color: Colors.orange, size: 30),
              SizedBox(width: 10),
              Text("¿Qué es eso? 🤔"),
            ],
          ),
          content: Text(
            "El código '$_codigoTeclado' no existe.\n\n¿Quieres registrar este producto? 📦",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
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
              label: const Text("SÍ, CREARLO"),
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
                  "${formater.format(item['precio'])} x unit",
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
                          onSubmitted: (text) => _procesarEntradaBuscador(text),

                          decoration: InputDecoration(
                            hintText: "Escanear o buscar...",
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
                        tooltip: "Inventario",
                      ),
                      IconButton(
                        onPressed: () => _abrirCajonMonedero(),
                        icon: const Icon(
                          Icons.point_of_sale_outlined,
                          color: Colors.blueGrey,
                        ),
                        tooltip: "Cajón",
                      ),
                    ],
                  ),
                ),

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
                            tooltip: "Crear Categoría",
                            onPressed: _agregarNuevaCategoria,
                          ),
                        );
                      }
                      final cat = _categorias[index];
                      bool isSelected = _categoriaActual == cat;
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
                              color: isSelected
                                  ? const Color(0xFF1A1F2B)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
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
                      bool tieneFoto =
                          p['imagen_path'] != null &&
                          File(p['imagen_path']).existsSync();

                      return InkWell(
                        onTap: () => _onSelect(p),
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
                                        child: Image.file(
                                          File(p['imagen_path']),
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
                                  "Stock: $stockTexto",
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
                      "🛒 Carrito (Cliente ${_currentSessionIndex + 1})",
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
                                const Text(
                                  "Carrito Vacío",
                                  style: TextStyle(color: Colors.grey),
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
                              const Text(
                                "COD:",
                                style: TextStyle(
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
                            const Text(
                              "TOTAL:",
                              style: TextStyle(
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
                                child: const Text(
                                  "COBRAR",
                                  style: TextStyle(
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
