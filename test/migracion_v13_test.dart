import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/finanzas_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Actualizar una caja de la v1.5.0 (base v12) con un turno abierto no debe
/// perder datos ni cambiar el cuadre (salvo el excedente de pagos mixtos,
/// que era cambio entregado al cliente).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late String ruta;

  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('novapos_mig_');
    ruta = '${dir.path}/v12.db';
    final viejo = await databaseFactoryFfi.openDatabase(ruta, options: OpenDatabaseOptions(version: 12));
    // Esquema de la v1.5.0 en las tablas que toca la migración
    for (final sql in [
      'CREATE TABLE usuarios (id INTEGER PRIMARY KEY AUTOINCREMENT, usuario TEXT UNIQUE, password_hash TEXT, rol TEXT, nombre_completo TEXT, esta_activo INTEGER DEFAULT 1, auth_uid TEXT UNIQUE)',
      'CREATE TABLE productos (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT, codigo_barras TEXT, codigo_plu TEXT, categoria TEXT, precio_costo REAL, precio_venta REAL, stock_actual REAL, es_pesable INTEGER DEFAULT 0, esta_activo INTEGER DEFAULT 1, imagen_path TEXT, uuid TEXT, dispositivo_uuid TEXT, es_favorito INTEGER DEFAULT 0, es_combo INTEGER DEFAULT 0)',
      'CREATE TABLE combo_detalles (id INTEGER PRIMARY KEY AUTOINCREMENT, combo_id INTEGER, producto_id INTEGER, cantidad REAL, uuid TEXT)',
      'CREATE TABLE configuracion (clave TEXT PRIMARY KEY, valor TEXT)',
      'CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT, telefono TEXT, direccion TEXT, deuda_actual REAL DEFAULT 0, cupo_credito REAL DEFAULT 0, esta_activo INTEGER DEFAULT 1, uuid TEXT)',
      'CREATE TABLE ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, total REAL, metodo_pago TEXT, usuario_id INTEGER, cliente_id INTEGER DEFAULT 0, anulada INTEGER DEFAULT 0, uuid TEXT, dispositivo_uuid TEXT, metodo_pago_detalle TEXT)',
      'CREATE TABLE detalle_ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, venta_id INTEGER, producto_id INTEGER, nombre_producto TEXT, cantidad REAL, cantidad_descontada REAL, precio_unitario REAL, subtotal REAL, costo_unitario REAL DEFAULT 0)',
      'CREATE TABLE compras (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, total REAL, metodo_pago TEXT, proveedor TEXT, uuid TEXT, usuario_id INTEGER)',
      'CREATE TABLE cierres_caja (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, fecha_inicio TEXT, fecha_fin TEXT, base REAL DEFAULT 0, ventas_turno REAL DEFAULT 0, ventas_turno_global REAL DEFAULT 0, ingresos_turno REAL DEFAULT 0, gastos_turno REAL DEFAULT 0, total_sistema REAL DEFAULT 0, real_contado REAL DEFAULT 0, diferencia REAL DEFAULT 0, estado TEXT, usuario_id INTEGER, detalle TEXT, uuid TEXT)',
      'CREATE TABLE movimientos_cartera (id INTEGER PRIMARY KEY AUTOINCREMENT, cliente_id INTEGER, tipo TEXT, venta_id INTEGER, fecha TEXT, monto REAL, usuario_id INTEGER, uuid TEXT)',
      'CREATE TABLE caja_movimientos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, tipo TEXT, monto REAL, descripcion TEXT, usuario_id INTEGER, uuid TEXT)',
      'CREATE TABLE mermas (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, producto_id INTEGER, nombre_producto TEXT, cantidad REAL, costo_unitario REAL, total_perdida REAL, motivo TEXT, usuario_id INTEGER, uuid TEXT)',
      'CREATE TABLE sync_pendientes (id INTEGER PRIMARY KEY AUTOINCREMENT, tipo TEXT NOT NULL, uuid TEXT NOT NULL, datos TEXT, estado INTEGER DEFAULT 0, creado_en TEXT)',
      'CREATE TABLE sync_aplicados (uuid TEXT PRIMARY KEY, tipo TEXT NOT NULL, epoch INTEGER DEFAULT 0)',
    ]) {
      await viejo.execute(sql);
    }
    final t0 = DateTime.now().subtract(const Duration(hours: 3));
    String t(int min) => t0.add(Duration(minutes: min)).toIso8601String();
    await viejo.insert('configuracion', {'clave': 'dispositivo_uuid', 'valor': 'caja-1'});
    await viejo.insert('configuracion', {'clave': 'permitir_stock_negativo', 'valor': '0'});
    await viejo.insert('productos',
        {'id': 1, 'nombre': 'Papa', 'precio_costo': 1000, 'precio_venta': 2000, 'stock_actual': 50, 'uuid': 'p1'});
    // Turno abierto con base 100.000
    await viejo.insert('caja_movimientos', {'fecha': t(0), 'tipo': 'APERTURA', 'monto': 100000, 'descripcion': 'Base', 'usuario_id': 1});
    // Venta en efectivo 20.000
    await viejo.insert('ventas', {'id': 1, 'fecha': t(10), 'total': 20000, 'metodo_pago': 'EFECTIVO', 'usuario_id': 1, 'uuid': 'v1', 'dispositivo_uuid': 'caja-1'});
    await viejo.insert('detalle_ventas', {'venta_id': 1, 'producto_id': 1, 'nombre_producto': 'Papa', 'cantidad': 10, 'cantidad_descontada': 10, 'precio_unitario': 2000, 'subtotal': 20000, 'costo_unitario': 1000});
    // Mixta de 50.000: entregó 30.000 en efectivo y 25.000 por Nequi (5.000 de cambio)
    await viejo.insert('ventas', {
      'id': 2, 'fecha': t(20), 'total': 50000, 'metodo_pago': 'MIXTO', 'usuario_id': 1, 'uuid': 'v2', 'dispositivo_uuid': 'caja-1',
      'metodo_pago_detalle': jsonEncode({'efectivo': 30000, 'digital': 25000, 'metodo_digital': 'NEQUI'}),
    });
    // Anulada (10.000 en efectivo) con su movimiento informativo
    await viejo.insert('ventas', {'id': 3, 'fecha': t(30), 'total': 10000, 'metodo_pago': 'EFECTIVO', 'usuario_id': 1, 'anulada': 1, 'uuid': 'v3', 'dispositivo_uuid': 'caja-1'});
    await viejo.insert('caja_movimientos', {'fecha': t(31), 'tipo': 'ANULACION', 'monto': 10000, 'descripcion': 'ANULACIÓN Venta #3', 'usuario_id': 1});
    // Venta de 8.000 con devolución vieja de 2.000 (total ya rebajado a 6.000)
    await viejo.insert('ventas', {'id': 4, 'fecha': t(40), 'total': 6000, 'metodo_pago': 'EFECTIVO', 'usuario_id': 1, 'uuid': 'v4', 'dispositivo_uuid': 'caja-1'});
    await viejo.insert('detalle_ventas', {'venta_id': 4, 'producto_id': 1, 'nombre_producto': 'Papa', 'cantidad': 3, 'cantidad_descontada': 3, 'precio_unitario': 2000, 'subtotal': 6000, 'costo_unitario': 1000});
    await viejo.insert('caja_movimientos', {'fecha': t(45), 'tipo': 'DEVOLUCION', 'monto': 2000, 'descripcion': 'Devolución Venta #4', 'usuario_id': 1});
    // Gasto viejo sin categoría y faltante de un cierre anterior
    await viejo.insert('caja_movimientos', {'fecha': t(50), 'tipo': 'GASTO', 'monto': 4000, 'descripcion': 'Pago domicilio', 'usuario_id': 1});
    await viejo.close();
  });

  tearDown(() async {
    final d = await DBHelper().database;
    await d.close();
    DBHelper.setDatabaseForTesting(null);
    await dir.delete(recursive: true);
  });

  test('Migra sin perder datos y el cuadre del turno abierto es correcto', () async {
    final db = DBHelper();
    final d = await db.abrirArchivoParaPruebas(ruta);
    expect(await d.getVersion(), 14);

    // Datos intactos
    expect((await d.query('ventas')).length, 4);
    expect((await d.query('caja_movimientos')).length, 4);

    // Efectivo cobrado: el de su estado (0 en la anulada, 25.000 en la mixta)
    final ventas = {for (final v in await d.query('ventas')) v['id']: v['efectivo_cobrado']};
    expect(ventas, {1: 20000.0, 2: 25000.0, 3: 0.0, 4: 6000.0});

    // 100.000 + 20.000 + 25.000 + 6.000 − 4.000 = 147.000
    final r = await db.obtenerResumenCaja();
    expect(await db.verificarCajaAbiertaHoy(), isTrue);
    expect(r['ventas_efectivo'], 51000);
    expect(r['gastos'], 4000);
    expect(r['total_en_caja'], 147000);
  });

  test('Después de migrar se puede devolver una venta vieja sin doble descuento', () async {
    final db = DBHelper();
    final d = await db.abrirArchivoParaPruebas(ruta);
    final linea = (await d.query('detalle_ventas', where: 'venta_id = 1')).first;
    final res = await db.devolverArticulo(linea['id'] as int, 1, 1, 10, 0, cantidadADevolver: 2, usuarioId: 1);
    expect(res['exito'], isTrue, reason: res['mensaje']?.toString());
    expect(res['efectivo'], 4000);
    expect((await db.obtenerResumenCaja())['total_en_caja'], 143000);

    // Y anular la que ya tenía una devolución vieja entrega solo lo que queda
    final anul = await db.anularVenta(4, usuarioId: 1);
    expect(anul['exito'], isTrue);
    expect(anul['efectivo'], 6000);
    expect((await db.obtenerResumenCaja())['total_en_caja'], 137000);
  });

  test('Los reportes leen bien los datos viejos', () async {
    final db = DBHelper();
    await db.abrirArchivoParaPruebas(ruta);
    final hoy = Periodo(DateTime.now(), DateTime.now());
    final r = await FinanzasService(db).resultados(hoy);
    expect(r.ventas, 76000); // 20.000 + 50.000 + 6.000
    expect(r.costoVentas, 13000);
    expect(r.gastos, 4000);
    expect(r.cantidadAnuladas, 1);
    final c = await FinanzasService(db).control(hoy);
    expect(c.cantidad('ANULACION'), 1);
    expect(c.cantidad('DEVOLUCION'), 1); // la vieja aparece como registro anterior
  });

  test('Abrir de nuevo no vuelve a migrar ni duplica', () async {
    final db = DBHelper();
    var d = await db.abrirArchivoParaPruebas(ruta);
    await d.close();
    DBHelper.setDatabaseForTesting(null);
    d = await db.abrirArchivoParaPruebas(ruta);
    expect((await d.query('ventas')).length, 4);
    expect((await db.obtenerResumenCaja())['total_en_caja'], 147000);
  });
}
