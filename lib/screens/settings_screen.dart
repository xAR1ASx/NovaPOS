import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import '../database/db_helper.dart';
import '../services/pin_auth_service.dart';
import '../services/printer_service.dart';
import '../services/balanza_service.dart';
import '../services/auto_backup_service.dart';
import '../utils/numero.dart';
import '../services/locale_service.dart';
import '../services/ui_mode_service.dart';
import '../services/sync_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Idioma / Language': 'Language',
  'Los textos del sistema en Inglés': 'System texts in English',
  'Los textos del sistema en Español': 'System texts in Spanish',
  'Sincronización entre cajas': 'Sync between cash registers',
  'Comparte productos, ventas y clientes entre varias cajas en tiempo real':
      'Share products, sales and customers between cash registers in real time',
  'Sincronización activa': 'Sync active',
  'Pendientes por subir': 'Pending to upload',
  'Sincronizando...': 'Syncing...',
  'Sincronización apagada': 'Sync off',
  'Sincronizar': 'Sync',
};

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
  final _regimenEmpresaCtrl = TextEditingController();
  final _direccionEmpresaCtrl = TextEditingController();
  final _ciudadEmpresaCtrl = TextEditingController();
  final _telefonoEmpresaCtrl = TextEditingController();
  final _mensajePieCtrl = TextEditingController();
  final _leyendaCtrl = TextEditingController();

  String _impresoraSeleccionada = "";
  List<String> _impresoras = [];
  bool _impresionDirecta = false;
  String _balanzaPuerto = "COM1";
  String _balanzaVelocidad = "9600";
  List<String> _puertosSerial = [];
  bool _balanzaConectada = false;
  String _estadoBalanza = "";
  bool _procesando = false;
  bool _syncActivo = true;
  bool _permitirStockNegativo = true;
  final _cloudinaryCloudCtrl = TextEditingController();
  final _cloudinaryPresetCtrl = TextEditingController();

  // Configuración de Copias de Seguridad Automáticas (Auto-Backup)
  bool _backupAutoActivo = true;
  String _backupAutoFrecuencia = 'cierre_caja';
  int _backupMaxArchivos = 3;
  Map<String, dynamic> _estadoBackups = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _nombreEmpresaCtrl.addListener(_onDatosTicketModificados);
    _nitEmpresaCtrl.addListener(_onDatosTicketModificados);
    _regimenEmpresaCtrl.addListener(_onDatosTicketModificados);
    _direccionEmpresaCtrl.addListener(_onDatosTicketModificados);
    _ciudadEmpresaCtrl.addListener(_onDatosTicketModificados);
    _telefonoEmpresaCtrl.addListener(_onDatosTicketModificados);
    _mensajePieCtrl.addListener(_onDatosTicketModificados);
    _leyendaCtrl.addListener(_onDatosTicketModificados);
    _cargarConfiguracion();
  }

  void _onDatosTicketModificados() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreEmpresaCtrl.removeListener(_onDatosTicketModificados);
    _nitEmpresaCtrl.removeListener(_onDatosTicketModificados);
    _regimenEmpresaCtrl.removeListener(_onDatosTicketModificados);
    _direccionEmpresaCtrl.removeListener(_onDatosTicketModificados);
    _ciudadEmpresaCtrl.removeListener(_onDatosTicketModificados);
    _telefonoEmpresaCtrl.removeListener(_onDatosTicketModificados);
    _mensajePieCtrl.removeListener(_onDatosTicketModificados);
    _leyendaCtrl.removeListener(_onDatosTicketModificados);

    _nombreEmpresaCtrl.dispose();
    _nitEmpresaCtrl.dispose();
    _regimenEmpresaCtrl.dispose();
    _direccionEmpresaCtrl.dispose();
    _ciudadEmpresaCtrl.dispose();
    _telefonoEmpresaCtrl.dispose();
    _mensajePieCtrl.dispose();
    _leyendaCtrl.dispose();
    _cloudinaryCloudCtrl.dispose();
    _cloudinaryPresetCtrl.dispose();
    super.dispose();
  }

  void _cargarConfiguracion() async {
    final config = await DBHelper().obtenerConfiguracion();
    final estadoBkp = await AutoBackupService().obtenerEstadoBackups();
    if (!mounted) return;
    setState(() {
      _nombreEmpresaCtrl.text = config['empresa_nombre'] ?? "";
      _nitEmpresaCtrl.text = config['empresa_nit'] ?? "";
      _regimenEmpresaCtrl.text = config['empresa_regimen'] ?? "";
      _direccionEmpresaCtrl.text = config['empresa_direccion'] ?? "";
      _ciudadEmpresaCtrl.text = config['empresa_ciudad'] ?? "";
      _telefonoEmpresaCtrl.text = config['empresa_telefono'] ?? "";
      _mensajePieCtrl.text = config['ticket_mensaje_pie'] ?? "";
      _leyendaCtrl.text = config['ticket_leyenda'] ?? "";

      _impresoraSeleccionada = config['impresora_nombre'] ?? "";
      _impresionDirecta = config['impresion_directa'] == '1';
      _balanzaPuerto = config['balanza_puerto'] ?? "COM1";
      _balanzaVelocidad = config['balanza_velocidad'] ?? "9600";
      _syncActivo = config['sync_activo'] != '0';
      _permitirStockNegativo = (config['permitir_stock_negativo'] ?? '1') == '1';
      _cloudinaryCloudCtrl.text = config['cloudinary_cloud_name'] ?? "";
      _cloudinaryPresetCtrl.text = config['cloudinary_upload_preset'] ?? "";

      _backupAutoActivo = (config['backup_auto_activo'] ?? '1') == '1';
      _backupAutoFrecuencia = config['backup_auto_frecuencia'] ?? 'cierre_caja';
      _backupMaxArchivos = int.tryParse(config['backup_max_archivos'] ?? '3') ?? 3;
      _estadoBackups = estadoBkp;
    });
  }

  void _guardarTodo() async {
    final db = DBHelper();
    await db.guardarConfiguracion('empresa_nombre', _nombreEmpresaCtrl.text.trim());
    await db.guardarConfiguracion('empresa_nit', _nitEmpresaCtrl.text.trim());
    await db.guardarConfiguracion('empresa_regimen', _regimenEmpresaCtrl.text.trim());
    await db.guardarConfiguracion('empresa_direccion', _direccionEmpresaCtrl.text.trim());
    await db.guardarConfiguracion('empresa_ciudad', _ciudadEmpresaCtrl.text.trim());
    await db.guardarConfiguracion('empresa_telefono', _telefonoEmpresaCtrl.text.trim());
    await db.guardarConfiguracion('ticket_mensaje_pie', _mensajePieCtrl.text.trim());
    await db.guardarConfiguracion('ticket_leyenda', _leyendaCtrl.text.trim());

    await db.guardarConfiguracion('impresora_nombre', _impresoraSeleccionada);
    await db.guardarConfiguracion(
      'impresion_directa',
      _impresionDirecta ? '1' : '0',
    );
    await db.guardarConfiguracion('balanza_puerto', _balanzaPuerto);
    await db.guardarConfiguracion('balanza_velocidad', _balanzaVelocidad);
    await db.guardarPermitirStockNegativo(_permitirStockNegativo);
    await db.guardarConfiguracion(
      'cloudinary_cloud_name',
      _cloudinaryCloudCtrl.text.trim(),
    );
    await db.guardarConfiguracion(
      'cloudinary_upload_preset',
      _cloudinaryPresetCtrl.text.trim(),
    );

    await db.guardarConfiguracion('backup_auto_activo', _backupAutoActivo ? '1' : '0');
    await db.guardarConfiguracion('backup_auto_frecuencia', _backupAutoFrecuencia);
    await db.guardarConfiguracion('backup_max_archivos', _backupMaxArchivos.toString());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Configuración guardada correctamente"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _hacerBackup() async {
    try {
      final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final nombreArchivo = 'NovaPOS_Backup_$now.db';

      final rutaDb = await DBHelper().obtenerRutaBaseDatos();
      final dbFile = File(rutaDb);
      if (!await dbFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ No se encontró la base de datos para respaldar"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final bytes = await dbFile.readAsBytes();

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Guardar copia de seguridad de NovaPOS',
        fileName: nombreArchivo,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (uri == null) return;
      final rutaDestino = uri.toFilePath();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Copia de seguridad guardada en: $rutaDestino"),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error al generar la copia de seguridad: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _restaurarBackup([String? rutaDirecta]) async {
    String? path = rutaDirecta;
    if (path == null) {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Selecciona el archivo de copia de seguridad (.db)',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (file == null || file.path == null) return;
      path = file.path!;
    }

    if (!mounted) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.amber),
            SizedBox(width: 8),
            Text("¿Restaurar copia de seguridad?"),
          ],
        ),
        content: Text(
          "⚠️ ATENCIÓN: Esta acción reemplazará toda la base de datos actual con la información del archivo:\n\n"
          "${path!}\n\n"
          "Se recomienda hacer una copia previa si deseas conservar los datos actuales.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("SÍ, RESTAURAR"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final ok = await DBHelper().restaurarBackup(path);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Base de datos restaurada correctamente"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
      _cargarConfiguracion();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Error al restaurar la base de datos. Verifica el archivo."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _crearBackupAutoAhora() async {
    setState(() => _procesando = true);
    final ok = await AutoBackupService().ejecutarBackupSiCorresponde(
      motivo: 'manual',
      forzar: true,
    );
    final estado = await AutoBackupService().obtenerEstadoBackups();
    if (!mounted) return;
    setState(() {
      _procesando = false;
      _estadoBackups = estado;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? "✅ Copia de seguridad automática guardada exitosamente"
            : "❌ Error al crear la copia de seguridad"),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red,
      ),
    );
  }

  void _dialogoListaBackups() async {
    final estado = await AutoBackupService().obtenerEstadoBackups();
    if (!mounted) return;
    final List archivos = (estado['archivos'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: Colors.indigo),
            SizedBox(width: 8),
            Text("Respaldos Automáticos Disponibles"),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: archivos.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "Aún no hay respaldos automáticos en la carpeta. Puedes pulsar 'Crear Respaldo Ahora' para generar el primero.",
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: archivos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final arc = archivos[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.storage, color: Colors.indigo),
                      title: Text(
                        arc['nombre'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("${arc['fecha']} • ${arc['tamano']}"),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _restaurarBackup(arc['path']);
                        },
                        child: const Text("Restaurar"),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text("Abrir Carpeta"),
            onPressed: () {
              Navigator.pop(ctx);
              AutoBackupService().abrirCarpetaEnExplorador();
            },
          ),
        ],
      ),
    );
  }

  void _imprimirTicketPrueba() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🖨️ Generando borrador de prueba para impresión..."),
        duration: Duration(seconds: 2),
      ),
    );
    await PrinterService().imprimirTicketPrueba(
      datosPersonalizados: {
        'empresa_nombre': _nombreEmpresaCtrl.text,
        'empresa_nit': _nitEmpresaCtrl.text,
        'empresa_regimen': _regimenEmpresaCtrl.text,
        'empresa_direccion': _direccionEmpresaCtrl.text,
        'empresa_ciudad': _ciudadEmpresaCtrl.text,
        'empresa_telefono': _telefonoEmpresaCtrl.text,
        'ticket_mensaje_pie': _mensajePieCtrl.text,
        'ticket_leyenda': _leyendaCtrl.text,
      },
    );
  }

  void _solicitarCambiarPin() {
    final pinActualCtrl = TextEditingController();
    final pinNuevoCtrl = TextEditingController();
    final pinConfirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cambiar mi PIN"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinActualCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: "PIN actual",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinNuevoCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: "PIN nuevo (6 digitos)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinConfirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: "Confirmar PIN nuevo",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (pinNuevoCtrl.text.length < 6) return;
              if (pinNuevoCtrl.text != pinConfirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Los PIN nuevos no coinciden"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              Map<String, dynamic> resultado =
                  await PinAuthService.cambiarPinPropio(
                pinActualCtrl.text,
                pinNuevoCtrl.text,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(resultado['mensaje']),
                  backgroundColor:
                      resultado['exito'] ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text("Guardar"),
          ),
        ],
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
            const Text("Ingresa tu PIN de ADMIN para confirmar:"),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: "PIN",
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
              bool esCorrecta = await PinAuthService.verificarPinActual(
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

  void _dialogoPrecargarCatalogoMaestro() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_stories, color: Colors.green),
            SizedBox(width: 8),
            Text("Catálogo Maestro Fruver"),
          ],
        ),
        content: const Text(
          "¿Deseas precargar el catálogo maestro colombiano de Fruver y Minimarket?\n\n"
          "Se agregarán aproximadamente 120 referencias con códigos PLU (ej: 101 Tomate, 201 Manzana), "
          "costos y precios sugeridos, organizados en Frutas, Verduras, Abarrotes, Lácteos, Bebidas y Aseo.\n\n"
          "Podrás modificar o eliminar cualquier producto desde el módulo de Inventario.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("SÍ, CARGAR CATÁLOGO"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      final insertados = await DBHelper().precargarCatalogoMaestro(forzar: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            insertados > 0
                ? "✅ ¡Éxito! Se precargaron $insertados productos en tu inventario."
                : "ℹ️ Todos los productos del catálogo maestro ya estaban cargados.",
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error al precargar catálogo: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
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
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (file != null) {
        setState(() => _procesando = true);
        File archivo = File(file.path!);
        var bytes = archivo.readAsBytesSync();
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
      } else if (tipo == 'MERMAS') {
        sheet.appendRow([
          TextCellValue('ID Merma'),
          TextCellValue('Fecha'),
          TextCellValue('Producto'),
          TextCellValue('Cantidad de Baja'),
          TextCellValue('Costo Unitario'),
          TextCellValue('Total Pérdida'),
          TextCellValue('Motivo'),
        ]);
        final data = await DBHelper().obtenerMermas();
        for (var m in data) {
          sheet.appendRow([
            IntCellValue(m['id'] as int? ?? 0),
            TextCellValue(m['fecha']?.toString() ?? ''),
            TextCellValue(m['nombre_producto']?.toString() ?? ''),
            DoubleCellValue((m['cantidad'] as num?)?.toDouble() ?? 0.0),
            DoubleCellValue((m['costo_unitario'] as num?)?.toDouble() ?? 0.0),
            DoubleCellValue((m['total_perdida'] as num?)?.toDouble() ?? 0.0),
            TextCellValue(m['motivo']?.toString() ?? ''),
          ]);
        }
      }
      String fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await _guardarExcelEnDispositivo(excel, "NovaPOS_${tipo}_$fecha.xlsx");
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
      return parseNumero(cell.value.toString()) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _guardarExcelEnDispositivo(
    Excel excel,
    String nombreArchivo,
  ) async {
    String rutaBase = "";
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final docs = await getApplicationDocumentsDirectory();
      rutaBase = docs.path;
    } else {
      rutaBase = "/storage/emulated/0/Download";
      if (!Directory(rutaBase).existsSync()) {
        final ext = await getExternalStorageDirectory();
        rutaBase = ext?.path ?? "";
      }
    }
    final String folderPath = "$rutaBase/NovaPOS_Reportes";
    await Directory(folderPath).create(recursive: true);
    String rutaFinal = "$folderPath/$nombreArchivo";
    File(rutaFinal)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 26),
            SizedBox(width: 8),
            Text("Archivo Guardado"),
          ],
        ),
        content: Text("Ubicación:\n$rutaFinal"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("CERRAR"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text("ABRIR CARPETA"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(c);
              if (Platform.isWindows) {
                Process.run('explorer.exe', ['/select,', rutaFinal]);
              }
            },
          ),
        ],
      ),
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

  Widget _construirFormularioDatosTicket() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, color: Colors.blueGrey.shade800),
                const SizedBox(width: 8),
                const Text(
                  "Datos del Negocio y Encabezado del Ticket",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Estos datos aparecerán impresos en la parte superior e inferior de cada factura o ticket entregado al cliente.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Divider(height: 25),
            TextField(
              controller: _nombreEmpresaCtrl,
              decoration: const InputDecoration(
                labelText: "Nombre Comercial del Negocio",
                hintText: "Ej: MI FRUVER & MINIMARKET / XXXXX",
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _nitEmpresaCtrl,
                    decoration: const InputDecoration(
                      labelText: "NIT / RUT / C.C.",
                      hintText: "Ej: 901.234.567-8 / XXXXX",
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: TextField(
                    controller: _regimenEmpresaCtrl,
                    decoration: const InputDecoration(
                      labelText: "Régimen / Tipo Contribuyente",
                      hintText: "Ej: No Responsable de IVA",
                      prefixIcon: Icon(Icons.account_balance_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _direccionEmpresaCtrl,
              decoration: const InputDecoration(
                labelText: "Dirección del Establecimiento",
                hintText: "Ej: Carrera 15 # 45-20 Barrio Centro / XXXXX",
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _ciudadEmpresaCtrl,
                    decoration: const InputDecoration(
                      labelText: "Ciudad / Municipio",
                      hintText: "Ej: Bogotá D.C. / XXXXX",
                      prefixIcon: Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: TextField(
                    controller: _telefonoEmpresaCtrl,
                    decoration: const InputDecoration(
                      labelText: "Teléfono / WhatsApp de Pedidos",
                      hintText: "Ej: 310 123 4567 / (601) 000 0000",
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Pie de Página y Mensaje Final",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mensajePieCtrl,
              decoration: const InputDecoration(
                labelText: "Mensaje de Despedida / Agradecimiento",
                hintText: "Ej: ¡Gracias por su compra! Vuelva pronto / XXXXX",
                prefixIcon: Icon(Icons.sentiment_satisfied_alt),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _leyendaCtrl,
              decoration: const InputDecoration(
                labelText: "Leyenda Legal / Resolución / Aviso",
                hintText: "Ej: Documento equivalente POS - Sistema NovaPOS",
                prefixIcon: Icon(Icons.info_outline),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirCardBorradorTicket() {
    final nombre = _nombreEmpresaCtrl.text.trim().isNotEmpty
        ? _nombreEmpresaCtrl.text.trim().toUpperCase()
        : "XXXXX (NOMBRE DEL NEGOCIO)";
    final nit = _nitEmpresaCtrl.text.trim().isNotEmpty
        ? _nitEmpresaCtrl.text.trim()
        : "NIT: 900.000.000-X / XXXXX";
    final regimen = _regimenEmpresaCtrl.text.trim().isNotEmpty
        ? _regimenEmpresaCtrl.text.trim()
        : "No Responsable de IVA (Régimen Simplificado)";
    final direccion = _direccionEmpresaCtrl.text.trim().isNotEmpty
        ? _direccionEmpresaCtrl.text.trim()
        : "Dirección: Calle XXXXX # XX-XX";
    final ciudad = _ciudadEmpresaCtrl.text.trim().isNotEmpty
        ? _ciudadEmpresaCtrl.text.trim()
        : "Ciudad: XXXXX, Colombia";
    final telefono = _telefonoEmpresaCtrl.text.trim().isNotEmpty
        ? _telefonoEmpresaCtrl.text.trim()
        : "Tel / WhatsApp: (XXX) XXX XXXX";
    final mensajePie = _mensajePieCtrl.text.trim().isNotEmpty
        ? _mensajePieCtrl.text.trim()
        : "¡Gracias por su compra! Vuelva pronto";
    final leyenda = _leyendaCtrl.text.trim().isNotEmpty
        ? _leyendaCtrl.text.trim()
        : "Documento equivalente POS - Sistema NovaPOS";

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      "Borrador en Vivo (80 mm)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "VISTA PREVIA",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(nit, style: const TextStyle(fontSize: 10)),
                  Text(
                    regimen,
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
                  ),
                  Text(
                    direccion,
                    style: const TextStyle(fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                  Text(ciudad, style: const TextStyle(fontSize: 9)),
                  Text(telefono, style: const TextStyle(fontSize: 9)),
                  const Divider(thickness: 1, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Ticket #0001 (BORRADOR)",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                        style: const TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Cajero: Administrador | Caja: 01",
                      style: TextStyle(fontSize: 8, color: Colors.black54),
                    ),
                  ),
                  const Divider(thickness: 1, height: 16),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Prod",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      Text(
                        "Cant",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Total",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Tomate Chonto Limpio",
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                      Text("2.50 kg ", style: TextStyle(fontSize: 9)),
                      SizedBox(width: 10),
                      Text(
                        "\$8.000",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Manzana Royal Gala",
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                      Text("1.80 kg ", style: TextStyle(fontSize: 9)),
                      SizedBox(width: 10),
                      Text(
                        "\$4.500",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Aguacate Hass Maduro",
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                      Text("2 un ", style: TextStyle(fontSize: 9)),
                      SizedBox(width: 10),
                      Text(
                        "\$5.000",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const Divider(thickness: 1, height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "TOTAL:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        "\$17.500",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Metodo Pago: EFECTIVO\n  Recibido: \$20.000  •  Cambio: \$2.500",
                      style: TextStyle(fontSize: 9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mensajePie,
                    style: const TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (leyenda.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      leyenda,
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text("IMPRIMIR TICKET DE PRUEBA FÍSICO"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _imprimirTicketPrueba,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Envía este borrador a tu impresora térmica para verificar corte y legibilidad.",
              style: TextStyle(fontSize: 11, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSeccionBackupsAuto() {
    final ruta = _estadoBackups['rutaCarpeta']?.toString() ??
        'Documents/NovaPOS_Backups';
    final total = _estadoBackups['totalArchivos'] ?? 0;
    final tamMb = _estadoBackups['tamanoTotalMb'] ?? '0.00';
    final ultimo = _estadoBackups['ultimoBackup'] ?? 'Ninguno registrado aún';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  "Copia de Seguridad Automática (Anti-Pérdida)",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Respalda toda la base de datos automáticamente (ventas, compras, inventario, clientes y caja). "
              "Aplica rotación inteligente para conservar solo las copias más recientes sin saturar el disco duro.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Divider(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Habilitar Copia de Seguridad Automática"),
              subtitle: const Text(
                "Realiza respaldos periódicos en segundo plano sin interrumpir las ventas",
              ),
              value: _backupAutoActivo,
              onChanged: (v) => setState(() => _backupAutoActivo = v),
            ),
            if (_backupAutoActivo) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _backupAutoFrecuencia,
                      decoration: const InputDecoration(
                        labelText: "Frecuencia de Respaldo",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cierre_caja',
                          child: Text("En cada Cierre de Caja (Recomendado)"),
                        ),
                        DropdownMenuItem(
                          value: 'semanal',
                          child: Text("Semanal (Cada 7 días)"),
                        ),
                        DropdownMenuItem(
                          value: 'desactivado',
                          child: Text("Solo manual"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _backupAutoFrecuencia = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _backupMaxArchivos,
                      decoration: const InputDecoration(
                        labelText: "Rotación de Archivos",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 3,
                          child: Text(
                            "Conservar las 3 más recientes (Recomendado)",
                          ),
                        ),
                        DropdownMenuItem(
                          value: 5,
                          child: Text("Conservar las 5 más recientes"),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text("Conservar 1 sola copia (Sobrescribir)"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _backupMaxArchivos = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder, size: 18, color: Colors.indigo),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Carpeta oficial: $ruta",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "📦 Almacenados: $total archivo(s) ($tamMb MB en disco)  •  🕒 Último: $ultimo",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text("Abrir Carpeta"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        AutoBackupService().abrirCarpetaEnExplorador(),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.backup),
                    label: const Text("Crear Respaldo Ahora"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _crearBackupAutoAhora,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text("Ver / Restaurar Copia"),
                    onPressed: _dialogoListaBackups,
                  ),
                ],
              ),
            ],
          ],
        ),
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
            Tab(icon: Icon(Icons.receipt_long), text: "Empresa & Ticket"),
            Tab(icon: Icon(Icons.usb), text: "Hardware"),
            Tab(icon: Icon(Icons.settings_system_daydream), text: "Sistema & Backup"),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final esAncho = constraints.maxWidth > 850;
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (esAncho)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _construirFormularioDatosTicket(),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 4,
                                child: _construirCardBorradorTicket(),
                              ),
                            ],
                          )
                        else ...[
                          _construirFormularioDatosTicket(),
                          const SizedBox(height: 20),
                          _construirCardBorradorTicket(),
                        ],
                        const SizedBox(height: 25),
                    const Text(
                      "🖥️ Interfaz",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ValueListenableBuilder<bool>(
                      valueListenable: UIModeService.tablet,
                      builder: (context, esTablet, child) {
                        return SwitchListTile(
                          title: const Text("Modo tablet (pantalla táctil)"),
                          subtitle: Text(
                            esTablet
                                ? "Botones y textos más grandes para tocar"
                                : "Interfaz normal para PC (ratón y teclado)",
                          ),
                          secondary: const Icon(Icons.tablet),
                          value: esTablet,
                          onChanged: (v) => UIModeService.setEsTablet(v),
                        );
                      },
                    ),
                    ListenableBuilder(
                      listenable: LocaleService(),
                      builder: (context, child) {
                        final esIngles = LocaleService().esIngles;
                        return SwitchListTile(
                          title: Text(_t("Idioma / Language")),
                          subtitle: Text(
                            esIngles
                                ? _t("Los textos del sistema en Inglés")
                                : _t("Los textos del sistema en Español"),
                          ),
                          secondary: const Icon(Icons.translate),
                          value: esIngles,
                          onChanged: (v) => LocaleService().setIdioma(
                            v ? 'en' : 'es',
                          ),
                        );
                      },
                    ),
                    SwitchListTile(
                      title: Text(_t("Sincronización entre cajas")),
                      subtitle: Text(
                        _t("Comparte productos, ventas y clientes entre varias cajas en tiempo real"),
                      ),
                      secondary: const Icon(Icons.cloud_sync),
                      value: _syncActivo,
                      onChanged: (v) async {
                        setState(() => _syncActivo = v);
                        await DBHelper().guardarConfiguracion(
                          'sync_activo',
                          v ? '1' : '0',
                        );
                        if (v) {
                          final cfg = await DBHelper().obtenerConfiguracion();
                          final nid = cfg['sync_negocio_id'] ?? '';
                          final uid = cfg['sync_usuario_uid'] ?? '';
                          if (nid.isNotEmpty) {
                            unawaited(SyncService()
                                .iniciar(
                                  negocioId: nid,
                                  usuarioUid: uid,
                                )
                                .catchError((e) {}));
                          }
                        } else {
                          await SyncService().detener();
                        }
                      },
                    ),
                    ValueListenableBuilder<SyncEstado>(
                      valueListenable: SyncService().estado,
                      builder: (context, st, child) {
                        final activa = _syncActivo && st.activo;
                        final linea = activa
                            ? st.pendientes > 0
                                ? "${_t('Sincronizando...')} (${st.pendientes} ${_t('Pendientes por subir')})"
                                : _t("Sincronización activa")
                            : _t("Sincronización apagada");
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            activa ? Icons.cloud_done : Icons.cloud_off,
                            color: activa ? Colors.green : Colors.grey,
                          ),
                          title: Text(linea),
                          trailing: activa
                              ? IconButton(
                                  tooltip: _t("Sincronizar"),
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    SyncService().sincronizarAhora();
                                  },
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "☁️ Almacenamiento de Fotos (Cloudinary)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    const Text(
                      "Sincroniza fotos entre cajas y tablets sin costo usando Cloudinary (Plan gratuito sin tarjeta).",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cloudinaryCloudCtrl,
                      decoration: const InputDecoration(
                        labelText: "Cloud Name",
                        hintText: "Ej: mi-fruver-cloud",
                        prefixIcon: Icon(Icons.cloud_queue),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cloudinaryPresetCtrl,
                      decoration: const InputDecoration(
                        labelText: "Upload Preset (Unsigned)",
                        hintText: "Ej: fruver_preset",
                        prefixIcon: Icon(Icons.folder_shared_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "📦 Inventario y Ventas",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text("Permitir venta con stock en cero / negativo"),
                      subtitle: const Text(
                        "Recomendado para fruver y minimarket: no detiene las ventas en caja si aún no se ha ingresado la compra del día.",
                      ),
                      secondary: const Icon(Icons.inventory_2_outlined),
                      value: _permitirStockNegativo,
                      onChanged: (v) async {
                        setState(() => _permitirStockNegativo = v);
                        await DBHelper().guardarPermitirStockNegativo(v);
                      },
                    ),
                  ],
                );
              },
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
                      initialValue: _impresoras.contains(_impresoraSeleccionada)
                          ? _impresoraSeleccionada
                          : null,
                      hint: const Text("Elige una impresora..."),
                      items: _impresoras
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _impresoraSeleccionada = v ?? ""),
                      decoration: const InputDecoration(
                        labelText: "Impresora (Windows)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final lista =
                                await PrinterService().obtenerImpresoras();
                            if (!mounted) return;
                            setState(() {
                              _impresoras = lista;
                              if (lista.contains(_impresoraSeleccionada)) {
                              } else if (lista.isNotEmpty) {
                                _impresoraSeleccionada = lista.first;
                              }
                            });
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text("Detectar impresoras"),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _impresoras.isEmpty
                                ? "Ninguna detectada aun"
                                : "Encontradas: ${_impresoras.length}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text("Impresión directa (sin diálogo)"),
                      subtitle: const Text(
                        "Envía el ticket directo a la impresora elegida",
                      ),
                      value: _impresionDirecta,
                      onChanged: (v) => setState(() => _impresionDirecta = v),
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
                            initialValue: _puertosSerial.contains(_balanzaPuerto)
                                ? _balanzaPuerto
                                : null,
                            hint: const Text("Elige un puerto..."),
                            items: _puertosSerial.isEmpty
                                ? const [
                                    DropdownMenuItem(
                                      value: "COM1",
                                      child: Text("COM1"),
                                    ),
                                  ]
                                : _puertosSerial
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) =>
                                setState(() => _balanzaPuerto = v ?? "COM1"),
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
                            items: ["9600", "19200", "115200"]
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final puertos = BalanzaService
                                .puertosDisponibles();
                            if (!mounted) return;
                            setState(() {
                              _puertosSerial = puertos;
                              if (puertos.contains(_balanzaPuerto)) {
                              } else if (puertos.isNotEmpty) {
                                _balanzaPuerto = puertos.first;
                              }
                            });
                          },
                          icon: const Icon(Icons.usb, size: 18),
                          label: const Text("Detectar puertos"),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _puertosSerial.isEmpty
                                ? "Sin puertos serial detectados"
                                : "Puertos: ${_puertosSerial.join(', ')}",
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _procesando || _balanzaConectada
                              ? null
                              : () async {
                                  setState(() {
                                    _procesando = true;
                                    _estadoBalanza = "";
                                  });
                                  final resultado = await BalanzaService
                                      .conectar();
                                  if (!mounted) return;
                                  final conectada =
                                      BalanzaService.estaConectada;
                                  setState(() {
                                    _procesando = false;
                                    _balanzaConectada = conectada;
                                    _estadoBalanza = resultado;
                                  });
                                },
                          icon: Icon(
                            _balanzaConectada
                                ? Icons.link_off
                                : Icons.link,
                            size: 18,
                          ),
                          label: Text(
                            _balanzaConectada
                                ? "Desconectar balanza"
                                : "Probar conexión",
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _estadoBalanza,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
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
                      leading: const Icon(Icons.auto_stories, color: Colors.green),
                      title: const Text("Catálogo Maestro Fruver (~120 Productos)"),
                      subtitle: const Text(
                        "Precarga frutas, verduras, abarrotes y aseo con PLU y precios de referencia",
                      ),
                      tileColor: Colors.green[50],
                      onTap: _dialogoPrecargarCatalogoMaestro,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: const Text("1. Descargar Plantilla Excel"),
                      onTap: _descargarPlantilla,
                      tileColor: Colors.green[50],
                    ),
                    const SizedBox(height: 5),
                    ListTile(
                      leading: const Icon(Icons.upload_file),
                      title: const Text("2. Importar Inventario desde Excel"),
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
                    ListTile(
                      leading: const Icon(Icons.delete_sweep, color: Colors.deepOrange),
                      title: const Text("Mermas y Desperdicios"),
                      onTap: () => _exportarExcel('MERMAS'),
                    ),

                    const SizedBox(height: 30),
                    _construirSeccionBackupsAuto(),
                    const SizedBox(height: 15),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                            child: Text(
                              "Respaldos Manuales / Externos",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.save_alt, color: Colors.indigo),
                            title: const Text("Exportar Copia Manual a USB u otra carpeta"),
                            subtitle: const Text(
                              "Guarda un respaldo completo de productos, ventas y configuración en una memoria USB o disco externo",
                            ),
                            onTap: _hacerBackup,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.restore_page, color: Colors.orange),
                            title: const Text("Restaurar desde archivo externo (.db)"),
                            subtitle: const Text(
                              "Selecciona un archivo .db guardado previamente en tu computador o USB",
                            ),
                            onTap: () => _restaurarBackup(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Text(
                      "🔒 Seguridad",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.password, color: Colors.teal),
                      title: const Text("Cambiar mi PIN"),
                      subtitle: const Text("Requiere tu PIN actual"),
                      onTap: _solicitarCambiarPin,
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
                      subtitle: const Text("Requiere tu PIN actual"),
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
