import 'dart:io';
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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE usuarios (id INTEGER PRIMARY KEY AUTOINCREMENT, usuario TEXT UNIQUE, password_hash TEXT, rol TEXT, nombre_completo TEXT, esta_activo INTEGER DEFAULT 1)',
    );
    await db.execute(
      'CREATE TABLE productos (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT, codigo_barras TEXT, codigo_plu TEXT, categoria TEXT, precio_costo REAL, precio_venta REAL, stock_actual REAL, es_pesable INTEGER DEFAULT 0, esta_activo INTEGER DEFAULT 1, imagen_path TEXT)',
    );
    await db.execute(
      'CREATE TABLE configuracion (clave TEXT PRIMARY KEY, valor TEXT)',
    );
    await db.execute(
      'CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT, telefono TEXT, direccion TEXT, deuda_actual REAL DEFAULT 0, cupo_credito REAL DEFAULT 0, esta_activo INTEGER DEFAULT 1)',
    );
    await db.execute(
      'CREATE TABLE ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, total REAL, metodo_pago TEXT, usuario_id INTEGER, cliente_id INTEGER DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE detalle_ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, venta_id INTEGER, producto_id INTEGER, nombre_producto TEXT, cantidad REAL, cantidad_descontada REAL, precio_unitario REAL, subtotal REAL)',
    );
    await db.execute(
      'CREATE TABLE caja_movimientos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, tipo TEXT, monto REAL, descripcion TEXT, usuario_id INTEGER)',
    );
    await db.execute(
      'CREATE TABLE compras (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, total REAL, metodo_pago TEXT, proveedor TEXT)',
    );
    await db.execute(
      'CREATE TABLE detalle_compras (id INTEGER PRIMARY KEY AUTOINCREMENT, compra_id INTEGER, producto_id INTEGER, nombre_producto TEXT, cantidad REAL, costo_unitario REAL, subtotal REAL)',
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

    final adminPassword = PasswordService.hashPassword("1234");
    final cajeroPassword = PasswordService.hashPassword("1234");

    await db.insert('usuarios', {
      'usuario': 'cajero',
      'password_hash': cajeroPassword,
      'rol': 'CAJERO',
      'nombre_completo': 'Usuario Cajero',
    });

    await db.insert("usuarios", {
      "usuario": "admin",
      "password_hash": adminPassword,
      "rol": "ADMIN",
      "nombre_completo": "Administrador",
    });

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
      "INSERT INTO configuracion (clave, valor) VALUES ('empresa_nombre', 'MI FRUVER')",
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

  // --- 🔑 AUTENTICACIÓN (RECUPERADO) ---
  Future<Map<String, dynamic>?> login(String usuario, String password) async {
    final db = await database;

    final resultado = await db.query(
      'usuarios',
      where: 'usuario = ?',
      whereArgs: [usuario],
      limit: 1,
    );

    if (resultado.isEmpty) {
      return null;
    }

    final usuarioDB = resultado.first;
    final hashGuardado = usuarioDB['password_hash']?.toString() ?? '';

    if (PasswordService.verifyPassword(password, hashGuardado)) {
      return usuarioDB;
    }

    return null;
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
    return await db.insert('productos', row);
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
        'gastos': 0,
        'ingresos_extra': 0,
        'total_en_caja': 0,
      };
    }

    final ventasRes = await db.rawQuery(
      "SELECT SUM(total) as total FROM ventas WHERE fecha >= ? AND metodo_pago = 'EFECTIVO'",
      [fechaInicio],
    );
    double ventas = (ventasRes.first['total'] as num?)?.toDouble() ?? 0;
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
      if (m['tipo'] == 'GASTO') gastos += v;
    }
    return {
      'base': base,
      'ventas_efectivo': ventas,
      'ingresos_extra': ingresos,
      'gastos': gastos,
      'total_en_caja': (base + ventas + ingresos) - gastos,
    };
  }

  Future<bool> verificarCajaAbiertaHoy() async {
    final res = await obtenerResumenCaja();
    return (res['base'] ?? 0) > 0;
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

    return await db.insert('caja_movimientos', {
      'fecha': DateTime.now().toIso8601String(),
      'tipo': tipo,
      'monto': monto,
      'descripcion': descripcion,
      'usuario_id': usuarioId,
    });
  }

  Future<int> registrarVenta(
    double total,
    String metodo,
    List<Map<String, dynamic>> items, {
    int clienteId = 0,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      int id = await txn.insert('ventas', {
        'fecha': DateTime.now().toIso8601String(),
        'total': total,
        'metodo_pago': metodo,
        'usuario_id': 1,
        'cliente_id': clienteId,
      });
      for (var i in items) {
        double factorPack = (i['contenido_pack'] as num?)?.toDouble() ?? 1.0;
        double cantidadReal = (i['cantidad'] as num).toDouble() * factorPack;
        await txn.insert('detalle_ventas', {
          'venta_id': id,
          'producto_id': i['id'],
          'nombre_producto': i['nombre'],
          'cantidad': i['cantidad'],
          'cantidad_descontada': cantidadReal,
          'precio_unitario': i['precio'],
          'subtotal': i['subtotal'],
        });
        await txn.rawUpdate(
          'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ?',
          [cantidadReal, i['id']],
        );
      }
      if (metodo == 'CREDITO' && clienteId > 0) {
        await txn.rawUpdate(
          'UPDATE clientes SET deuda_actual = deuda_actual + ? WHERE id = ?',
          [total, clienteId],
        );
      }
      return id;
    });
  }

  Future<void> devolverArticulo(
    int detId,
    int prodId,
    int ventId,
    double cant,
    double dinero,
  ) async {
    final db = await database;
    final vi = await db.query('ventas', where: 'id = ?', whereArgs: [ventId]);
    if (vi.isEmpty) return;
    String metodo = vi.first['metodo_pago'] as String;
    int cid = (vi.first['cliente_id'] as num?)?.toInt() ?? 0;
    await db.transaction((txn) async {
      await txn.delete('detalle_ventas', where: 'id = ?', whereArgs: [detId]);
      await txn.rawUpdate(
        'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
        [cant, prodId],
      );
      await txn.rawUpdate('UPDATE ventas SET total = total - ? WHERE id = ?', [
        dinero,
        ventId,
      ]);
      if (metodo == 'CREDITO' && cid > 0) {
        await txn.rawUpdate(
          'UPDATE clientes SET deuda_actual = deuda_actual - ? WHERE id = ?',
          [dinero, cid],
        );
      } else if (metodo == 'EFECTIVO')
        await txn.insert('caja_movimientos', {
          'fecha': DateTime.now().toIso8601String(),
          'tipo': 'GASTO',
          'monto': dinero,
          'descripcion': 'Devolución Venta #$ventId',
          'usuario_id': 1,
        });
    });
  }

  Future<void> anularVenta(int vId) async {
    final db = await database;
    await db.transaction((txn) async {
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
      await txn.delete(
        'detalle_ventas',
        where: 'venta_id = ?',
        whereArgs: [vId],
      );
      final v = await txn.query('ventas', where: 'id = ?', whereArgs: [vId]);
      double tot = (v.first['total'] as num).toDouble();
      await txn.delete('ventas', where: 'id = ?', whereArgs: [vId]);
      await txn.insert('caja_movimientos', {
        'fecha': DateTime.now().toIso8601String(),
        'tipo': 'GASTO',
        'monto': tot,
        'descripcion': 'ANULACIÓN Venta #$vId',
        'usuario_id': 1,
      });
    });
  }

  // --- COMPRAS ---
  Future<void> registrarCompra(
    List<Map<String, dynamic>> productos,
    double total,
    bool pagoConCaja,
    String proveedor,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      int compraId = await txn.insert('compras', {
        'fecha': DateTime.now().toIso8601String(),
        'total': total,
        'metodo_pago': pagoConCaja ? 'CAJA' : 'CREDITO/BANCO',
        'proveedor': proveedor.isEmpty ? 'General' : proveedor,
      });
      for (var item in productos) {
        await txn.rawUpdate(
          'UPDATE productos SET stock_actual = stock_actual + ?, precio_costo = ?, precio_venta = ? WHERE id = ?',
          [
            item['cantidad'],
            item['nuevo_costo'],
            item['nuevo_precio_venta'],
            item['id'],
          ],
        );
        await txn.insert('detalle_compras', {
          'compra_id': compraId,
          'producto_id': item['id'],
          'nombre_producto': item['nombre'],
          'cantidad': item['cantidad'],
          'costo_unitario': item['nuevo_costo'],
          'subtotal': item['subtotal_compra'],
        });
      }
      String tipoMov = pagoConCaja ? 'GASTO' : 'COMPRA_CREDITO';
      String desc = pagoConCaja
          ? 'Compra Mercancía ($proveedor)'
          : 'Ingreso Mercancía - Crédito/Banco ($proveedor)';
      await txn.insert('caja_movimientos', {
        'fecha': DateTime.now().toIso8601String(),
        'tipo': tipoMov,
        'monto': total,
        'descripcion': desc,
        'usuario_id': 1,
      });
    });
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
      ''' SELECT v.id as venta_id, v.fecha, v.metodo_pago, d.nombre_producto, d.cantidad, d.precio_unitario, d.subtotal FROM ventas v INNER JOIN detalle_ventas d ON v.id = d.venta_id ORDER BY v.fecha DESC ''',
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
      "SELECT strftime('%Y-%m-%d', fecha) as dia, SUM(total) as total FROM ventas WHERE fecha >= date('now', '-6 days') GROUP BY dia ORDER BY dia ASC",
    );
  }

  Future<List<Map<String, dynamic>>> obtenerTopProductos() async {
    final db = await database;
    return await db.rawQuery(
      "SELECT nombre_producto, SUM(cantidad) as cantidad_total FROM detalle_ventas GROUP BY producto_id ORDER BY cantidad_total DESC LIMIT 5",
    );
  }

  Future<List<Map<String, dynamic>>> obtenerMetodosPagoHoy() async {
    final db = await database;
    String hoy = DateTime.now().toIso8601String().substring(0, 10);
    return await db.rawQuery(
      "SELECT metodo_pago, SUM(total) as total FROM ventas WHERE fecha LIKE '$hoy%' GROUP BY metodo_pago",
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

  Future<List<Map<String, dynamic>>> obtenerClientes() async {
    final db = await database;
    return await db.query(
      'clientes',
      where: 'esta_activo = 1',
      orderBy: 'nombre ASC',
    );
  }

  Future<int> crearCliente(Map<String, dynamic> r) async {
    final db = await database;
    return await db.insert('clientes', r);
  }

  Future<void> registrarAbonoCliente(int id, String nom, double m) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE clientes SET deuda_actual = deuda_actual - ? WHERE id = ?',
        [m, id],
      );
      await txn.insert('caja_movimientos', {
        'fecha': DateTime.now().toIso8601String(),
        'tipo': 'INGRESO',
        'monto': m,
        'descripcion': 'Abono: $nom',
        'usuario_id': 1,
      });
    });
  }

  Future<List<Map<String, dynamic>>> obtenerVentasPorRango(
    String fi,
    String ff,
  ) async {
    final db = await database;
    return await db.query(
      'ventas',
      where: 'fecha BETWEEN ? AND ?',
      whereArgs: [fi, ff],
      orderBy: "fecha DESC",
    );
  }

  // --- INTELIGENCIA FINANCIERA ---
  Future<Map<String, double>> obtenerReporteFinanciero(
    String inicio,
    String fin,
  ) async {
    final db = await database;
    final resVentas = await db.rawQuery(
      "SELECT SUM(total) as t FROM ventas WHERE fecha BETWEEN ? AND ?",
      [inicio, fin],
    );
    double ventas = (resVentas.first['t'] as num?)?.toDouble() ?? 0;
    final resCostos = await db.rawQuery(
      ''' SELECT SUM(d.cantidad * p.precio_costo) as t FROM detalle_ventas d JOIN ventas v ON v.id = d.venta_id JOIN productos p ON p.id = d.producto_id WHERE v.fecha BETWEEN ? AND ? ''',
      [inicio, fin],
    );
    double costos = (resCostos.first['t'] as num?)?.toDouble() ?? 0;
    final resGastos = await db.rawQuery(
      "SELECT SUM(monto) as t FROM caja_movimientos WHERE tipo = 'GASTO' AND fecha BETWEEN ? AND ?",
      [inicio, fin],
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
    return await db.rawQuery(
      ''' SELECT d.nombre_producto, SUM(d.cantidad) as cantidad_total, SUM(d.subtotal) as dinero_total FROM detalle_ventas d JOIN ventas v ON v.id = d.venta_id WHERE v.fecha BETWEEN ? AND ? GROUP BY d.producto_id ORDER BY cantidad_total DESC LIMIT 10 ''',
      [inicio, fin],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerVentasPorCategoria(
    String inicio,
    String fin,
  ) async {
    final db = await database;
    return await db.rawQuery(
      ''' SELECT p.categoria, SUM(d.subtotal) as total FROM detalle_ventas d JOIN ventas v ON v.id = d.venta_id JOIN productos p ON p.id = d.producto_id WHERE v.fecha BETWEEN ? AND ? GROUP BY p.categoria ORDER BY total DESC ''',
      [inicio, fin],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerMetodosPagoPorRango(
    String inicio,
    String fin,
  ) async {
    final db = await database;
    return await db.rawQuery(
      ''' SELECT metodo_pago, SUM(total) as total FROM ventas WHERE fecha BETWEEN ? AND ? GROUP BY metodo_pago ''',
      [inicio, fin],
    );
  }

  // --- 🔥 IMPORTACIÓN MASIVA INTELIGENTE (FUSIÓN DE INVENTARIO) 🔥 ---
  Future<void> importarProductosMasivos(
    List<Map<String, dynamic>> nuevosProductos,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var p in nuevosProductos) {
        // 1. Buscar si ya existe el producto por NOMBRE (ignora mayúsculas/minúsculas)
        final List<Map<String, dynamic>> existe = await txn.query(
          'productos',
          where: 'LOWER(nombre) = LOWER(?)',
          whereArgs: [p['nombre']],
        );

        if (existe.isNotEmpty) {
          // 🔄 YA EXISTE: FUSIÓN DE DATOS
          // Sumamos el stock que viene en el Excel al que ya tenemos en sistema
          var prodAntiguo = existe.first;
          int id = prodAntiguo['id'] as int;
          double stockAntiguo = (prodAntiguo['stock_actual'] as num).toDouble();
          double stockNuevo = (p['stock_actual'] as num).toDouble();

          double stockTotal = stockAntiguo + stockNuevo;

          await txn.update(
            'productos',
            {
              'stock_actual': stockTotal, // Guardamos la suma
              'precio_costo': p['precio_costo'], // Actualizamos precios
              'precio_venta': p['precio_venta'],
              'codigo_barras': p['codigo_barras'],
              'categoria': p['categoria'],
              'es_pesable': p['es_pesable'],
              'esta_activo': 1, // Lo reactivamos por si estaba borrado
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          // 🆕 NO EXISTE: CREAR NUEVO
          await txn.insert('productos', {
            'nombre': p['nombre'],
            'codigo_barras': p['codigo_barras'],
            'codigo_plu': '',
            'categoria': p['categoria'],
            'precio_costo': p['precio_costo'],
            'precio_venta': p['precio_venta'],
            'stock_actual': p['stock_actual'],
            'es_pesable': p['es_pesable'],
            'esta_activo': 1,
            'imagen_path': null,
          });
        }
      }
    });
  }

  // --- SEGURIDAD ---
  Future<bool> validarContrasenaAdmin(String password) async {
    final db = await database;
    final res = await db.query(
      'usuarios',
      where: "usuario = 'admin' AND password_hash = ?",
      whereArgs: [password],
    );
    return res.isNotEmpty;
  }

  Future<void> resetFactory() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('detalle_ventas');
      await txn.delete('ventas');
      await txn.delete('detalle_compras');
      await txn.delete('compras');
      await txn.delete('caja_movimientos');
      await txn.delete('presentaciones');
      await txn.delete('productos');
      await txn.delete('clientes');
      await txn.rawDelete(
        "DELETE FROM sqlite_sequence WHERE name IN ('ventas', 'productos', 'clientes', 'caja_movimientos')",
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
  }
}
