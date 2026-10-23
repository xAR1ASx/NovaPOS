@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/copia_nube_service.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/reporte_z.dart';
import 'package:novapos/services/role_permissions.dart';
import 'package:novapos/services/session_service.dart';
import 'package:novapos/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Auditoría: operaciones delicadas hechas en una caja y revisadas en la
/// otra (fiados, anulaciones, compras, mermas, ventas simultáneas sin
/// internet, fotos y subida inicial), más la copia en la nube con fiados.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const negocio = 'negocio-auditoria';
  const varias = SyncService.modoMulticaja;
  const una = SyncService.modoUnaCaja;
  late FakeFirebaseFirestore nube;
  late Directory dir;
  final dbs = <String, Database>{};
  final db = DBHelper();

  setUp(() async {
    nube = FakeFirebaseFirestore();
    dir = await Directory.systemTemp.createTemp('novapos_auditoria_');
    await SessionService.login({'id': 1, 'nombre': 'Ana', 'rol': 'ADMIN'});
    await PermissionService.loadPermissions(RolePermissions.permisosPara('ADMIN'));
  });

  tearDown(() async {
    for (final d in dbs.values) {
      if (d.isOpen) await d.close();
    }
    dbs.clear();
    DBHelper.setDatabaseForTesting(null);
    if (await dir.exists()) await dir.delete(recursive: true);
    await SessionService.logout();
    await PermissionService.clear();
  });

  CopiaNubeService copias() => CopiaNubeService.paraPruebas(nube, dir, tamanoParte: 8192);

  Future<T> esperar<T>(Future<T> Function() leer, bool Function(T) listo, {int intentos = 150}) async {
    late T v;
    for (var i = 0; i < intentos; i++) {
      try {
        v = await leer();
        if (listo(v)) return v;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return v;
  }

  Future<void> usar(String nombre) async {
    if (dbs[nombre] == null) {
      DBHelper.setDatabaseForTesting(null);
      dbs[nombre] = await db.abrirArchivoParaPruebas('${dir.path}/$nombre.db');
    }
    DBHelper.setDatabaseForTesting(dbs[nombre]);
  }

  Future<void> enCaja(String nombre, Future<void> Function(SyncService s) accion,
      {String modo = varias}) async {
    await usar(nombre);
    await db.guardarConfiguracion('modo_sync', modo);
    final s = SyncService.paraPruebas(nube, copias: copias());
    await s.iniciar(negocioId: negocio, usuarioUid: 'uid-ana');
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      await accion(s);
      if (modo == varias) {
        await esperar(() async {
          await s.sincronizarAhora();
          return (await db.obtenerPendientes()).length;
        }, (n) => n == 0);
      }
    } finally {
      await s.detener();
    }
  }

  Future<Map<String, dynamic>> producto(String nombre) async {
    final d = await db.database;
    final r = await d.query('productos', where: 'nombre = ?', whereArgs: [nombre]);
    if (r.isEmpty) throw StateError('Producto no encontrado: $nombre');
    return r.first;
  }

  Future<double> stock(String nombre) async =>
      ((await producto(nombre))['stock_actual'] as num).toDouble();

  Future<void> darStock(String nombre, double s) async {
    final p = await producto(nombre);
    final d = await db.database;
    await d.update('productos', {'stock_actual': s}, where: 'id = ?', whereArgs: [p['id']]);
    await db.encolarProductoCambio({...p, 'stock_actual': s}, stockRecon: true);
  }

  Future<void> abrirCaja() async {
    if (!await db.verificarCajaAbiertaHoy()) {
      await db.registrarMovimientoCaja('APERTURA', 50000, 'Base', 1);
    }
  }

  Future<Map<String, dynamic>> vender(String nombre, double cant,
      {String metodo = 'EFECTIVO', int clienteId = 0}) async {
    await abrirCaja();
    final p = await producto(nombre);
    final r = await db.registrarVenta(cant * 2000, metodo, [
      {'id': p['id'], 'nombre': nombre, 'cantidad': cant, 'precio': 2000, 'subtotal': cant * 2000, 'costo_unitario': 1000}
    ], usuarioId: 1, clienteId: clienteId);
    expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
    return r;
  }

  Future<Map<String, dynamic>> cliente(String nombre) async {
    final d = await db.database;
    return (await d.query('clientes', where: 'nombre = ?', whereArgs: [nombre])).single;
  }

  Future<int> contar(String tabla, [String? where]) async {
    final d = await db.database;
    return (await d.rawQuery('SELECT COUNT(*) AS n FROM $tabla${where == null ? '' : ' WHERE $where'}')).first['n'] as int;
  }

  test('Cajas en vivo: la caja principal ve cómo va la otra caja, con su nombre y su efectivo', () async {
    await enCaja('caja1', (s) async {
      await db.guardarConfiguracion('caja_nombre', 'Caja principal');
      await darStock('Papa Pastusa', 100);
    });
    double esperadoCaja2 = 0;
    await enCaja('caja2', (s) async {
      await db.guardarConfiguracion('caja_nombre', 'Caja frutas');
      await esperar(() => stock('Papa Pastusa'), (v) => v == 100);
      await abrirCaja(); // base 50.000
      await vender('Papa Pastusa', 5); // 10.000 en efectivo
      await vender('Papa Pastusa', 2, metodo: 'TRANSFERENCIA'); // 4.000
      await db.registrarMovimientoCaja('GASTO', 3000, 'Bolsas', 1);
      esperadoCaja2 = (await db.obtenerResumenCaja())['total_en_caja']!;
      expect(esperadoCaja2, 57000);
    });
    await enCaja('caja1', (s) async {
      await abrirCaja();
      await vender('Papa Pastusa', 1);
      final cajas = await esperar(() => db.estadoDeLasCajas(),
          (List<EstadoCaja> l) => l.any((c) => c.nombre == 'Caja frutas' && (c.turno?.pedidos ?? 0) == 2));
      expect(cajas.length, 2);
      final principal = cajas.singleWhere((c) => c.esEstaCaja);
      expect(principal.nombre, 'Caja principal');
      expect(principal.abierta, isTrue);
      expect(principal.turno!.ventasTotal, 2000);
      final frutas = cajas.singleWhere((c) => !c.esEstaCaja);
      expect(frutas.nombre, 'Caja frutas');
      expect(frutas.abierta, isTrue);
      expect(frutas.turno!.esperado, esperadoCaja2, reason: 'lo mismo que la caja 2 calcula para su cajón');
      expect(frutas.turno!.ventasTotal, 14000);
      expect(frutas.turno!.ventasPorMedio['Transferencia'], 4000);
      expect(frutas.turno!.gastos, 3000);
      expect(frutas.ventasHoy, 14000);
      // La venta de la caja 1 no se cuenta en la caja 2 ni al revés
      expect(principal.turno!.pedidos, 1);
    });
    // La caja 2 cierra: la principal la ve cerrada con la diferencia del cierre
    await enCaja('caja2', (s) async {
      await db.cerrarTurno(realContado: 56000, fechaInicio: '', usuarioId: 1);
    });
    await enCaja('caja1', (s) async {
      final cajas = await esperar(() => db.estadoDeLasCajas(),
          (List<EstadoCaja> l) => l.any((c) => c.nombre == 'Caja frutas' && !c.abierta && c.ultimaDiferencia != null));
      final frutas = cajas.singleWhere((c) => !c.esEstaCaja);
      expect(frutas.abierta, isFalse);
      expect(frutas.ultimaDiferencia, -1000);
    });
  });

  test('Fiado en una caja y abono en la otra: la deuda queda igual en las dos', () async {
    await enCaja('caja1', (s) async {
      await darStock('Papa Pastusa', 100);
      final id = await db.crearCliente({'nombre': 'Doña Rosa', 'telefono': '300', 'direccion': 'Centro'});
      expect(await db.actualizarClienteCupo(id, 100000), isTrue);
      await vender('Papa Pastusa', 10, metodo: 'CREDITO', clienteId: id); // 20.000 de deuda
      expect((await cliente('Doña Rosa'))['deuda_actual'], 20000);
    });
    await enCaja('caja2', (s) async {
      final c = await esperar(() => cliente('Doña Rosa'), (c) => c['deuda_actual'] == 20000);
      expect(c['deuda_actual'], 20000);
      await abrirCaja();
      final r = await db.registrarAbonoCliente(c['id'] as int, 'Doña Rosa', 5000, usuarioId: 1);
      expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
      expect((await cliente('Doña Rosa'))['deuda_actual'], 15000);
    });
    await enCaja('caja1', (s) async {
      expect((await esperar(() => cliente('Doña Rosa'), (c) => c['deuda_actual'] == 15000))['deuda_actual'], 15000);
      await Future.delayed(const Duration(milliseconds: 500));
      expect((await cliente('Doña Rosa'))['deuda_actual'], 15000, reason: 'no se aplica dos veces');
    });
    final enNube = (await nube.collection('negocios').doc(negocio).collection('clientes').get())
        .docs.map((d) => d.data()).singleWhere((c) => c['nombre'] == 'Doña Rosa');
    expect(enNube['deuda_actual'], 15000);
  });

  test('Anular en la caja 1 una venta hecha en la caja 2 devuelve el stock en las dos', () async {
    await enCaja('caja1', (s) async { await darStock('Papa Pastusa', 40); });
    String ventaUuid = '';
    await enCaja('caja2', (s) async {
      await esperar(() => stock('Papa Pastusa'), (v) => v == 40);
      final r = await vender('Papa Pastusa', 6);
      final d = await db.database;
      ventaUuid = (await d.query('ventas', where: 'id = ?', whereArgs: [r['venta_id']])).single['uuid'] as String;
      expect(await stock('Papa Pastusa'), 34);
    });
    await enCaja('caja1', (s) async {
      await esperar(() => stock('Papa Pastusa'), (v) => v == 34);
      final d = await db.database;
      final v = await esperar(() => d.query('ventas', where: 'uuid = ?', whereArgs: [ventaUuid]),
          (List<Map<String, dynamic>> l) => l.isNotEmpty);
      await abrirCaja();
      final r = await db.anularVenta(v.single['id'] as int, usuarioId: 1, motivo: 'Cliente arrepentido');
      expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
      expect(await stock('Papa Pastusa'), 40);
    });

    await enCaja('caja2', (s) async {
      expect(await esperar(() => stock('Papa Pastusa'), (v) => v == 40), 40);
      final d = await db.database;
      final v = await esperar(() => d.query('ventas', where: 'uuid = ?', whereArgs: [ventaUuid]),
          (List<Map<String, dynamic>> l) => l.single['anulada'] == 1);
      expect(v.single['anulada'], 1);
      await Future.delayed(const Duration(milliseconds: 500));
      expect(await stock('Papa Pastusa'), 40, reason: 'la anulación no se aplica dos veces');
    });
  });

  test('Compra en una caja y merma en la otra mueven el stock en las dos', () async {
    await enCaja('caja1', (s) async { await darStock('Papa Pastusa', 10); });
    await enCaja('caja2', (s) async {
      await esperar(() => stock('Papa Pastusa'), (v) => v == 10);
      final p = await producto('Papa Pastusa');
      final r = await db.registrarCompra([
        {'id': p['id'], 'nombre': 'Papa Pastusa', 'cantidad': 25, 'subtotal_compra': 25000, 'costo': 1000, 'costo_unitario': 1000}
      ], 25000, false, 'Proveedor Andes', usuarioId: 1);
      expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
      expect(await stock('Papa Pastusa'), 35);
    });
    await enCaja('caja1', (s) async {
      expect(await esperar(() => stock('Papa Pastusa'), (v) => v == 35), 35);
      expect(await esperar(() => contar('compras'), (n) => n == 1), 1);
      final p = await producto('Papa Pastusa');
      await db.registrarMerma(productoId: p['id'] as int, cantidad: 3, motivo: 'Dañada', usuarioId: 1);
      expect(await stock('Papa Pastusa'), 32);
    });
    await enCaja('caja2', (s) async {
      expect(await esperar(() => stock('Papa Pastusa'), (v) => v == 32), 32);
      expect(await esperar(() => contar('mermas'), (n) => n == 1), 1);
    });
  });

  test('Las dos cajas venden lo mismo sin internet y al conectarse el stock es exacto', () async {
    await enCaja('caja1', (s) async { await darStock('Papa Pastusa', 50); });
    await enCaja('caja2', (s) async { await esperar(() => stock('Papa Pastusa'), (v) => v == 50); });
    // Sin internet (sin sincronizar): cada una vende por su lado
    await usar('caja1');
    await vender('Papa Pastusa', 7);
    await vender('Papa Pastusa', 1.5);
    await usar('caja2');
    await vender('Papa Pastusa', 4);
    // Vuelve el internet
    await enCaja('caja1', (s) async {});
    await enCaja('caja2', (s) async {
      expect(await esperar(() => stock('Papa Pastusa'), (v) => v == 37.5), 37.5);
    });
    await enCaja('caja1', (s) async {
      expect(await esperar(() => stock('Papa Pastusa'), (v) => v == 37.5), 37.5);
      expect(await esperar(() => contar('ventas'), (n) => n == 3), 3);
    });
    final pu = (await producto('Papa Pastusa'))['uuid'] as String;
    final recon = (await nube.collection('negocios').doc(negocio).collection('productos').doc(pu).get())
        .data()!['stock_recon'];
    expect(recon, 37.5, reason: 'el stock de la nube también cuadra');
  });

  test('Un producto editado en las dos cajas queda con el cambio más reciente', () async {
    await enCaja('caja1', (s) async { await darStock('Papa Pastusa', 5); });
    await enCaja('caja2', (s) async { await esperar(() => stock('Papa Pastusa'), (v) => v == 5); });
    Future<void> cambiarPrecio(double precio) async {
      final p = await producto('Papa Pastusa');
      final d = await db.database;
      await d.update('productos', {'precio_venta': precio}, where: 'id = ?', whereArgs: [p['id']]);
      await db.encolarProductoCambio({...p, 'precio_venta': precio});
    }
    await usar('caja1');
    await cambiarPrecio(2500);
    await Future.delayed(const Duration(milliseconds: 20));
    await usar('caja2');
    await cambiarPrecio(2700); // posterior
    await enCaja('caja2', (s) async {});
    await enCaja('caja1', (s) async {
      expect((await esperar(() => producto('Papa Pastusa'), (p) => p['precio_venta'] == 2700))['precio_venta'], 2700);
    });
    await enCaja('caja2', (s) async {
      await Future.delayed(const Duration(milliseconds: 500));
      expect((await producto('Papa Pastusa'))['precio_venta'], 2700);
      expect(await stock('Papa Pastusa'), 5, reason: 'editar no toca el stock');
    });
  });

  test('Subida inicial de un equipo que ya tenía datos: lleva la foto y los paquetes', () async {
    await usar('caja1');
    await db.guardarConfiguracion('sync_activo', '0');
    final foto = File('${dir.path}/foto_papa.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    final id = await db.insertProduct({
      'nombre': 'Papa Criolla', 'precio_costo': 1500, 'precio_venta': 3000, 'stock_actual': 12,
      'imagen_path': foto.path,
    });
    await db.agregarPresentacion(id, 'Bulto x 5', 5, 14000);
    await db.descartarPendientes(); // como si la sincronización nunca hubiera estado prendida
    await db.guardarConfiguracion('sync_activo', '1');

    await db.prepararParaSincronizar(await db.obtenerDispositivoUuid());
    final pend = (await db.obtenerPendientes())
        .where((p) => p['tipo'] == 'PRODUCTO')
        .map((p) => jsonDecode(p['datos'] as String) as Map<String, dynamic>)
        .firstWhere((d) => d['nombre'] == 'Papa Criolla');
    expect(pend['imagen_path_local'], foto.path, reason: 'la foto debe ir a Cloudinary');
    expect((pend['presentaciones'] as List).single['nombre'], 'Bulto x 5');
    expect(pend['semilla'], isTrue);

    // Al sincronizar intenta subir la foto (en las pruebas no hay internet:
    // queda en la cola de reintento) y el producto llega a la nube con su paquete.
    final s = SyncService.paraPruebas(nube, copias: copias());
    await s.iniciar(negocioId: negocio, usuarioUid: 'uid-ana');
    try {
      final pu = (await producto('Papa Criolla'))['uuid'] as String;
      final doc = await esperar(
          () => nube.collection('negocios').doc(negocio).collection('productos').doc(pu).get(),
          (d) => d.exists);
      expect((doc.data()!['presentaciones'] as List).single['cantidad'], 5);
      expect(s.imagenesPorSubir.any((e) => e.startsWith(pu)), isTrue);
    } finally {
      await s.detener();
    }
  });

  test('Editar el precio de un producto con foto no vuelve a subir la foto', () async {
    await enCaja('caja1', (s) async {
      final foto = File('${dir.path}/uva.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
      final id = await db.insertProduct({'nombre': 'Uva Isabela', 'precio_costo': 3000, 'precio_venta': 6000, 'stock_actual': 4, 'imagen_path': foto.path});
      final d = await db.database;
      final p = (await d.query('productos', where: 'id = ?', whereArgs: [id])).single;
      // La foto ya se había subido antes a Cloudinary
      await db.guardarConfiguracion('img_url_${p['uuid']}', 'https://res.cloudinary.com/x/uva_1.jpg');
      await db.guardarConfiguracion('img_local_${p['uuid']}', foto.path);
      await d.update('productos', {'precio_venta': 6500}, where: 'id = ?', whereArgs: [id]);
      await db.encolarProductoCambio({...p, 'precio_venta': 6500});
      await esperar(() async {
        await s.sincronizarAhora();
        return (await db.obtenerPendientes()).length;
      }, (n) => n == 0);
      final doc = (await nube.collection('negocios').doc(negocio).collection('productos').doc(p['uuid'] as String).get()).data()!;
      expect(doc['precio_venta'], 6500);
      expect(doc['imagen_url'], 'https://res.cloudinary.com/x/uva_1.jpg');
      expect(s.imagenesPorSubir, isEmpty, reason: 'no hubo intento de subir la foto otra vez');
    });
  });

  test('Una caja: la foto nueva queda pendiente sin internet y lo demás se descarta', () async {
    await enCaja('caja1', (s) async {
      final foto = File('${dir.path}/foto.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
      await db.insertProduct({'nombre': 'Mango Tommy', 'precio_costo': 1000, 'precio_venta': 2500, 'stock_actual': 8, 'imagen_path': foto.path});
      await darStock('Papa Pastusa', 20);
      await vender('Papa Pastusa', 2);
      await s.sincronizarAhora();
      final pend = await db.obtenerPendientes();
      expect(pend.length, 1, reason: 'solo la foto queda esperando internet');
      expect(jsonDecode(pend.single['datos'] as String)['nombre'], 'Mango Tommy');
    }, modo: una);
    for (final c in ['productos', 'ventas', 'stock_ops']) {
      expect((await nube.collection('negocios').doc(negocio).collection(c).get()).docs, isEmpty);
    }
  });

  test('Copia con un abono sin subir: la caja nueva no descuenta la deuda dos veces', () async {
    int clienteId = 0;
    await enCaja('caja1', (s) async {
      await darStock('Papa Pastusa', 100);
      clienteId = await db.crearCliente({'nombre': 'Don Pedro', 'telefono': '310', 'direccion': 'Plaza'});
      await db.actualizarClienteCupo(clienteId, 100000);
      await vender('Papa Pastusa', 15, metodo: 'CREDITO', clienteId: clienteId); // 30.000
    });
    // Sin internet: abono de 10.000 y en ese momento se hace la copia
    await usar('caja1');
    await abrirCaja();
    expect((await db.registrarAbonoCliente(clienteId, 'Don Pedro', 10000, usuarioId: 1))['exito'], isTrue);
    expect(await copias().subir(negocioId: negocio), isNull);
    await enCaja('caja1', (s) async {}); // vuelve el internet y sube el abono

    await usar('caja2');
    await copias().restaurar(negocioId: negocio, cajaNueva: true, modoSync: varias, nombreCaja: 'Caja 2');
    dbs['caja2'] = await db.database;
    expect((await cliente('Don Pedro'))['deuda_actual'], 20000);
    await enCaja('caja2', (s) async {
      await Future.delayed(const Duration(milliseconds: 1200));
      expect((await cliente('Don Pedro'))['deuda_actual'], 20000);
      expect(await contar('movimientos_cartera'), 2);
    });
  });
}
