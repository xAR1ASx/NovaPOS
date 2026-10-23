@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/database/db_helper.dart';
import 'package:novapos/services/copia_nube_service.dart';
import 'package:novapos/services/permission_service.dart';
import 'package:novapos/services/role_permissions.dart';
import 'package:novapos/services/session_service.dart';
import 'package:novapos/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Modo una caja / varias cajas y copia diaria en la nube: cada caja tiene
/// su propia base y todas usan la misma nube simulada.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const negocio = 'negocio-prueba';
  const una = SyncService.modoUnaCaja;
  const varias = SyncService.modoMulticaja;
  late FakeFirebaseFirestore nube;
  late Directory dir;
  final dbs = <String, Database>{};
  final db = DBHelper();

  setUp(() async {
    nube = FakeFirebaseFirestore();
    dir = await Directory.systemTemp.createTemp('novapos_copia_nube_');
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

  /// Pedazos de 4 KB: así una base de prueba ya ocupa varios.
  CopiaNubeService copias() => CopiaNubeService.paraPruebas(nube, dir, tamanoParte: 4096);

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

  /// Este equipo pasa a ser la caja [nombre] (sin prender la sincronización).
  Future<void> usar(String nombre) async {
    if (dbs[nombre] == null) {
      DBHelper.setDatabaseForTesting(null);
      dbs[nombre] = await db.abrirArchivoParaPruebas('${dir.path}/$nombre.db');
    }
    DBHelper.setDatabaseForTesting(dbs[nombre]);
  }

  /// Prende la caja [nombre] en el [modo] dado, ejecuta [accion] y la apaga
  /// (con varias cajas, después de subir todo lo pendiente).
  Future<void> enCaja(String nombre, String modo, Future<void> Function(SyncService s) accion) async {
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

  Future<void> vender(String nombre, double cant) async {
    if (!await db.verificarCajaAbiertaHoy()) {
      await db.registrarMovimientoCaja('APERTURA', 10000, 'Base', 1);
    }
    final p = await producto(nombre);
    final r = await db.registrarVenta(cant * 2000, 'EFECTIVO', [
      {'id': p['id'], 'nombre': nombre, 'cantidad': cant, 'precio': 2000, 'subtotal': cant * 2000, 'costo_unitario': 1000}
    ], usuarioId: 1);
    expect(r['exito'], isTrue, reason: r['mensaje']?.toString());
  }

  Future<int> contar(String tabla) async {
    final d = await db.database;
    return (await d.rawQuery('SELECT COUNT(*) AS n FROM $tabla')).first['n'] as int;
  }

  DocumentReference<Map<String, dynamic>> indice() =>
      nube.collection('negocios').doc(negocio).collection('respaldos').doc('indice');

  Future<int> enNube(String coleccion) async =>
      (await nube.collection('negocios').doc(negocio).collection(coleccion).get()).docs.length;

  Future<List<String>> partesEnNube() async =>
      (await indice().collection('partes').get()).docs.map((d) => d.id).toList();

  /// Negocio con catálogo y algo vendido en la caja [nombre], sin sincronizar.
  Future<void> negocioConVentas(String nombre, {double stockPapa = 50, int ventas = 2}) async {
    await usar(nombre);
    await db.precargarCatalogoMaestro();
    await darStock('Papa Pastusa', stockPapa);
    for (var i = 0; i < ventas; i++) {
      await vender('Papa Pastusa', 1);
    }
  }

  group('Copia en la nube', () {
    test('Sube en pedazos, baja idéntica y la nueva reemplaza a la anterior', () async {
      await negocioConVentas('caja1');
      expect(await copias().subir(negocioId: negocio), isNull);

      final primera = InfoCopiaNube.desde((await indice().get()).data())!;
      expect(primera.partes, greaterThan(1), reason: 'con pedazos de 4 KB debe ocupar varios');
      expect((await partesEnNube()).length, primera.partes);
      final cfg = await db.obtenerConfiguracion();
      expect(cfg['copia_nube_pendiente'], '0');
      expect(cfg['copia_nube_ultima'], isNotEmpty);

      // Lo que baja es exactamente la base de la caja
      final ruta = await copias().descargar(negocio, primera);
      final copia = await databaseFactory.openDatabase(ruta, options: OpenDatabaseOptions(readOnly: true));
      expect((await copia.rawQuery('SELECT COUNT(*) AS n FROM ventas')).first['n'], 2);
      await copia.close();

      // Al día siguiente: otra venta y otra copia. En la nube queda solo la nueva.
      await Future.delayed(const Duration(milliseconds: 5));
      await vender('Papa Pastusa', 1);
      expect(await copias().subir(negocioId: negocio), isNull);
      final segunda = InfoCopiaNube.desde((await indice().get()).data())!;
      expect(segunda.copiaId, isNot(primera.copiaId));
      final partes = await partesEnNube();
      expect(partes.length, segunda.partes);
      expect(partes.every((id) => id.startsWith(segunda.copiaId)), isTrue);
    });

    test('Los pedazos de una subida que se cortó se borran en la siguiente', () async {
      await negocioConVentas('caja1');
      expect(await copias().subir(negocioId: negocio), isNull);
      final vigente = InfoCopiaNube.desde((await indice().get()).data())!;

      // Simula una subida cortada a mitad: dos pedazos sueltos y el índice
      // sigue apuntando a la copia buena (no se pierde).
      for (var i = 0; i < 2; i++) {
        await indice().collection('partes').doc('cortada_$i').set({
          'copia_id': 'cortada',
          'parte': i,
          'datos': Blob(Uint8List.fromList([1, 2, 3])),
        });
      }
      await db.guardarConfiguracion('copia_nube_intento', 'cortada|2');
      expect(InfoCopiaNube.desde((await indice().get()).data())!.copiaId, vigente.copiaId);

      await Future.delayed(const Duration(milliseconds: 5));
      expect(await copias().subir(negocioId: negocio), isNull);
      final nueva = InfoCopiaNube.desde((await indice().get()).data())!;
      final partes = await partesEnNube();
      expect(partes.any((id) => id.startsWith('cortada')), isFalse);
      expect(partes.any((id) => id.startsWith(vigente.copiaId)), isFalse);
      expect(partes.length, nueva.partes);
    });

    test('Dos cajas que suben copia al mismo tiempo no dejan copias huérfanas', () async {
      await negocioConVentas('caja1');
      expect(await copias().subir(negocioId: negocio), isNull);
      final propia = InfoCopiaNube.desde((await indice().get()).data())!;

      // Otra caja subió la suya justo después: el índice apunta a ella y la
      // de la caja 1 quedó sin borrar.
      for (var i = 0; i < 2; i++) {
        await indice().collection('partes').doc('otra_$i').set({
          'copia_id': 'otra', 'parte': i, 'datos': Blob(Uint8List.fromList([9])),
        });
      }
      await indice().update({'copia_id': 'otra', 'partes': 2});
      expect((await partesEnNube()).any((id) => id.startsWith(propia.copiaId)), isTrue);

      // En el siguiente cierre de la caja 1 queda solo su copia nueva.
      await Future.delayed(const Duration(milliseconds: 5));
      expect(await copias().subir(negocioId: negocio), isNull);
      final nueva = InfoCopiaNube.desde((await indice().get()).data())!;
      final partes = await partesEnNube();
      expect(partes.length, nueva.partes);
      expect(partes.every((id) => id.startsWith(nueva.copiaId)), isTrue);
    });

    test('Una copia dañada o de una versión más nueva no se restaura y la base no cambia', () async {
      await negocioConVentas('caja1');
      expect(await copias().subir(negocioId: negocio), isNull);
      final info = InfoCopiaNube.desde((await indice().get()).data())!;

      await negocioConVentas('caja2', ventas: 0);
      // Pedazo alterado: no coincide la huella (sha256)
      await indice().collection('partes').doc('${info.copiaId}_0').update({
        'datos': Blob(Uint8List.fromList(List.filled(4096, 7))),
      });
      await expectLater(
        copias().restaurar(negocioId: negocio, cajaNueva: true, modoSync: varias),
        throwsA(isA<CopiaNubeException>()),
      );
      expect(await contar('ventas'), 0);
      expect(await db.equipoSinDatos(), isTrue);

      // Copia hecha con una versión más nueva de NovaPOS
      await indice().update({'version_bd': DBHelper.versionBaseDatos + 1});
      await expectLater(
        copias().restaurar(negocioId: negocio, cajaNueva: true, modoSync: varias),
        throwsA(isA<CopiaNubeException>()),
      );
      expect(await contar('ventas'), 0);
    });

    test('Sin copia en la nube no hay nada que restaurar', () async {
      await usar('caja1');
      expect(await copias().leerIndice(negocio), isNull);
      await expectLater(
        copias().restaurar(negocioId: negocio, cajaNueva: false, modoSync: una),
        throwsA(isA<CopiaNubeException>()),
      );
    });
  });

  group('Una sola caja', () {
    test('No sube nada en vivo y en el equipo no se pierde nada', () async {
      await enCaja('caja1', una, (s) async {
        expect(s.unaCaja, isTrue);
        await darStock('Papa Pastusa', 50);
        await vender('Papa Pastusa', 3);
        await db.crearCliente({'nombre': 'Doña Rosa', 'telefono': '300', 'direccion': 'Centro'});
        await s.sincronizarAhora();
        expect(await db.obtenerPendientes(), isEmpty);
      });
      for (final c in ['productos', 'ventas', 'stock_ops', 'clientes', 'caja_movimientos']) {
        expect(await enNube(c), 0, reason: 'con una caja no se escribe $c en la nube');
      }
      expect(await stock('Papa Pastusa'), 47);
      expect(await contar('ventas'), 1);
      final cfg = await db.obtenerConfiguracion();
      expect(cfg['modo_sync_aplicado'], una);
    });

    test('Un PC nuevo que reemplaza a la caja la trae completa, con la misma caja', () async {
      await negocioConVentas('caja1', ventas: 3);
      await db.guardarConfiguracion('modo_sync_aplicado', una);
      await db.guardarConfiguracion('caja_nombre', 'Caja principal');
      final cajaVieja = await db.obtenerDispositivoUuid();
      expect(await copias().subir(negocioId: negocio), isNull);
      expect(InfoCopiaNube.desde((await indice().get()).data())!.multicaja, isFalse);

      await usar('pc_nuevo');
      expect(await db.equipoSinDatos(), isTrue);
      await copias().restaurar(negocioId: negocio, cajaNueva: false, modoSync: una);
      dbs['pc_nuevo'] = await db.database;
      expect(await contar('ventas'), 3);
      expect(await stock('Papa Pastusa'), 47);
      expect(await db.obtenerDispositivoUuid(), cajaVieja);
      expect(await db.verificarCajaAbiertaHoy(), isTrue, reason: 'sigue el mismo turno de la caja');
      expect(await db.equipoSinDatos(), isFalse);
    });
  });

  group('Varias cajas', () {
    test('De una caja a varias: la caja nueva trae todo y nada se cuenta dos veces', () async {
      // Etapa una caja: vende sin subir nada
      await enCaja('caja1', una, (s) async {
        await darStock('Papa Pastusa', 50);
        await vender('Papa Pastusa', 4);
        await db.guardarConfiguracion('caja_nombre', 'Caja 1');
      });
      expect(await stock('Papa Pastusa'), 46);
      expect(await copias().subir(negocioId: negocio), isNull);
      expect(InfoCopiaNube.desde((await indice().get()).data())!.multicaja, isFalse);

      // Una caja nueva no puede arrancar hasta que la principal prepare la nube
      // (la pantalla de ingreso lo impide; aquí se verifica la marca).
      // El proveedor cambia a varias cajas: la caja 1 sube productos y
      // clientes con sus valores exactos y una copia nueva.
      await enCaja('caja1', varias, (s) async {
        final info = await esperar(
          () async => InfoCopiaNube.desde((await indice().get()).data()),
          (InfoCopiaNube? i) => i != null && i.multicaja,
          intentos: 200,
        );
        expect(info!.multicaja, isTrue);
      });
      final papaNube = (await nube.collection('negocios').doc(negocio).collection('productos')
              .doc((await producto('Papa Pastusa'))['uuid'] as String).get())
          .data()!;
      expect(papaNube['stock_recon'], 46);
      expect(await enNube('ventas'), 0, reason: 'el historial no se sube venta por venta');
      final caja1 = await db.obtenerDispositivoUuid();

      // Caja 2: equipo vacío, trae la copia
      await usar('caja2');
      expect(await db.equipoSinDatos(), isTrue);
      await copias().restaurar(negocioId: negocio, cajaNueva: true, modoSync: varias, nombreCaja: 'Caja 2');
      dbs['caja2'] = await db.database;
      expect(await contar('ventas'), 1);
      expect(await stock('Papa Pastusa'), 46);
      expect(await db.obtenerDispositivoUuid(), isNot(caja1));
      expect((await db.obtenerConfiguracion())['caja_nombre'], 'Caja 2');
      expect(await db.verificarCajaAbiertaHoy(), isFalse, reason: 'el cajón de la caja 2 empieza vacío');
      expect(await db.obtenerPendientes(), isEmpty);

      // Caja 2 sincroniza: no cuenta otra vez nada de la copia, y vende 1
      await enCaja('caja2', varias, (s) async {
        await Future.delayed(const Duration(milliseconds: 800));
        expect(await stock('Papa Pastusa'), 46);
        await vender('Papa Pastusa', 1);
      });
      expect(await stock('Papa Pastusa'), 45);

      // Caja 1 recibe la venta de la caja 2 y vende 2
      await enCaja('caja1', varias, (s) async {
        expect(await esperar(() => stock('Papa Pastusa'), (v) => v == 45), 45);
        await vender('Papa Pastusa', 2);
      });
      expect(await stock('Papa Pastusa'), 43);
      expect(await contar('ventas'), 3);

      // Caja 2 recibe la de la caja 1 (una sola vez)
      await enCaja('caja2', varias, (s) async {
        expect(await esperar(() => stock('Papa Pastusa'), (v) => v == 43), 43);
        await Future.delayed(const Duration(milliseconds: 500));
        expect(await stock('Papa Pastusa'), 43);
        expect(await contar('ventas'), 3);
      });
    });

    test('Ventas que no alcanzaron a subir antes de la copia no se duplican en la caja nueva', () async {
      await enCaja('caja1', varias, (s) async {
        await darStock('Papa Pastusa', 30);
      });
      // La caja 1 vende sin internet y en ese momento se hace la copia
      await usar('caja1');
      await vender('Papa Pastusa', 5);
      expect(await db.obtenerPendientes(), isNotEmpty);
      expect(await copias().subir(negocioId: negocio), isNull);
      // Vuelve el internet: sube la venta
      await enCaja('caja1', varias, (s) async {});
      expect(await enNube('ventas'), 1);

      await usar('caja2');
      await copias().restaurar(negocioId: negocio, cajaNueva: true, modoSync: varias, nombreCaja: 'Caja 2');
      dbs['caja2'] = await db.database;
      await enCaja('caja2', varias, (s) async {
        await Future.delayed(const Duration(milliseconds: 1200));
        expect(await stock('Papa Pastusa'), 25);
        expect(await contar('ventas'), 1);
      });
    });

    test('Un cambio de precio posterior a la copia llega a la caja nueva', () async {
      await enCaja('caja1', varias, (s) async {
        await darStock('Papa Pastusa', 20);
      });
      await usar('caja1');
      expect(await copias().subir(negocioId: negocio), isNull);

      await usar('caja2');
      await copias().restaurar(negocioId: negocio, cajaNueva: true, modoSync: varias, nombreCaja: 'Caja 2');
      dbs['caja2'] = await db.database;

      await Future.delayed(const Duration(milliseconds: 5));
      await enCaja('caja1', varias, (s) async {
        final p = await producto('Papa Pastusa');
        final d = await db.database;
        await d.update('productos', {'precio_venta': 3500}, where: 'id = ?', whereArgs: [p['id']]);
        await db.encolarProductoCambio({...p, 'precio_venta': 3500});
      });
      await enCaja('caja2', varias, (s) async {
        final p = await esperar(() => producto('Papa Pastusa'), (p) => p['precio_venta'] == 3500);
        expect(p['precio_venta'], 3500);
        expect(await stock('Papa Pastusa'), 20, reason: 'el stock no se reemplaza');
      });
    });
  });
}
