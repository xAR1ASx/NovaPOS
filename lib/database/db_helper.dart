import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../services/password_service.dart';
import '../data/catalogo_maestro.dart';
import '../utils/categorias_caja.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;
  static void Function()? onDatoEncolado;

  @visibleForTesting
  static void setDatabaseForTesting(Database? db) {
    _database = db;
  }

  @visibleForTesting
  Future<Database> initMemoryDBForTesting() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 14,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      ),
    );
    _database = db;
    return db;
  }

  /// Abre un archivo con el mismo proceso de creación y migración de la app.
  @visibleForTesting
  Future<Database> abrirArchivoParaPruebas(String path) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 14,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      ),
    );
    _database = db;
    return db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    Directory directory;
    try {
      directory = await getApplicationDocumentsDirectory();
    } catch (_) {
      directory = Directory.systemTemp;
    }
    final rutaCarpeta = Directory(join(directory.path, 'Sistema_Fruver_Data'));
    if (!await rutaCarpeta.exists()) {
      await rutaCarpeta.create(recursive: true);
    }

    final path = join(rutaCarpeta.path, 'mifruver_sistema_v12_imagenes_ok.db');

    return await openDatabase(
      path,
      version: 14,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE usuarios (id INTEGER PRIMARY KEY AUTOINCREMENT, usuario TEXT UNIQUE, password_hash TEXT, rol TEXT, nombre_completo TEXT, esta_activo INTEGER DEFAULT 1, auth_uid TEXT UNIQUE)',
    );
    await db.execute(
      'CREATE TABLE productos (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT, codigo_barras TEXT, codigo_plu TEXT, categoria TEXT, precio_costo REAL, precio_venta REAL, stock_actual REAL, es_pesable INTEGER DEFAULT 0, esta_activo INTEGER DEFAULT 1, imagen_path TEXT, uuid TEXT, dispositivo_uuid TEXT, es_favorito INTEGER DEFAULT 0, es_combo INTEGER DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE combo_detalles (id INTEGER PRIMARY KEY AUTOINCREMENT, combo_id INTEGER, producto_id INTEGER, cantidad REAL, uuid TEXT)',
    );
    await db.execute(
      'CREATE TABLE configuracion (clave TEXT PRIMARY KEY, valor TEXT)',
    );
    await db.execute(
      'CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT, telefono TEXT, direccion TEXT, deuda_actual REAL DEFAULT 0, cupo_credito REAL DEFAULT 0, esta_activo INTEGER DEFAULT 1, uuid TEXT)',
    );
    await db.execute(
      'CREATE TABLE ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, total REAL, metodo_pago TEXT, usuario_id INTEGER, cliente_id INTEGER DEFAULT 0, anulada INTEGER DEFAULT 0, uuid TEXT, dispositivo_uuid TEXT, metodo_pago_detalle TEXT)',
    );
    await db.execute(
      'CREATE TABLE detalle_ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, venta_id INTEGER, producto_id INTEGER, nombre_producto TEXT, cantidad REAL, cantidad_descontada REAL, precio_unitario REAL, subtotal REAL, costo_unitario REAL DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE compras (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, total REAL, metodo_pago TEXT, proveedor TEXT, uuid TEXT, usuario_id INTEGER)',
    );
    await db.execute(
      'CREATE TABLE detalle_compras (id INTEGER PRIMARY KEY AUTOINCREMENT, compra_id INTEGER, producto_id INTEGER, nombre_producto TEXT, cantidad REAL, costo_unitario REAL, subtotal REAL)',
    );
    await db.execute(
      'CREATE TABLE cierres_caja (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, fecha_inicio TEXT, fecha_fin TEXT, base REAL DEFAULT 0, ventas_turno REAL DEFAULT 0, ventas_turno_global REAL DEFAULT 0, ingresos_turno REAL DEFAULT 0, gastos_turno REAL DEFAULT 0, total_sistema REAL DEFAULT 0, real_contado REAL DEFAULT 0, diferencia REAL DEFAULT 0, estado TEXT, usuario_id INTEGER, detalle TEXT, uuid TEXT)',
    );
    await db.execute(
      'CREATE TABLE movimientos_cartera (id INTEGER PRIMARY KEY AUTOINCREMENT, cliente_id INTEGER, tipo TEXT, venta_id INTEGER, fecha TEXT, monto REAL, usuario_id INTEGER, uuid TEXT)',
    );
    await db.execute(
      'CREATE TABLE caja_movimientos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, tipo TEXT, monto REAL, descripcion TEXT, usuario_id INTEGER, uuid TEXT)',
    );
    await db.execute(
      'CREATE TABLE presentaciones (id INTEGER PRIMARY KEY AUTOINCREMENT, producto_id INTEGER, nombre TEXT, cantidad REAL, precio REAL, codigo_barras TEXT)',
    );
    await db.execute('''
CREATE TABLE mermas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT,
  producto_id INTEGER,
  nombre_producto TEXT,
  cantidad REAL,
  costo_unitario REAL,
  total_perdida REAL,
  motivo TEXT,
  usuario_id INTEGER,
  uuid TEXT
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS promociones (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  dias_semana TEXT NOT NULL,
  tipo_alcance TEXT NOT NULL,
  alcance_valor TEXT,
  tipo_descuento TEXT NOT NULL,
  valor_descuento REAL NOT NULL,
  esta_activa INTEGER DEFAULT 1,
  forzar_hoy INTEGER DEFAULT 0,
  creado_en TEXT,
  uuid TEXT
)
''');

    await db.execute('''
CREATE TABLE roles(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL UNIQUE,
  descripcion TEXT
)
''');

    await db.execute('''
CREATE TABLE permisos(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  codigo TEXT NOT NULL UNIQUE,
  descripcion TEXT
)
''');

    await db.execute('''
CREATE TABLE roles_permisos(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rol_id INTEGER NOT NULL,
  permiso_id INTEGER NOT NULL,
  FOREIGN KEY (rol_id) REFERENCES roles(id),
  FOREIGN KEY (permiso_id) REFERENCES permisos(id)
)
''');

    // =======================
    // ROLES DEL SISTEMA
    // =======================

    await db.insert("roles", {
      "nombre": "ADMIN",
      "descripcion": "Administrador del sistema",
    });

    await db.insert("roles", {"nombre": "CAJERO", "descripcion": "Cajero"});

    // =======================
    // PERMISOS
    // =======================

    final permisos = [
      ["VENTAS_VER", "Ver ventas"],
      ["VENTAS_CREAR", "Crear ventas"],
      ["VENTAS_EDITAR", "Editar ventas"],
      ["VENTAS_ANULAR", "Anular ventas"],

      ["CAJA_VER", "Ver caja"],
      ["CAJA_ABRIR", "Abrir caja"],
      ["CAJA_CERRAR", "Cerrar caja"],
      ["CAJA_MOVIMIENTOS", "Movimientos de caja"],

      ["INVENTARIO_VER", "Ver inventario"],
      ["INVENTARIO_CREAR", "Crear productos"],
      ["INVENTARIO_EDITAR", "Editar productos"],
      ["INVENTARIO_ELIMINAR", "Eliminar productos"],

      ["COMPRAS_VER", "Ver compras"],
      ["COMPRAS_CREAR", "Crear compras"],
      ["COMPRAS_EDITAR", "Editar compras"],
      ["COMPRAS_ELIMINAR", "Eliminar compras"],

      ["REPORTES_VER", "Ver reportes"],

      ["USUARIOS_VER", "Ver usuarios"],
      ["USUARIOS_CREAR", "Crear usuarios"],
      ["USUARIOS_EDITAR", "Editar usuarios"],
      ["USUARIOS_ELIMINAR", "Eliminar usuarios"],

      ["CONFIGURACION_GENERAL", "Configuración general"],
      ["PROMOCIONES_GESTIONAR", "Gestionar Días de Plaza y Promociones"],
    ];

    for (var permiso in permisos) {
      await db.insert("permisos", {
        "codigo": permiso[0],
        "descripcion": permiso[1],
      });
    }

    // =======================
    // ASIGNAR TODOS LOS PERMISOS AL ADMIN
    // =======================

    final permisosDB = await db.query("permisos");

    for (final permiso in permisosDB) {
      await db.insert("roles_permisos", {
        "rol_id": 1, // ADMIN
        "permiso_id": permiso["id"],
      });
    }

    // =======================
    // PERMISOS DEL CAJERO
    // =======================

    const permisosCajero = [
      "VENTAS_VER",
      "VENTAS_CREAR",
      "CAJA_VER",
      "CAJA_ABRIR",
      "CAJA_CERRAR",
    ];

    for (final codigo in permisosCajero) {
      final permiso = await db.query(
        "permisos",
        where: "codigo = ?",
        whereArgs: [codigo],
        limit: 1,
      );

      if (permiso.isNotEmpty) {
        await db.insert("roles_permisos", {
          "rol_id": 2, // CAJERO
          "permiso_id": permiso.first["id"],
        });
      }
    }

    await db.execute(
      "INSERT INTO configuracion (clave, valor) VALUES ('empresa_nombre', 'NovaPOS')",
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sync_pendientes (id INTEGER PRIMARY KEY AUTOINCREMENT, tipo TEXT NOT NULL, uuid TEXT NOT NULL, datos TEXT, estado INTEGER DEFAULT 0, creado_en TEXT)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sync_aplicados (uuid TEXT PRIMARY KEY, tipo TEXT NOT NULL, epoch INTEGER DEFAULT 0)',
    );
    await db.execute(
      "INSERT INTO configuracion (clave, valor) VALUES ('sync_activo', '1')",
    );
    await db.execute(
      "INSERT INTO configuracion (clave, valor) VALUES ('permitir_stock_negativo', '0')",
    );
    await db.execute(
      "INSERT INTO configuracion (clave, valor) VALUES ('promociones_activas', '1')",
    );
    await db.execute(
      "INSERT INTO configuracion (clave, valor) VALUES ('balanza_etiqueta_activa', '1')",
    );
    await db.execute(
      "INSERT INTO configuracion (clave, valor) VALUES ('balanza_etiqueta_prefijo_peso', '20')",
    );
    await db.execute(
      "INSERT INTO configuracion (clave, valor) VALUES ('balanza_etiqueta_prefijo_precio', '21')",
    );
    await db.execute(
      "INSERT INTO clientes (nombre, telefono, direccion) VALUES ('Cliente Casual', '000', 'Local')",
    );
    await _asegurarEsquemaFinanzas(db);
  }

  /// Obtiene todos los permisos de un rol
  Future<List<String>> getPermissionsByRole(String rol) async {
    final db = await database;

    final resultado = await db.rawQuery(
      '''
    SELECT p.codigo
    FROM permisos p
    INNER JOIN roles_permisos rp ON p.id = rp.permiso_id
    INNER JOIN roles r ON r.id = rp.rol_id
    WHERE r.nombre = ?
  ''',
      [rol],
    );

    return resultado.map((e) => e["codigo"].toString()).toList();
  }

  // --- GESTIÓN DINÁMICA DE CATEGORÍAS ---
  Future<List<String>> obtenerCategorias() async {
    final db = await database;
    List<String> lista = [
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
    final res = await db.query(
      'configuracion',
      where: "clave = 'categorias_extra'",
    );
    if (res.isNotEmpty) {
      String extra = res.first['valor'] as String;
      if (extra.isNotEmpty) lista.addAll(extra.split(','));
    }
    return lista.toSet().toList();
  }

  Future<void> guardarNuevaCategoria(String nuevaCat) async {
    final db = await database;
    final res = await db.query(
      'configuracion',
      where: "clave = 'categorias_extra'",
    );
    String actuales = res.isNotEmpty ? res.first['valor'] as String : "";
    actuales = actuales.isEmpty ? nuevaCat : "$actuales,$nuevaCat";
    await db.insert('configuracion', {
      'clave': 'categorias_extra',
      'valor': actuales,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- MÉTODOS DE PRODUCTOS ---
  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await database;
    final pu = row['uuid'] == null
        ? generateUuidV4()
        : row['uuid'].toString();
    row['uuid'] = pu;
    if (row['dispositivo_uuid'] == null) {
      row['dispositivo_uuid'] = await obtenerDispositivoUuid();
    }
    final id = await db.insert('productos', row);
    final actualizado = (await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    )).first;
    await encolarProductoCambio(actualizado, stockRecon: true);
    return id;
  }

  Future<List<Map<String, dynamic>>> _componentesComboPayload(
    DatabaseExecutor db,
    int comboId,
  ) async {
    final filas = await db.rawQuery('''
      SELECT cd.cantidad, p.uuid AS producto_uuid
      FROM combo_detalles cd
      INNER JOIN productos p ON p.id = cd.producto_id
      WHERE cd.combo_id = ?
    ''', [comboId]);
    return [
      for (final f in filas)
        if ((f['producto_uuid'] ?? '').toString().isNotEmpty)
          {
            'producto_uuid': f['producto_uuid'].toString(),
            'cantidad': (f['cantidad'] as num?)?.toDouble() ?? 1.0,
          }
    ];
  }

  /// Construye y encola la subida de un producto. Si [stockRecon] es true se
  /// incluye el stock actual como punto de partida en la nube.
  Future<void> encolarProductoCambio(
    Map<String, dynamic> p, {
    bool stockRecon = false,
    bool semilla = false,
  }) async {
    final disp = await obtenerDispositivoUuid();
    final esCombo = (p['es_combo'] as num?)?.toInt() == 1 ? 1 : 0;
    final payload = <String, dynamic>{
      'uuid': p['uuid'],
      'nombre': p['nombre'],
      'codigo_barras': p['codigo_barras'],
      'codigo_plu': p['codigo_plu'],
      'categoria': p['categoria'],
      'precio_costo': p['precio_costo'],
      'precio_venta': p['precio_venta'],
      'es_pesable': p['es_pesable'] ?? 0,
      'es_combo': esCombo,
      'esta_activo': p['esta_activo'] ?? 1,
      'imagen_path_local': p['imagen_path'],
      'actualizado_epoch': DateTime.now().millisecondsSinceEpoch,
      'dispositivo_uuid': disp,
    };
    if (esCombo == 1 && p['id'] != null) {
      final db = await database;
      payload['combo_componentes'] =
          await _componentesComboPayload(db, (p['id'] as num).toInt());
    }
    if (p['id'] != null) {
      final db = await database;
      final packs = await db.query('presentaciones',
          where: 'producto_id = ?', whereArgs: [p['id']]);
      payload['presentaciones'] = [
        for (final k in packs)
          {
            'nombre': k['nombre'],
            'cantidad': k['cantidad'],
            'precio': k['precio'],
            'codigo_barras': k['codigo_barras'],
          }
      ];
    }
    if (stockRecon) {
      payload['stock_recon'] = (p['stock_actual'] as num?)?.toDouble() ?? 0;
      // Hora del ajuste: la nube no acepta un ajuste más viejo o repetido.
      payload['stock_recon_epoch'] = DateTime.now().millisecondsSinceEpoch;
    }
    if (semilla) payload['semilla'] = true;
    await encolarPendiente('PRODUCTO', p['uuid'] as String, jsonEncode(payload));
  }

  /// Encola una operación de stock (incremento). Devuelve su uuid.
  Future<String> encolarStockOp(int productoId, double cantidad) async {
    await obtenerDispositivoUuid();
    final db = await database;
    final pu = await _uuidDeTabla(db, 'productos', productoId);
    if (pu == null) return '';
    final opUuid = generateUuidV4();
    final epoch = DateTime.now().millisecondsSinceEpoch;
    final payload = jsonEncode({
      'producto_uuid': pu,
      'cantidad': cantidad,
      'fecha_epoch': epoch,
      'dispositivo_uuid': await obtenerDispositivoUuid(),
    });
    await encolarPendiente('STOCK_OP', opUuid, payload);
    await guardarAplicado('STOCK_OP', opUuid, epoch);
    return opUuid;
  }

  /// Encola el cambio de stock de un ítem vendido/devuelto. En un combo el
  /// stock que cambia es el de sus componentes, no el del combo.
  Future<void> _encolarStockDeItem(
    int productoId,
    double cantidad, {
    double cantidadCombo = 0,
    bool? esCombo,
  }) async {
    final db = await database;
    bool combo = esCombo ?? false;
    if (esCombo == null) {
      final p = await db.query('productos',
          columns: ['es_combo'], where: 'id = ?', whereArgs: [productoId], limit: 1);
      combo = p.isNotEmpty && (p.first['es_combo'] as num?)?.toInt() == 1;
    }
    if (!combo) {
      await encolarStockOp(productoId, cantidad);
      return;
    }
    final signo = cantidad < 0 ? -1.0 : 1.0;
    final comps = await db.query('combo_detalles',
        where: 'combo_id = ?', whereArgs: [productoId]);
    for (final c in comps) {
      final cant = (c['cantidad'] as num).toDouble() * cantidadCombo * signo;
      if (cant != 0) {
        await encolarStockOp((c['producto_id'] as num).toInt(), cant);
      }
    }
  }

  /// Encola un movimiento de cartera (abono, fiado, devolución, anulación).
  /// [deudaCambio] es el incremento de deuda con signo (FIADO +, ABONO -).
  Future<String> _encolarCartera({
    required int clienteId,
    required String tipo,
    required double monto,
    required double deudaCambio,
    int ventaId = 0,
    required int usuarioId,
    required int fechaEpoch,
  }) async {
    await obtenerDispositivoUuid();
    final db = await database;
    final mu = generateUuidV4();
    final clienteUuid = await _uuidDeTabla(db, 'clientes', clienteId);
    final ventaUuid = await _uuidDeTabla(db, 'ventas', ventaId);
    final usuarioUid = await authUidPorUsuario(usuarioId);
    if (clienteUuid == null) return '';
    final payload = jsonEncode({
      'uuid': mu,
      'cliente_uuid': clienteUuid,
      'tipo': tipo,
      'monto': monto,
      'deuda_cambio': deudaCambio,
      'venta_uuid': ventaUuid,
      'fecha_epoch': fechaEpoch,
      'usuario_uid': usuarioUid,
      'dispositivo_uuid': await obtenerDispositivoUuid(),
    });
    await encolarPendiente('CARTERA', mu, payload);
    await guardarAplicado('CARTERA', mu, fechaEpoch);
    return mu;
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query(
      'productos',
      where: 'esta_activo = 1',
      orderBy: "nombre ASC",
    );
  }

  Future<void> desactivarProducto(int id) async {
    final db = await database;
    await db.update(
      'productos',
      {'esta_activo': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    final p = (await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    ));
    if (p.isNotEmpty) await encolarProductoCambio(p.first);
  }

  Future<List<Map<String, dynamic>>> obtenerTodoElInventario() async {
    final db = await database;
    return await db.query('productos', orderBy: "nombre ASC");
  }

  // --- PRESENTACIONES ---
  Future<int> agregarPresentacion(
    int prodId,
    String nombre,
    double cantidad,
    double precio,
  ) async {
    final db = await database;
    final id = await db.insert('presentaciones', {
      'producto_id': prodId,
      'nombre': nombre,
      'cantidad': cantidad,
      'precio': precio,
    });
    await _encolarProductoPorId(prodId);
    return id;
  }

  /// Vuelve a subir un producto (por ejemplo al cambiar sus paquetes).
  Future<void> _encolarProductoPorId(int prodId) async {
    final db = await database;
    final p = await db.query('productos', where: 'id = ?', whereArgs: [prodId], limit: 1);
    if (p.isNotEmpty) await encolarProductoCambio(p.first);
  }

  /// Reemplaza los paquetes locales de un producto con los recibidos de otra caja.
  Future<void> sincronizarPresentaciones(int prodId, List<dynamic> packs) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('presentaciones', where: 'producto_id = ?', whereArgs: [prodId]);
      for (final k in packs) {
        if (k is! Map) continue;
        await txn.insert('presentaciones', {
          'producto_id': prodId,
          'nombre': k['nombre'],
          'cantidad': (k['cantidad'] as num?)?.toDouble() ?? 1,
          'precio': (k['precio'] as num?)?.toDouble() ?? 0,
          'codigo_barras': k['codigo_barras'],
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> obtenerPresentaciones(int prodId) async {
    final db = await database;
    return await db.query(
      'presentaciones',
      where: 'producto_id = ?',
      whereArgs: [prodId],
      orderBy: 'cantidad ASC',
    );
  }

  Future<void> borrarPresentacion(int id) async {
    final db = await database;
    final k = await db.query('presentaciones', columns: ['producto_id'], where: 'id = ?', whereArgs: [id], limit: 1);
    await db.delete('presentaciones', where: 'id = ?', whereArgs: [id]);
    if (k.isNotEmpty) await _encolarProductoPorId((k.first['producto_id'] as num).toInt());
  }

  // --- CAJA Y VENTAS ---
  // --- CAJA: CÁLCULO DEL TURNO ---
  /// Filas de esta caja. Las que no tienen dispositivo son anteriores a la
  /// sincronización de la caja y siempre son locales.
  static const String _deEstaCaja =
      '(dispositivo_uuid IS NULL OR dispositivo_uuid = ?)';

  static const Map<String, double> _turnoVacio = {
    'base': 0,
    'ventas_efectivo': 0,
    'ventas_global': 0,
    'gastos': 0,
    'ingresos_extra': 0,
    'devoluciones': 0,
    'devoluciones_otros_turnos': 0,
    'total_en_caja': 0,
  };

  /// Reparte un pago mixto: lo digital se toma exacto (hasta el total) y el
  /// efectivo cubre el resto. Lo que el cliente entregó de más en efectivo
  /// fue cambio, no entra al cajón.
  static Map<String, double> partesMixto(double total, String? detalleJson) {
    double ef = 0, dig = 0;
    if (detalleJson != null && detalleJson.isNotEmpty) {
      try {
        final d = jsonDecode(detalleJson);
        if (d is Map) {
          ef = (d['efectivo'] as num?)?.toDouble() ?? 0;
          dig = (d['digital'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {}
    }
    if (total <= 0) return {'efectivo': 0, 'digital': 0};
    dig = dig.clamp(0, total).toDouble();
    ef = ef.clamp(0, total - dig).toDouble();
    return {'efectivo': ef, 'digital': dig};
  }

  /// Efectivo que le corresponde a una venta según su estado actual.
  static double efectivoDeVenta(Map<String, dynamic> v) {
    final total = (v['total'] as num?)?.toDouble() ?? 0;
    final metodo = (v['metodo_pago'] ?? '').toString();
    if (metodo == 'EFECTIVO') return total;
    if (metodo != 'MIXTO') return 0;
    return partesMixto(total, v['metodo_pago_detalle']?.toString())['efectivo']!;
  }

  /// Último APERTURA de esta caja si su turno sigue abierto.
  Future<Map<String, dynamic>?> _turnoAbierto(
    DatabaseExecutor ex,
    String disp,
  ) async {
    final ap = await ex.query(
      'caja_movimientos',
      where: "tipo = 'APERTURA' AND $_deEstaCaja",
      whereArgs: [disp],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (ap.isEmpty) return null;
    final ci = await ex.query(
      'caja_movimientos',
      where: "tipo = 'CIERRE' AND fecha > ? AND $_deEstaCaja",
      whereArgs: [ap.first['fecha'], disp],
      limit: 1,
    );
    return ci.isEmpty ? ap.first : null;
  }

  /// Cuadre del turno como flujo de efectivo del cajón:
  /// base + efectivo cobrado en ventas + ingresos − gastos/compras −
  /// efectivo devuelto (anulaciones y devoluciones), sea de la venta que sea.
  /// Así devolver una venta de otro turno o de otra caja nunca descuadra.
  Future<Map<String, double>> _calcularTurno(
    DatabaseExecutor ex,
    String fi,
    String disp,
  ) async {
    final ventas = await ex.query(
      'ventas',
      columns: [
        'id',
        'total',
        'metodo_pago',
        'metodo_pago_detalle',
        'anulada',
        'efectivo_cobrado',
      ],
      where: "fecha >= ? AND $_deEstaCaja",
      whereArgs: [fi, disp],
    );
    double cobrado = 0;
    final idsTurno = <int>{};
    for (final v in ventas) {
      idsTurno.add(v['id'] as int);
      final ec = (v['efectivo_cobrado'] as num?)?.toDouble();
      if (ec != null) {
        cobrado += ec;
      } else if ((v['anulada'] ?? 0) != 1) {
        cobrado += efectivoDeVenta(v);
      }
    }

    final movs = await ex.query(
      'caja_movimientos',
      where: "fecha >= ? AND $_deEstaCaja",
      whereArgs: [fi, disp],
    );
    double base = 0, ingresos = 0, gastos = 0, devTurno = 0, devOtros = 0;
    for (final m in movs) {
      final v = (m['monto'] as num?)?.toDouble() ?? 0;
      switch (m['tipo']) {
        case 'APERTURA':
          base += v;
          break;
        case 'INGRESO':
          ingresos += v;
          break;
        case 'GASTO':
        case 'COMPRA':
          gastos += v;
          break;
        case 'DEVOLUCION':
        case 'ANULACION':
          if ((m['resta_caja'] ?? 0) == 1) {
            final vid = (m['venta_id'] as num?)?.toInt();
            if (vid != null && idsTurno.contains(vid)) {
              devTurno += v;
            } else {
              devOtros += v;
            }
          }
          break;
      }
    }

    // Informativo: efectivo vendido por todas las cajas desde la apertura.
    final globales = await ex.query(
      'ventas',
      columns: ['total', 'metodo_pago', 'metodo_pago_detalle'],
      where: "fecha >= ? AND anulada = 0 AND metodo_pago IN ('EFECTIVO', 'MIXTO')",
      whereArgs: [fi],
    );
    double ventasGlobal = 0;
    for (final v in globales) {
      ventasGlobal += efectivoDeVenta(v);
    }

    // Lo devuelto de ventas de este mismo turno se muestra como menos venta;
    // lo de otros turnos o cajas, como una salida más.
    final ventasEfectivo = cobrado - devTurno;
    final salidas = gastos + devOtros;
    return {
      'base': base,
      'ventas_efectivo': ventasEfectivo,
      'ventas_global': ventasGlobal,
      'ingresos_extra': ingresos,
      'gastos': salidas,
      'devoluciones': devTurno + devOtros,
      'devoluciones_otros_turnos': devOtros,
      'total_en_caja': (base + ventasEfectivo + ingresos) - salidas,
    };
  }

  Future<Map<String, double>> obtenerResumenCaja() async {
    final db = await database;
    final disp = await obtenerDispositivoUuid();
    final turno = await _turnoAbierto(db, disp);
    if (turno == null) return Map<String, double>.from(_turnoVacio);
    return _calcularTurno(db, turno['fecha'] as String, disp);
  }

  Future<bool> verificarCajaAbiertaHoy() async {
    final db = await database;
    return (await _turnoAbierto(db, await obtenerDispositivoUuid())) != null;
  }

  Future<List<Map<String, dynamic>>> obtenerMovimientosTurnoActual() async {
    final db = await database;
    final disp = await obtenerDispositivoUuid();
    final turno = await _turnoAbierto(db, disp);
    if (turno == null) return [];
    return await db.query(
      'caja_movimientos',
      where: "fecha >= ? AND $_deEstaCaja",
      whereArgs: [turno['fecha'], disp],
      orderBy: "id DESC",
    );
  }

  /// Fila lista para insertar en caja_movimientos, ya marcada con esta caja.
  Map<String, dynamic> _filaMovCaja({
    required String tipo,
    required double monto,
    required String descripcion,
    required int usuarioId,
    required String disp,
    String? categoria,
    int? ventaId,
    bool restaCaja = false,
  }) {
    return {
      'fecha': DateTime.now().toIso8601String(),
      'tipo': tipo,
      'monto': monto,
      'descripcion': descripcion,
      'usuario_id': usuarioId,
      'uuid': generateUuidV4(),
      'dispositivo_uuid': disp,
      'categoria': categoria ?? CategoriasCaja.porDefecto(tipo),
      'venta_id': ventaId,
      'resta_caja': restaCaja ? 1 : 0,
    };
  }

  /// Sube a la nube un movimiento de caja (para los reportes del dueño en
  /// todas las cajas). No cambia el cuadre de las otras cajas.
  Future<void> _encolarMovCaja(Map<String, dynamic> fila) async {
    final db = await database;
    final fecha = fila['fecha']?.toString() ?? '';
    await encolarPendiente('CAJA_MOV', fila['uuid'] as String, jsonEncode({
      'uuid': fila['uuid'],
      'fecha': fecha,
      'fecha_epoch': DateTime.tryParse(fecha)?.millisecondsSinceEpoch ?? 0,
      'tipo': fila['tipo'],
      'monto': fila['monto'],
      'descripcion': fila['descripcion'],
      'categoria': fila['categoria'],
      'resta_caja': fila['resta_caja'] ?? 0,
      'venta_uuid': await _uuidDeTabla(db, 'ventas', fila['venta_id']),
      'usuario_uid': await authUidPorUsuario(fila['usuario_id']),
      'dispositivo_uuid': fila['dispositivo_uuid'],
    }));
  }

  Future<int> registrarMovimientoCaja(
    String tipo,
    double monto,
    String descripcion,
    int usuarioId, {
    String? categoria,
  }) async {
    final db = await database;
    if (tipo == 'APERTURA') {
      final abierta = await verificarCajaAbiertaHoy();
      if (abierta) throw Exception('La caja ya está abierta');
    }
    if (tipo == 'CIERRE') {
      final abierta = await verificarCajaAbiertaHoy();
      if (!abierta) throw Exception('No hay un turno abierto para cerrar');
    }
    if (tipo == 'INGRESO' || tipo == 'GASTO') {
      if (monto.isNaN || monto.isInfinite || monto <= 0) {
        throw Exception('El monto debe ser mayor a cero');
      }
      final abierta = await verificarCajaAbiertaHoy();
      if (!abierta) {
        throw Exception('Debe abrir la caja antes de registrar movimientos');
      }
    }
    if (tipo == 'GASTO') {
      final disponible = (await obtenerResumenCaja())['total_en_caja'] ?? 0;
      if (monto > disponible + 0.005) {
        throw Exception('Fondos insuficientes en caja');
      }
    }

    final fila = _filaMovCaja(
      tipo: tipo,
      monto: monto,
      descripcion: descripcion,
      usuarioId: usuarioId,
      disp: await obtenerDispositivoUuid(),
      categoria: categoria,
    );
    final id = await db.insert('caja_movimientos', fila);
    await _encolarMovCaja(fila);
    return id;
  }

  /// Ingresa efectivo a la caja (refuerzo) y paga un gasto en UNA sola
  /// transacción: o quedan registrados los dos movimientos o ninguno.
  ///
  /// Caso típico: llega un pedido de $300.000 y en caja solo hay $150.000.
  /// Se ingresa el faltante (más un colchón opcional) y se registra el pago,
  /// de modo que el efectivo restante queda visible y auditable.
  Future<Map<String, dynamic>> registrarIngresoYGasto({
    required double ingreso,
    required double gasto,
    required String descripcionIngreso,
    required String descripcionGasto,
    required int usuarioId,
    String? categoriaIngreso,
    String? categoriaGasto,
  }) async {
    if (ingreso.isNaN || ingreso.isInfinite || ingreso <= 0 ||
        gasto.isNaN || gasto.isInfinite || gasto <= 0) {
      throw Exception('El monto debe ser mayor a cero');
    }
    if (!await verificarCajaAbiertaHoy()) {
      throw Exception('Debe abrir la caja antes de registrar movimientos');
    }
    final disponible = (await obtenerResumenCaja())['total_en_caja'] ?? 0;
    if (disponible + ingreso + 0.005 < gasto) {
      throw Exception('Fondos insuficientes en caja');
    }
    final db = await database;
    final disp = await obtenerDispositivoUuid();
    final filaIngreso = _filaMovCaja(
      tipo: 'INGRESO',
      monto: ingreso,
      descripcion: descripcionIngreso,
      usuarioId: usuarioId,
      disp: disp,
      categoria: categoriaIngreso,
    );
    final filaGasto = _filaMovCaja(
      tipo: 'GASTO',
      monto: gasto,
      descripcion: descripcionGasto,
      usuarioId: usuarioId,
      disp: disp,
      categoria: categoriaGasto,
    );
    late int ingresoId;
    late int gastoId;
    await db.transaction((txn) async {
      ingresoId = await txn.insert('caja_movimientos', filaIngreso);
      gastoId = await txn.insert('caja_movimientos', filaGasto);
    });
    await _encolarMovCaja(filaIngreso);
    await _encolarMovCaja(filaGasto);
    return {
      'exito': true,
      'ingreso_id': ingresoId,
      'gasto_id': gastoId,
      'total_en_caja': disponible + ingreso - gasto,
    };
  }

  /// Crea o actualiza el usuario local ligado al UID de Firebase. Devuelve su id.
  Future<int> asegurarUsuarioLocal({
    required String uid,
    String nombre = '',
    String rol = 'CAJERO',
    bool activo = true,
  }) async {
    final db = await database;
    final res = await db.query(
      'usuarios',
      where: 'auth_uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (res.isNotEmpty) {
      final id = res.first['id'] as int;
      await db.update(
        'usuarios',
        {
          'nombre_completo': nombre,
          'rol': rol,
          'esta_activo': activo ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
    return await db.insert('usuarios', {
      'usuario': uid,
      'auth_uid': uid,
      'nombre_completo': nombre,
      'rol': rol,
      'esta_activo': activo ? 1 : 0,
      'password_hash': '',
    });
  }

  /// Cierra el turno en una sola transacción: inserta el movimiento CIERRE y
  /// registra el cierre formal con totales recalculados de la base de datos.
  Future<Map<String, dynamic>> cerrarTurno({
    double? base,
    required double realContado,
    double diferencia = 0,
    String estado = 'OK',
    String detalle = '',
    required String fechaInicio,
    required int usuarioId,
  }) async {
    if (realContado.isNaN || realContado.isInfinite || realContado < 0) {
      throw Exception('El efectivo contado no es válido');
    }
    final db = await database;
    final disp = await obtenerDispositivoUuid();
    late Map<String, dynamic> filaMov;
    final resultado = await db.transaction((txn) async {
      final turno = await _turnoAbierto(txn, disp);
      if (turno == null) {
        final hubo = await txn.query(
          'caja_movimientos',
          where: "tipo = 'APERTURA' AND $_deEstaCaja",
          whereArgs: [disp],
          limit: 1,
        );
        throw Exception(hubo.isEmpty
            ? 'No hay un turno abierto para cerrar'
            : 'El turno ya fue cerrado');
      }
      final fi = turno['fecha'] as String;
      final t = await _calcularTurno(txn, fi, disp);
      final totalSistema = t['total_en_caja']!;
      // La diferencia se calcula aquí (contado − esperado). Ya no se registra
      // un gasto o ingreso de "ajuste" antes de cerrar: eso dejaba la tirilla
      // Z con el faltante dentro de los gastos y el esperado igual a lo contado.
      final dif = _redondear(realContado - totalSistema);
      final estadoCalc = dif.abs() < 1 ? 'OK' : (dif > 0 ? 'SOBRA' : 'FALTA');

      // --- DESGLOSE EXACTO POR MÉTODO DE PAGO (todas las cajas) ---
      final ventasPeriodo = await txn.query(
        'ventas',
        columns: ['total', 'metodo_pago', 'metodo_pago_detalle'],
        where: 'fecha >= ? AND anulada = 0',
        whereArgs: [fi],
      );
      final metodos = <String, double>{};
      for (final v in ventasPeriodo) {
        final mp = (v['metodo_pago'] ?? '').toString();
        final total = (v['total'] as num?)?.toDouble() ?? 0;
        if (mp != 'MIXTO') {
          metodos[mp] = (metodos[mp] ?? 0) + total;
          continue;
        }
        final detalleMixto = v['metodo_pago_detalle']?.toString();
        final partes = partesMixto(total, detalleMixto);
        if (partes['efectivo']! > 0) {
          metodos['EFECTIVO'] = (metodos['EFECTIVO'] ?? 0) + partes['efectivo']!;
        }
        if (partes['digital']! > 0) {
          String nombreDig = 'DIGITAL';
          try {
            final d = jsonDecode(detalleMixto ?? '');
            if (d is Map && d['metodo_digital'] != null) {
              nombreDig = d['metodo_digital'].toString().toUpperCase();
            }
          } catch (_) {}
          metodos[nombreDig] = (metodos[nombreDig] ?? 0) + partes['digital']!;
        }
      }
      final desgloseJson = jsonEncode(metodos);
      // AJUSTE:NO = cierre sin movimiento de ajuste (el descuadre está aquí).
      final nuevoDetalle = detalle.isEmpty
          ? 'AJUSTE:NO|METODOS:$desgloseJson'
          : '$detalle|AJUSTE:NO|METODOS:$desgloseJson';

      filaMov = _filaMovCaja(
        tipo: 'CIERRE',
        monto: realContado,
        descripcion: detalle, // Para el movimiento dejamos el detalle normal
        usuarioId: usuarioId,
        disp: disp,
      );
      await txn.insert('caja_movimientos', filaMov);
      final fechaCierreNow = DateTime.now().toIso8601String();
      final idCierre = await txn.insert('cierres_caja', {
        'fecha': fechaCierreNow,
        'fecha_inicio': fi,
        'fecha_fin': fechaCierreNow,
        'base': t['base'],
        'ventas_turno': t['ventas_efectivo'],
        'ventas_turno_global': t['ventas_global'],
        'ingresos_turno': t['ingresos_extra'],
        'gastos_turno': t['gastos'],
        'total_sistema': totalSistema,
        'real_contado': realContado,
        'diferencia': dif,
        'estado': estadoCalc,
        'usuario_id': usuarioId,
        'detalle': nuevoDetalle,
        'uuid': generateUuidV4(),
        'dispositivo_uuid': disp,
        'caja_nombre': await nombreCaja(txn),
      });

      final cierreCreado = (await txn.query(
        'cierres_caja',
        where: 'id = ?',
        whereArgs: [idCierre],
        limit: 1,
      )).first;

      return {
        'exito': true,
        'cierre': cierreCreado,
        'total_sistema': totalSistema,
        'ventas_turno_global': t['ventas_global'],
      };
    });
    await _encolarMovCaja(filaMov);
    await _encolarCierre(resultado['cierre'] as Map<String, dynamic>);
    return resultado;
  }

  /// Sube un cierre a la nube para la auditoría de cierres en todas las cajas.
  Future<void> _encolarCierre(Map<String, dynamic> c) async {
    final uuid = (c['uuid'] ?? '').toString();
    if (uuid.isEmpty) return;
    final datos = Map<String, dynamic>.from(c)..remove('id');
    datos['usuario_uid'] = await authUidPorUsuario(c['usuario_id']);
    datos.remove('usuario_id');
    datos['fecha_epoch'] =
        DateTime.tryParse(c['fecha']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
    await encolarPendiente('CIERRE', uuid, jsonEncode(datos));
  }

  /// Nombre que el dueño le dio a esta caja (ej. "Caja principal").
  Future<String> nombreCaja([DatabaseExecutor? ex]) async {
    final e = ex ?? await database;
    final r = await e.query('configuracion', where: "clave = 'caja_nombre'", limit: 1);
    final v = r.isEmpty ? '' : (r.first['valor'] ?? '').toString().trim();
    return v.isEmpty ? 'Caja principal' : v;
  }

  Future<String?> obtenerFechaAperturaActual() async {
    final db = await database;
    final res = await db.query(
      'caja_movimientos',
      where: "tipo = 'APERTURA' AND $_deEstaCaja",
      whereArgs: [await obtenerDispositivoUuid()],
      orderBy: "id DESC",
      limit: 1,
    );
    return res.isEmpty ? null : res.first['fecha'] as String?;
  }

  Future<int> guardarCierreCaja(Map<String, dynamic> datos) async {
    final db = await database;
    return await db.insert('cierres_caja', datos);
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialCierres() async {
    final db = await database;
    return await db.rawQuery(
      'SELECT * FROM cierres_caja ORDER BY fecha DESC',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerCajeros() async {
    final db = await database;
    return await db.rawQuery(
      'SELECT id, nombre_completo as nombre, rol FROM usuarios WHERE esta_activo = 1 ORDER BY nombre_completo ASC',
    );
  }

  Future<Map<String, dynamic>> registrarVenta(
    double total,
    String metodo,
    List<Map<String, dynamic>> items, {
    int clienteId = 0,
    required int usuarioId,
    String? metodoPagoDetalle,
  }) async {
    final db = await database;
    final ventaUuid = generateUuidV4();
    final disp = await obtenerDispositivoUuid();
    final cajaAbierta = await verificarCajaAbiertaHoy();
    if (!cajaAbierta) {
      return {'exito': false, 'mensaje': 'Debe abrir la caja antes de vender'};
    }
    final cfg = await obtenerConfiguracion();
    final permitirNegativo = (cfg['permitir_stock_negativo'] ?? '0') == '1';
    if (metodo == 'CREDITO') {
      if (clienteId <= 0) {
        return {'exito': false, 'mensaje': 'Debe seleccionar un cliente válido'};
      }
    }
    // Pago mixto: se guarda lo que realmente queda en el cajón (el efectivo
    // entregado de más fue cambio) y se conserva lo recibido como referencia.
    if (metodo == 'MIXTO') {
      final partes = partesMixto(total, metodoPagoDetalle);
      Map<String, dynamic> original = {};
      try {
        final d = jsonDecode(metodoPagoDetalle ?? '');
        if (d is Map) original = Map<String, dynamic>.from(d);
      } catch (_) {}
      metodoPagoDetalle = jsonEncode({
        ...original,
        'efectivo': partes['efectivo'],
        'digital': partes['digital'],
        if (original['efectivo'] != null) 'efectivo_recibido': original['efectivo'],
      });
    }
    try {
      int ventaId = await db.transaction((txn) async {
        if (metodo == 'CREDITO' && clienteId > 0) {
          final cliente = await txn.query(
            'clientes',
            where: 'id = ?',
            whereArgs: [clienteId],
            limit: 1,
          );
          if (cliente.isEmpty) {
            throw Exception('CLIENTE_NO_EXISTE');
          }
          if ((cliente.first['esta_activo'] ?? 1) != 1) {
            throw Exception('CLIENTE_INACTIVO');
          }
          final deuda = (cliente.first['deuda_actual'] as num?)?.toDouble() ?? 0;
          final cupo = (cliente.first['cupo_credito'] as num?)?.toDouble() ?? 0;
          if (deuda + total > cupo) {
            throw Exception('EXCEDE_CUPO');
          }
        }

        // H-01 VALIDACIÓN DE SEGURIDAD: Recalcular el total desde los items para evitar
        // que una alteración manual en la UI o en la base de datos evada el cobro real.
        double totalCalculado = 0.0;
        for (var i in items) {
          totalCalculado += (i['subtotal'] as num).toDouble();
        }
        
        // Permitimos una tolerancia de $1 peso/centavo por redondeo
        if ((totalCalculado - total).abs() > 1.0) {
          throw Exception('ALERTA DE SEGURIDAD: El total recibido ($total) no coincide con la suma de los productos ($totalCalculado). Venta rechazada.');
        }

        int id = await txn.insert('ventas', {
          'fecha': DateTime.now().toIso8601String(),
          'total': totalCalculado, // Guardamos el calculado por seguridad
          'metodo_pago': metodo,
          'usuario_id': usuarioId,
          'cliente_id': clienteId,
          'anulada': 0,
          'uuid': ventaUuid,
          'dispositivo_uuid': disp,
          'metodo_pago_detalle': metodoPagoDetalle,
          'efectivo_cobrado': efectivoDeVenta({
            'total': totalCalculado,
            'metodo_pago': metodo,
            'metodo_pago_detalle': metodoPagoDetalle,
          }),
        });
        for (var i in items) {
          // Se consulta la base: el carrito del POS no trae la marca de combo.
          final prodInfo = await txn.query('productos',
              columns: ['es_combo'], where: 'id = ?', whereArgs: [i['id']], limit: 1);
          bool esCombo = (i['es_combo'] as num?)?.toInt() == 1 ||
              (prodInfo.isNotEmpty && (prodInfo.first['es_combo'] as num?)?.toInt() == 1);
          double factorPack = (i['contenido_pack'] as num?)?.toDouble() ?? 1.0;
          double cantidadReal = (i['cantidad'] as num).toDouble() * factorPack;
          double costoUnitario = (i['costo_unitario'] as num?)?.toDouble() ?? 0;

          if (esCombo) {
            final componentes = await txn.query('combo_detalles', where: 'combo_id = ?', whereArgs: [i['id']]);
            // Costo real del combo: la suma del costo de sus componentes.
            double costoCombo = 0;
            for (var comp in componentes) {
              final pc = await txn.query('productos',
                  columns: ['precio_costo'], where: 'id = ?', whereArgs: [comp['producto_id']], limit: 1);
              costoCombo += (comp['cantidad'] as num).toDouble() *
                  (pc.isEmpty ? 0 : ((pc.first['precio_costo'] as num?)?.toDouble() ?? 0));
            }
            if (costoCombo > 0) costoUnitario = costoCombo;
            for (var comp in componentes) {
              double cantComp = (comp['cantidad'] as num).toDouble() * (i['cantidad'] as num).toDouble();
              int compResStock;
              if (permitirNegativo) {
                compResStock = await txn.rawUpdate(
                  'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ?',
                  [cantComp, comp['producto_id']],
                );
              } else {
                compResStock = await txn.rawUpdate(
                  'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ? AND stock_actual >= (? - 0.001)',
                  [cantComp, comp['producto_id'], cantComp],
                );
              }
              if (compResStock == 0) {
                throw Exception('STOCK_INSUF|${comp['producto_id']}|Componente de Combo ${i['nombre']}');
              }
            }
          } else {
            int resStock;
            if (permitirNegativo) {
              resStock = await txn.rawUpdate(
                'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ?',
                [cantidadReal, i['id']],
              );
            } else {
              resStock = await txn.rawUpdate(
                'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ? AND stock_actual >= (? - 0.001)',
                [cantidadReal, i['id'], cantidadReal],
              );
            }
            if (resStock == 0) {
              throw Exception(
                'STOCK_INSUF|${i['id']}|${i['nombre']}',
              );
            }
          }

          await txn.insert('detalle_ventas', {
            'venta_id': id,
            'producto_id': i['id'],
            'nombre_producto': i['nombre'],
            'cantidad': i['cantidad'],
            'cantidad_descontada': cantidadReal,
            'precio_unitario': i['precio'],
            'costo_unitario': costoUnitario,
            'subtotal': i['subtotal'],
          });
        }
        if (metodo == 'CREDITO' && clienteId > 0) {
          await txn.rawUpdate(
            'UPDATE clientes SET deuda_actual = deuda_actual + ? WHERE id = ?',
            [total, clienteId],
          );
          await txn.insert('movimientos_cartera', {
            'cliente_id': clienteId,
            'tipo': 'FIADO',
            'venta_id': id,
            'fecha': DateTime.now().toIso8601String(),
            'monto': total,
            'usuario_id': usuarioId,
          });
        }
        return id;
      });
      final vRow = (await db.query(
        'ventas',
        where: 'id = ?',
        whereArgs: [ventaId],
        limit: 1,
      )).first;
      final detalle = await db.query(
        'detalle_ventas',
        where: 'venta_id = ?',
        whereArgs: [ventaId],
      );
      final clienteUuid = await _uuidDeTabla(db, 'clientes', clienteId);
      final usuarioUid = await authUidPorUsuario(usuarioId);
      final detallePayload = await _detalleVentaPayload(db, detalle);
      final fechaEpoch = DateTime.now().millisecondsSinceEpoch;
      await encolarPendiente('VENTA', ventaUuid, jsonEncode({
        'uuid': ventaUuid,
        'fecha': vRow['fecha'],
        'fecha_epoch': fechaEpoch,
        'total': total,
        'metodo_pago': metodo,
        'usuario_uid': usuarioUid,
        'cliente_uuid': clienteUuid,
        'anulada': 0,
        'dispositivo_uuid': disp,
        'metodo_pago_detalle': metodoPagoDetalle,
        'efectivo_cobrado': vRow['efectivo_cobrado'],
        'detalle': detallePayload,
      }));
      for (var i in items) {
        double factorPack = (i['contenido_pack'] as num?)?.toDouble() ?? 1.0;
        double cantidadReal = (i['cantidad'] as num).toDouble() * factorPack;
        await _encolarStockDeItem(
          (i['id'] as num).toInt(),
          -cantidadReal,
          cantidadCombo: (i['cantidad'] as num).toDouble(),
        );
      }
      if (metodo == 'CREDITO' && clienteId > 0) {
        await _encolarCartera(
          clienteId: clienteId,
          tipo: 'FIADO',
          monto: total,
          deudaCambio: total,
          ventaId: ventaId,
          usuarioId: usuarioId,
          fechaEpoch: fechaEpoch,
        );
      }
      return {'exito': true, 'venta_id': ventaId};
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('CLIENTE_NO_EXISTE')) {
        return {
          'exito': false,
          'mensaje': 'El cliente seleccionado ya no existe',
        };
      }
      if (msg.contains('CLIENTE_INACTIVO')) {
        return {
          'exito': false,
          'mensaje': 'El cliente está inactivo',
        };
      }
      if (msg.contains('EXCEDE_CUPO')) {
        return {
          'exito': false,
          'mensaje': 'Excede el cupo de crédito del cliente',
        };
      }
      if (msg.contains('STOCK_INSUF')) {
        final partes = msg.split('|');
        return {
          'exito': false,
          'mensaje':
              'Stock insuficiente para "${partes.length > 2 ? partes[2] : 'producto'}"',
        };
      }
      return {'exito': false, 'mensaje': 'Error al registrar la venta: $e'};
    }
  }

  static double _redondear(double v) => (v * 100).roundToDouble() / 100;

  /// $12.500 para mensajes al usuario.
  static String _pesos(double v) {
    final entero = v.round().abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) b.write('.');
      b.write(entero[i]);
    }
    return '${v < 0 ? '-' : ''}\$$b';
  }

  /// Valida que esta caja pueda entregar [efectivo] (turno abierto y fondos).
  /// Devuelve el mensaje de error o null si se puede.
  Future<String?> _validarSalidaEfectivo(double efectivo, String accion) async {
    if (efectivo <= 0) return null;
    final db = await database;
    final disp = await obtenerDispositivoUuid();
    final turno = await _turnoAbierto(db, disp);
    if (turno == null) {
      return 'Abra la caja para $accion: se deben entregar ${_pesos(efectivo)} en efectivo';
    }
    final disponible =
        (await _calcularTurno(db, turno['fecha'] as String, disp))['total_en_caja']!;
    if (efectivo > disponible + 0.005) {
      return 'Fondos insuficientes en caja para $accion: se necesitan ${_pesos(efectivo)} y hay ${_pesos(disponible)}';
    }
    return null;
  }

  /// Sube el estado actual completo de una venta (total, pago y detalle).
  /// Las demás cajas lo aplican tal cual, así una devolución hecha en una
  /// caja queda igual en todas.
  Future<void> _encolarVentaActualizada(int ventaId, int epoch) async {
    final db = await database;
    final v = await db.query('ventas', where: 'id = ?', whereArgs: [ventaId], limit: 1);
    if (v.isEmpty) return;
    final venta = v.first;
    final uuid = (venta['uuid'] ?? '').toString();
    if (uuid.isEmpty) return;
    final detalle = await db.query('detalle_ventas', where: 'venta_id = ?', whereArgs: [ventaId]);
    await encolarPendiente('VENTA_ACTUALIZA', uuid, jsonEncode({
      'uuid': uuid,
      'total': venta['total'],
      'metodo_pago_detalle': venta['metodo_pago_detalle'],
      'anulada': venta['anulada'] ?? 0,
      'actualizado_epoch': epoch,
      'detalle': await _detalleVentaPayload(db, detalle),
    }));
    // Que el eco de este mismo cambio desde la nube no se vuelva a aplicar.
    await guardarAplicado('VENTA', uuid, epoch);
  }

  /// Devuelve [cantidadADevolver] (en la unidad en que se vendió la línea:
  /// kilos, unidades o paquetes) de un artículo de una venta.
  ///
  /// El dinero se calcula aquí, en proporción al subtotal real de la línea
  /// (la devolución total devuelve exactamente lo cobrado). Según el pago:
  /// - Efectivo: sale del cajón del turno abierto de esta caja, sea la venta
  ///   de este turno, de uno anterior o de otra caja. Se valida que alcance.
  /// - Mixto: se devuelve primero el efectivo cobrado y luego lo digital.
  /// - Crédito: se descuenta de la deuda del cliente.
  /// - Digital (Nequi, tarjeta...): se devuelve por el mismo medio.
  /// [cant] y [dinero] se conservan por compatibilidad; el cálculo usa la
  /// línea guardada.
  Future<Map<String, dynamic>> devolverArticulo(
    int detId,
    int prodId,
    int ventId,
    double cant,
    double dinero, {
    double? cantidadADevolver,
    required int usuarioId,
    String motivo = '',
  }) async {
    final db = await database;
    final disp = await obtenerDispositivoUuid();
    final vi = await db.query('ventas', where: 'id = ?', whereArgs: [ventId], limit: 1);
    if (vi.isEmpty) {
      return {'exito': false, 'mensaje': 'Venta no encontrada'};
    }
    final venta = vi.first;
    if ((venta['anulada'] ?? 0) == 1) {
      return {'exito': false, 'mensaje': 'La venta está anulada'};
    }
    final det = await db.query(
      'detalle_ventas',
      where: 'id = ? AND venta_id = ?',
      whereArgs: [detId, ventId],
      limit: 1,
    );
    if (det.isEmpty) {
      return {'exito': false, 'mensaje': 'El artículo ya no está en la venta'};
    }
    final linea = det.first;
    final productoId = (linea['producto_id'] as num?)?.toInt() ?? prodId;
    final cantLinea = (linea['cantidad'] as num?)?.toDouble() ?? 0;
    final descLinea =
        (linea['cantidad_descontada'] as num?)?.toDouble() ?? cantLinea;
    final subLinea = (linea['subtotal'] as num?)?.toDouble() ?? 0;
    final cantDev = cantidadADevolver ?? cantLinea;
    if (cantDev.isNaN || cantDev <= 0 || cantDev > cantLinea + 0.0001) {
      return {'exito': false, 'mensaje': 'Cantidad o monto inválido'};
    }
    final esTotal = cantDev >= cantLinea - 0.0001;
    final proporcion = cantLinea > 0 ? (cantDev / cantLinea).clamp(0.0, 1.0) : 1.0;
    final totalVenta = (venta['total'] as num?)?.toDouble() ?? 0;
    final monto = (esTotal ? subLinea : _redondear(subLinea * proporcion))
        .clamp(0.0, totalVenta)
        .toDouble();
    // Unidades de inventario (un paquete de 6 devuelve 6 unidades).
    final baseDev = esTotal ? descLinea : descLinea * proporcion;

    final metodo = (venta['metodo_pago'] ?? '').toString();
    final cid = (venta['cliente_id'] as num?)?.toInt() ?? 0;
    String? detallePago = venta['metodo_pago_detalle']?.toString();
    double efectivoDev = 0;
    if (metodo == 'EFECTIVO') {
      efectivoDev = monto;
    } else if (metodo == 'MIXTO') {
      final partes = partesMixto(totalVenta, detallePago);
      efectivoDev = min(monto, partes['efectivo']!);
      final digitalDev = monto - efectivoDev;
      Map<String, dynamic> original = {};
      try {
        final d = jsonDecode(detallePago ?? '');
        if (d is Map) original = Map<String, dynamic>.from(d);
      } catch (_) {}
      detallePago = jsonEncode({
        ...original,
        'efectivo': _redondear(partes['efectivo']! - efectivoDev),
        'digital': _redondear(max(0.0, partes['digital']! - digitalDev)),
      });
    }

    final error = await _validarSalidaEfectivo(efectivoDev, 'hacer la devolución');
    if (error != null) return {'exito': false, 'mensaje': error};

    final nombre = (linea['nombre_producto'] ?? 'Producto').toString();
    final filaCaja = efectivoDev > 0
        ? _filaMovCaja(
            tipo: 'DEVOLUCION',
            monto: efectivoDev,
            descripcion: 'Devolución Venta #$ventId: $nombre',
            usuarioId: usuarioId,
            disp: disp,
            ventaId: ventId,
            restaCaja: true,
          )
        : null;
    final epoch = DateTime.now().millisecondsSinceEpoch;
    final devUuid = generateUuidV4();
    final filaDev = {
      'fecha': DateTime.now().toIso8601String(),
      'venta_id': ventId,
      'producto_id': productoId,
      'nombre_producto': nombre,
      'cantidad': cantDev,
      'monto': monto,
      'efectivo': efectivoDev,
      'metodo_pago': metodo,
      'motivo': motivo,
      'usuario_id': usuarioId,
      'dispositivo_uuid': disp,
      'uuid': devUuid,
    };
    bool esCombo = false;
    try {
      await db.transaction((txn) async {
        // La línea no cambió mientras se confirmaba (doble toque, otra caja).
        final actual = await txn.query('detalle_ventas', where: 'id = ?', whereArgs: [detId], limit: 1);
        if (actual.isEmpty ||
            (((actual.first['cantidad'] as num?)?.toDouble() ?? 0) - cantLinea).abs() > 0.0001) {
          throw Exception('LINEA_CAMBIO');
        }

        final prod = await txn.query('productos', columns: ['es_combo'], where: 'id = ?', whereArgs: [productoId]);
        esCombo = prod.isNotEmpty && (prod.first['es_combo'] as num?)?.toInt() == 1;
        if (esCombo) {
          final componentes = await txn.query('combo_detalles', where: 'combo_id = ?', whereArgs: [productoId]);
          for (var comp in componentes) {
            final cantComp = (comp['cantidad'] as num).toDouble() * cantDev;
            await txn.rawUpdate(
              'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
              [cantComp, comp['producto_id']],
            );
          }
        } else {
          await txn.rawUpdate(
            'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
            [baseDev, productoId],
          );
        }

        if (esTotal) {
          await txn.delete('detalle_ventas', where: 'id = ?', whereArgs: [detId]);
        } else {
          await txn.update(
            'detalle_ventas',
            {
              'cantidad': cantLinea - cantDev,
              'cantidad_descontada': max(0.0, descLinea - baseDev),
              'subtotal': max(0.0, subLinea - monto),
            },
            where: 'id = ?',
            whereArgs: [detId],
          );
        }
        final upd = await txn.rawUpdate(
          'UPDATE ventas SET total = MAX(total - ?, 0), metodo_pago_detalle = ?, actualizado_epoch = ? '
          'WHERE id = ? AND anulada = 0 AND total >= ? - 0.005',
          [monto, detallePago, epoch, ventId, monto],
        );
        if (upd == 0) throw Exception('MONTO_EXCEDE_TOTAL');

        if (metodo == 'CREDITO' && cid > 0) {
          await txn.rawUpdate(
            'UPDATE clientes SET deuda_actual = deuda_actual - ? WHERE id = ?',
            [monto, cid],
          );
          await txn.insert('movimientos_cartera', {
            'cliente_id': cid,
            'tipo': 'DEVOLUCION',
            'venta_id': ventId,
            'fecha': DateTime.now().toIso8601String(),
            'monto': -monto,
            'usuario_id': usuarioId,
          });
        }
        if (filaCaja != null) await txn.insert('caja_movimientos', filaCaja);
        await txn.insert('devoluciones', filaDev);
      });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('LINEA_CAMBIO')) {
        return {'exito': false, 'mensaje': 'El artículo cambió mientras se devolvía. Abra la venta de nuevo.'};
      }
      if (msg.contains('MONTO_EXCEDE_TOTAL')) {
        return {'exito': false, 'mensaje': 'El monto a devolver supera el total de la venta'};
      }
      return {'exito': false, 'mensaje': 'Error al devolver: $e'};
    }

    // Sincronización (después de la transacción).
    await _encolarStockDeItem(productoId, esCombo ? 1 : baseDev,
        cantidadCombo: cantDev, esCombo: esCombo);
    if (metodo == 'CREDITO' && cid > 0) {
      await _encolarCartera(
        clienteId: cid,
        tipo: 'DEVOLUCION',
        monto: -monto,
        deudaCambio: -monto,
        ventaId: ventId,
        usuarioId: usuarioId,
        fechaEpoch: epoch,
      );
    }
    if (filaCaja != null) await _encolarMovCaja(filaCaja);
    await _encolarVentaActualizada(ventId, epoch);
    await encolarPendiente('DEVOLUCION', devUuid, jsonEncode({
      ...filaDev,
      'venta_uuid': venta['uuid'],
      'producto_uuid': await _uuidDeTabla(db, 'productos', productoId),
      'usuario_uid': await authUidPorUsuario(usuarioId),
      'fecha_epoch': epoch,
    }..remove('venta_id')..remove('producto_id')..remove('usuario_id')));

    final mensaje = efectivoDev > 0
        ? 'Devolución registrada. Entregue ${_pesos(efectivoDev)} en efectivo'
        : (metodo == 'CREDITO'
            ? 'Devolución registrada. Se descontaron ${_pesos(monto)} de la deuda del cliente'
            : 'Devolución registrada por ${_pesos(monto)}');
    return {
      'exito': true,
      'mensaje': mensaje,
      'monto': monto,
      'efectivo': efectivoDev,
    };
  }

  /// Anula una venta completa: devuelve el inventario, ajusta la deuda si
  /// fue fiada y, si se cobró en efectivo, entrega ese efectivo desde el
  /// cajón del turno abierto de esta caja (validando que alcance).
  Future<Map<String, dynamic>> anularVenta(
    int vId, {
    required int usuarioId,
    String motivo = '',
  }) async {
    final db = await database;
    final disp = await obtenerDispositivoUuid();
    final vi = await db.query('ventas', where: 'id = ?', whereArgs: [vId], limit: 1);
    if (vi.isEmpty) {
      return {'exito': false, 'mensaje': 'Venta no encontrada'};
    }
    final venta = vi.first;
    if ((venta['anulada'] ?? 0) == 1) {
      return {'exito': false, 'mensaje': 'La venta ya está anulada'};
    }
    final efectivo = efectivoDeVenta(venta);
    final error = await _validarSalidaEfectivo(efectivo, 'anular la venta');
    if (error != null) return {'exito': false, 'mensaje': error};

    final filaCaja = efectivo > 0
        ? _filaMovCaja(
            tipo: 'ANULACION',
            monto: efectivo,
            descripcion: 'ANULACIÓN Venta #$vId',
            usuarioId: usuarioId,
            disp: disp,
            ventaId: vId,
            restaCaja: true,
          )
        : null;
    final ahora = DateTime.now();
    final ahoraEpoch = ahora.millisecondsSinceEpoch;
    try {
      await db.transaction((txn) async {
        final res = await txn.rawUpdate(
          'UPDATE ventas SET anulada = 1, anulada_en = ?, anulada_por = ?, motivo_anulacion = ?, actualizado_epoch = ? '
          'WHERE id = ? AND anulada = 0',
          [ahora.toIso8601String(), usuarioId, motivo, ahoraEpoch, vId],
        );
        if (res == 0) {
          throw Exception('VENTA_YA_ANULADA');
        }
        final items = await txn.query(
          'detalle_ventas',
          where: 'venta_id = ?',
          whereArgs: [vId],
        );
        for (var i in items) {
          double cantReal =
              (i['cantidad_descontada'] as num?)?.toDouble() ??
              (i['cantidad'] as num).toDouble();

          final prod = await txn.query('productos', columns: ['es_combo'], where: 'id = ?', whereArgs: [i['producto_id']]);
          bool esCombo = prod.isNotEmpty && (prod.first['es_combo'] as num?)?.toInt() == 1;

          if (esCombo) {
             final componentes = await txn.query('combo_detalles', where: 'combo_id = ?', whereArgs: [i['producto_id']]);
             for (var comp in componentes) {
                 double cantComp = (comp['cantidad'] as num).toDouble() * (i['cantidad'] as num).toDouble();
                 await txn.rawUpdate(
                   'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
                   [cantComp, comp['producto_id']],
                 );
             }
          } else {
             await txn.rawUpdate(
               'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
               [cantReal, i['producto_id']],
             );
          }
        }
        double tot = (venta['total'] as num).toDouble();
        String metodo = venta['metodo_pago'] as String;
        int cid = (venta['cliente_id'] as num?)?.toInt() ?? 0;
        if (metodo == 'CREDITO' && cid > 0) {
          await txn.rawUpdate(
            'UPDATE clientes SET deuda_actual = deuda_actual - ? WHERE id = ?',
            [tot, cid],
          );
          await txn.insert('movimientos_cartera', {
            'cliente_id': cid,
            'tipo': 'ANULACION',
            'venta_id': vId,
            'fecha': DateTime.now().toIso8601String(),
            'monto': -tot,
            'usuario_id': usuarioId,
          });
        }
        if (filaCaja != null) await txn.insert('caja_movimientos', filaCaja);
      });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('VENTA_YA_ANULADA')) {
        return {'exito': false, 'mensaje': 'La venta ya está anulada'};
      }
      return {'exito': false, 'mensaje': 'Error al anular la venta: $e'};
    }

    final ventaUuid = venta['uuid']?.toString() ?? '';
    final tot = (venta['total'] as num).toDouble();
    final metodo = (venta['metodo_pago'] as String?) ?? '';
    final cid = (venta['cliente_id'] as num?)?.toInt() ?? 0;
    if (ventaUuid.isNotEmpty) {
      await encolarPendiente('VENTA_ANULA', ventaUuid, jsonEncode({
        'uuid': ventaUuid,
        'actualizado_epoch': ahoraEpoch,
        'anulada_en': ahora.toIso8601String(),
        'anulada_por_uid': await authUidPorUsuario(usuarioId),
        'motivo_anulacion': motivo,
      }));
      await guardarAplicado('VENTA', ventaUuid, ahoraEpoch);
    }
    final items2 = await db.query(
      'detalle_ventas',
      where: 'venta_id = ?',
      whereArgs: [vId],
    );
    for (var i in items2) {
      double cantReal =
          (i['cantidad_descontada'] as num?)?.toDouble() ??
          (i['cantidad'] as num).toDouble();
      await _encolarStockDeItem(
        (i['producto_id'] as num).toInt(),
        cantReal,
        cantidadCombo: (i['cantidad'] as num).toDouble(),
      );
    }
    if (metodo == 'CREDITO' && cid > 0) {
      await _encolarCartera(
        clienteId: cid,
        tipo: 'ANULACION',
        monto: -tot,
        deudaCambio: -tot,
        ventaId: vId,
        usuarioId: usuarioId,
        fechaEpoch: ahoraEpoch,
      );
    }
    if (filaCaja != null) await _encolarMovCaja(filaCaja);
    return {
      'exito': true,
      'mensaje': efectivo > 0
          ? 'Venta anulada. Entregue ${_pesos(efectivo)} en efectivo'
          : 'Venta anulada correctamente',
      'efectivo': efectivo,
    };
  }

  // --- COMPRAS ---
  Future<Map<String, dynamic>> registrarCompra(
    List<Map<String, dynamic>> productos,
    double total,
    bool pagoConCaja,
    String proveedor, {
    required int usuarioId,
  }) async {
    final db = await database;
    Map<String, dynamic>? filaCaja;
    if (pagoConCaja) {
      final cajaAbierta = await verificarCajaAbiertaHoy();
      if (!cajaAbierta) {
        return {
          'exito': false,
          'mensaje':
              'Compra pagada con caja: debe abrir la caja antes de registrar',
        };
      }
      final disponible = (await obtenerResumenCaja())['total_en_caja'] ?? 0;
      if (total > disponible + 0.005) {
        return {
          'exito': false,
          'mensaje':
              'Fondos insuficientes en caja para pagar la compra: cuesta ${_pesos(total)} y hay ${_pesos(disponible)}. '
              'Ingrese dinero a la caja o regístrela como pagada por fuera de la caja.',
        };
      }
      filaCaja = _filaMovCaja(
        tipo: 'COMPRA',
        monto: total,
        descripcion: 'Compra Mercancía ($proveedor)',
        usuarioId: usuarioId,
        disp: await obtenerDispositivoUuid(),
        categoria: 'COMPRA',
      );
    }
    // Fusionar productos repetidos en la misma factura y validar datos
    final Map<int, Map<String, dynamic>> agrupados = {};
    for (var item in productos) {
      double cantidad = (item['cantidad'] as num).toDouble();
      if (cantidad <= 0 || (item['id'] as num?) == null) {
        return {'exito': false, 'mensaje': 'Cantidad inválida en la compra'};
      }
      final id = (item['id'] as num).toInt();
      final previo = agrupados[id];
      if (previo == null) {
        agrupados[id] = Map<String, dynamic>.from(item);
      } else {
        previo['cantidad'] = (previo['cantidad'] as num).toDouble() + cantidad;
        previo['subtotal_compra'] =
            (previo['subtotal_compra'] as num).toDouble() +
            (item['subtotal_compra'] as num).toDouble();
      }
    }

    final compraUuid = generateUuidV4();
    final disp = await obtenerDispositivoUuid();
    try {
      int compraId = 0;
      await db.transaction((txn) async {
        compraId = await txn.insert('compras', {
          'fecha': DateTime.now().toIso8601String(),
          'total': total,
          'metodo_pago': pagoConCaja ? 'CAJA' : 'CREDITO/BANCO',
          'proveedor': proveedor.isEmpty ? 'General' : proveedor,
          'uuid': compraUuid,
          'usuario_id': usuarioId,
        });
        for (var item in agrupados.values) {
          final id = (item['id'] as num).toInt();
          double cantidad = (item['cantidad'] as num).toDouble();
          double subtotalLinea =
              (item['subtotal_compra'] as num).toDouble();

          final prod = await txn.query(
            'productos',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (prod.isEmpty) continue;
          final p = prod.first;
          double stockAntiguoReal = (p['stock_actual'] as num).toDouble();
          double stockAntiguoParaCosto = stockAntiguoReal < 0 ? 0 : stockAntiguoReal;
          double costoAntiguo = (p['precio_costo'] as num?)?.toDouble() ?? 0;

          // Costo promedio ponderado en BD (Ignoramos negativos para no distorsionar el costo)
          final stockTotalParaCosto = stockAntiguoParaCosto + cantidad;
          final nuevoCosto = stockTotalParaCosto > 0
              ? ((stockAntiguoParaCosto * costoAntiguo) + subtotalLinea) / stockTotalParaCosto
              : (subtotalLinea / cantidad);

          // El stock físico sí debe compensar las ventas en negativo hechas previamente
          final nuevoStockFisico = stockAntiguoReal + cantidad;

          double? nuevoPrecioVenta = (item['nuevo_precio_venta'] as num?)?.toDouble();
          Map<String, dynamic> campos = {
            'stock_actual': nuevoStockFisico,
            'precio_costo': nuevoCosto,
          };
          if (nuevoPrecioVenta != null && nuevoPrecioVenta > 0) {
            campos['precio_venta'] = nuevoPrecioVenta;
          }
          await txn.update('productos', campos, where: 'id = ?', whereArgs: [id]);
          await txn.insert('detalle_compras', {
            'compra_id': compraId,
            'producto_id': id,
            'nombre_producto': item['nombre'],
            'cantidad': cantidad,
            'costo_unitario': nuevoCosto,
            'subtotal': subtotalLinea,
          });
        }
        if (filaCaja != null) {
          await txn.insert('caja_movimientos', filaCaja);
        }
      });
      if (filaCaja != null) await _encolarMovCaja(filaCaja);
      final fechaEpoch = DateTime.now().millisecondsSinceEpoch;
      final usuarioUid = await authUidPorUsuario(usuarioId);
      final detalleCompras = await db.query(
        'detalle_compras',
        where: 'compra_id = ?',
        whereArgs: [compraId],
      );
      final detallePayload = await _detalleCompraPayload(db, detalleCompras);
      await encolarPendiente('COMPRA', compraUuid, jsonEncode({
        'uuid': compraUuid,
        'fecha': DateTime.now().toIso8601String(),
        'fecha_epoch': fechaEpoch,
        'total': total,
        'metodo_pago': pagoConCaja ? 'CAJA' : 'CREDITO/BANCO',
        'proveedor': proveedor.isEmpty ? 'General' : proveedor,
        'usuario_uid': usuarioUid,
        'dispositivo_uuid': disp,
        'detalle': detallePayload,
      }));
      for (final item in agrupados.values) {
        final idProd = (item['id'] as num).toInt();
        final cantidad = (item['cantidad'] as num).toDouble();
        await encolarStockOp(idProd, cantidad);
        final pAct = (await db.query(
          'productos',
          where: 'id = ?',
          whereArgs: [idProd],
          limit: 1,
        ));
        if (pAct.isNotEmpty) await encolarProductoCambio(pAct.first);
      }
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error al registrar la compra: $e',
      };
    }
    return {'exito': true, 'mensaje': 'Compra registrada'};
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialCompras() async {
    final db = await database;
    return await db.query('compras', orderBy: "id DESC");
  }

  Future<List<Map<String, dynamic>>> obtenerDetalleCompra(int cid) async {
    final db = await database;
    return await db.query(
      'detalle_compras',
      where: 'compra_id = ?',
      whereArgs: [cid],
    );
  }

  // --- EXPORTAR ---
  Future<List<Map<String, dynamic>>> obtenerVentasDetalladasExportar() async {
    final db = await database;
    return await db.rawQuery(
      ''' SELECT v.id as venta_id, v.fecha, v.metodo_pago, v.anulada, d.nombre_producto, d.cantidad, d.precio_unitario, d.subtotal FROM ventas v INNER JOIN detalle_ventas d ON v.id = d.venta_id WHERE v.anulada = 0 ORDER BY v.fecha DESC ''',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerComprasDetalladasExportar() async {
    final db = await database;
    return await db.rawQuery(
      ''' SELECT c.id as compra_id, c.fecha, c.proveedor, d.nombre_producto, d.cantidad, d.costo_unitario, d.subtotal FROM compras c INNER JOIN detalle_compras d ON c.id = d.compra_id ORDER BY c.fecha DESC ''',
    );
  }

  // --- REPORTES ---
  Future<List<Map<String, dynamic>>> obtenerVentasSemana() async {
    final db = await database;
    return await db.rawQuery(
      "SELECT strftime('%Y-%m-%d', fecha) as dia, SUM(total) as total FROM ventas WHERE fecha >= date('now', '-6 days') AND anulada = 0 GROUP BY dia ORDER BY dia ASC",
    );
  }

  Future<List<Map<String, dynamic>>> obtenerTopProductos() async {
    final db = await database;
    return await db.rawQuery(
      "SELECT nombre_producto, SUM(cantidad) as cantidad_total FROM detalle_ventas d JOIN ventas v ON v.id = d.venta_id WHERE v.anulada = 0 GROUP BY producto_id ORDER BY cantidad_total DESC LIMIT 5",
    );
  }

  Future<List<Map<String, dynamic>>> obtenerMetodosPagoHoy() async {
    final db = await database;
    String hoy = DateTime.now().toIso8601String().substring(0, 10);
    return await db.rawQuery(
      "SELECT metodo_pago, SUM(total) as total FROM ventas WHERE fecha LIKE '$hoy%' AND anulada = 0 GROUP BY metodo_pago",
    );
  }

  Future<Map<String, String>> obtenerConfiguracion() async {
    final db = await database;
    final res = await db.query('configuracion');
    Map<String, String> c = {};
    for (var r in res) {
      c[r['clave'] as String] = r['valor'] as String;
    }
    return c;
  }

  Future<void> guardarConfiguracion(String k, String v) async {
    final db = await database;
    await db.insert('configuracion', {
      'clave': k,
      'valor': v,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // =================== SINCRONIZACIÓN ENTRE CAJAS ===================

  static String generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Identificador estable de esta instalación (caja física).
  Future<String> obtenerDispositivoUuid() async {
    final cfg = await obtenerConfiguracion();
    var d = cfg['dispositivo_uuid'];
    if (d == null || d.isEmpty) {
      d = generateUuidV4();
      await guardarConfiguracion('dispositivo_uuid', d);
    }
    return d;
  }

  Future<void> encolarPendiente(String tipo, String uuid, String datos) async {
    final db = await database;
    await db.insert('sync_pendientes', {
      'tipo': tipo,
      'uuid': uuid,
      'datos': datos,
      'estado': 0,
      'creado_en': DateTime.now().toIso8601String(),
    });
    try {
      onDatoEncolado?.call();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> obtenerPendientes() async {
    final db = await database;
    return await db.query(
      'sync_pendientes',
      where: 'estado = 0',
      orderBy: 'id ASC',
    );
  }

  Future<void> marcarPendienteSubido(int id) async {
    final db = await database;
    await db.update(
      'sync_pendientes',
      {'estado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> obtenerAplicado(
    String tipo,
    String uuid,
  ) async {
    final db = await database;
    final res = await db.query(
      'sync_aplicados',
      where: 'tipo = ? AND uuid = ?',
      whereArgs: [tipo, uuid],
      limit: 1,
    );
    return res.isEmpty ? null : res.first;
  }

  Future<void> guardarAplicado(String tipo, String uuid, int epoch) async {
    final db = await database;
    await db.insert(
      'sync_aplicados',
      {'tipo': tipo, 'uuid': uuid, 'epoch': epoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> idProductoPorUuid(String uuid) async {
    if (uuid.isEmpty) return null;
    final db = await database;
    final res = await db.query(
      'productos',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return res.isEmpty ? null : res.first['id'] as int?;
  }

  Future<int?> idClientePorUuid(String uuid) async {
    if (uuid.isEmpty) return null;
    final db = await database;
    final res = await db.query(
      'clientes',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return res.isEmpty ? null : res.first['id'] as int?;
  }

  Future<int?> idVentaPorUuid(String uuid) async {
    if (uuid.isEmpty) return null;
    final db = await database;
    final res = await db.query(
      'ventas',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return res.isEmpty ? null : res.first['id'] as int?;
  }

  Future<int?> idCompraPorUuid(String uuid) async {
    if (uuid.isEmpty) return null;
    final db = await database;
    final res = await db.query(
      'compras',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return res.isEmpty ? null : res.first['id'] as int?;
  }

  Future<int?> idUsuarioPorAuthUid(String uid) async {
    if (uid.isEmpty) return null;
    final db = await database;
    final res = await db.query(
      'usuarios',
      columns: ['id'],
      where: 'auth_uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return res.isEmpty ? null : res.first['id'] as int?;
  }

  Future<String?> authUidPorUsuario(dynamic usuarioId) async {
    final id = (usuarioId is num)
        ? usuarioId.toInt()
        : int.tryParse(usuarioId?.toString() ?? '');
    if (id == null || id <= 0) return null;
    final db = await database;
    final res = await db.query(
      'usuarios',
      columns: ['auth_uid'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    final u = res.first['auth_uid'];
    return (u == null || u.toString().isEmpty) ? null : u.toString();
  }

  /// Asigna UUIDs faltantes y prepara (una sola vez) la subida inicial de
  /// todos los datos del dispositivo actual.
  Future<void> prepararParaSincronizar(String dispositivoUuid) async {
    final db = await database;
    await _asegurarUuidTabla('productos');
    await _asegurarUuidTabla('clientes');
    await _asegurarUuidTabla('ventas');
    await _asegurarUuidTabla('compras');
    await _asegurarUuidTabla('caja_movimientos');
    await _asegurarUuidTabla('cierres_caja');
    await _asegurarUuidTabla('movimientos_cartera');

    await db.rawUpdate(
      "UPDATE ventas SET dispositivo_uuid = ? WHERE dispositivo_uuid IS NULL OR dispositivo_uuid = ''",
      [dispositivoUuid],
    );

    await _sembrarFinanzas(db, dispositivoUuid);

    final cfg = await db.query(
      'configuracion',
      where: "clave = 'sync_semilla'",
    );
    if (cfg.isNotEmpty && cfg.first['valor'] == dispositivoUuid) return;

    await _sembrarDatos(db, dispositivoUuid);
    await db.insert(
      'configuracion',
      {'clave': 'sync_semilla', 'valor': dispositivoUuid},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Una sola vez por caja: marca sus movimientos y cierres anteriores con
  /// el dispositivo y los sube, para que los reportes del dueño muestren el
  /// historial de todas las cajas.
  Future<void> _sembrarFinanzas(Database db, String dispositivoUuid) async {
    final cfg = await db.query('configuracion',
        where: "clave = 'sync_semilla_finanzas'", limit: 1);
    if (cfg.isNotEmpty && cfg.first['valor'] == dispositivoUuid) return;

    await db.rawUpdate(
      "UPDATE caja_movimientos SET dispositivo_uuid = ? WHERE dispositivo_uuid IS NULL OR dispositivo_uuid = ''",
      [dispositivoUuid],
    );
    await db.rawUpdate(
      "UPDATE cierres_caja SET dispositivo_uuid = ? WHERE dispositivo_uuid IS NULL OR dispositivo_uuid = ''",
      [dispositivoUuid],
    );
    final movs = await db.query('caja_movimientos',
        where: 'dispositivo_uuid = ?', whereArgs: [dispositivoUuid], orderBy: 'id ASC');
    for (final m in movs) {
      if ((m['uuid'] ?? '').toString().isEmpty) continue;
      await _encolarMovCaja(Map<String, dynamic>.from(m)
        ..['categoria'] = CategoriasCaja.de(m));
    }
    final cierres = await db.query('cierres_caja',
        where: 'dispositivo_uuid = ?', whereArgs: [dispositivoUuid], orderBy: 'id ASC');
    for (final c in cierres) {
      await _encolarCierre(c);
    }
    await db.insert(
      'configuracion',
      {'clave': 'sync_semilla_finanzas', 'valor': dispositivoUuid},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _asegurarUuidTabla(String tabla) async {
    final db = await database;
    final filas = await db.query(tabla);
    for (final f in filas) {
      final uuid = f['uuid'];
      if (uuid == null || uuid.toString().isEmpty) {
        await db.update(
          tabla,
          {'uuid': generateUuidV4()},
          where: 'id = ?',
          whereArgs: [f['id']],
        );
      }
    }
  }

  /// Subida inicial: encola toda la información del dispositivo en la nube.
  Future<void> _sembrarDatos(Database db, String dispositivoUuid) async {
    final productos = await db.query('productos');
    for (final p in productos) {
      final pu = p['uuid'] as String? ?? generateUuidV4();
      if (p['uuid'] == null) {
        await db.update(
          'productos',
          {'uuid': pu},
          where: 'id = ?',
          whereArgs: [p['id']],
        );
      }
      final esCombo = (p['es_combo'] as num?)?.toInt() == 1 ? 1 : 0;
      await encolarPendiente('PRODUCTO', pu, jsonEncode({
        'uuid': pu,
        'nombre': p['nombre'],
        'codigo_barras': p['codigo_barras'],
        'codigo_plu': p['codigo_plu'],
        'categoria': p['categoria'],
        'precio_costo': p['precio_costo'],
        'precio_venta': p['precio_venta'],
        'es_pesable': p['es_pesable'] ?? 0,
        'es_combo': esCombo,
        if (esCombo == 1 && p['id'] != null)
          'combo_componentes':
              await _componentesComboPayload(db, (p['id'] as num).toInt()),
        'esta_activo': p['esta_activo'] ?? 1,
        'imagen_path': p['imagen_path'],
        'stock_recon': (p['stock_actual'] as num?)?.toDouble() ?? 0,
        'stock_recon_epoch': DateTime.now().millisecondsSinceEpoch,
        'actualizado_epoch': DateTime.now().millisecondsSinceEpoch,
        'dispositivo_uuid': dispositivoUuid,
        'semilla': true,
      }));
    }

    final clientes = await db.query('clientes');
    for (final c in clientes) {
      final cu = c['uuid'] as String? ?? generateUuidV4();
      if (c['uuid'] == null) {
        await db.update(
          'clientes',
          {'uuid': cu},
          where: 'id = ?',
          whereArgs: [c['id']],
        );
      }
      await encolarPendiente('CLIENTE', cu, jsonEncode({
        'uuid': cu,
        'nombre': c['nombre'],
        'telefono': c['telefono'],
        'direccion': c['direccion'],
        'deuda_actual': c['deuda_actual'] ?? 0,
        'cupo_credito': c['cupo_credito'] ?? 0,
        'esta_activo': c['esta_activo'] ?? 1,
        'deuda_seed': true,
        'actualizado_epoch': DateTime.now().millisecondsSinceEpoch,
        'dispositivo_uuid': dispositivoUuid,
      }));
    }

    final ventas = await db.query('ventas', orderBy: 'id ASC');
    for (final v in ventas) {
      final vu = v['uuid'] as String? ?? generateUuidV4();
      if (v['uuid'] == null) {
        await db.update(
          'ventas',
          {'uuid': vu},
          where: 'id = ?',
          whereArgs: [v['id']],
        );
      }
      final detalle = await db.query(
        'detalle_ventas',
        where: 'venta_id = ?',
        whereArgs: [v['id']],
      );
      final clienteUuid = await _uuidDeTabla(db, 'clientes', v['cliente_id']);
      final usuarioUid = await authUidPorUsuario(v['usuario_id']);
      final detallePayload = await _detalleVentaPayload(db, detalle);
      await encolarPendiente('VENTA', vu, jsonEncode({
        'uuid': vu,
        'fecha': v['fecha'],
        'fecha_epoch':
            DateTime.tryParse(v['fecha']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0,
        'total': v['total'],
        'metodo_pago': v['metodo_pago'],
        'usuario_uid': usuarioUid,
        'cliente_uuid': clienteUuid,
        'anulada': v['anulada'] ?? 0,
        'dispositivo_uuid':
            (v['dispositivo_uuid'] as String? ?? dispositivoUuid),
        'metodo_pago_detalle': v['metodo_pago_detalle'],
        'efectivo_cobrado': v['efectivo_cobrado'],
        'detalle': detallePayload,
      }));
    }

    final compras = await db.query('compras', orderBy: 'id ASC');
    for (final c in compras) {
      final cu = c['uuid'] as String? ?? generateUuidV4();
      if (c['uuid'] == null) {
        await db.update(
          'compras',
          {'uuid': cu},
          where: 'id = ?',
          whereArgs: [c['id']],
        );
      }
      final detalle = await db.query(
        'detalle_compras',
        where: 'compra_id = ?',
        whereArgs: [c['id']],
      );
      final usuarioUid = await authUidPorUsuario(c['usuario_id']);
      final detallePayload = await _detalleCompraPayload(db, detalle);
      await encolarPendiente('COMPRA', cu, jsonEncode({
        'uuid': cu,
        'fecha': c['fecha'],
        'fecha_epoch':
            DateTime.tryParse(c['fecha']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0,
        'total': c['total'],
        'metodo_pago': c['metodo_pago'],
        'proveedor': c['proveedor'],
        'usuario_uid': usuarioUid,
        'dispositivo_uuid': dispositivoUuid,
        'detalle': detallePayload,
      }));
    }

    final cartera = await db.query('movimientos_cartera', orderBy: 'id ASC');
    for (final m in cartera) {
      final mu = m['uuid'] as String? ?? generateUuidV4();
      if (m['uuid'] == null) {
        await db.update(
          'movimientos_cartera',
          {'uuid': mu},
          where: 'id = ?',
          whereArgs: [m['id']],
        );
      }
      final monto = (m['monto'] as num?)?.toDouble() ?? 0;
      final tipo = (m['tipo'] as String? ?? '');
      final deudaCambio = tipo == 'ABONO' ? -monto : monto;
      final clienteUuid = await _uuidDeTabla(db, 'clientes', m['cliente_id']);
      final ventaUuid = await _uuidDeTabla(db, 'ventas', m['venta_id']);
      final usuarioUid = await authUidPorUsuario(m['usuario_id']);
      await encolarPendiente('CARTERA', mu, jsonEncode({
        'uuid': mu,
        'cliente_uuid': clienteUuid,
        'tipo': tipo,
        'monto': monto,
        'deuda_cambio': deudaCambio,
        'venta_uuid': ventaUuid,
        'fecha_epoch':
            DateTime.tryParse(m['fecha']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0,
        'usuario_uid': usuarioUid,
        'dispositivo_uuid': dispositivoUuid,
        'sin_deuda': true,
      }));
      await guardarAplicado('CARTERA', mu,
          DateTime.tryParse(m['fecha']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0);
    }
  }

  Future<String?> _uuidDeTabla(Database db, String tabla, dynamic id) async {
    if (id == null || (id is num && id == 0)) return null;
    final res = await db.query(
      tabla,
      columns: ['uuid'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res.isEmpty ? null : res.first['uuid'] as String?;
  }

  Future<List<Map<String, dynamic>>> _detalleVentaPayload(
    Database db,
    List<Map<String, dynamic>> detalle,
  ) async {
    final salida = <Map<String, dynamic>>[];
    for (final d in detalle) {
      final pu = await _uuidDeTabla(db, 'productos', d['producto_id']);
      salida.add({
        'producto_uuid': pu ?? '',
        'nombre_producto': d['nombre_producto'],
        'cantidad': d['cantidad'],
        'cantidad_descontada': d['cantidad_descontada'],
        'precio_unitario': d['precio_unitario'],
        'subtotal': d['subtotal'],
        'costo_unitario': d['costo_unitario'] ?? 0,
      });
    }
    return salida;
  }

  Future<List<Map<String, dynamic>>> _detalleCompraPayload(
    Database db,
    List<Map<String, dynamic>> detalle,
  ) async {
    final salida = <Map<String, dynamic>>[];
    for (final d in detalle) {
      final pu = await _uuidDeTabla(db, 'productos', d['producto_id']);
      salida.add({
        'producto_uuid': pu ?? '',
        'nombre_producto': d['nombre_producto'],
        'cantidad': d['cantidad'],
        'costo_unitario': d['costo_unitario'],
        'subtotal': d['subtotal'],
      });
    }
    return salida;
  }

  Future<List<Map<String, dynamic>>> obtenerClientes() async {
    final db = await database;
    return await db.query(
      'clientes',
      where: 'esta_activo = 1',
      orderBy: 'nombre ASC',
    );
  }

  Future<Map<String, dynamic>?> obtenerCliente(int id) async {
    final db = await database;
    final res = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return res.isEmpty ? null : res.first;
  }

  Future<int> crearCliente(Map<String, dynamic> r) async {
    final db = await database;
    r['uuid'] = r['uuid'] ?? generateUuidV4();
    final id = await db.insert('clientes', r);
    final c = (await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    )).first;
    await _encolarCliente(c);
    return id;
  }

  Future<void> _encolarCliente(Map<String, dynamic> c) async {
    await obtenerDispositivoUuid();
    final cu = c['uuid'] as String? ?? '';
    if (cu.isEmpty) return;
    final payload = jsonEncode({
      'uuid': cu,
      'nombre': c['nombre'],
      'telefono': c['telefono'],
      'direccion': c['direccion'],
      'deuda_actual': c['deuda_actual'] ?? 0,
      'cupo_credito': c['cupo_credito'] ?? 0,
      'esta_activo': c['esta_activo'] ?? 1,
      'actualizado_epoch': DateTime.now().millisecondsSinceEpoch,
      'dispositivo_uuid': await obtenerDispositivoUuid(),
    });
    await encolarPendiente('CLIENTE', cu, payload);
  }

  Future<bool> actualizarClienteCupo(int id, double cupo) async {
    final db = await database;
    if (cupo < 0) return false;
    final res = await db.update(
      'clientes',
      {'cupo_credito': cupo},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (res > 0) {
      final c = (await db.query(
        'clientes',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      )).first;
      await _encolarCliente(c);
    }
    return res > 0;
  }

  Future<List<Map<String, dynamic>>> obtenerMovimientosCartera(int clienteId) async {
    final db = await database;
    return await db.query(
      'movimientos_cartera',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      orderBy: 'fecha DESC',
      limit: 10,
    );
  }

  Future<Map<String, dynamic>> registrarAbonoCliente(
    int id, String nom, double m, {required int usuarioId}) async {
    final db = await database;
    if (m <= 0) {
      return {'exito': false, 'mensaje': 'El monto del abono debe ser mayor a cero'};
    }
    // El abono es efectivo que entra al cajón: con la caja cerrada no quedaba
    // en ningún turno y el cuadre del día siguiente no lo veía.
    if (!await verificarCajaAbiertaHoy()) {
      return {
        'exito': false,
        'mensaje': 'Abra la caja para recibir el abono: el efectivo debe quedar en el turno',
      };
    }
    final filaCaja = _filaMovCaja(
      tipo: 'INGRESO',
      monto: m,
      descripcion: 'Abono: $nom',
      usuarioId: usuarioId,
      disp: await obtenerDispositivoUuid(),
      categoria: 'ABONO_CLIENTE',
    );
    try {
      await db.transaction((txn) async {
        final res = await txn.rawUpdate(
          'UPDATE clientes SET deuda_actual = deuda_actual - ? WHERE id = ? AND deuda_actual >= ?',
          [m, id, m],
        );
        if (res == 0) {
          throw Exception('ABONO_EXCEDE_DEUDA');
        }
        await txn.insert('caja_movimientos', filaCaja);
        await txn.insert('movimientos_cartera', {
          'cliente_id': id,
          'tipo': 'ABONO',
          'venta_id': 0,
          'fecha': DateTime.now().toIso8601String(),
          'monto': m,
          'usuario_id': usuarioId,
        });
      });
      await _encolarMovCaja(filaCaja);
      await _encolarCartera(
        clienteId: id,
        tipo: 'ABONO',
        monto: m,
        deudaCambio: -m,
        ventaId: 0,
        usuarioId: usuarioId,
        fechaEpoch: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (e.toString().contains('ABONO_EXCEDE_DEUDA')) {
        return {
          'exito': false,
          'mensaje': 'El abono excede la deuda actual del cliente',
        };
      }
      return {'exito': false, 'mensaje': 'Error al registrar el abono: $e'};
    }
    return {'exito': true, 'mensaje': 'Abono registrado'};
  }

  Future<List<Map<String, dynamic>>> obtenerVentasPorRango(
    String fi,
    String ff,
  ) async {
    final db = await database;
    final finExcl = DateTime.parse(ff).add(const Duration(days: 1)).toIso8601String();
    return await db.query(
      'ventas',
      where: 'fecha >= ? AND fecha < ?',
      whereArgs: [fi, finExcl],
      orderBy: "fecha DESC",
    );
  }

  // --- INTELIGENCIA FINANCIERA ---
  Future<Map<String, double>> obtenerReporteFinanciero(
    String inicio,
    String fin, {
    int? usuarioId,
  }) async {
    final db = await database;
    final finExcl = DateTime.parse(fin).add(const Duration(days: 1)).toIso8601String();
    final argsVentas = <dynamic>[
      inicio,
      finExcl,
      if (usuarioId != null) usuarioId,
    ];
    final resVentas = await db.rawQuery(
      "SELECT SUM(total) as t FROM ventas WHERE fecha >= ? AND fecha < ? AND anulada = 0${usuarioId != null ? ' AND usuario_id = ?' : ''}",
      argsVentas,
    );
    double ventas = (resVentas.first['t'] as num?)?.toDouble() ?? 0;
    final argsCostos = <dynamic>[
      inicio,
      finExcl,
      if (usuarioId != null) usuarioId,
    ];
    final resCostos = await db.rawQuery(
      "SELECT SUM(dv.cantidad_descontada * dv.costo_unitario) as t FROM detalle_ventas dv JOIN ventas v ON v.id = dv.venta_id WHERE v.fecha >= ? AND v.fecha < ? AND v.anulada = 0${usuarioId != null ? ' AND v.usuario_id = ?' : ''}",
      argsCostos,
    );
    double costos = (resCostos.first['t'] as num?)?.toDouble() ?? 0;
    final argsGastos = <dynamic>[
      inicio,
      finExcl,
      if (usuarioId != null) usuarioId,
    ];
    final resGastos = await db.rawQuery(
      "SELECT SUM(monto) as t FROM caja_movimientos WHERE tipo = 'GASTO' AND fecha >= ? AND fecha < ?${usuarioId != null ? ' AND usuario_id = ?' : ''}",
      argsGastos,
    );
    double gastos = (resGastos.first['t'] as num?)?.toDouble() ?? 0;

    final argsMermas = <dynamic>[
      inicio,
      finExcl,
      if (usuarioId != null) usuarioId,
    ];
    final resMermas = await db.rawQuery(
      "SELECT SUM(total_perdida) as t FROM mermas WHERE fecha >= ? AND fecha < ?${usuarioId != null ? ' AND usuario_id = ?' : ''}",
      argsMermas,
    );
    double mermas = (resMermas.first['t'] as num?)?.toDouble() ?? 0;

    return {
      'ventas': ventas,
      'costos': costos,
      'utilidad_bruta': ventas - costos,
      'gastos': gastos,
      'mermas': mermas,
      'utilidad_neta': (ventas - costos) - gastos - mermas,
    };
  }

  Future<double> obtenerTotalCuentasPorCobrar() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT SUM(deuda_actual) as t FROM clientes WHERE esta_activo = 1",
    );
    return (res.first['t'] as num?)?.toDouble() ?? 0;
  }

  Future<double> obtenerValorInventario() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT SUM(stock_actual * precio_costo) as t FROM productos WHERE esta_activo = 1",
    );
    return (res.first['t'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Map<String, dynamic>>> obtenerTopProductosPorRango(
    String inicio,
    String fin,
  ) async {
    final db = await database;
    final finExcl = DateTime.parse(fin).add(const Duration(days: 1)).toIso8601String();
    return await db.rawQuery(
      ''' SELECT d.nombre_producto, SUM(d.cantidad) as cantidad_total, SUM(d.subtotal) as dinero_total FROM detalle_ventas d JOIN ventas v ON v.id = d.venta_id WHERE v.fecha >= ? AND v.fecha < ? AND v.anulada = 0 GROUP BY d.producto_id ORDER BY cantidad_total DESC LIMIT 10 ''',
      [inicio, finExcl],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerVentasPorCategoria(
    String inicio,
    String fin,
  ) async {
    final db = await database;
    final finExcl = DateTime.parse(fin).add(const Duration(days: 1)).toIso8601String();
    return await db.rawQuery(
      ''' SELECT p.categoria, SUM(d.subtotal) as total FROM detalle_ventas d JOIN ventas v ON v.id = d.venta_id JOIN productos p ON p.id = d.producto_id WHERE v.fecha >= ? AND v.fecha < ? AND v.anulada = 0 GROUP BY p.categoria ORDER BY total DESC ''',
      [inicio, finExcl],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerMetodosPagoPorRango(
    String inicio,
    String fin,
  ) async {
    final db = await database;
    final finExcl = DateTime.parse(fin).add(const Duration(days: 1)).toIso8601String();
    return await db.rawQuery(
      ''' SELECT metodo_pago, SUM(total) as total FROM ventas WHERE fecha >= ? AND fecha < ? AND anulada = 0 GROUP BY metodo_pago ''',
      [inicio, finExcl],
    );
  }

  // --- 🔥 IMPORTACIÓN MASIVA INTELIGENTE (FUSIÓN DE INVENTARIO) 🔥 ---
  Future<void> importarProductosMasivos(
    List<Map<String, dynamic>> nuevosProductos,
  ) async {
    final db = await database;
    final creados = <int>[];
    final actualizados = <int>{};
    final stockAgregado = <int, double>{};
    await db.transaction((txn) async {
      for (var p in nuevosProductos) {
        String nombre = (p['nombre'] ?? '').toString().trim();
        if (nombre.isEmpty) continue;
        double stockNuevo = (p['stock_actual'] as num?)?.toDouble() ?? 0;
        double costoNuevo = (p['precio_costo'] as num?)?.toDouble() ?? 0;
        double precioNuevo = (p['precio_venta'] as num?)?.toDouble() ?? 0;
        String barras = (p['codigo_barras'] ?? '').toString().trim();

        // Buscar si ya existe el producto por NOMBRE (ignora mayúsculas/minúsculas)
        final List<Map<String, dynamic>> existe = await txn.query(
          'productos',
          where: 'LOWER(nombre) = LOWER(?)',
          whereArgs: [nombre],
        );

        if (existe.isNotEmpty) {
          // 🔄 YA EXISTE: FUSIÓN DE DATOS SIN REACTIVAR PRODUCTOS ANULADOS
          var prodAntiguo = existe.first;
          int id = prodAntiguo['id'] as int;
          double stockAntiguo = (prodAntiguo['stock_actual'] as num).toDouble();
          if (stockAntiguo < 0) stockAntiguo = 0;
          double costoAntiguo = (prodAntiguo['precio_costo'] as num?)?.toDouble() ?? 0;

          double stockTotal = stockAntiguo + stockNuevo;
          double costoPromedio = stockTotal > 0
              ? ((stockAntiguo * costoAntiguo) + (stockNuevo * costoNuevo)) /
                    stockTotal
              : costoNuevo;

          Map<String, dynamic> campos = {
            'stock_actual': stockTotal,
            'precio_costo': costoPromedio,
          };
          if (precioNuevo > 0) campos['precio_venta'] = precioNuevo;
          if (barras.isNotEmpty) {
            final conflicto = await txn.query(
              'productos',
              where: 'codigo_barras = ? AND id != ?',
              whereArgs: [barras, id],
              limit: 1,
            );
            if (conflicto.isEmpty) campos['codigo_barras'] = barras;
          }
          if (p['categoria'] != null) campos['categoria'] = p['categoria'];
          await txn.update(
            'productos',
            campos,
            where: 'id = ?',
            whereArgs: [id],
          );
          actualizados.add(id);
          stockAgregado[id] = (stockAgregado[id] ?? 0) + stockNuevo;
        } else {
          // 🆕 NO EXISTE: CREAR NUEVO
          final id = await txn.insert('productos', {
            'nombre': nombre,
            'codigo_barras': barras,
            'codigo_plu': '',
            'categoria': p['categoria'] ?? 'Otros',
            'precio_costo': costoNuevo,
            'precio_venta': precioNuevo,
            'stock_actual': stockNuevo,
            'es_pesable': p['es_pesable'] ?? 0,
            'esta_activo': 1,
            'imagen_path': null,
            'uuid': generateUuidV4(),
          });
          creados.add(id);
        }
      }
    });
    for (final id in creados) {
      final p = (await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      ));
      if (p.isNotEmpty) await encolarProductoCambio(p.first, stockRecon: true);
    }
    for (final id in actualizados) {
      final cant = stockAgregado[id] ?? 0;
      if (cant > 0) await encolarStockOp(id, cant);
      final p = (await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      ));
      if (p.isNotEmpty) await encolarProductoCambio(p.first);
    }
  }

  // --- SEGURIDAD ---
  Future<void> resetFactory() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('detalle_ventas');
      await txn.delete('ventas');
      await txn.delete('detalle_compras');
      await txn.delete('compras');
      await txn.delete('caja_movimientos');
      await txn.delete('cierres_caja');
      await txn.delete('movimientos_cartera');
      await txn.delete('presentaciones');
      await txn.delete('productos');
      await txn.delete('clientes');
      await txn.delete('mermas');
      await txn.delete('devoluciones');
      await txn.delete('combo_detalles');
      await txn.delete('promociones');
      // Sin esto, lo que quedó pendiente por subir (y la marca de equipo ya
      // sincronizado) iría a parar al próximo negocio que use este equipo.
      await txn.delete('sync_pendientes');
      await txn.delete('sync_aplicados');
      await txn.delete('configuracion',
          where: "clave IN ('sync_semilla', 'sync_semilla_finanzas', 'sync_negocio_id', 'sync_usuario_uid') OR clave LIKE 'img_url_%' OR clave LIKE 'login_offline_%'");
      await txn.rawDelete(
        "DELETE FROM sqlite_sequence WHERE name IN ('ventas', 'productos', 'clientes', 'caja_movimientos', 'compras', 'detalle_compras', 'cierres_caja', 'movimientos_cartera', 'mermas', 'devoluciones', 'combo_detalles', 'promociones')",
      );
      await txn.insert('clientes', {
        'nombre': 'Cliente Casual',
        'telefono': '000',
        'direccion': 'Local',
      });
    });
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final usuarios = await db.query('usuarios');

      for (final usuario in usuarios) {
        final passwordActual = usuario['password_hash']?.toString() ?? '';

        // Evitar volver a convertir un hash existente
        if (passwordActual.length != 64) {
          final nuevoHash = PasswordService.hashPassword(passwordActual);

          await db.update(
            'usuarios',
            {'password_hash': nuevoHash},
            where: 'id = ?',
            whereArgs: [usuario['id']],
          );
        }
      }
    }
    if (oldVersion < 3) {
      final colsDet = await db.rawQuery('PRAGMA table_info(detalle_ventas)');
      final colsVen = await db.rawQuery('PRAGMA table_info(ventas)');
      if (!colsDet.any((c) => c['name'] == 'costo_unitario')) {
        await db.execute(
          'ALTER TABLE detalle_ventas ADD COLUMN costo_unitario REAL DEFAULT 0',
        );
      }
      if (!colsVen.any((c) => c['name'] == 'anulada')) {
        await db.execute(
          'ALTER TABLE ventas ADD COLUMN anulada INTEGER DEFAULT 0',
        );
      }
      await db.execute(
        'CREATE TABLE IF NOT EXISTS cierres_caja (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, fecha_inicio TEXT, fecha_fin TEXT, base REAL DEFAULT 0, ventas_turno REAL DEFAULT 0, ingresos_turno REAL DEFAULT 0, gastos_turno REAL DEFAULT 0, total_sistema REAL DEFAULT 0, real_contado REAL DEFAULT 0, diferencia REAL DEFAULT 0, estado TEXT, usuario_id INTEGER, detalle TEXT)',
      );
    }
    if (oldVersion < 4) {
      final colsUsu = await db.rawQuery('PRAGMA table_info(usuarios)');
      if (!colsUsu.any((c) => c['name'] == 'auth_uid')) {
        await db.execute('ALTER TABLE usuarios ADD COLUMN auth_uid TEXT');
      }
      await db.execute(
        'CREATE TABLE IF NOT EXISTS movimientos_cartera (id INTEGER PRIMARY KEY AUTOINCREMENT, cliente_id INTEGER, tipo TEXT, venta_id INTEGER, fecha TEXT, monto REAL, usuario_id INTEGER)',
      );
    }
    if (oldVersion < 5) {
      final colsProd = await db.rawQuery('PRAGMA table_info(productos)');
      final colsCli = await db.rawQuery('PRAGMA table_info(clientes)');
      final colsVen = await db.rawQuery('PRAGMA table_info(ventas)');
      final colsCom = await db.rawQuery('PRAGMA table_info(compras)');
      final colsCaja = await db.rawQuery('PRAGMA table_info(caja_movimientos)');
      final colsCie = await db.rawQuery('PRAGMA table_info(cierres_caja)');
      final colsCar = await db.rawQuery('PRAGMA table_info(movimientos_cartera)');

      if (!colsProd.any((c) => c['name'] == 'uuid')) {
        await db.execute('ALTER TABLE productos ADD COLUMN uuid TEXT');
      }
      if (!colsCli.any((c) => c['name'] == 'uuid')) {
        await db.execute('ALTER TABLE clientes ADD COLUMN uuid TEXT');
      }
      if (!colsVen.any((c) => c['name'] == 'uuid')) {
        await db.execute('ALTER TABLE ventas ADD COLUMN uuid TEXT');
      }
      if (!colsVen.any((c) => c['name'] == 'dispositivo_uuid')) {
        await db.execute('ALTER TABLE ventas ADD COLUMN dispositivo_uuid TEXT');
      }
      if (!colsCom.any((c) => c['name'] == 'uuid')) {
        await db.execute('ALTER TABLE compras ADD COLUMN uuid TEXT');
      }
      if (!colsCaja.any((c) => c['name'] == 'uuid')) {
        await db.execute('ALTER TABLE caja_movimientos ADD COLUMN uuid TEXT');
      }
      if (!colsCie.any((c) => c['name'] == 'uuid')) {
        await db.execute('ALTER TABLE cierres_caja ADD COLUMN uuid TEXT');
      }
      if (!colsCar.any((c) => c['name'] == 'uuid')) {
        await db.execute('ALTER TABLE movimientos_cartera ADD COLUMN uuid TEXT');
      }
      await db.execute(
        'CREATE TABLE IF NOT EXISTS sync_pendientes (id INTEGER PRIMARY KEY AUTOINCREMENT, tipo TEXT NOT NULL, uuid TEXT NOT NULL, datos TEXT, estado INTEGER DEFAULT 0, creado_en TEXT)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS sync_aplicados (uuid TEXT PRIMARY KEY, tipo TEXT NOT NULL, epoch INTEGER DEFAULT 0)',
      );
      final cfgSync = await db.query(
        'configuracion',
        where: "clave = 'sync_activo'",
        limit: 1,
      );
      if (cfgSync.isEmpty) {
        await db
            .insert('configuracion', {'clave': 'sync_activo', 'valor': '1'});
      }
    }
    if (oldVersion < 6) {
      final colsCie = await db.rawQuery('PRAGMA table_info(cierres_caja)');
      if (!colsCie.any((c) => c['name'] == 'ventas_turno_global')) {
        await db.execute(
          'ALTER TABLE cierres_caja ADD COLUMN ventas_turno_global REAL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 7) {
      // Corrige bases existentes que nunca recibieron las columnas o tablas
      // agregadas en versiones posteriores (misma clase de error: el esquema
      // nuevo está incompleto en bases viejas).
      final colsProd = await db.rawQuery('PRAGMA table_info(productos)');
      if (!colsProd.any((c) => c['name'] == 'uuid')) {
        await db.execute('ALTER TABLE productos ADD COLUMN uuid TEXT');
      }
      if (!colsProd.any((c) => c['name'] == 'dispositivo_uuid')) {
        await db.execute(
          'ALTER TABLE productos ADD COLUMN dispositivo_uuid TEXT',
        );
      }
      if (!colsProd.any((c) => c['name'] == 'imagen_path')) {
        await db.execute('ALTER TABLE productos ADD COLUMN imagen_path TEXT');
      }

      final colsCom = await db.rawQuery('PRAGMA table_info(compras)');
      if (!colsCom.any((c) => c['name'] == 'usuario_id')) {
        await db.execute('ALTER TABLE compras ADD COLUMN usuario_id INTEGER');
      }

      await db.execute(
        'CREATE TABLE IF NOT EXISTS presentaciones (id INTEGER PRIMARY KEY AUTOINCREMENT, producto_id INTEGER, nombre TEXT, cantidad REAL, precio REAL, codigo_barras TEXT)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS roles (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL UNIQUE, descripcion TEXT)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS permisos (id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT NOT NULL UNIQUE, descripcion TEXT)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS roles_permisos (id INTEGER PRIMARY KEY AUTOINCREMENT, rol_id INTEGER NOT NULL, permiso_id INTEGER NOT NULL)',
      );

      final rolesExistentes = await db.query('roles');
      if (rolesExistentes.isEmpty) {
        await db.insert('roles', {
          'nombre': 'ADMIN',
          'descripcion': 'Administrador del sistema',
        });
        await db.insert('roles', {'nombre': 'CAJERO', 'descripcion': 'Cajero'});
      }

      final permisosExistentes = await db.query('permisos');
      if (permisosExistentes.isEmpty) {
        const listaPermisos = [
          'VENTAS_VER', 'VENTAS_CREAR', 'VENTAS_EDITAR', 'VENTAS_ANULAR',
          'CAJA_VER', 'CAJA_ABRIR', 'CAJA_CERRAR', 'CAJA_MOVIMIENTOS',
          'INVENTARIO_VER', 'INVENTARIO_CREAR', 'INVENTARIO_EDITAR',
          'INVENTARIO_ELIMINAR', 'COMPRAS_VER', 'COMPRAS_CREAR',
          'COMPRAS_EDITAR', 'COMPRAS_ELIMINAR', 'REPORTES_VER',
          'USUARIOS_VER', 'USUARIOS_CREAR', 'USUARIOS_EDITAR',
          'USUARIOS_ELIMINAR', 'CONFIGURACION_GENERAL',
        ];
        for (final codigo in listaPermisos) {
          await db.insert('permisos', {
            'codigo': codigo,
            'descripcion': codigo,
          });
        }
      }

      final rp = await db.query('roles_permisos');
      if (rp.isEmpty && permisosExistentes.isNotEmpty) {
        final admin = await db.query('roles',
            where: 'nombre = ?', whereArgs: ['ADMIN'], limit: 1);
        final cajero = await db.query('roles',
            where: 'nombre = ?', whereArgs: ['CAJERO'], limit: 1);
        final permisosTodos = await db.query('permisos');
        if (admin.isNotEmpty) {
          for (final permiso in permisosTodos) {
            await db.insert('roles_permisos', {
              'rol_id': admin.first['id'],
              'permiso_id': permiso['id'],
            });
          }
        }
        if (cajero.isNotEmpty) {
          const cajeroCodes = {
            'VENTAS_VER', 'VENTAS_CREAR', 'CAJA_VER', 'CAJA_ABRIR', 'CAJA_CERRAR',
          };
          for (final permiso in permisosTodos) {
            if (cajeroCodes.contains(permiso['codigo'])) {
              await db.insert('roles_permisos', {
                'rol_id': cajero.first['id'],
                'permiso_id': permiso['id'],
              });
            }
          }
        }
      }
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mermas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha TEXT,
          producto_id INTEGER,
          nombre_producto TEXT,
          cantidad REAL,
          costo_unitario REAL,
          total_perdida REAL,
          motivo TEXT,
          usuario_id INTEGER,
          uuid TEXT
        )
      ''');
      final cfgStockNeg = await db.query(
        'configuracion',
        where: "clave = 'permitir_stock_negativo'",
        limit: 1,
      );
      if (cfgStockNeg.isEmpty) {
        await db.insert('configuracion', {
          'clave': 'permitir_stock_negativo',
          'valor': '1',
        });
      }
      final colsVen = await db.rawQuery('PRAGMA table_info(ventas)');
      if (!colsVen.any((c) => c['name'] == 'metodo_pago_detalle')) {
        await db.execute(
          'ALTER TABLE ventas ADD COLUMN metodo_pago_detalle TEXT',
        );
      }
    }
    if (oldVersion < 9) {
      final colsProd = await db.rawQuery('PRAGMA table_info(productos)');
      if (!colsProd.any((c) => c['name'] == 'es_favorito')) {
        await db.execute(
          'ALTER TABLE productos ADD COLUMN es_favorito INTEGER DEFAULT 0',
        );
      }
      // Marcar los 12 staples principales como favoritos si existen en la base
      await db.rawUpdate('''
        UPDATE productos SET es_favorito = 1
        WHERE codigo_plu IN ('101', '103', '110', '201', '202', '205', '206', '207', '208', '211', '212', '214')
      ''');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS promociones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL,
          dias_semana TEXT NOT NULL,
          tipo_alcance TEXT NOT NULL,
          alcance_valor TEXT,
          tipo_descuento TEXT NOT NULL,
          valor_descuento REAL NOT NULL,
          esta_activa INTEGER DEFAULT 1,
          forzar_hoy INTEGER DEFAULT 0,
          creado_en TEXT,
          uuid TEXT
        )
      ''');

      final configsDefecto = {
        'promociones_activas': '1',
        'balanza_etiqueta_activa': '1',
        'balanza_etiqueta_prefijo_peso': '20',
        'balanza_etiqueta_prefijo_precio': '21',
      };

      for (final entry in configsDefecto.entries) {
        final cfg = await db.query(
          'configuracion',
          where: 'clave = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        if (cfg.isEmpty) {
          await db.insert('configuracion', {
            'clave': entry.key,
            'valor': entry.value,
          });
        }
      }

      // Permiso PROMOCIONES_GESTIONAR para ADMIN
      final permPromo = await db.query(
        'permisos',
        where: 'codigo = ?',
        whereArgs: ['PROMOCIONES_GESTIONAR'],
        limit: 1,
      );
      int permPromoId;
      if (permPromo.isEmpty) {
        permPromoId = await db.insert('permisos', {
          'codigo': 'PROMOCIONES_GESTIONAR',
          'descripcion': 'Gestionar Días de Plaza y Promociones',
        });
      } else {
        permPromoId = permPromo.first['id'] as int;
      }
      final adminRole = await db.query(
        'roles',
        where: 'nombre = ?',
        whereArgs: ['ADMIN'],
        limit: 1,
      );
      if (adminRole.isNotEmpty) {
        final yaAsignado = await db.query(
          'roles_permisos',
          where: 'rol_id = ? AND permiso_id = ?',
          whereArgs: [adminRole.first['id'], permPromoId],
        );
        if (yaAsignado.isEmpty) {
          await db.insert('roles_permisos', {
            'rol_id': adminRole.first['id'],
            'permiso_id': permPromoId,
          });
        }
      }

      // Sembrar plantillas recomendadas para Fruvers si no hay ninguna
      final totalPromos = await db.query('promociones');
      if (totalPromos.isEmpty) {
        await db.insert('promociones', {
          'nombre': 'Martes Campesino',
          'dias_semana': '2',
          'tipo_alcance': 'CATEGORIA',
          'alcance_valor': 'Verduras',
          'tipo_descuento': 'PORCENTAJE',
          'valor_descuento': 10.0,
          'esta_activa': 0,
          'forzar_hoy': 0,
          'creado_en': DateTime.now().toIso8601String(),
          'uuid': generateUuidV4(),
        });
        await db.insert('promociones', {
          'nombre': 'Miércoles de Cosecha',
          'dias_semana': '3',
          'tipo_alcance': 'CATEGORIA',
          'alcance_valor': 'Frutas',
          'tipo_descuento': 'PORCENTAJE',
          'valor_descuento': 10.0,
          'esta_activa': 0,
          'forzar_hoy': 0,
          'creado_en': DateTime.now().toIso8601String(),
          'uuid': generateUuidV4(),
        });
      }
    }
    if (oldVersion < 11) {
      final colsProd = await db.rawQuery('PRAGMA table_info(productos)');
      if (!colsProd.any((c) => c['name'] == 'es_combo')) {
        await db.execute('ALTER TABLE productos ADD COLUMN es_combo INTEGER DEFAULT 0');
      }
      await db.execute(
        'CREATE TABLE IF NOT EXISTS combo_detalles (id INTEGER PRIMARY KEY AUTOINCREMENT, combo_id INTEGER, producto_id INTEGER, cantidad REAL, uuid TEXT)'
      );
    }
    if (oldVersion < 12) {
      await db.execute(
        "UPDATE configuracion SET valor = '0' WHERE clave = 'permitir_stock_negativo'",
      );
    }
    if (oldVersion < 13) {
      await _asegurarEsquemaFinanzas(db);
      await _rellenarEfectivoCobrado(db);
    }
    if (oldVersion < 14) {
      await _asegurarEsquemaFinanzas(db);
    }
  }

  // --- ESQUEMA FINANCIERO (v13) ---
  /// Columnas y tablas del módulo financiero. Es idempotente: se puede correr
  /// sobre una base nueva o sobre una que ya las tenga.
  Future<void> _asegurarEsquemaFinanzas(Database db) async {
    Future<void> columna(String tabla, String nombre, String tipo) async {
      final cols = await db.rawQuery('PRAGMA table_info($tabla)');
      if (!cols.any((c) => c['name'] == nombre)) {
        await db.execute('ALTER TABLE $tabla ADD COLUMN $nombre $tipo');
      }
    }

    // Movimientos de caja: categoría del gasto/ingreso, caja que lo hizo,
    // venta asociada (devoluciones/anulaciones) y si el dinero sale del cajón.
    await columna('caja_movimientos', 'categoria', 'TEXT');
    await columna('caja_movimientos', 'dispositivo_uuid', 'TEXT');
    await columna('caja_movimientos', 'venta_id', 'INTEGER');
    await columna('caja_movimientos', 'resta_caja', 'INTEGER DEFAULT 0');
    await columna('cierres_caja', 'dispositivo_uuid', 'TEXT');
    await columna('cierres_caja', 'caja_nombre', 'TEXT');
    // Ventas: efectivo que entró al cajón al cobrar (no cambia con
    // devoluciones) y auditoría de la anulación.
    await columna('ventas', 'efectivo_cobrado', 'REAL');
    await columna('ventas', 'anulada_en', 'TEXT');
    await columna('ventas', 'anulada_por', 'INTEGER');
    await columna('ventas', 'motivo_anulacion', 'TEXT');
    await columna('ventas', 'actualizado_epoch', 'INTEGER DEFAULT 0');
    await columna('mermas', 'producto_uuid', 'TEXT');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS devoluciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT,
        venta_id INTEGER,
        producto_id INTEGER,
        nombre_producto TEXT,
        cantidad REAL,
        monto REAL,
        efectivo REAL DEFAULT 0,
        metodo_pago TEXT,
        motivo TEXT,
        usuario_id INTEGER,
        dispositivo_uuid TEXT,
        uuid TEXT
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas(fecha)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_detalle_ventas_venta ON detalle_ventas(venta_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_caja_mov_fecha ON caja_movimientos(fecha)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_compras_fecha ON compras(fecha)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mermas_fecha ON mermas(fecha)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_devoluciones_fecha ON devoluciones(fecha)');
  }

  /// Ventas anteriores a v13: el efectivo cobrado se toma de su estado actual.
  /// Sus devoluciones/anulaciones viejas ya están descontadas en ese estado
  /// (y no restan del cajón), así que el cuadre del turno abierto no cambia.
  Future<void> _rellenarEfectivoCobrado(Database db) async {
    final filas = await db.query(
      'ventas',
      columns: ['id', 'total', 'metodo_pago', 'metodo_pago_detalle', 'anulada'],
      where: 'efectivo_cobrado IS NULL',
    );
    final batch = db.batch();
    for (final v in filas) {
      final ef = (v['anulada'] ?? 0) == 1 ? 0.0 : efectivoDeVenta(v);
      batch.update('ventas', {'efectivo_cobrado': ef},
          where: 'id = ?', whereArgs: [v['id']]);
    }
    await batch.commit(noResult: true);
  }

  // --- GESTIÓN DE PROMOCIONES Y DÍAS DE PLAZA ---
  Future<List<Map<String, dynamic>>> obtenerPromociones() async {
    final db = await database;
    return await db.query('promociones', orderBy: 'id DESC');
  }

  Future<int> guardarPromocion(Map<String, dynamic> promo) async {
    final db = await database;
    final Map<String, dynamic> datos = Map.from(promo);
    if (datos['uuid'] == null || datos['uuid'].toString().isEmpty) {
      datos['uuid'] = generateUuidV4();
    }
    if (datos['creado_en'] == null) {
      datos['creado_en'] = DateTime.now().toIso8601String();
    }
    
    // La tabla local no tiene estas columnas: solo viajan a la nube (antes
    // se intentaban guardar y crear o editar una promoción fallaba).
    final nube = {
      'actualizado_epoch': DateTime.now().millisecondsSinceEpoch,
      'dispositivo_uuid': await obtenerDispositivoUuid(),
    };
    datos.remove('actualizado_epoch');
    datos.remove('dispositivo_uuid');

    int idRes;
    if (datos.containsKey('id') && datos['id'] != null) {
      idRes = datos['id'] as int;
      await db.update('promociones', datos, where: 'id = ?', whereArgs: [idRes]);
    } else {
      idRes = await db.insert('promociones', datos);
    }
    
    // Sync to cloud
    datos['id'] = idRes;
    await encolarPendiente('PROMOCION', datos['uuid'], jsonEncode({...datos, ...nube}));
    return idRes;
  }

  Future<int> eliminarPromocion(int id) async {
    final db = await database;
    final pList = await db.query('promociones', columns: ['uuid'], where: 'id = ?', whereArgs: [id]);
    if (pList.isNotEmpty) {
      final uuid = pList.first['uuid'] as String;
      await encolarPendiente('PROMOCION_ELIMINAR', uuid, jsonEncode({'uuid': uuid, 'actualizado_epoch': DateTime.now().millisecondsSinceEpoch}));
    }
    return await db.delete('promociones', where: 'id = ?', whereArgs: [id]);
  }

  /// Sube la promoción con su versión, para que las otras cajas la apliquen.
  Future<void> _encolarPromocion(int id) async {
    final db = await database;
    final pList = await db.query('promociones', where: 'id = ?', whereArgs: [id]);
    if (pList.isEmpty) return;
    await encolarPendiente('PROMOCION', pList.first['uuid'] as String, jsonEncode({
      ...pList.first,
      'actualizado_epoch': DateTime.now().millisecondsSinceEpoch,
      'dispositivo_uuid': await obtenerDispositivoUuid(),
    }));
  }

  Future<void> togglePromocionActiva(int id, bool activa) async {
    final db = await database;
    await db.update(
      'promociones',
      {'esta_activa': activa ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _encolarPromocion(id);
  }

  Future<void> togglePromocionForzarHoy(int id, bool forzar) async {
    final db = await database;
    await db.update(
      'promociones',
      {'forzar_hoy': forzar ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _encolarPromocion(id);
  }

  // --- CONFIGURACIÓN DE STOCK FLEXIBLE ---
  Future<bool> permitirStockNegativo() async {
    final cfg = await obtenerConfiguracion();
    return (cfg['permitir_stock_negativo'] ?? '0') == '1';
  }

  Future<void> guardarPermitirStockNegativo(bool permitir) async {
    await guardarConfiguracion('permitir_stock_negativo', permitir ? '1' : '0');
  }

  // --- GESTIÓN DE MERMAS Y DESPERDICIOS ---
  Future<int> registrarMerma({
    required int productoId,
    required double cantidad,
    required String motivo,
    required int usuarioId,
  }) async {
    final db = await database;
    final prod = await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [productoId],
      limit: 1,
    );
    if (prod.isEmpty) throw Exception('Producto no encontrado');

    final p = prod.first;
    final nombre = p['nombre']?.toString() ?? '';
    final costoUnitario = (p['precio_costo'] as num?)?.toDouble() ?? 0.0;
    final totalPerdida = costoUnitario * cantidad;
    final mermaUuid = generateUuidV4();
    final fecha = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ?',
        [cantidad, productoId],
      );

      final datosMerma = {
        'fecha': fecha,
        'producto_id': productoId,
        'nombre_producto': nombre,
        'cantidad': cantidad,
        'costo_unitario': costoUnitario,
        'total_perdida': totalPerdida,
        'motivo': motivo,
        'usuario_id': usuarioId,
        'uuid': mermaUuid,
        'producto_uuid': p['uuid'],
      };

      final mermaId = await txn.insert('mermas', datosMerma);
      return {'id': mermaId, 'datos': datosMerma};
    }).then((res) async {
      await encolarStockOp(productoId, -cantidad);
      await encolarPendiente('MERMA', mermaUuid, jsonEncode(res['datos']));
      return res['id'] as int;
    });
  }

  Future<List<Map<String, dynamic>>> obtenerMermas({
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;
    if (fechaInicio != null && fechaFin != null) {
      whereClause = 'fecha >= ? AND fecha <= ?';
      whereArgs = [fechaInicio, fechaFin];
    }
    return await db.query(
      'mermas',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'fecha DESC',
    );
  }

  Future<double> obtenerTotalMermas(String fechaInicio, String fechaFin) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT SUM(total_perdida) as total FROM mermas WHERE fecha >= ? AND fecha <= ?',
      [fechaInicio, fechaFin],
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // --- COPIAS DE SEGURIDAD (BACKUP Y RESTAURACIÓN) ---
  Future<String> obtenerRutaBaseDatos() async {
    // La del archivo abierto (es la misma que calcula _initDB).
    final abierta = _database?.path;
    if (abierta != null && abierta.isNotEmpty && abierta != inMemoryDatabasePath) {
      return abierta;
    }
    Directory directory;
    try {
      directory = await getApplicationDocumentsDirectory();
    } catch (_) {
      directory = Directory.systemTemp;
    }
    final rutaCarpeta = Directory(join(directory.path, 'Sistema_Fruver_Data'));
    return join(rutaCarpeta.path, 'mifruver_sistema_v12_imagenes_ok.db');
  }

  /// Genera una copia completa y consistente de la base en [rutaDestino],
  /// aunque la app esté vendiendo en ese momento (VACUUM INTO hace una foto
  /// de la base sin depender de lo que esté a medio escribir). Antes se
  /// copiaba el archivo directamente y la copia podía quedar incompleta.
  Future<bool> exportarBackup(String rutaDestino) async {
    try {
      final db = await database;
      final destino = File(rutaDestino);
      if (await destino.exists()) await destino.delete();
      try {
        await db.execute('VACUUM INTO ?', [rutaDestino]);
      } catch (e) {
        debugPrint('VACUUM INTO no disponible, se copia el archivo: $e');
        try {
          await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
        } catch (_) {}
        final origen = File(await obtenerRutaBaseDatos());
        if (!await origen.exists()) return false;
        await origen.copy(rutaDestino);
      }
      final ok = await esCopiaValida(rutaDestino);
      if (!ok && await destino.exists()) await destino.delete();
      return ok;
    } catch (e) {
      debugPrint('Error exportando backup: $e');
      return false;
    }
  }

  /// Un archivo es una copia válida de NovaPOS si SQLite lo lee sin errores
  /// y tiene las tablas principales.
  Future<bool> esCopiaValida(String ruta) async {
    Database? copia;
    try {
      if (!await File(ruta).exists()) return false;
      copia = await databaseFactory.openDatabase(
        ruta,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final check = await copia.rawQuery('PRAGMA quick_check');
      if (check.isEmpty || check.first.values.first.toString() != 'ok') return false;
      final tablas = (await copia.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((t) => t['name'].toString())
          .toSet();
      return tablas.containsAll(['productos', 'ventas', 'caja_movimientos', 'configuracion']);
    } catch (e) {
      debugPrint('Copia no válida ($ruta): $e');
      return false;
    } finally {
      await copia?.close();
    }
  }

  /// Reemplaza la base con una copia. Primero verifica que sea una copia de
  /// NovaPOS y guarda la base actual al lado ("..._antes_de_restaurar"), para
  /// poder deshacer si se eligió la copia equivocada.
  Future<bool> restaurarBackup(String rutaArchivoBackup) async {
    try {
      if (!await esCopiaValida(rutaArchivoBackup)) return false;
      final destinoPath = await obtenerRutaBaseDatos();
      final marca = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
      await exportarBackup('${destinoPath}_antes_de_restaurar_$marca.db');

      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      final archivoBackup = File(rutaArchivoBackup);
      final archivoDestino = File(destinoPath);
      await archivoBackup.copy(archivoDestino.path);

      final walFile = File('$destinoPath-wal');
      if (await walFile.exists()) await walFile.delete();
      final shmFile = File('$destinoPath-shm');
      if (await shmFile.exists()) await shmFile.delete();

      // Se reabre el mismo archivo, con la misma migración de la app (una
      // copia de una versión anterior se actualiza sola).
      _database = await databaseFactory.openDatabase(
        destinoPath,
        options: OpenDatabaseOptions(version: 14, onCreate: _createDB, onUpgrade: _upgradeDB),
      );
      return true;
    } catch (e) {
      debugPrint('Error restaurando backup: $e');
      return false;
    }
  }


  /// Carga el catálogo maestro de ~120 productos de Fruver y Minimarket
  /// con códigos PLU, costos, precios y categorías colombianas.
  /// Si [forzar] es true, inserta las referencias que falten aunque ya haya productos.
  Future<int> precargarCatalogoMaestro({bool forzar = false}) async {
    final db = await database;
    if (!forzar) {
      final res = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM productos WHERE esta_activo = 1',
      );
      final cuenta = (res.isNotEmpty ? res.first['total'] as num? : 0)?.toInt() ?? 0;
      if (cuenta > 0) return 0;
    }

    int insertados = 0;
    for (final p in catalogoMaestroProductos) {
      final existente = await db.query(
        'productos',
        where: 'codigo_plu = ? OR nombre = ?',
        whereArgs: [p.codigoPlu, p.nombre],
        limit: 1,
      );
      if (existente.isEmpty) {
        final map = p.toMap();
        final id = await db.insert('productos', map);
        map['id'] = id;
        try {
          await encolarProductoCambio(map, stockRecon: true, semilla: true);
        } catch (_) {}
        insertados++;
      }
    }
    return insertados;
  }

  // --- GESTIÓN DE PRODUCTOS FAVORITOS (TOP 12) ---
  Future<void> toggleFavorito(int productoId, bool esFavorito) async {
    final db = await database;
    try {
      final colsProd = await db.rawQuery('PRAGMA table_info(productos)');
      if (!colsProd.any((c) => c['name'] == 'es_favorito')) {
        await db.execute('ALTER TABLE productos ADD COLUMN es_favorito INTEGER DEFAULT 0');
      }
    } catch (_) {}

    await db.update(
      'productos',
      {'es_favorito': esFavorito ? 1 : 0},
      where: 'id = ?',
      whereArgs: [productoId],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerProductosFavoritos({int limit = 12}) async {
    final db = await database;
    try {
      final colsProd = await db.rawQuery('PRAGMA table_info(productos)');
      if (!colsProd.any((c) => c['name'] == 'es_favorito')) {
        await db.execute('ALTER TABLE productos ADD COLUMN es_favorito INTEGER DEFAULT 0');
      }
    } catch (_) {}

    // 1. Obtener los productos marcados explícitamente como favoritos
    final marcados = await db.query(
      'productos',
      where: 'esta_activo = 1 AND es_favorito = 1',
      limit: limit,
    );

    if (marcados.length >= limit) {
      return List<Map<String, dynamic>>.from(marcados);
    }

    final idsYa = marcados.map((m) => m['id']).toSet();
    final List<Map<String, dynamic>> resultado = List.from(marcados);

    // 2. Complementar con los productos más vendidos en el historial
    try {
      final resVendidos = await db.rawQuery('''
        SELECT p.*, SUM(dv.cantidad) as total_vendido
        FROM detalle_ventas dv
        INNER JOIN productos p ON p.id = dv.producto_id
        WHERE p.esta_activo = 1
        GROUP BY p.id
        ORDER BY total_vendido DESC
        LIMIT ?
      ''', [limit * 2]);

      for (final p in resVendidos) {
        if (!idsYa.contains(p['id']) && resultado.length < limit) {
          idsYa.add(p['id']);
          resultado.add(p);
        }
      }
    } catch (_) {}

    // 3. Si aún no llega al límite, complementar con los staples de Fruver por código PLU
    if (resultado.length < limit) {
      final faltan = limit - resultado.length;
      try {
        final resStaples = await db.rawQuery('''
          SELECT * FROM productos
          WHERE esta_activo = 1
          ORDER BY
            CASE
              WHEN codigo_plu IN ('101', '103', '110', '201', '202', '205', '206', '207', '208', '211', '212', '214') THEN 0
              WHEN es_pesable = 1 THEN 1
              ELSE 2
            END,
            nombre ASC
          LIMIT ?
        ''', [faltan * 3]);

        for (final p in resStaples) {
          if (!idsYa.contains(p['id']) && resultado.length < limit) {
            idsYa.add(p['id']);
            resultado.add(p);
          }
        }
      } catch (_) {}
    }

    return resultado;
  }

  // --- GESTIÓN DE COMBOS ---
  Future<int> crearCombo(Map<String, dynamic> datosCombo, List<Map<String, dynamic>> componentes) async {
    final db = await database;
    final disp = await obtenerDispositivoUuid();
    int comboId = 0;

    await db.transaction((txn) async {
      datosCombo['uuid'] = datosCombo['uuid'] ?? generateUuidV4();
      datosCombo['dispositivo_uuid'] = datosCombo['dispositivo_uuid'] ?? disp;
      datosCombo['es_combo'] = 1;

      comboId = await txn.insert('productos', datosCombo);

      for (var comp in componentes) {
        await txn.insert('combo_detalles', {
          'combo_id': comboId,
          'producto_id': comp['producto_id'],
          'cantidad': comp['cantidad'],
          'uuid': generateUuidV4(),
        });
      }
    });

    final actualizado = await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [comboId],
      limit: 1,
    );
    if (actualizado.isNotEmpty) {
      await encolarProductoCambio(actualizado.first, stockRecon: true);
    }
    return comboId;
  }

  /// Actualiza los componentes locales de un combo recibido de otra caja.
  Future<void> sincronizarComponentesCombo(
    int comboId,
    List<dynamic> componentes,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('combo_detalles', where: 'combo_id = ?', whereArgs: [comboId]);
      for (final item in componentes) {
        if (item is! Map) continue;
        final prodUuid = (item['producto_uuid'] ?? '').toString();
        if (prodUuid.isEmpty) continue;
        final prod = await txn.query(
          'productos',
          columns: ['id'],
          where: 'uuid = ?',
          whereArgs: [prodUuid],
          limit: 1,
        );
        if (prod.isEmpty) continue;
        await txn.insert('combo_detalles', {
          'combo_id': comboId,
          'producto_id': prod.first['id'],
          'cantidad': (item['cantidad'] as num?)?.toDouble() ?? 1.0,
          'uuid': generateUuidV4(),
        });
      }
    });
  }

  Future<void> eliminarCombo(int comboId) async {
    final db = await database;
    await db.delete('combo_detalles', where: 'combo_id = ?', whereArgs: [comboId]);
    await desactivarProducto(comboId);
  }

  Future<List<Map<String, dynamic>>> obtenerDetallesCombo(int comboId) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT cd.*, p.nombre, p.precio_venta, p.imagen_path
      FROM combo_detalles cd
      INNER JOIN productos p ON p.id = cd.producto_id
      WHERE cd.combo_id = ?
    ''', [comboId]);
    return res;
  }
}

