import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import 'dart:math';
import 'dart:io'; // Necesario para manejar archivos
import 'package:image_picker/image_picker.dart'; // Para abrir el explorador
import 'package:path_provider/path_provider.dart'; // Para guardar la copia
import 'package:path/path.dart' as path;
import '../services/inventory_service.dart';

class InventoryScreen extends StatefulWidget {
  final String? codigoPrellenado;
  const InventoryScreen({super.key, this.codigoPrellenado});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  final InventoryService _inventoryService = InventoryService();
  // --- VARIABLES FORMULARIO ---
  final _nombreCtrl = TextEditingController();
  final _precioVentaCtrl = TextEditingController();
  final _precioCostoCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _pluCtrl = TextEditingController();
  final _barrasCtrl = TextEditingController();

  bool _esPesable = false;
  int? _idEdicion;
  String? _imagenPathActual; // 🔥 Variable para la ruta de la foto

  // CATEGORÍAS
  final List<String> _categorias = [
    "Frutas",
    "Verduras",
    "Abarrotes",
    "Carnes",
    "Lácteos",
    "Bebidas",
    "Dulces",
    "Aseo",
    "Otros",
  ];
  String _categoriaSeleccionada = "Otros";

  // VARIABLES LISTA
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarProductos();
    if (widget.codigoPrellenado != null) {
      _pluCtrl.text = widget.codigoPrellenado!;
      _tabController.animateTo(1);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreCtrl.dispose();
    _precioVentaCtrl.dispose();
    _precioCostoCtrl.dispose();
    _stockCtrl.dispose();
    _pluCtrl.dispose();
    _barrasCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- 📥 CARGA DE DATOS ---
  void _cargarProductos() async {
    setState(() => _isLoading = true);
    final data = await DBHelper().getProducts();
    setState(() {
      _productos = data;
      _productosFiltrados = data;
      _isLoading = false;
      if (_searchCtrl.text.isNotEmpty) _filtrarProductos(_searchCtrl.text);
    });
  }

  // 🔥 HELPER PARA QUITAR TILDES 🔥
  String _limpiarTexto(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  // 🔥 BÚSQUEDA MEJORADA 🔥
  void _filtrarProductos(String query) {
    if (query.isEmpty) {
      setState(() => _productosFiltrados = _productos);
      return;
    }
    setState(() {
      _productosFiltrados = _productos.where((p) {
        // Normalizamos todo antes de comparar
        final textoBusqueda = _limpiarTexto(query);
        final nombre = _limpiarTexto(p['nombre'].toString());
        final plu = _limpiarTexto((p['codigo_plu'] ?? '').toString());
        final barras = _limpiarTexto((p['codigo_barras'] ?? '').toString());

        return nombre.contains(textoBusqueda) ||
            plu.contains(textoBusqueda) ||
            barras.contains(textoBusqueda);
      }).toList();
    });
  }

  // --- 📸 LÓGICA DE FOTOS ---
  Future<void> _subirImagen() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String imageDirPath = path.join(directory.path, 'product_images');
      await Directory(imageDirPath).create(recursive: true);

      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String localPath = path.join(imageDirPath, fileName);

      await File(pickedFile.path).copy(localPath);

      setState(() {
        _imagenPathActual = localPath;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Imagen cargada correctamente 🖼️")),
        );
      }
    }
  }

  // --- 📦 GESTIÓN DE PACKS ---
  void _gestionarPresentaciones(Map<String, dynamic> producto) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: DBHelper().obtenerPresentaciones(producto['id']),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final packs = snapshot.data!;
              return AlertDialog(
                title: Text("Packs de: ${producto['nombre']}"),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Ej: Agrega 'Cubeta' que trae 30 unds.",
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (packs.isEmpty)
                        const Text(
                          "No hay presentaciones extra.",
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: packs.length,
                        itemBuilder: (c, i) {
                          final p = packs[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.inventory_2,
                              color: Colors.orange,
                            ),
                            title: Text(
                              p['nombre'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "Trae: ${p['cantidad']} | Venta: ${formater.format(p['precio'])}",
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await DBHelper().borrarPresentacion(p['id']);
                                setSt(() {});
                              },
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("AGREGAR PACK"),
                        onPressed: () =>
                            _dialogoAgregarPack(context, producto, setSt),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("CERRAR"),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _dialogoAgregarPack(
    BuildContext ctx,
    Map<String, dynamic> prod,
    StateSetter parentSetState,
  ) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text("Nuevo Pack / Caja"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "Nombre (Ej: Cubeta)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Unidades que trae",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Precio Venta Pack",
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty &&
                  qtyCtrl.text.isNotEmpty &&
                  priceCtrl.text.isNotEmpty) {
                await DBHelper().agregarPresentacion(
                  prod['id'],
                  nameCtrl.text,
                  double.parse(qtyCtrl.text.replaceAll(',', '.')),
                  double.parse(priceCtrl.text.replaceAll(',', '.')),
                );
                Navigator.pop(c);
                parentSetState(() {});
              }
            },
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }

  // --- 💾 LÓGICA DE GUARDADO ---
  void _guardar() async {
    if (_nombreCtrl.text.isEmpty || _precioVentaCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Nombre y Precio Venta son obligatorios'),
        ),
      );
      return;
    }
    try {
      double precioVenta = double.parse(
        _precioVentaCtrl.text.replaceAll(',', '.'),
      );
      double precioCosto =
          double.tryParse(_precioCostoCtrl.text.replaceAll(',', '.')) ?? 0;
      double stock = double.tryParse(_stockCtrl.text.replaceAll(',', '.')) ?? 0;

      Map<String, dynamic> datos = {
        'nombre': _nombreCtrl.text,
        'precio_venta': precioVenta,
        'precio_costo': precioCosto,
        'stock_actual': stock,
        'es_pesable': _esPesable ? 1 : 0,
        'esta_activo': 1,
        'codigo_plu': _pluCtrl.text,
        'codigo_barras': _barrasCtrl.text,
        'categoria': _categoriaSeleccionada,
        'imagen_path': _imagenPathActual,
      };

      if (_idEdicion == null) {
        await _inventoryService.crearProducto(datos);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Producto Creado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _inventoryService.actualizarProducto(_idEdicion!, datos);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔄 Producto Actualizado'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
      _limpiarFormulario();
      _cargarProductos();
      _tabController.animateTo(0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: Revise números ($e)'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cargarParaEditar(Map<String, dynamic> producto) {
    setState(() {
      _idEdicion = producto['id'];
      _nombreCtrl.text = producto['nombre'];
      _precioVentaCtrl.text = producto['precio_venta'].toString();
      _precioCostoCtrl.text = (producto['precio_costo'] ?? 0).toString();
      _stockCtrl.text = producto['stock_actual'].toString();
      _pluCtrl.text = producto['codigo_plu'] ?? "";
      _barrasCtrl.text = producto['codigo_barras'] ?? "";
      _esPesable = (producto['es_pesable'] == 1);
      _categoriaSeleccionada = producto['categoria'] ?? "Otros";
      _imagenPathActual = producto['imagen_path'];
    });
    _tabController.animateTo(1);
  }

  void _eliminarProducto(int id) async {
    await _inventoryService.eliminarProducto(id);
    _cargarProductos();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('🗑️ Producto eliminado')));
    }
  }

  void _limpiarFormulario() {
    _nombreCtrl.clear();
    _precioVentaCtrl.clear();
    _precioCostoCtrl.clear();
    _stockCtrl.clear();
    _pluCtrl.clear();
    _barrasCtrl.clear();
    setState(() {
      _esPesable = false;
      _idEdicion = null;
      _categoriaSeleccionada = "Otros";
      _imagenPathActual = null;
    });
  }

  void _generarCodigoAzar() {
    setState(() {
      _pluCtrl.text = (Random().nextInt(9000) + 1000).toString();
    });
  }

  // --- VISTAS ---
  Widget _buildProductList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_productosFiltrados.isEmpty) {
      return const Center(child: Text("No hay productos"));
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),
      separatorBuilder: (c, i) => const Divider(height: 1),
      itemCount: _productosFiltrados.length,
      itemBuilder: (context, index) {
        final p = _productosFiltrados[index];
        bool tieneFoto =
            p['imagen_path'] != null && File(p['imagen_path']).existsSync();

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[200],
            // 🔥 AQUÍ OPTIMICÉ LA IMAGEN PARA QUE LA LISTA NO SEA LENTA 🔥
            backgroundImage: tieneFoto
                ? ResizeImage(FileImage(File(p['imagen_path'])), width: 100)
                : null,
            child: tieneFoto
                ? null
                : const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
          title: Text(
            p['nombre'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            "${p['categoria']} | \$${formater.format(p['precio_venta'])}",
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.layers, color: Colors.indigo),
                onPressed: () => _gestionarPresentaciones(p),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _cargarParaEditar(p),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmarEliminar(p),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmarEliminar(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrar producto?"),
        content: Text("¿Seguro deseas eliminar '${p['nombre']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              _eliminarProducto(p['id']);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("ELIMINAR"),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Título
          Container(
            padding: const EdgeInsets.all(10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _idEdicion == null ? "NUEVO PRODUCTO" : "EDITAR PRODUCTO",
              style: TextStyle(
                color: Colors.blue[900],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 🔥 ZONA DE CARGA DE IMAGEN (ESTILO PC) 🔥
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Previsualización
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[400]!),
                  image:
                      _imagenPathActual != null &&
                          File(_imagenPathActual!).existsSync()
                      ? DecorationImage(
                          // 🔥 OPTIMIZACIÓN: ResizeImage evita que fotos 4K congelen el formulario
                          image: ResizeImage(
                            FileImage(File(_imagenPathActual!)),
                            width: 300,
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imagenPathActual == null
                    ? const Icon(Icons.image, size: 40, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 15),
              // Botones
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Imagen del Producto:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    ElevatedButton.icon(
                      onPressed: _subirImagen,
                      icon: const Icon(Icons.folder_open),
                      label: const Text("Explorar Archivos..."),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_imagenPathActual != null)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _imagenPathActual = null),
                        icon: const Icon(
                          Icons.delete,
                          size: 16,
                          color: Colors.red,
                        ),
                        label: const Text(
                          "Quitar foto",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    const Text(
                      "Soporta: JPG, PNG",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),

          // Campos normales
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pluCtrl,
                  decoration: InputDecoration(
                    labelText: "Cód. PLU",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.shuffle),
                      onPressed: _generarCodigoAzar,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _barrasCtrl,
                  decoration: const InputDecoration(
                    labelText: "Cód. Barras",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(
              labelText: "Nombre",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label),
            ),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            initialValue: _categoriaSeleccionada,
            decoration: const InputDecoration(
              labelText: "Categoría",
              border: OutlineInputBorder(),
            ),
            items: _categorias
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _categoriaSeleccionada = val!),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _precioVentaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Precio Venta",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _precioCostoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Costo",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _stockCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Stock",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.warehouse),
            ),
          ),
          const SizedBox(height: 15),
          SwitchListTile(
            title: const Text("¿Se vende por Peso?"),
            subtitle: const Text("Activar para balanza (Kg)"),
            value: _esPesable,
            activeThumbColor: Colors.green,
            secondary: const Icon(Icons.scale),
            onChanged: (v) => setState(() => _esPesable = v),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save),
              label: const Text("GUARDAR DATOS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ EL MÉTODO BUILD ESTÁ AQUÍ CORRECTAMENTE CERRADO Y POSICIONADO
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Inventario"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: "LISTA"),
            Tab(icon: Icon(Icons.add_circle), text: "CREAR / EDITAR"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña 1: Lista con buscador
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _filtrarProductos,
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre, PLU o barras...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _filtrarProductos('');
                              // 🔥 LIMPIEZA EXTRA: Ocultar teclado al borrar búsqueda
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              Expanded(child: _buildProductList()),
            ],
          ),
          // Pestaña 2: Formulario
          _buildForm(),
        ],
      ),
    );
  }
}
