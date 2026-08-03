import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import '../database/db_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nombreEmpresaCtrl = TextEditingController();
  final _nitEmpresaCtrl = TextEditingController();
  final _direccionEmpresaCtrl = TextEditingController();
  String _impresoraSeleccionada = "SUNMI";
  String _balanzaPuerto = "COM1";
  String _balanzaVelocidad = "9600";
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreEmpresaCtrl.dispose();
    _nitEmpresaCtrl.dispose();
    _direccionEmpresaCtrl.dispose();
    super.dispose();
  }

  void _cargarConfiguracion() async {
    final config = await DBHelper().obtenerConfiguracion();
    if (!mounted) return;
    setState(() {
      _nombreEmpresaCtrl.text = config['empresa_nombre'] ?? "";
      _nitEmpresaCtrl.text = config['empresa_nit'] ?? "";
      _direccionEmpresaCtrl.text = config['empresa_direccion'] ?? "";
      _impresoraSeleccionada = config['impresora_tipo'] ?? "SUNMI";
      _balanzaPuerto = config['balanza_puerto'] ?? "COM1";
      _balanzaVelocidad = config['balanza_velocidad'] ?? "9600";
    });
  }

  void _guardarTodo() async {
    final db = DBHelper();
    await db.guardarConfiguracion('empresa_nombre', _nombreEmpresaCtrl.text);
    await db.guardarConfiguracion('empresa_nit', _nitEmpresaCtrl.text);
    await db.guardarConfiguracion(
      'empresa_direccion',
      _direccionEmpresaCtrl.text,
    );
    await db.guardarConfiguracion('impresora_tipo', _impresoraSeleccionada);
    await db.guardarConfiguracion('balanza_puerto', _balanzaPuerto);
    await db.guardarConfiguracion('balanza_velocidad', _balanzaVelocidad);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Configuración guardada"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _solicitarPasswordYBorrar() {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text("¡ZONA DE PELIGRO!"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Esta acción BORRARÁ TODOS los productos, ventas y clientes.\n\nNo se puede deshacer.",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text("Ingresa tu contraseña de ADMIN para confirmar:"),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Contraseña",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (passCtrl.text.isEmpty) return;
              bool esCorrecta = await DBHelper().validarContrasenaAdmin(
                passCtrl.text,
              );
              if (esCorrecta) {
                Navigator.pop(ctx);
                _ejecutarBorrado();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("❌ Contraseña Incorrecta"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("BORRAR TODO"),
          ),
        ],
      ),
    );
  }

  void _ejecutarBorrado() async {
    setState(() => _procesando = true);
    try {
      await DBHelper().resetFactory();
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text("♻️ Sistema Reiniciado"),
          content: const Text(
            "La base de datos ha sido limpiada correctamente.\n\nAhora puedes importar tu inventario nuevo.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al borrar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _procesando = false);
    }
  }

  void _descargarPlantilla() async {
    setState(() => _procesando = true);
    var excel = Excel.createExcel();
    String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    Sheet sheet = excel[defaultSheet];
    sheet.appendRow([
      TextCellValue('Nombre Producto (Obligatorio)'),
      TextCellValue('Codigo Barras'),
      TextCellValue('Categoria (Ej: Frutas)'),
      TextCellValue('Costo (Solo números)'),
      TextCellValue('Precio Venta (Solo números)'),
      TextCellValue('Stock Inicial'),
      TextCellValue('Es Pesable (SI/NO)'),
    ]);
    sheet.appendRow([
      TextCellValue('Ej: Manzana Roja'),
      TextCellValue('770123456789'),
      TextCellValue('Frutas'),
      IntCellValue(2000),
      IntCellValue(3500),
      IntCellValue(50),
      TextCellValue('SI'),
    ]);
    await _guardarExcelEnDispositivo(excel, "PLANTILLA_IMPORTAR_FRUVER.xlsx");
    setState(() => _procesando = false);
  }

  void _importarInventario() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result != null) {
        setState(() => _procesando = true);
        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);
        List<Map<String, dynamic>> listaProductos = [];
        int filasLeidas = 0;
        if (excel.tables.isNotEmpty) {
          var table = excel.tables[excel.tables.keys.first]!;
          for (var row in table.rows) {
            filasLeidas++;
            if (filasLeidas <= 1) continue;
            String nombre = _getCellValue(row[0]);
            if (nombre.trim().isEmpty) break;
            if (nombre.contains("Ej: Manzana")) continue;
            String codigo = _getCellValue(row[1]);
            String categoria = _getCellValue(row[2]);
            if (categoria.isEmpty) categoria = "Otros";
            double costo = _getDoubleValue(row[3]);
            double precio = _getDoubleValue(row[4]);
            double stock = _getDoubleValue(row[5]);
            String esPesableStr = _getCellValue(row[6]).toUpperCase();
            int esPesable = (esPesableStr == "SI" || esPesableStr == "S")
                ? 1
                : 0;
            listaProductos.add({
              'nombre': nombre,
              'codigo_barras': codigo,
              'codigo_plu': '',
              'categoria': categoria,
              'precio_costo': costo,
              'precio_venta': precio,
              'stock_actual': stock,
              'es_pesable': esPesable,
            });
          }
        }
        if (listaProductos.isNotEmpty) {
          await DBHelper().importarProductosMasivos(listaProductos);
          if (!mounted) return;
          _mostrarAlerta(
            "¡Importación Exitosa!",
            "✅ Se procesaron ${listaProductos.length} productos (Nuevos agregados y existentes actualizados).",
          );
        } else {
          _mostrarAlerta("Aviso", "El archivo parece estar vacío.");
        }
      }
    } catch (e) {
      _mostrarAlerta("Error Crítico", "Error: $e");
    } finally {
      setState(() => _procesando = false);
    }
  }

  void _exportarExcel(String tipo) async {
    setState(() => _procesando = true);
    try {
      var excel = Excel.createExcel();
      String sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      Sheet sheet = excel[sheetName];
      if (tipo == 'INVENTARIO') {
        sheet.appendRow([
          TextCellValue('ID'),
          TextCellValue('Producto'),
          TextCellValue('Stock'),
          TextCellValue('Costo Unit'),
          TextCellValue('Precio Venta'),
          TextCellValue('Codigo'),
        ]);
        final data = await DBHelper().obtenerTodoElInventario();
        for (var p in data) {
          sheet.appendRow([
            IntCellValue(p['id']),
            TextCellValue(p['nombre']),
            DoubleCellValue((p['stock_actual'] as num).toDouble()),
            DoubleCellValue((p['precio_costo'] as num).toDouble()),
            DoubleCellValue((p['precio_venta'] as num).toDouble()),
            TextCellValue(p['codigo_barras'] ?? ''),
          ]);
        }
      } else if (tipo == 'VENTAS') {
        sheet.appendRow([
          TextCellValue('ID Venta'),
          TextCellValue('Fecha'),
          TextCellValue('Pago'),
          TextCellValue('Prod'),
          TextCellValue('Cant'),
          TextCellValue('Precio'),
          TextCellValue('Subtotal'),
        ]);
        final data = await DBHelper().obtenerVentasDetalladasExportar();
        for (var v in data) {
          sheet.appendRow([
            IntCellValue(v['venta_id']),
            TextCellValue(v['fecha']),
            TextCellValue(v['metodo_pago']),
            TextCellValue(v['nombre_producto']),
            DoubleCellValue((v['cantidad'] as num).toDouble()),
            DoubleCellValue((v['precio_unitario'] as num).toDouble()),
            DoubleCellValue((v['subtotal'] as num).toDouble()),
          ]);
        }
      } else if (tipo == 'COMPRAS') {
        sheet.appendRow([
          TextCellValue('ID Compra'),
          TextCellValue('Fecha'),
          TextCellValue('Prov'),
          TextCellValue('Prod'),
          TextCellValue('Cant'),
          TextCellValue('Costo'),
          TextCellValue('Subtotal'),
        ]);
        final data = await DBHelper().obtenerComprasDetalladasExportar();
        for (var c in data) {
          sheet.appendRow([
            IntCellValue(c['compra_id']),
            TextCellValue(c['fecha']),
            TextCellValue(c['proveedor']),
            TextCellValue(c['nombre_producto']),
            DoubleCellValue((c['cantidad'] as num).toDouble()),
            DoubleCellValue((c['costo_unitario'] as num).toDouble()),
            DoubleCellValue((c['subtotal'] as num).toDouble()),
          ]);
        }
      }
      String fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await _guardarExcelEnDispositivo(excel, "Fruver_${tipo}_$fecha.xlsx");
    } catch (e) {
      _mostrarAlerta("Error Exportando", "Detalle: $e");
    } finally {
      setState(() => _procesando = false);
    }
  }

  String _getCellValue(Data? cell) {
    return cell?.value.toString() ?? "";
  }

  double _getDoubleValue(Data? cell) {
    if (cell == null || cell.value == null) return 0;
    try {
      return double.parse(cell.value.toString());
    } catch (e) {
      return 0;
    }
  }

  Future<void> _guardarExcelEnDispositivo(
    Excel excel,
    String nombreArchivo,
  ) async {
    String rutaBase = "";
    if (Platform.isWindows || Platform.isLinux) {
      final docs = await getApplicationDocumentsDirectory();
      rutaBase = docs.path;
    } else {
      rutaBase = "/storage/emulated/0/Download";
      if (!Directory(rutaBase).existsSync()) {
        final ext = await getExternalStorageDirectory();
        rutaBase = ext?.path ?? "";
      }
    }
    final String folderPath = "$rutaBase/Reportes_Fruver";
    await Directory(folderPath).create(recursive: true);
    String rutaFinal = "$folderPath/$nombreArchivo";
    File(rutaFinal)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);
    _mostrarAlerta(
      "Archivo Guardado",
      "Ubicación: $rutaFinal\n(Carpeta Descargas/Reportes_Fruver)",
    );
  }

  void _mostrarAlerta(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración Total"),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.store), text: "Empresa"),
            Tab(icon: Icon(Icons.usb), text: "Hardware"),
            Tab(icon: Icon(Icons.settings_system_daydream), text: "Sistema"),
          ],
        ),
      ),
      body: _procesando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Procesando..."),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      "Datos del Negocio",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    TextField(
                      controller: _nombreEmpresaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nombre del Negocio",
                        prefixIcon: Icon(Icons.storefront),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _nitEmpresaCtrl,
                      decoration: const InputDecoration(
                        labelText: "NIT / RUT",
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _direccionEmpresaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Dirección y Teléfono",
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      "🖨️ Impresora",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      initialValue: _impresoraSeleccionada,
                      items: ["SUNMI", "USB", "BLUETOOTH"]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _impresoraSeleccionada = v!),
                      decoration: const InputDecoration(
                        labelText: "Tipo Conexión",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "⚖️ Balanza",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _balanzaPuerto,
                            items: ["COM1", "COM2", "/dev/ttyS0"]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _balanzaPuerto = v!),
                            decoration: const InputDecoration(
                              labelText: "Puerto",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _balanzaVelocidad,
                            items: ["9600", "115200"]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _balanzaVelocidad = v!),
                            decoration: const InputDecoration(
                              labelText: "Baudios",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      "📥 Carga Masiva",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: const Text("1. Descargar Plantilla"),
                      onTap: _descargarPlantilla,
                      tileColor: Colors.green[50],
                    ),
                    const SizedBox(height: 5),
                    ListTile(
                      leading: const Icon(Icons.upload_file),
                      title: const Text("2. Importar Inventario"),
                      onTap: _importarInventario,
                      tileColor: Colors.green[50],
                    ),

                    const SizedBox(height: 30),
                    const Text(
                      "📤 Exportar Datos",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.inventory),
                      title: const Text("Inventario"),
                      onTap: () => _exportarExcel('INVENTARIO'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.receipt),
                      title: const Text("Ventas"),
                      onTap: () => _exportarExcel('VENTAS'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_shipping),
                      title: const Text("Compras"),
                      onTap: () => _exportarExcel('COMPRAS'),
                    ),

                    const SizedBox(height: 30),
                    const Text(
                      "⚠️ Zona de Peligro",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                      ),
                      title: const Text(
                        "Borrar BD (Reset de Fábrica)",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text("Requiere contraseña de Admin"),
                      onTap: _solicitarPasswordYBorrar,
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _guardarTodo,
        label: const Text("GUARDAR"),
        icon: const Icon(Icons.save),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
    );
  }
}
