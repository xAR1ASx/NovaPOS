import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import 'dart:math';
import 'dart:io'; // Necesario para manejar archivos
import 'package:image_picker/image_picker.dart'; // Para abrir el explorador
import 'package:path_provider/path_provider.dart'; // Para guardar la copia
import 'package:path/path.dart' as path;
import '../services/inventory_service.dart';
import '../services/locale_service.dart';
import '../utils/numero.dart';
import 'mermas_screen.dart';
import '../services/excel_export_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Nueva Categoría': 'New Category',
  'Nombre de la categoría': 'Category name',
  'Cancelar': 'Cancel',
  'Crear': 'Create',
  'Imagen cargada correctamente 🖼️': 'Image uploaded successfully 🖼️',
  'Packs de': 'Packs of',
  "Ej: Agrega 'Cubeta' que trae 30 unds.":
      "E.g.: Add 'Cubeta' that brings 30 units.",
  'No hay presentaciones extra.': 'No extra presentations.',
  'Trae': 'Contains',
  'Venta': 'Sale',
  'AGREGAR PACK': 'ADD PACK',
  'CERRAR': 'CLOSE',
  'Nuevo Pack / Caja': 'New Pack / Box',
  'Nombre (Ej: Cubeta)': 'Name (E.g.: Cubeta)',
  'Unidades que trae': 'Units it contains',
  'Precio Venta Pack': 'Pack Sale Price',
  'GUARDAR': 'SAVE',
  '⚠️ Nombre y Precio Venta son obligatorios':
      '⚠️ Name and Sale Price are required',
  '⚠️ El Precio Venta debe ser mayor a cero':
      '⚠️ The Sale Price must be greater than zero',
  '⚠️ El stock no puede ser negativo': '⚠️ Stock cannot be negative',
  '⚠️ El costo no puede ser negativo': '⚠️ Cost cannot be negative',
  '⚠️ El costo no puede ser mayor que el precio de venta':
      '⚠️ Cost cannot be greater than the sale price',
  '✅ Producto Creado': '✅ Product Created',
  '🔄 Producto Actualizado': '🔄 Product Updated',
  '❌ Error: Revise números': '❌ Error: Check numbers',
  '⚠️ Revisa los valores (Cantidad y Precio)': '⚠️ Check the values (Quantity and Price)',
  '🗑️ Producto eliminado': '🗑️ Product deleted',
  'No hay productos': 'No products',
  '¿Borrar producto?': 'Delete product?',
  '¿Seguro deseas eliminar': 'Are you sure you want to delete',
  'ELIMINAR': 'DELETE',
  'NUEVO PRODUCTO': 'NEW PRODUCT',
  'EDITAR PRODUCTO': 'EDIT PRODUCT',
  'Imagen del Producto:': 'Product Image:',
  'Explorar Archivos...': 'Browse Files...',
  'Quitar foto': 'Remove photo',
  'Soporta: JPG, PNG': 'Supports: JPG, PNG',
  'Cód. PLU': 'Code PLU',
  'Cód. Barras': 'Barcode Code',
  'Nombre': 'Name',
  'Categoría': 'Category',
  'Precio Venta': 'Sale Price',
  'Costo': 'Cost',
  'Stock': 'Stock',
  '¿Se vende por Peso?': 'Sold by Weight?',
  'Activar para balanza (Kg)': 'Enable for scale (Kg)',
  'GUARDAR DATOS': 'SAVE DATA',
  'Gestión de Inventario': 'Inventory Management',
  'LISTA': 'LIST',
  'CREAR / EDITAR': 'CREATE / EDIT',
  'Buscar por nombre, PLU o barras...': 'Search by name, PLU or barcode...',
  'Crear nueva categoría': 'Create new category',
  'Nueva categoría': 'New category',
};

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
  bool _esFavorito = false;
  int? _idEdicion;
  String? _imagenPathActual; // 🔥 Variable para la ruta de la foto

  // CATEGORÍAS
  List<String> _categorias = [];
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
    _cargarCategorias();
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
  void _cargarCategorias() async {
    final cats = await DBHelper().obtenerCategorias();
    if (!mounted) return;
    setState(() {
      if (!cats.contains(_categoriaSeleccionada)) {
        cats.add(_categoriaSeleccionada);
      }
      _categorias = cats;
    });
  }

  Future<void> _crearNuevaCategoria() async {
    final controlador = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t("Nueva Categoría")),
        content: TextField(
          controller: controlador,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _t("Nombre de la categoría"),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.category_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t("Cancelar")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controlador.text.trim()),
            child: Text(_t("Crear")),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    await DBHelper().guardarNuevaCategoria(nombre);
    final cats = await DBHelper().obtenerCategorias();
    if (!mounted) return;
    setState(() {
      if (!cats.contains(_categoriaSeleccionada)) {
        cats.add(_categoriaSeleccionada);
      }
      _categorias = cats;
      _categoriaSeleccionada = cats.contains(nombre) ? nombre : _categoriaSeleccionada;
    });
  }

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
          SnackBar(content: Text(_t("Imagen cargada correctamente 🖼️"))),
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
                title: Text("${_t('Packs de')}: ${producto['nombre']}"),
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
                        child: Text(
                          _t("Ej: Agrega 'Cubeta' que trae 30 unds."),
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (packs.isEmpty)
                        Text(
                          _t("No hay presentaciones extra."),
                          style: const TextStyle(fontStyle: FontStyle.italic),
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
                              "${_t('Trae')}: ${p['cantidad']} | ${_t('Venta')}: ${formater.format(p['precio'])}",
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
                        label: Text(_t("AGREGAR PACK")),
                        onPressed: () =>
                            _dialogoAgregarPack(context, producto, setSt),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(_t("CERRAR")),
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
        title: Text(_t("Nuevo Pack / Caja")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: _t("Nombre (Ej: Cubeta)"),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _t("Unidades que trae"),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _t("Precio Venta Pack"),
                prefixIcon: const Icon(Icons.attach_money),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(_t("Cancelar")),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = parseNumero(qtyCtrl.text);
              final price = parseNumero(priceCtrl.text);
              if (nameCtrl.text.isNotEmpty &&
                  qty != null &&
                  price != null &&
                  price > 0) {
                await DBHelper().agregarPresentacion(
                  prod['id'],
                  nameCtrl.text,
                  qty,
                  price,
                );
                Navigator.pop(c);
                parentSetState(() {});
              } else {
                ScaffoldMessenger.of(c).showSnackBar(
                  SnackBar(
                    content: Text(_t('⚠️ Revisa los valores (Cantidad y Precio)')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(_t("GUARDAR")),
          ),
        ],
      ),
    );
  }

  // --- 💾 LÓGICA DE GUARDADO ---
  void _guardar() async {
    if (_nombreCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('⚠️ Nombre y Precio Venta son obligatorios')),
        ),
      );
      return;
    }
    try {
      double? precioVenta = parseNumero(_precioVentaCtrl.text);
      if (precioVenta == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('⚠️ Nombre y Precio Venta son obligatorios')),
          ),
        );
        return;
      }
      double precioCosto = parseNumero(_precioCostoCtrl.text) ?? 0;
      double stock = parseNumero(_stockCtrl.text) ?? 0;

      if (precioVenta <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('⚠️ El Precio Venta debe ser mayor a cero')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (stock < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('⚠️ El stock no puede ser negativo')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (precioCosto < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('⚠️ El costo no puede ser negativo')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (precioCosto > precioVenta) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('⚠️ El costo no puede ser mayor que el precio de venta')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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
        'es_favorito': _esFavorito ? 1 : 0,
      };

      if (_idEdicion == null) {
        await _inventoryService.crearProducto(datos);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('✅ Producto Creado')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _inventoryService.actualizarProducto(_idEdicion!, datos);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('🔄 Producto Actualizado')),
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
          content: Text('${_t('❌ Error: Revise números')} ($e)'),
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
      _esFavorito = (producto['es_favorito'] == 1);
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
      ).showSnackBar(SnackBar(content: Text(_t('🗑️ Producto eliminado'))));
    }
  }

  void _dialogoPrecargarCatalogo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.storefront, color: Colors.green),
            SizedBox(width: 8),
            Text("Catálogo Maestro Fruver"),
          ],
        ),
        content: const Text(
          "¿Deseas precargar el catálogo con más de 120 referencias típicas de fruver y minimarket?\n\n"
          "Incluye frutas, verduras, tubérculos con códigos PLU, granos, lácteos y aseo con precios sugeridos. Podrás modificar precios o eliminar lo que no vendas.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_done),
            label: const Text("SÍ, CARGAR PRODUCTOS"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final n = await DBHelper().precargarCatalogoMaestro(forzar: true);
              _cargarProductos();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("✅ Se agregaron $n productos del catálogo maestro."),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
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
      _esFavorito = false;
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
      return Center(child: Text(_t("No hay productos")));
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),
      separatorBuilder: (c, i) => const Divider(height: 1),
      itemCount: _productosFiltrados.length,
      itemBuilder: (context, index) {
        final p = _productosFiltrados[index];
        final imgPath = (p['imagen_path'] ?? '').toString();
        final bool esAsset = imgPath.startsWith('assets/');
        final bool tieneFoto = imgPath.isNotEmpty &&
            (esAsset || File(imgPath).existsSync());

        ImageProvider? imgProvider;
        if (tieneFoto) {
          imgProvider = esAsset
              ? AssetImage(imgPath)
              : ResizeImage(FileImage(File(imgPath)), width: 100);
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[200],
            backgroundImage: imgProvider,
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
                icon: Icon(
                  p['es_favorito'] == 1 ? Icons.star : Icons.star_border,
                  color: p['es_favorito'] == 1 ? Colors.amber[700] : Colors.grey,
                ),
                tooltip: p['es_favorito'] == 1
                    ? "Quitar de Favoritos"
                    : "Marcar como Favorito (Top 12)",
                onPressed: () async {
                  final nuevoEstado = (p['es_favorito'] == 1) ? 0 : 1;
                  await DBHelper().toggleFavorito(p['id'], nuevoEstado == 1);
                  _cargarProductos();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(nuevoEstado == 1
                            ? "⭐ '${p['nombre']}' añadido a Favoritos."
                            : "'${p['nombre']}' removido de Favoritos."),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
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
        title: Text(_t("¿Borrar producto?")),
        content: Text("${_t('¿Seguro deseas eliminar')} '${p['nombre']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t("Cancelar")),
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
            child: Text(_t("ELIMINAR")),
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
              _idEdicion == null ? _t("NUEVO PRODUCTO") : _t("EDITAR PRODUCTO"),
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
                  image: () {
                    if (_imagenPathActual == null || _imagenPathActual!.isEmpty) {
                      return null;
                    }
                    if (_imagenPathActual!.startsWith('assets/')) {
                      return DecorationImage(
                        image: AssetImage(_imagenPathActual!),
                        fit: BoxFit.cover,
                      );
                    }
                    if (File(_imagenPathActual!).existsSync()) {
                      return DecorationImage(
                        image: ResizeImage(
                          FileImage(File(_imagenPathActual!)),
                          width: 300,
                        ),
                        fit: BoxFit.cover,
                      );
                    }
                    return null;
                  }(),
                ),
                child: (_imagenPathActual == null || _imagenPathActual!.isEmpty)
                    ? const Icon(Icons.image, size: 40, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 15),
              // Botones
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t("Imagen del Producto:"),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    ElevatedButton.icon(
                      onPressed: _subirImagen,
                      icon: const Icon(Icons.folder_open),
                      label: Text(_t("Explorar Archivos...")),
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
                        label: Text(
                          _t("Quitar foto"),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Text(
                      _t("Soporta: JPG, PNG"),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                    labelText: _t("Cód. PLU"),
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
                  decoration: InputDecoration(
                    labelText: _t("Cód. Barras"),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.qr_code),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _nombreCtrl,
            decoration: InputDecoration(
              labelText: _t("Nombre"),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.label),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _categorias.contains(_categoriaSeleccionada)
                      ? _categoriaSeleccionada
                      : _categorias.isNotEmpty
                      ? _categorias.first
                      : "Otros",
                  decoration: InputDecoration(
                    labelText: _t("Categoría"),
                    border: const OutlineInputBorder(),
                  ),
                  items: _categorias
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _categoriaSeleccionada = val!),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _t("Crear nueva categoría"),
                child: IconButton.filledTonal(
                  onPressed: _crearNuevaCategoria,
                  icon: const Icon(Icons.add),
                  tooltip: _t("Nueva categoría"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _precioVentaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _t("Precio Venta"),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _precioCostoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _t("Costo"),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _stockCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t("Stock"),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.warehouse),
            ),
          ),
          const SizedBox(height: 15),
          SwitchListTile(
            title: Text(_t("¿Se vende por Peso?")),
            subtitle: Text(_t("Activar para balanza (Kg)")),
            value: _esPesable,
            activeThumbColor: Colors.green,
            secondary: const Icon(Icons.scale),
            onChanged: (v) => setState(() => _esPesable = v),
          ),
          SwitchListTile(
            title: const Text("⭐ Producto Favorito (Top 12)"),
            subtitle: const Text("Acceso rápido táctil prioritario en el POS"),
            value: _esFavorito,
            activeThumbColor: Colors.amber[700],
            secondary: Icon(
              _esFavorito ? Icons.star : Icons.star_border,
              color: _esFavorito ? Colors.amber[700] : Colors.grey,
            ),
            onChanged: (v) => setState(() => _esFavorito = v),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save),
              label: Text(_t("GUARDAR DATOS")),
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
        title: Text(_t("Gestión de Inventario")),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_stories_outlined),
            tooltip: "Cargar Catálogo Maestro Fruver",
            onPressed: _dialogoPrecargarCatalogo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: "Mermas / Desperdicios",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MermasScreen()),
              ).then((_) => _cargarProductos());
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_view_outlined),
            tooltip: "Exportar Inventario a Excel",
            onPressed: () {
              ExcelExportService().exportarInventario().then((ruta) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("✅ Inventario exportado: $ruta"),
                      backgroundColor: Colors.green.shade800,
                      action: SnackBarAction(
                        label: "ABRIR CARPETA",
                        textColor: Colors.white,
                        onPressed: () =>
                            ExcelExportService().abrirCarpetaEnExplorador(ruta),
                      ),
                    ),
                  );
                }
              }).catchError((e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error exportando inventario: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: const Icon(Icons.list), text: _t("LISTA")),
            Tab(
              icon: const Icon(Icons.add_circle),
              text: _t("CREAR / EDITAR"),
            ),
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
                    hintText: _t("Buscar por nombre, PLU o barras..."),
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
