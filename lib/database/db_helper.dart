import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../services/password_service.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

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
    final directory = await getApplicationDocumentsDirectory();
    final rutaCarpeta = Directory(join(directory.path, 'Sistema_Fruver_Data'));
    if (!await rutaCarpeta.exists()) {
      await rutaCarpeta.create(recursive: true);
    }

    final path = join(rutaCarpeta.path, 'mifruver_sistema_v12_imagenes_ok.db');

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE usuarios (id INTEGER PRIMARY KEY AUTOINCREMENT, usuario TEXT UNIQUE, password_hash TEXT, rol TEXT, nombre_completo TEXT, esta_activo INTEGER DEFAULT 1, auth_uid TEXT UNIQUE)',
    );
    await db.execute(
      'CREATE TABLE productos (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT, codigo_barras TEXT, codigo_plu TEXT, categoria TEXT, precio_costo REAL, precio_venta REAL, stock_actual REAL, es_pesable INTEGER DEFAULT 0, esta_activo INTEGER DEFAULT 1, imagen_path TEXT, uuid TEXT, dispositivo_uuid TEXT)',
    );
    await db.execute(
      'CREATE TABLE configuracion (clave TEXT PRIMARY KEY, valor TEXT)',
    );
    await db.execute(
      'CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT, telefono TEXT, direccion TEXT, deuda_actual REAL DEFAULT 0, cupo_credito REAL DEFAULT 0, esta_activo INTEGER DEFAULT 1, uuid TEXT)',
    );
    await db.execute(
      'CREATE TABLE ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, total REAL, metodo_pago TEXT, usuario_id INTEGER, cliente_id INTEGER DEFAULT 0, anulada INTEGER DEFAULT 0, uuid TEXT, dispositivo_uuid TEXT)',
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
      "INSERT INTO clientes (nombre, telefono, direccion) VALUES ('Cliente Casual', '000', 'Local')",
    );
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

  /// Construye y encola la subida de un producto. Si [stockRecon] es true se
  /// incluye el stock actual como punto de partida en la nube.
  Future<void> encolarProductoCambio(
    Map<String, dynamic> p, {
    bool stockRecon = false,
  }) async {
    final disp = await obtenerDispositivoUuid();
    final payload = <String, dynamic>{
      'uuid': p['uuid'],
      'nombre': p['nombre'],
      'codigo_barras': p['codigo_barras'],
      'codigo_plu': p['codigo_plu'],
      'categoria': p['categoria'],
      'precio_costo': p['precio_costo'],
      'precio_venta': p['precio_venta'],
      'es_pesable': p['es_pesable'] ?? 0,
      'esta_activo': p['esta_activo'] ?? 1,
      'imagen_path_local': p['imagen_path'],
      'actualizado_epoch': DateTime.now().millisecondsSinceEpoch,
      'dispositivo_uuid': disp,
    };
    if (stockRecon) {
      payload['stock_recon'] =
          ((p['stock_actual'] as num?)?.toDouble() ?? 0).toInt();
    }
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
    return await db.insert('presentaciones', {
      'producto_id': prodId,
      'nombre': nombre,
      'cantidad': cantidad,
      'precio': precio,
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
    await db.delete('presentaciones', where: 'id = ?', whereArgs: [id]);
  }

  // --- CAJA Y VENTAS ---
  Future<Map<String, double>> obtenerResumenCaja() async {
    final db = await database;
    final lastApertura = await db.query(
      'caja_movimientos',
      where: "tipo = 'APERTURA'",
      orderBy: "id DESC",
      limit: 1,
    );
    if (lastApertura.isEmpty) {
      return {
        'base': 0,
        'ventas_efectivo': 0,
        'ventas_global': 0,
        'gastos': 0,
        'ingresos_extra': 0,
        'total_en_caja': 0,
      };
    }
    String fechaInicio = lastApertura.first['fecha'] as String;
    final lastCierre = await db.query(
      'caja_movimientos',
      where: "tipo = 'CIERRE' AND fecha > ?",
      whereArgs: [fechaInicio],
      limit: 1,
    );
    if (lastCierre.isNotEmpty) {
      return {
        'base': 0,
        'ventas_efectivo': 0,
        'ventas_global': 0,
        'gastos': 0,
        'ingresos_extra': 0,
        'total_en_caja': 0,
      };
    }

    final ventasRes = await db.rawQuery(
      "SELECT SUM(total) as total FROM ventas WHERE fecha >= ? AND metodo_pago = 'EFECTIVO' AND anulada = 0 AND (dispositivo_uuid IS NULL OR dispositivo_uuid = ?)",
      [fechaInicio, await obtenerDispositivoUuid()],
    );
    double ventas = (ventasRes.first['total'] as num?)?.toDouble() ?? 0;
    final ventasGlobalRes = await db.rawQuery(
      "SELECT SUM(total) as total FROM ventas WHERE fecha >= ? AND metodo_pago = 'EFECTIVO' AND anulada = 0",
      [fechaInicio],
    );
    double ventasGlobal =
        (ventasGlobalRes.first['total'] as num?)?.toDouble() ?? 0;
    final cajaRes = await db.query(
      'caja_movimientos',
      where: "fecha >= ?",
      whereArgs: [fechaInicio],
    );
    double base = 0, gastos = 0, ingresos = 0;
    for (var m in cajaRes) {
      double v = (m['monto'] as num).toDouble();
      if (m['tipo'] == 'APERTURA') base += v;
      if (m['tipo'] == 'INGRESO') ingresos += v;
      if (m['tipo'] == 'GASTO' || m['tipo'] == 'COMPRA') gastos += v;
    }
    return {
      'base': base,
      'ventas_efectivo': ventas,
      'ventas_global': ventasGlobal,
      'ingresos_extra': ingresos,
      'gastos': gastos,
      'total_en_caja': (base + ventas + ingresos) - gastos,
    };
  }

  Future<bool> verificarCajaAbiertaHoy() async {
    final db = await database;
    final lastApertura = await db.query(
      'caja_movimientos',
      where: "tipo = 'APERTURA'",
      orderBy: "id DESC",
      limit: 1,
    );
    if (lastApertura.isEmpty) return false;
    final fi = lastApertura.first['fecha'] as String;
    final lc = await db.query(
      'caja_movimientos',
      where: "tipo = 'CIERRE' AND fecha > ?",
      whereArgs: [fi],
      limit: 1,
    );
    return lc.isEmpty;
  }

  Future<List<Map<String, dynamic>>> obtenerMovimientosTurnoActual() async {
    final db = await database;
    final lastApertura = await db.query(
      'caja_movimientos',
      where: "tipo = 'APERTURA'",
      orderBy: "id DESC",
      limit: 1,
    );
    if (lastApertura.isEmpty) return [];
    String fi = lastApertura.first['fecha'] as String;
    final lc = await db.query(
      'caja_movimientos',
      where: "tipo = 'CIERRE' AND fecha > ?",
      whereArgs: [fi],
      limit: 1,
    );
    if (lc.isNotEmpty) return [];
    return await db.query(
      'caja_movimientos',
      where: "fecha >= ?",
      whereArgs: [fi],
      orderBy: "id DESC",
    );
  }

  Future<int> registrarMovimientoCaja(
    String tipo,
    double monto,
    String descripcion,
    int usuarioId,
  ) async {
    final db = await database;
    if (tipo == 'APERTURA') {
      final abierta = await verificarCajaAbiertaHoy();
      if (abierta) throw Exception('La caja ya está abierta');
    }
    if (tipo == 'CIERRE') {
      final abierta = await verificarCajaAbiertaHoy();
      if (!abierta) throw Exception('No hay un turno abierto para cerrar');
    }

    return await db.insert('caja_movimientos', {
      'fecha': DateTime.now().toIso8601String(),
      'tipo': tipo,
      'monto': monto,
      'descripcion': descripcion,
      'usuario_id': usuarioId,
    });
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
    final db = await database;
    final disp = await obtenerDispositivoUuid();
    return await db.transaction((txn) async {
      final lastApertura = await txn.query(
        'caja_movimientos',
        where: "tipo = 'APERTURA'",
        orderBy: "id DESC",
        limit: 1,
      );
      if (lastApertura.isEmpty) {
        throw Exception('No hay un turno abierto para cerrar');
      }
      final fi = lastApertura.first['fecha'] as String;
      final yaCerrada = await txn.query(
        'caja_movimientos',
        where: "tipo = 'CIERRE' AND fecha > ?",
        whereArgs: [fi],
        limit: 1,
      );
      if (yaCerrada.isNotEmpty) {
        throw Exception('El turno ya fue cerrado');
      }

      final ventasRes = await txn.rawQuery(
        "SELECT SUM(total) as total FROM ventas WHERE fecha >= ? AND metodo_pago = 'EFECTIVO' AND anulada = 0 AND (dispositivo_uuid IS NULL OR dispositivo_uuid = ?)",
        [fi, disp],
      );
      final ventas = (ventasRes.first['total'] as num?)?.toDouble() ?? 0;

      final ventasGlobalRes = await txn.rawQuery(
        "SELECT SUM(total) as total FROM ventas WHERE fecha >= ? AND metodo_pago = 'EFECTIVO' AND anulada = 0",
        [fi],
      );
      final ventasGlobal =
          (ventasGlobalRes.first['total'] as num?)?.toDouble() ?? 0;

      final cajaRes = await txn.query(
        'caja_movimientos',
        where: 'fecha >= ?',
        whereArgs: [fi],
      );
      double baseTurno = 0, gastos = 0, ingresos = 0;
      for (var m in cajaRes) {
        double v = (m['monto'] as num).toDouble();
        if (m['tipo'] == 'APERTURA') baseTurno += v;
        if (m['tipo'] == 'INGRESO') ingresos += v;
        if (m['tipo'] == 'GASTO' || m['tipo'] == 'COMPRA') gastos += v;
      }
      final totalSistema = (baseTurno + ventas + ingresos) - gastos;

      await txn.insert('caja_movimientos', {
        'fecha': DateTime.now().toIso8601String(),
        'tipo': 'CIERRE',
        'monto': realContado,
        'descripcion': detalle,
        'usuario_id': usuarioId,
      });
      await txn.insert('cierres_caja', {
        'fecha': DateTime.now().toIso8601String(),
        'fecha_inicio': fi,
        'fecha_fin': DateTime.now().toIso8601String(),
        'base': baseTurno,
        'ventas_turno': ventas,
        'ventas_turno_global': ventasGlobal,
        'ingresos_turno': ingresos,
        'gastos_turno': gastos,
        'total_sistema': totalSistema,
        'real_contado': realContado,
        'diferencia': diferencia,
        'estado': estado,
        'usuario_id': usuarioId,
        'detalle': detalle,
      });
      return {
        'exito': true,
        'total_sistema': totalSistema,
        'ventas_turno_global': ventasGlobal,
      };
    });
  }

  Future<String?> obtenerFechaAperturaActual() async {
    final db = await database;
    final res = await db.query(
      'caja_movimientos',
      where: "tipo = 'APERTURA'",
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
  }) async {
    final db = await database;
    final ventaUuid = generateUuidV4();
    final disp = await obtenerDispositivoUuid();
    final cajaAbierta = await verificarCajaAbiertaHoy();
    if (!cajaAbierta) {
      return {'exito': false, 'mensaje': 'Debe abrir la caja antes de vender'};
    }
    if (metodo == 'CREDITO') {
      if (clienteId <= 0) {
        return {'exito': false, 'mensaje': 'Debe seleccionar un cliente válido'};
      }
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
        int id = await txn.insert('ventas', {
          'fecha': DateTime.now().toIso8601String(),
          'total': total,
          'metodo_pago': metodo,
          'usuario_id': usuarioId,
          'cliente_id': clienteId,
          'anulada': 0,
          'uuid': ventaUuid,
          'dispositivo_uuid': disp,
        });
        for (var i in items) {
          double factorPack = (i['contenido_pack'] as num?)?.toDouble() ?? 1.0;
          double cantidadReal = (i['cantidad'] as num).toDouble() * factorPack;
          final resStock = await txn.rawUpdate(
            'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ? AND stock_actual >= ?',
            [cantidadReal, i['id'], cantidadReal],
          );
          if (resStock == 0) {
            throw Exception(
              'STOCK_INSUF|${i['id']}|${i['nombre']}',
            );
          }
          await txn.insert('detalle_ventas', {
            'venta_id': id,
            'producto_id': i['id'],
            'nombre_producto': i['nombre'],
            'cantidad': i['cantidad'],
            'cantidad_descontada': cantidadReal,
            'precio_unitario': i['precio'],
            'costo_unitario': i['costo_unitario'] ?? 0,
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
        'detalle': detallePayload,
      }));
      for (var i in items) {
        double factorPack = (i['contenido_pack'] as num?)?.toDouble() ?? 1.0;
        double cantidadReal = (i['cantidad'] as num).toDouble() * factorPack;
        await encolarStockOp((i['id'] as num).toInt(), -cantidadReal);
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

  Future<Map<String, dynamic>> devolverArticulo(
    int detId,
    int prodId,
    int ventId,
    double cant,
    double dinero, {
    double? cantidadADevolver,
    required int usuarioId,
  }) async {
    final db = await database;
    final vi = await db.query('ventas', where: 'id = ?', whereArgs: [ventId]);
    if (vi.isEmpty) {
      return {'exito': false, 'mensaje': 'Venta no encontrada'};
    }
    final venta = vi.first;
    if ((venta['anulada'] ?? 0) == 1) {
      return {'exito': false, 'mensaje': 'La venta está anulada'};
    }
    double cantDev = cantidadADevolver ?? cant;
    if (cantDev <= 0 || dinero < 0) {
      return {'exito': false, 'mensaje': 'Cantidad o monto inválido'};
    }
    String metodo = venta['metodo_pago'] as String;
    int cid = (venta['cliente_id'] as num?)?.toInt() ?? 0;
    try {
      await db.transaction((txn) async {
        final det = await txn.query(
          'detalle_ventas',
          where: 'id = ?',
          whereArgs: [detId],
          limit: 1,
        );
        if (det.isEmpty) throw Exception('DETALLE_NO_EXISTE');
        final detalle = det.first;
        double cantActual = (detalle['cantidad'] as num).toDouble();
        double cantDescontada =
            (detalle['cantidad_descontada'] as num?)?.toDouble() ??
            cantActual;

        await txn.rawUpdate(
          'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
          [cantDev, prodId],
        );

        if (cantDev >= cantDescontada) {
          await txn.delete('detalle_ventas', where: 'id = ?', whereArgs: [detId]);
          await txn.rawUpdate(
            'UPDATE ventas SET total = total - ? WHERE id = ? AND total >= ?',
            [dinero, ventId, dinero],
          );
        } else {
          await txn.update(
            'detalle_ventas',
            {
              'cantidad': cantActual - cantDev,
              'cantidad_descontada': cantDescontada - cantDev,
              'subtotal':
                  ((detalle['subtotal'] as num).toDouble() - dinero)
                      .clamp(0, double.infinity),
            },
            where: 'id = ?',
            whereArgs: [detId],
          );
          await txn.rawUpdate(
            'UPDATE ventas SET total = total - ? WHERE id = ? AND total >= ?',
            [dinero, ventId, dinero],
          );
          if (venta['total'] as num < dinero) {
            throw Exception('MONTO_EXCEDE_TOTAL');
          }
        }
        if (metodo == 'CREDITO' && cid > 0) {
          await txn.rawUpdate(
            'UPDATE clientes SET deuda_actual = deuda_actual - ? WHERE id = ?',
            [dinero, cid],
          );
          await txn.insert('movimientos_cartera', {
            'cliente_id': cid,
            'tipo': 'DEVOLUCION',
            'venta_id': ventId,
            'fecha': DateTime.now().toIso8601String(),
            'monto': -dinero,
            'usuario_id': usuarioId,
          });
        } else if (metodo == 'EFECTIVO')
          await txn.insert('caja_movimientos', {
            'fecha': DateTime.now().toIso8601String(),
            'tipo': 'DEVOLUCION',
            'monto': dinero,
            'descripcion': 'Devolución Venta #$ventId',
            'usuario_id': usuarioId,
          });
      });
      final nowEpoch = DateTime.now().millisecondsSinceEpoch;
      await encolarStockOp(prodId, cantDev);
      if (metodo == 'CREDITO' && cid > 0) {
        await _encolarCartera(
          clienteId: cid,
          tipo: 'DEVOLUCION',
          monto: -dinero,
          deudaCambio: -dinero,
          ventaId: ventId,
          usuarioId: usuarioId,
          fechaEpoch: nowEpoch,
        );
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al devolver: $e'};
    }
    return {'exito': true, 'mensaje': 'Devolución registrada'};
  }

  Future<Map<String, dynamic>> anularVenta(
    int vId, {
    required int usuarioId,
  }) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final res = await txn.rawUpdate(
          'UPDATE ventas SET anulada = 1 WHERE id = ? AND anulada = 0',
          [vId],
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
          await txn.rawUpdate(
            'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
            [cantReal, i['producto_id']],
          );
        }
        final v = await txn.query('ventas', where: 'id = ?', whereArgs: [vId]);
        if (v.isEmpty) throw Exception('VENTA_NO_EXISTE');
        double tot = (v.first['total'] as num).toDouble();
        String metodo = v.first['metodo_pago'] as String;
        int cid = (v.first['cliente_id'] as num?)?.toInt() ?? 0;
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
        if (metodo == 'EFECTIVO') {
          await txn.insert('caja_movimientos', {
            'fecha': DateTime.now().toIso8601String(),
            'tipo': 'ANULACION',
            'monto': tot,
            'descripcion': 'ANULACIÓN Venta #$vId',
            'usuario_id': usuarioId,
          });
        }
      });
      final ahoraEpoch = DateTime.now().millisecondsSinceEpoch;
      final vRow = (await db.query(
        'ventas',
        where: 'id = ?',
        whereArgs: [vId],
        limit: 1,
      )).first;
      final ventaUuid = vRow['uuid']?.toString() ?? '';
      final tot = (vRow['total'] as num).toDouble();
      final metodo = (vRow['metodo_pago'] as String?) ?? '';
      final cid = (vRow['cliente_id'] as num?)?.toInt() ?? 0;
      if (ventaUuid.isNotEmpty) {
        await encolarPendiente('VENTA_ANULA', ventaUuid, jsonEncode({
          'uuid': ventaUuid,
          'actualizado_epoch': ahoraEpoch,
        }));
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
        await encolarStockOp((i['producto_id'] as num).toInt(), cantReal);
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
      return {'exito': true, 'mensaje': 'Venta anulada correctamente'};
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('VENTA_YA_ANULADA')) {
        return {'exito': false, 'mensaje': 'La venta ya está anulada'};
      }
      if (msg.contains('VENTA_NO_EXISTE')) {
        return {'exito': false, 'mensaje': 'Venta no encontrada'};
      }
      return {'exito': false, 'mensaje': 'Error al anular la venta: $e'};
    }
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
    if (pagoConCaja) {
      final cajaAbierta = await verificarCajaAbiertaHoy();
      if (!cajaAbierta) {
        return {
          'exito': false,
          'mensaje':
              'Compra pagada con caja: debe abrir la caja antes de registrar',
        };
      }
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
          double stockAntiguo = (p['stock_actual'] as num).toDouble();
          if (stockAntiguo < 0) stockAntiguo = 0;
          double costoAntiguo = (p['precio_costo'] as num?)?.toDouble() ?? 0;

          // Costo promedio ponderado en BD
          final stockTotal = stockAntiguo + cantidad;
          final nuevoCosto = stockTotal > 0
              ? ((stockAntiguo * costoAntiguo) + subtotalLinea) / stockTotal
              : (subtotalLinea / cantidad);

          double? nuevoPrecioVenta = (item['nuevo_precio_venta'] as num?)?.toDouble();
          Map<String, dynamic> campos = {
            'stock_actual': stockTotal,
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
        if (pagoConCaja) {
          await txn.insert('caja_movimientos', {
            'fecha': DateTime.now().toIso8601String(),
            'tipo': 'COMPRA',
            'monto': total,
            'descripcion': 'Compra Mercancía ($proveedor)',
            'usuario_id': usuarioId,
          });
        }
      });
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

  Future<String?> authUidPorUsuario(int usuarioId) async {
    if (usuarioId <= 0) return null;
    final db = await database;
    final res = await db.query(
      'usuarios',
      columns: ['auth_uid'],
      where: 'id = ?',
      whereArgs: [usuarioId],
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
      await encolarPendiente('PRODUCTO', pu, jsonEncode({
        'uuid': pu,
        'nombre': p['nombre'],
        'codigo_barras': p['codigo_barras'],
        'codigo_plu': p['codigo_plu'],
        'categoria': p['categoria'],
        'precio_costo': p['precio_costo'],
        'precio_venta': p['precio_venta'],
        'es_pesable': p['es_pesable'] ?? 0,
        'esta_activo': p['esta_activo'] ?? 1,
        'imagen_path': p['imagen_path'],
        'stock_recon':
            ((p['stock_actual'] as num?)?.toDouble() ?? 0).toInt(),
        'actualizado_epoch': DateTime.now().millisecondsSinceEpoch,
        'dispositivo_uuid': dispositivoUuid,
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
      final usuarioUid = await authUidPorUsuario(v['usuario_id'] as int);
      final detallePayload = await _detalleVentaPayload(db, detalle);
      await encolarPendiente('VENTA', vu, jsonEncode({
        'uuid': vu,
        'fecha': v['fecha'],
        'fecha_epoch':
            DateTime.tryParse(v['fecha'] as String)?.millisecondsSinceEpoch ?? 0,
        'total': v['total'],
        'metodo_pago': v['metodo_pago'],
        'usuario_uid': usuarioUid,
        'cliente_uuid': clienteUuid,
        'anulada': v['anulada'] ?? 0,
        'dispositivo_uuid':
            (v['dispositivo_uuid'] as String? ?? dispositivoUuid),
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
      final usuarioUid = await authUidPorUsuario(c['usuario_id'] as int);
      final detallePayload = await _detalleCompraPayload(db, detalle);
      await encolarPendiente('COMPRA', cu, jsonEncode({
        'uuid': cu,
        'fecha': c['fecha'],
        'fecha_epoch':
            DateTime.tryParse(c['fecha'] as String)?.millisecondsSinceEpoch ?? 0,
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
      final usuarioUid = await authUidPorUsuario(m['usuario_id'] as int);
      await encolarPendiente('CARTERA', mu, jsonEncode({
        'uuid': mu,
        'cliente_uuid': clienteUuid,
        'tipo': tipo,
        'monto': monto,
        'deuda_cambio': deudaCambio,
        'venta_uuid': ventaUuid,
        'fecha_epoch':
            DateTime.tryParse(m['fecha'] as String)?.millisecondsSinceEpoch ?? 0,
        'usuario_uid': usuarioUid,
        'dispositivo_uuid': dispositivoUuid,
        'sin_deuda': true,
      }));
      await guardarAplicado('CARTERA', mu,
          DateTime.tryParse(m['fecha'] as String)?.millisecondsSinceEpoch ?? 0);
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
    try {
      await db.transaction((txn) async {
        final res = await txn.rawUpdate(
          'UPDATE clientes SET deuda_actual = deuda_actual - ? WHERE id = ? AND deuda_actual >= ?',
          [m, id, m],
        );
        if (res == 0) {
          throw Exception('ABONO_EXCEDE_DEUDA');
        }
        await txn.insert('caja_movimientos', {
          'fecha': DateTime.now().toIso8601String(),
          'tipo': 'INGRESO',
          'monto': m,
          'descripcion': 'Abono: $nom',
          'usuario_id': usuarioId,
        });
        await txn.insert('movimientos_cartera', {
          'cliente_id': id,
          'tipo': 'ABONO',
          'venta_id': 0,
          'fecha': DateTime.now().toIso8601String(),
          'monto': m,
          'usuario_id': usuarioId,
        });
      });
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
    return {
      'ventas': ventas,
      'costos': costos,
      'utilidad_bruta': ventas - costos,
      'gastos': gastos,
      'utilidad_neta': (ventas - costos) - gastos,
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
      await txn.rawDelete(
        "DELETE FROM sqlite_sequence WHERE name IN ('ventas', 'productos', 'clientes', 'caja_movimientos', 'compras', 'detalle_compras', 'cierres_caja', 'movimientos_cartera')",
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
  }
}
