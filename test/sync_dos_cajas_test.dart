import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/finanzas_service.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/role_permissions.dart';
import 'package:novapos/services/session_service.dart';
import 'package:novapos/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Dos cajas del mismo negocio contra una nube simulada. Cada caja tiene su
/// propia base y se turnan (como dos PCs que se prenden en distinto momento).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const negocio = 'negocio-prueba';
  late FakeFirebaseFirestore nube;
  late Directory dir;
  final dbs = <String, Database>{};
  final db = DBHelper();

  setUp(() async {
    nube = FakeFirebaseFirestore();
    dir = await Directory.systemTemp.createTemp('novapos_sync_');
    await SessionService.login({'id': 1, 'nombre': 'Ana', 'rol': 'ADMIN'});
    await PermissionService.loadPermissions(RolePermissions.permisosPara('ADMIN'));
  });

  tearDown(() async {
    for (final d in dbs.values) {
      await d.close();
    }
    dbs.clear();
    DBHelper.setDatabaseForTesting(null);
    await dir.delete(recursive: true);
    await SessionService.logout();
    await PermissionService.clear();
  });

  Future<T> esperar<T>(Future<T> Function() leer, bool Function(T) listo, {int intentos = 60}) async {
    late T v;
    for (var i = 0; i < intentos; i++) {
      v = await leer();
      if (listo(v)) return v;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return v;
  }

  /// Prende la caja [nombre], la deja sincronizada y ejecuta [accion].
  Future<void> enCaja(String nombre, Future<void> Function(SyncService s) accion) async {
    if (dbs[nombre] == null) {
      DBHelper.setDatabaseForTesting(null);
      dbs[nombre] = await db.abrirArchivoParaPruebas('${dir.path}/$nombre.db');
    }
    DBHelper.setDatabaseForTesting(dbs[nombre]);
    final s = SyncService.paraPruebas(nube);
    await s.iniciar(negocioId: negocio, usuarioUid: 'uid-ana');
    await Future.delayed(const Duration(milliseconds: 400)); // primeras escuchas
    await accion(s);
    // Todo lo pendiente sube antes de apagar la caja
    await esperar(() async {
      await s.sincronizarAhora();
      return (await db.obtenerPendientes()).length;
    }, (n) => n == 0);
    await s.detener();
  }

  Future<Map<String, dynamic>> producto(String nombre) async {
    final d = await db.database;
    return (await d.query('productos', where: 'nombre = ?', whereArgs: [nombre])).first;
  }

  Future<void> darStock(String nombre, double stock) async {
    final p = await producto(nombre);
    final d = await db.database;
    await d.update('productos', {'stock_actual': stock}, where: 'id = ?', whereArgs: [p['id']]);
    await db.encolarProductoCambio({...p, 'stock_actual': stock}, stockRecon: true);
  }

  test('Caja 2 se une al negocio sin pisar precios y con el stock real', () async {
    // Caja 1: negocio nuevo → arranca con el catálogo; el dueño ajusta un precio y el stock
    String nombre = '';
    await enCaja('caja1', (s) async {
      final d = await db.database;
      final p = (await d.query('productos', limit: 1)).first;
      nombre = p['nombre'] as String;
      await d.update('productos', {'precio_venta': 9999}, where: 'id = ?', whereArgs: [p['id']]);
      await darStock(nombre, 40);
      final actualizado = await producto(nombre);
      await db.encolarProductoCambio(actualizado, stockRecon: true);
    });
    final enNube = await nube.collection('negocios').doc(negocio).collection('productos').get();
    expect(enNube.docs.length, greaterThan(100));

    // Caja 2: equipo nuevo del mismo negocio
    await enCaja('caja2', (s) async {
      final p = await esperar(() => producto(nombre), (p) => p['precio_venta'] == 9999);
      expect(p['precio_venta'], 9999);
      expect(p['stock_actual'], 40);
      final d = await db.database;
      final n = (await d.rawQuery('SELECT COUNT(*) AS n FROM productos')).first['n'];
      expect(n, enNube.docs.length); // sin duplicar el catálogo
    });
    // La caja 2 no cambió el precio en la nube
    final doc = enNube.docs.firstWhere((x) => x['nombre'] == nombre);
    final ahora = await doc.reference.get();
    expect(ahora['precio_venta'], 9999);
  });

  test('Ventas, stock, devoluciones y cierres llegan a la otra caja', () async {
    late String papa;
    await enCaja('caja1', (s) async {
      papa = (await producto('Papa Pastusa'))['nombre'] as String;
      await darStock(papa, 50);
    });
    await enCaja('caja2', (s) async {
      await esperar(() => producto(papa), (p) => p['stock_actual'] == 50);
    });

    // Caja 1 vende 4 kg en efectivo
    int ventaId = 0;
    await enCaja('caja1', (s) async {
      await db.registrarMovimientoCaja('APERTURA', 20000, 'Base', 1);
      final p = await producto(papa);
      final r = await db.registrarVenta(4 * 2000, 'EFECTIVO', [
        {'id': p['id'], 'nombre': papa, 'cantidad': 4, 'precio': 2000, 'subtotal': 8000, 'costo_unitario': 1000}
      ], usuarioId: 1);
      expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
      ventaId = r['venta_id'] as int;
      expect((await producto(papa))['stock_actual'], 46);
    });

    // Caja 2 la ve, ve el stock y devuelve 1 kg desde su propio cajón
    await enCaja('caja2', (s) async {
      expect((await esperar(() => producto(papa), (p) => p['stock_actual'] == 46))['stock_actual'], 46);
      final d = await db.database;
      final venta = await esperar(
          () => d.query('ventas'), (List<Map<String, dynamic>> v) => v.isNotEmpty);
      expect(venta.single['total'], 8000);
      await db.guardarConfiguracion('caja_nombre', 'Caja frutas');
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base caja 2', 1);
      final linea = (await d.query('detalle_ventas', where: 'venta_id = ?', whereArgs: [venta.single['id']])).single;
      final r = await db.devolverArticulo(linea['id'] as int, linea['producto_id'] as int, venta.single['id'] as int,
          4, 0, cantidadADevolver: 1, usuarioId: 1, motivo: 'Dañada');
      expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
      expect((await db.obtenerResumenCaja())['total_en_caja'], 8000); // 10.000 − 2.000
      final total = (await db.obtenerResumenCaja())['total_en_caja']!;
      await db.cerrarTurno(realContado: total, fechaInicio: (await db.obtenerFechaAperturaActual())!, usuarioId: 1);
    });

    // Caja 1: la venta quedó en 6.000, el stock volvió y su cajón no cambió
    await enCaja('caja1', (s) async {
      final d = await db.database;
      final v = await esperar(() async => (await d.query('ventas', where: 'id = ?', whereArgs: [ventaId])).single,
          (Map<String, dynamic> v) => v['total'] == 6000);
      expect(v['total'], 6000);
      expect((await esperar(() => producto(papa), (p) => p['stock_actual'] == 47))['stock_actual'], 47);
      expect((await db.obtenerResumenCaja())['total_en_caja'], 28000); // 20.000 + 8.000 cobrados aquí

      // El dueño ve el cierre de la caja 2 y la devolución en su Centro Financiero
      final hoy = Periodo(DateTime.now(), DateTime.now());
      final cierres = await esperar(() => FinanzasService(db).cierresDe(hoy),
          (Cierres c) => c.cierres.any((x) => x.caja == 'Caja frutas'));
      expect(cierres.cierres.any((x) => x.caja == 'Caja frutas' && !x.estaCaja), isTrue);
      final control = await esperar(() => FinanzasService(db).control(hoy), (Control c) => c.cantidad('DEVOLUCION') == 1);
      expect(control.eventos.firstWhere((e) => e.tipo == 'DEVOLUCION').motivo, 'Dañada');
    });
  });

  test('Una promoción eliminada en una caja deja de aplicar en la otra', () async {
    await enCaja('caja1', (s) async {
      await db.guardarPromocion({
        'nombre': 'Martes campesino',
        'dias_semana': '1,2,3,4,5,6,7',
        'tipo_alcance': 'TODO',
        'tipo_descuento': 'PORCENTAJE',
        'valor_descuento': 10,
        'esta_activa': 1,
      });
    });
    await enCaja('caja2', (s) async {
      await esperar(() => db.obtenerPromociones(), (List<Map<String, dynamic>> p) => p.length == 1);
      expect((await db.obtenerPromociones()).length, 1);
    });
    // Desactivarla también llega
    await enCaja('caja1', (s) async {
      await db.togglePromocionActiva((await db.obtenerPromociones()).single['id'] as int, false);
    });
    await enCaja('caja2', (s) async {
      final p = await esperar(() => db.obtenerPromociones(),
          (List<Map<String, dynamic>> p) => p.length == 1 && p.single['esta_activa'] == 0);
      expect(p.single['esta_activa'], 0);
    });
    await enCaja('caja1', (s) async {
      await db.eliminarPromocion((await db.obtenerPromociones()).single['id'] as int);
    });
    await enCaja('caja2', (s) async {
      final p = await esperar(() => db.obtenerPromociones(), (List<Map<String, dynamic>> p) => p.isEmpty);
      expect(p, isEmpty);
    });
  });

  test('Al reabrir solo se leen los cambios nuevos', () async {
    await enCaja('caja1', (s) async {});
    final cfg = await db.obtenerConfiguracion();
    expect(cfg['sync_marca_PRODUCTO'], isNotNull);
    expect(cfg['sync_marca_VENTA'], isNotNull);
    // Todo lo que se escribe en la nube lleva la hora del servidor
    final docs = await nube.collection('negocios').doc(negocio).collection('productos').limit(5).get();
    expect(docs.docs.every((d) => d.data()['sync_ts'] is Timestamp), isTrue);
  });

  test('Combos y paquetes creados en una caja funcionan en la otra', () async {
    await enCaja('caja1', (s) async {
      await darStock('Papa Pastusa', 30);
      await darStock('Cebolla Cabezona Roja', 30);
      final papa = await producto('Papa Pastusa');
      final cebolla = await producto('Cebolla Cabezona Roja');
      await db.crearCombo(
        {'nombre': 'Combo sancocho', 'precio_venta': 9000, 'precio_costo': 0, 'stock_actual': 0, 'categoria': 'Combos'},
        [
          {'producto_id': papa['id'], 'cantidad': 2},
          {'producto_id': cebolla['id'], 'cantidad': 1},
        ],
      );
      await db.agregarPresentacion(papa['id'] as int, 'Bulto x 5', 5, 9000);
    });
    await enCaja('caja2', (s) async {
      final combo = await esperar(() async {
        final d = await db.database;
        return d.query('productos', where: "nombre = 'Combo sancocho'");
      }, (List<Map<String, dynamic>> c) => c.isNotEmpty);
      expect(combo.single['es_combo'], 1);
      final comps = await esperar(() => db.obtenerDetallesCombo(combo.single['id'] as int),
          (List<Map<String, dynamic>> c) => c.length == 2);
      expect(comps.length, 2);
      final papa = await producto('Papa Pastusa');
      final packs = await esperar(() => db.obtenerPresentaciones(papa['id'] as int),
          (List<Map<String, dynamic>> p) => p.isNotEmpty);
      expect(packs.single['nombre'], 'Bulto x 5');

      // Vender el combo en la caja 2 descuenta sus componentes
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
      final r = await db.registrarVenta(9000, 'EFECTIVO', [
        {'id': combo.single['id'], 'nombre': 'Combo sancocho', 'cantidad': 1, 'precio': 9000, 'subtotal': 9000}
      ], usuarioId: 1);
      expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
      expect((await producto('Papa Pastusa'))['stock_actual'], 28);
      expect((await producto('Cebolla Cabezona Roja'))['stock_actual'], 29);
    });
    // Y la caja 1 ve el stock de los componentes actualizado
    await enCaja('caja1', (s) async {
      final p = await esperar(() => producto('Papa Pastusa'), (p) => p['stock_actual'] == 28);
      expect(p['stock_actual'], 28);
    });
  });
}
