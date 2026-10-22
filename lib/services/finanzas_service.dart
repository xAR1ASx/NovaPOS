import 'dart:convert';

import '../database/db_helper.dart';
import '../utils/categorias_caja.dart';

/// Período de un reporte: días completos de [desde] a [hasta] (incluidos).
class Periodo {
  final DateTime desde;
  final DateTime hasta;
  Periodo(DateTime desde, DateTime hasta)
      : desde = DateTime(desde.year, desde.month, desde.day),
        hasta = DateTime(hasta.year, hasta.month, hasta.day);

  String get inicioIso => desde.toIso8601String();
  String get finExclusivoIso =>
      DateTime(hasta.year, hasta.month, hasta.day + 1).toIso8601String();
  int get dias => hasta.difference(desde).inDays + 1;

  /// El período de igual duración justo antes de este (para comparar).
  Periodo get anterior => Periodo(
        DateTime(desde.year, desde.month, desde.day - dias),
        DateTime(desde.year, desde.month, desde.day - 1),
      );

  List<DateTime> get listaDias =>
      List.generate(dias, (i) => DateTime(desde.year, desde.month, desde.day + i));
}

String _clave(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _diaDe(String? iso) => (iso ?? '').length >= 10 ? iso!.substring(0, 10) : '';

double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Una fila agregada: nombre, cantidad de veces y total.
class Grupo {
  final String clave;
  final String nombre;
  final int cantidad;
  final double total;
  const Grupo(this.clave, this.nombre, this.cantidad, this.total);
}

class DiaFinanzas {
  final DateTime fecha;
  final double ventas;
  final double costo;
  final double gastos;
  final double mermas;
  const DiaFinanzas(this.fecha, this.ventas, this.costo, this.gastos, this.mermas);
  double get utilidad => ventas - costo - gastos - mermas;
  bool get sinMovimiento => ventas == 0 && costo == 0 && gastos == 0 && mermas == 0;
}

/// Estado de resultados del período (vista de gestión, no contable).
class Resultados {
  final Periodo periodo;
  final double ventas;
  final int cantidadVentas;
  final double costoVentas;
  final double gastos;
  final double mermas;
  final double faltantesCaja;
  final double sobrantesCaja;
  final double devoluciones;
  final int cantidadDevoluciones;
  final double anuladas;
  final int cantidadAnuladas;
  final double prestamos;
  final double retiros;
  final double compras;
  final int cantidadCompras;
  final double ventasFiadas;
  final double abonosClientes;
  final double ventasSinCosto;
  final List<DiaFinanzas> diario;
  final double ventasAnterior;
  final double utilidadAnterior;

  const Resultados({
    required this.periodo,
    required this.ventas,
    required this.cantidadVentas,
    required this.costoVentas,
    required this.gastos,
    required this.mermas,
    required this.faltantesCaja,
    required this.sobrantesCaja,
    required this.devoluciones,
    required this.cantidadDevoluciones,
    required this.anuladas,
    required this.cantidadAnuladas,
    required this.prestamos,
    required this.retiros,
    required this.compras,
    required this.cantidadCompras,
    required this.ventasFiadas,
    required this.abonosClientes,
    required this.ventasSinCosto,
    required this.diario,
    required this.ventasAnterior,
    required this.utilidadAnterior,
  });

  double get utilidadBruta => ventas - costoVentas;
  double get descuadreNeto => faltantesCaja - sobrantesCaja;
  double get utilidadNeta => utilidadBruta - gastos - mermas - descuadreNeto;
  double get margenBruto => ventas > 0 ? utilidadBruta / ventas * 100 : 0;
  double get margenNeto => ventas > 0 ? utilidadNeta / ventas * 100 : 0;
  double get ticketPromedio => cantidadVentas > 0 ? ventas / cantidadVentas : 0;
  bool get vacio => ventas == 0 && costoVentas == 0 && gastos == 0 && mermas == 0 && compras == 0;

  /// Variación porcentual frente al período anterior (null si no hay base).
  double? get variacionVentas =>
      ventasAnterior > 0 ? (ventas - ventasAnterior) / ventasAnterior * 100 : null;
  double? get variacionUtilidad => utilidadAnterior.abs() > 0
      ? (utilidadNeta - utilidadAnterior) / utilidadAnterior.abs() * 100
      : null;
}

class GastoDetalle {
  final DateTime? fecha;
  final String categoria;
  final String descripcion;
  final double monto;
  final String usuario;
  const GastoDetalle(this.fecha, this.categoria, this.descripcion, this.monto, this.usuario);
}

/// Gastos, compras y flujo de efectivo del período.
class GastosCompras {
  final List<Grupo> gastosPorCategoria;
  final List<GastoDetalle> gastos;
  final List<Grupo> salidasNoGasto;
  final List<Grupo> comprasPorProveedor;
  final double totalCompras;
  final double comprasConCaja;
  final List<Grupo> metodosPago;
  // Flujo de efectivo (todas las cajas)
  final double entroVentas;
  final double entroAbonos;
  final double entroOtros;
  final double salioGastos;
  final double salioCompras;
  final double salioDevoluciones;
  final double salioPrestamosRetiros;

  const GastosCompras({
    required this.gastosPorCategoria,
    required this.gastos,
    required this.salidasNoGasto,
    required this.comprasPorProveedor,
    required this.totalCompras,
    required this.comprasConCaja,
    required this.metodosPago,
    required this.entroVentas,
    required this.entroAbonos,
    required this.entroOtros,
    required this.salioGastos,
    required this.salioCompras,
    required this.salioDevoluciones,
    required this.salioPrestamosRetiros,
  });

  double get totalGastos => gastosPorCategoria.fold(0.0, (a, g) => a + g.total);
  double get totalEntradas => entroVentas + entroAbonos + entroOtros;
  double get totalSalidas => salioGastos + salioCompras + salioDevoluciones + salioPrestamosRetiros;
  double get flujoNeto => totalEntradas - totalSalidas;
}

class Rentable {
  final String nombre;
  final double cantidad;
  final double ventas;
  final double costo;
  final bool sinCosto;
  const Rentable(this.nombre, this.cantidad, this.ventas, this.costo, this.sinCosto);
  double get utilidad => ventas - costo;
  double get margen => ventas > 0 ? utilidad / ventas * 100 : 0;
}

class Rentabilidad {
  final List<Rentable> categorias;
  final List<Rentable> productos;
  const Rentabilidad(this.categorias, this.productos);
  List<Rentable> get masUtilidad =>
      (List.of(productos.where((p) => !p.sinCosto))..sort((a, b) => b.utilidad.compareTo(a.utilidad)))
          .take(15)
          .toList();
  /// Productos que dejan poco o pierden (margen < 10 %).
  List<Rentable> get margenBajo =>
      (List.of(productos.where((p) => !p.sinCosto && p.ventas > 0 && p.margen < 10))
            ..sort((a, b) => a.margen.compareTo(b.margen)))
          .take(15)
          .toList();
  List<Rentable> get sinCosto => productos.where((p) => p.sinCosto).toList();
}

/// Un evento de control: anulación, devolución, merma o descuadre.
class EventoControl {
  final String tipo; // ANULACION | DEVOLUCION | MERMA | DESCUADRE
  final DateTime? fecha;
  final String titulo;
  final String detalle;
  final double monto;
  final double efectivo;
  final String usuario;
  final String motivo;
  const EventoControl({
    required this.tipo,
    required this.fecha,
    required this.titulo,
    required this.detalle,
    required this.monto,
    this.efectivo = 0,
    required this.usuario,
    required this.motivo,
  });
}

class ResumenPersona {
  final String usuario;
  final Map<String, int> porTipo;
  final double monto;
  const ResumenPersona(this.usuario, this.porTipo, this.monto);
  int get total => porTipo.values.fold(0, (a, b) => a + b);
}

class Control {
  final List<EventoControl> eventos;
  const Control(this.eventos);
  static const tipos = ['ANULACION', 'DEVOLUCION', 'MERMA', 'DESCUADRE'];
  int cantidad(String tipo) => eventos.where((e) => e.tipo == tipo).length;
  double monto(String tipo) =>
      eventos.where((e) => e.tipo == tipo).fold(0.0, (a, e) => a + e.monto);
  List<ResumenPersona> get porPersona {
    final mapa = <String, Map<String, int>>{};
    final montos = <String, double>{};
    for (final e in eventos) {
      final m = mapa.putIfAbsent(e.usuario, () => {for (final t in tipos) t: 0});
      m[e.tipo] = (m[e.tipo] ?? 0) + 1;
      montos[e.usuario] = (montos[e.usuario] ?? 0) + e.monto;
    }
    return mapa.entries.map((e) => ResumenPersona(e.key, e.value, montos[e.key] ?? 0)).toList()
      ..sort((a, b) => b.monto.compareTo(a.monto));
  }
}

class CierreAuditoria {
  final int id;
  final String cajero;
  final String caja;
  final bool estaCaja;
  final DateTime? apertura;
  final DateTime? cierre;
  final double base;
  final double ventas;
  final double ingresos;
  final double gastos;
  final double esperado;
  final double? contado;
  final double? diferencia;
  final String estado; // ABIERTO | CUADRADO | FALTANTE | SOBRANTE
  final Map<String, double> metodos;
  final String? dispositivo;
  const CierreAuditoria({
    required this.id,
    required this.cajero,
    required this.caja,
    required this.estaCaja,
    required this.apertura,
    required this.cierre,
    required this.base,
    required this.ventas,
    required this.ingresos,
    required this.gastos,
    required this.esperado,
    required this.contado,
    required this.diferencia,
    required this.estado,
    required this.metodos,
    required this.dispositivo,
  });
}

class ResumenCajero {
  final String cajero;
  final int turnos;
  final int cuadrados;
  final double faltante;
  final double sobrante;
  final double ventas;
  const ResumenCajero(this.cajero, this.turnos, this.cuadrados, this.faltante, this.sobrante, this.ventas);
  double get neto => sobrante - faltante;
}

class Cierres {
  final List<CierreAuditoria> cierres;
  const Cierres(this.cierres);
  double get totalFaltante => cierres.fold(0.0, (a, c) => a + ((c.diferencia ?? 0) < 0 && c.estado == 'FALTANTE' ? -c.diferencia! : 0));
  double get totalSobrante => cierres.fold(0.0, (a, c) => a + ((c.diferencia ?? 0) > 0 && c.estado == 'SOBRANTE' ? c.diferencia! : 0));
  int contar(String estado) => cierres.where((c) => c.estado == estado).length;
  List<ResumenCajero> get porCajero {
    final m = <String, List<CierreAuditoria>>{};
    for (final c in cierres) {
      m.putIfAbsent(c.cajero, () => []).add(c);
    }
    return m.entries.map((e) {
      final l = e.value;
      return ResumenCajero(
        e.key,
        l.length,
        l.where((c) => c.estado == 'CUADRADO').length,
        l.fold(0.0, (a, c) => a + (c.estado == 'FALTANTE' ? -(c.diferencia ?? 0) : 0)),
        l.fold(0.0, (a, c) => a + (c.estado == 'SOBRANTE' ? (c.diferencia ?? 0) : 0)),
        l.fold(0.0, (a, c) => a + c.ventas),
      );
    }).toList()
      ..sort((a, b) => b.faltante.compareTo(a.faltante));
  }
}

class MovimientoTurno {
  final DateTime? fecha;
  final String tipo;
  final String categoria;
  final String descripcion;
  final double monto;
  final String usuario;
  const MovimientoTurno(this.fecha, this.tipo, this.categoria, this.descripcion, this.monto, this.usuario);
}

/// Ventas por día de la semana y hora.
class HorasPico {
  /// [diaSemana 1..7][hora 0..23] = ventas
  final List<List<double>> celdas;
  final List<List<int>> tickets;
  final List<int> vecesDia; // cuántos lunes, martes... tiene el período
  const HorasPico(this.celdas, this.tickets, this.vecesDia);
  double get maximo => celdas.expand((f) => f).fold(0.0, (a, b) => b > a ? b : a);
  List<double> get porHora => List.generate(24, (h) => List.generate(7, (d) => celdas[d][h]).fold(0.0, (a, b) => a + b));
  List<double> get promedioDia => List.generate(7, (d) {
        final t = celdas[d].fold(0.0, (a, b) => a + b);
        return vecesDia[d] > 0 ? t / vecesDia[d] : 0;
      });
  int? get horaPico {
    final p = porHora;
    double m = 0;
    int? h;
    for (var i = 0; i < 24; i++) {
      if (p[i] > m) {
        m = p[i];
        h = i;
      }
    }
    return h;
  }

  int? get diaPico {
    final p = promedioDia;
    double m = 0;
    int? d;
    for (var i = 0; i < 7; i++) {
      if (p[i] > m) {
        m = p[i];
        d = i;
      }
    }
    return d;
  }
}

/// Cálculos del Centro Financiero sobre la base local (que, con la
/// sincronización activa, tiene los datos de todas las cajas del negocio).
/// Solo lee: no modifica nada.
class FinanzasService {
  final DBHelper _db;
  FinanzasService([DBHelper? db]) : _db = db ?? DBHelper();

  static const double toleranciaCuadre = 1;

  Future<Map<int, String>> _usuarios() async {
    final db = await _db.database;
    final filas = await db.query('usuarios', columns: ['id', 'nombre_completo', 'usuario']);
    return {
      for (final f in filas)
        f['id'] as int: ((f['nombre_completo'] ?? '').toString().trim().isNotEmpty
            ? f['nombre_completo'].toString()
            : (f['usuario'] ?? 'Usuario').toString()),
    };
  }

  String _nombre(Map<int, String> u, Object? id) {
    final i = (id as num?)?.toInt();
    if (i == null || i == 0) return 'Sin registrar';
    return u[i] ?? 'Usuario #$i';
  }

  String _filtroUsuario(int? usuarioId, [String alias = '']) =>
      usuarioId == null ? '' : ' AND ${alias}usuario_id = $usuarioId';

  // ------------------------------------------------------------ RESULTADOS
  Future<Resultados> resultados(Periodo p, {int? usuarioId}) async {
    final base = await _resultadosBase(p, usuarioId: usuarioId, conDiario: true);
    final ant = await _resultadosBase(p.anterior, usuarioId: usuarioId, conDiario: false);
    return Resultados(
      periodo: p,
      ventas: base.ventas,
      cantidadVentas: base.cantidadVentas,
      costoVentas: base.costoVentas,
      gastos: base.gastos,
      mermas: base.mermas,
      faltantesCaja: base.faltantesCaja,
      sobrantesCaja: base.sobrantesCaja,
      devoluciones: base.devoluciones,
      cantidadDevoluciones: base.cantidadDevoluciones,
      anuladas: base.anuladas,
      cantidadAnuladas: base.cantidadAnuladas,
      prestamos: base.prestamos,
      retiros: base.retiros,
      compras: base.compras,
      cantidadCompras: base.cantidadCompras,
      ventasFiadas: base.ventasFiadas,
      abonosClientes: base.abonosClientes,
      ventasSinCosto: base.ventasSinCosto,
      diario: base.diario,
      ventasAnterior: ant.ventas,
      utilidadAnterior: ant.utilidadNeta,
    );
  }

  Future<Resultados> _resultadosBase(Periodo p, {int? usuarioId, required bool conDiario}) async {
    final db = await _db.database;
    final a = [p.inicioIso, p.finExclusivoIso];
    final fu = _filtroUsuario(usuarioId);
    final fuv = _filtroUsuario(usuarioId, 'v.');

    final dias = <String, List<double>>{}; // ventas, costo, gastos, mermas
    List<double> dia(String k) => dias.putIfAbsent(k, () => [0, 0, 0, 0]);

    final ventas = await db.rawQuery(
      'SELECT fecha, total, metodo_pago FROM ventas WHERE fecha >= ? AND fecha < ? AND anulada = 0$fu', a);
    double totalVentas = 0, fiadas = 0;
    for (final v in ventas) {
      final t = _n(v['total']);
      totalVentas += t;
      if (v['metodo_pago'] == 'CREDITO') fiadas += t;
      if (conDiario) dia(_diaDe(v['fecha'] as String?))[0] += t;
    }

    final costos = await db.rawQuery(
      'SELECT v.fecha, SUM(d.cantidad_descontada * d.costo_unitario) AS c, '
      'SUM(CASE WHEN COALESCE(d.costo_unitario, 0) <= 0 THEN d.subtotal ELSE 0 END) AS sin_costo '
      'FROM detalle_ventas d JOIN ventas v ON v.id = d.venta_id '
      'WHERE v.fecha >= ? AND v.fecha < ? AND v.anulada = 0$fuv GROUP BY substr(v.fecha, 1, 10)', a);
    double costo = 0, sinCosto = 0;
    for (final c in costos) {
      costo += _n(c['c']);
      sinCosto += _n(c['sin_costo']);
      if (conDiario) dia(_diaDe(c['fecha'] as String?))[1] += _n(c['c']);
    }

    final movs = await db.rawQuery(
      "SELECT fecha, tipo, monto, categoria, descripcion FROM caja_movimientos "
      "WHERE fecha >= ? AND fecha < ? AND tipo IN ('GASTO', 'INGRESO')$fu", a);
    double gastos = 0, faltantes = 0, sobrantes = 0, prestamos = 0, retiros = 0, abonos = 0;
    for (final m in movs) {
      final cat = CategoriasCaja.de(m);
      final v = _n(m['monto']);
      if (m['tipo'] == 'INGRESO') {
        if (cat == 'SOBRANTE') sobrantes += v;
        if (cat == 'ABONO_CLIENTE') abonos += v;
        continue;
      }
      if (cat == 'PRESTAMO') {
        prestamos += v;
      } else if (cat == 'RETIRO') {
        retiros += v;
      } else if (cat == 'DESCUADRE') {
        faltantes += v;
      } else {
        gastos += v;
        if (conDiario) dia(_diaDe(m['fecha'] as String?))[2] += v;
      }
    }

    final mermas = await db.rawQuery(
        'SELECT fecha, total_perdida FROM mermas WHERE fecha >= ? AND fecha < ?$fu', a);
    double totalMermas = 0;
    for (final m in mermas) {
      totalMermas += _n(m['total_perdida']);
      if (conDiario) dia(_diaDe(m['fecha'] as String?))[3] += _n(m['total_perdida']);
    }

    final dev = await db.rawQuery(
        'SELECT COUNT(*) AS n, COALESCE(SUM(monto), 0) AS t FROM devoluciones WHERE fecha >= ? AND fecha < ?$fu', a);
    final anul = await db.rawQuery(
        'SELECT COUNT(*) AS n, COALESCE(SUM(total), 0) AS t FROM ventas '
        'WHERE anulada = 1 AND COALESCE(anulada_en, fecha) >= ? AND COALESCE(anulada_en, fecha) < ?$fu', a);
    final comp = await db.rawQuery(
        'SELECT COUNT(*) AS n, COALESCE(SUM(total), 0) AS t FROM compras WHERE fecha >= ? AND fecha < ?$fu', a);

    final diario = conDiario
        ? p.listaDias.map((d) {
            final v = dias[_clave(d)] ?? [0, 0, 0, 0];
            return DiaFinanzas(d, v[0], v[1], v[2], v[3]);
          }).toList()
        : <DiaFinanzas>[];

    return Resultados(
      periodo: p,
      ventas: totalVentas,
      cantidadVentas: ventas.length,
      costoVentas: costo,
      gastos: gastos,
      mermas: totalMermas,
      faltantesCaja: faltantes,
      sobrantesCaja: sobrantes,
      devoluciones: _n(dev.first['t']),
      cantidadDevoluciones: (dev.first['n'] as num?)?.toInt() ?? 0,
      anuladas: _n(anul.first['t']),
      cantidadAnuladas: (anul.first['n'] as num?)?.toInt() ?? 0,
      prestamos: prestamos,
      retiros: retiros,
      compras: _n(comp.first['t']),
      cantidadCompras: (comp.first['n'] as num?)?.toInt() ?? 0,
      ventasFiadas: fiadas,
      abonosClientes: abonos,
      ventasSinCosto: sinCosto,
      diario: diario,
      ventasAnterior: 0,
      utilidadAnterior: 0,
    );
  }

  // ------------------------------------------------------- GASTOS Y COMPRAS
  Future<GastosCompras> gastosCompras(Periodo p, {int? usuarioId}) async {
    final db = await _db.database;
    final u = await _usuarios();
    final a = [p.inicioIso, p.finExclusivoIso];
    final fu = _filtroUsuario(usuarioId);

    final movs = await db.rawQuery(
        'SELECT * FROM caja_movimientos WHERE fecha >= ? AND fecha < ?$fu ORDER BY fecha DESC', a);
    final porCat = <String, List<double>>{};
    final noGasto = <String, List<double>>{};
    final detalle = <GastoDetalle>[];
    double gastos = 0, compras = 0, devoluciones = 0, prestamos = 0, abonos = 0, otros = 0;
    for (final m in movs) {
      final tipo = (m['tipo'] ?? '').toString();
      final v = _n(m['monto']);
      final cat = CategoriasCaja.de(m);
      switch (tipo) {
        case 'GASTO':
          if (CategoriasCaja.noSonGasto.contains(cat)) {
            prestamos += v;
            final g = noGasto.putIfAbsent(cat, () => [0, 0]);
            g[0]++;
            g[1] += v;
          } else {
            gastos += v;
            final g = porCat.putIfAbsent(cat, () => [0, 0]);
            g[0]++;
            g[1] += v;
            detalle.add(GastoDetalle(
              DateTime.tryParse(m['fecha']?.toString() ?? ''),
              CategoriasCaja.nombre('GASTO', cat),
              (m['descripcion'] ?? '').toString(),
              v,
              _nombre(u, m['usuario_id']),
            ));
          }
          break;
        case 'COMPRA':
          compras += v;
          break;
        case 'DEVOLUCION':
        case 'ANULACION':
          // Las anteriores a v13 ya están descontadas en la venta (su
          // efectivo cobrado quedó neto), así que solo cuentan las nuevas.
          if ((m['resta_caja'] ?? 0) == 1) devoluciones += v;
          break;
        case 'INGRESO':
          if (cat == 'ABONO_CLIENTE') {
            abonos += v;
          } else if (cat != 'SOBRANTE') {
            otros += v;
          }
          break;
      }
    }

    final ventas = await db.rawQuery(
        'SELECT total, metodo_pago, metodo_pago_detalle, efectivo_cobrado, anulada FROM ventas '
        'WHERE fecha >= ? AND fecha < ?$fu', a);
    double entroVentas = 0;
    final metodos = <String, List<double>>{};
    for (final v in ventas) {
      // Efectivo que entró al cobrar (aunque luego se haya devuelto: la
      // devolución está en las salidas).
      final ec = (v['efectivo_cobrado'] as num?)?.toDouble();
      entroVentas += ec ?? ((v['anulada'] ?? 0) == 1 ? 0 : DBHelper.efectivoDeVenta(v));
      if ((v['anulada'] ?? 0) == 1) continue;
      final total = _n(v['total']);
      final mp = (v['metodo_pago'] ?? '').toString();
      if (mp == 'MIXTO') {
        final partes = DBHelper.partesMixto(total, v['metodo_pago_detalle']?.toString());
        String dig = 'DIGITAL';
        try {
          final d = jsonDecode(v['metodo_pago_detalle']?.toString() ?? '');
          if (d is Map && d['metodo_digital'] != null) dig = d['metodo_digital'].toString().toUpperCase();
        } catch (_) {}
        for (final e in {'EFECTIVO': partes['efectivo']!, dig: partes['digital']!}.entries) {
          if (e.value <= 0) continue;
          final g = metodos.putIfAbsent(e.key, () => [0, 0]);
          g[0]++;
          g[1] += e.value;
        }
      } else {
        final g = metodos.putIfAbsent(mp, () => [0, 0]);
        g[0]++;
        g[1] += total;
      }
    }

    final comp = await db.rawQuery(
        "SELECT COALESCE(NULLIF(TRIM(proveedor), ''), 'General') AS prov, COUNT(*) AS n, SUM(total) AS t "
        'FROM compras WHERE fecha >= ? AND fecha < ?$fu GROUP BY prov ORDER BY t DESC', a);

    List<Grupo> ordenar(Map<String, List<double>> m, String Function(String) nombre) =>
        m.entries.map((e) => Grupo(e.key, nombre(e.key), e.value[0].toInt(), e.value[1])).toList()
          ..sort((x, y) => y.total.compareTo(x.total));

    return GastosCompras(
      gastosPorCategoria: ordenar(porCat, (k) => CategoriasCaja.nombre('GASTO', k)),
      gastos: detalle,
      salidasNoGasto: ordenar(noGasto, (k) => CategoriasCaja.nombre('GASTO', k)),
      comprasPorProveedor: comp
          .map((c) => Grupo(c['prov'].toString(), c['prov'].toString(), (c['n'] as num).toInt(), _n(c['t'])))
          .toList(),
      totalCompras: comp.fold(0.0, (x, c) => x + _n(c['t'])),
      comprasConCaja: compras,
      metodosPago: ordenar(metodos, nombreMetodo),
      entroVentas: entroVentas,
      entroAbonos: abonos,
      entroOtros: otros,
      salioGastos: gastos,
      salioCompras: compras,
      salioDevoluciones: devoluciones,
      salioPrestamosRetiros: prestamos,
    );
  }

  static String nombreMetodo(String m) {
    switch (m) {
      case 'EFECTIVO':
        return 'Efectivo';
      case 'CREDITO':
        return 'Fiado (crédito)';
      case 'NEQUI':
        return 'Nequi';
      case 'DAVIPLATA':
        return 'Daviplata';
      case 'TARJETA':
        return 'Tarjeta';
      case 'TRANSFERENCIA':
        return 'Transferencia';
      case 'DIGITAL':
        return 'Digital';
      default:
        return m.isEmpty ? 'Otro' : m[0] + m.substring(1).toLowerCase();
    }
  }

  // ------------------------------------------------------------ RENTABILIDAD
  Future<Rentabilidad> rentabilidad(Periodo p, {int? usuarioId}) async {
    final db = await _db.database;
    final a = [p.inicioIso, p.finExclusivoIso];
    final fuv = _filtroUsuario(usuarioId, 'v.');
    final filas = await db.rawQuery(
      "SELECT d.producto_id, d.nombre_producto, COALESCE(NULLIF(TRIM(pr.categoria), ''), 'Sin categoría') AS cat, "
      'SUM(d.cantidad) AS cant, SUM(d.subtotal) AS ventas, '
      'SUM(d.cantidad_descontada * d.costo_unitario) AS costo, '
      'MIN(COALESCE(d.costo_unitario, 0)) AS costo_min '
      'FROM detalle_ventas d JOIN ventas v ON v.id = d.venta_id '
      'LEFT JOIN productos pr ON pr.id = d.producto_id '
      'WHERE v.fecha >= ? AND v.fecha < ? AND v.anulada = 0$fuv '
      'GROUP BY COALESCE(d.producto_id, d.nombre_producto)',
      a,
    );
    final productos = <Rentable>[];
    final cats = <String, List<double>>{};
    final catSinCosto = <String, bool>{};
    for (final f in filas) {
      final sinCosto = _n(f['costo_min']) <= 0;
      final r = Rentable(
        (f['nombre_producto'] ?? 'Producto').toString(),
        _n(f['cant']),
        _n(f['ventas']),
        _n(f['costo']),
        sinCosto,
      );
      productos.add(r);
      final c = cats.putIfAbsent(f['cat'].toString(), () => [0, 0, 0]);
      c[0] += r.cantidad;
      c[1] += r.ventas;
      c[2] += r.costo;
      if (sinCosto) catSinCosto[f['cat'].toString()] = true;
    }
    final categorias = cats.entries
        .map((e) => Rentable(e.key, e.value[0], e.value[1], e.value[2], catSinCosto[e.key] ?? false))
        .toList()
      ..sort((x, y) => y.utilidad.compareTo(x.utilidad));
    return Rentabilidad(categorias, productos);
  }

  // ------------------------------------------------------------ CONTROL
  Future<Control> control(Periodo p, {int? usuarioId}) async {
    final db = await _db.database;
    final u = await _usuarios();
    final a = [p.inicioIso, p.finExclusivoIso];
    final eventos = <EventoControl>[];

    // Anulaciones (las viejas no guardaban quién ni cuándo: se usa la venta)
    final anuladas = await db.rawQuery(
      'SELECT * FROM ventas WHERE anulada = 1 AND COALESCE(anulada_en, fecha) >= ? AND COALESCE(anulada_en, fecha) < ?'
      '${usuarioId == null ? '' : ' AND COALESCE(anulada_por, usuario_id) = $usuarioId'}',
      a,
    );
    for (final v in anuladas) {
      final efectivo = (v['efectivo_cobrado'] as num?)?.toDouble() ?? 0;
      eventos.add(EventoControl(
        tipo: 'ANULACION',
        fecha: DateTime.tryParse((v['anulada_en'] ?? v['fecha'])?.toString() ?? ''),
        titulo: 'Venta #${v['id']}',
        detalle: '${nombreMetodo((v['metodo_pago'] ?? '').toString())} · vendió ${_nombre(u, v['usuario_id'])}',
        monto: _n(v['total']),
        efectivo: efectivo,
        usuario: v['anulada_por'] != null ? _nombre(u, v['anulada_por']) : 'Sin registrar',
        motivo: (v['motivo_anulacion'] ?? '').toString(),
      ));
    }

    // Devoluciones con detalle (desde esta versión)
    final devs = await db.rawQuery(
        'SELECT * FROM devoluciones WHERE fecha >= ? AND fecha < ?${_filtroUsuario(usuarioId)}', a);
    for (final d in devs) {
      final cant = _n(d['cantidad']);
      eventos.add(EventoControl(
        tipo: 'DEVOLUCION',
        fecha: DateTime.tryParse(d['fecha']?.toString() ?? ''),
        titulo: (d['nombre_producto'] ?? 'Producto').toString(),
        detalle: '${_cant(cant)} · Venta #${d['venta_id'] ?? '?'} · ${nombreMetodo((d['metodo_pago'] ?? '').toString())}',
        monto: _n(d['monto']),
        efectivo: _n(d['efectivo']),
        usuario: _nombre(u, d['usuario_id']),
        motivo: (d['motivo'] ?? '').toString(),
      ));
    }
    // Devoluciones anteriores a esta versión: solo quedó el movimiento de caja
    final devViejas = await db.rawQuery(
      "SELECT * FROM caja_movimientos WHERE tipo = 'DEVOLUCION' AND COALESCE(resta_caja, 0) = 0 "
      'AND fecha >= ? AND fecha < ?${_filtroUsuario(usuarioId)}',
      a,
    );
    for (final m in devViejas) {
      eventos.add(EventoControl(
        tipo: 'DEVOLUCION',
        fecha: DateTime.tryParse(m['fecha']?.toString() ?? ''),
        titulo: (m['descripcion'] ?? 'Devolución').toString(),
        detalle: 'Registro anterior (sin detalle del producto)',
        monto: _n(m['monto']),
        efectivo: _n(m['monto']),
        usuario: _nombre(u, m['usuario_id']),
        motivo: '',
      ));
    }

    final mermas = await db.rawQuery(
        'SELECT * FROM mermas WHERE fecha >= ? AND fecha < ?${_filtroUsuario(usuarioId)}', a);
    for (final m in mermas) {
      eventos.add(EventoControl(
        tipo: 'MERMA',
        fecha: DateTime.tryParse(m['fecha']?.toString() ?? ''),
        titulo: (m['nombre_producto'] ?? 'Producto').toString(),
        detalle: _cant(_n(m['cantidad'])),
        monto: _n(m['total_perdida']),
        usuario: _nombre(u, m['usuario_id']),
        motivo: (m['motivo'] ?? '').toString(),
      ));
    }

    final cierres = await cierresDe(p, usuarioId: usuarioId);
    for (final c in cierres.cierres.where((c) => c.estado == 'FALTANTE' || c.estado == 'SOBRANTE')) {
      eventos.add(EventoControl(
        tipo: 'DESCUADRE',
        fecha: c.cierre,
        titulo: c.estado == 'FALTANTE' ? 'Faltante en cierre' : 'Sobrante en cierre',
        detalle: '${c.caja} · esperado ${_pesos(c.esperado)} · contado ${_pesos(c.contado ?? 0)}',
        monto: (c.diferencia ?? 0).abs(),
        usuario: c.cajero,
        motivo: '',
      ));
    }

    eventos.sort((x, y) => (y.fecha ?? DateTime(0)).compareTo(x.fecha ?? DateTime(0)));
    return Control(eventos);
  }

  static String _cant(double v) => v == v.roundToDouble()
      ? '${v.toStringAsFixed(0)} und'
      : '${v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceAll('.', ',')} kg/und';

  static String _pesos(double v) {
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}\$$b';
  }

  // ------------------------------------------------------------ CIERRES
  Future<Cierres> cierresDe(Periodo p, {int? usuarioId}) async {
    final db = await _db.database;
    final u = await _usuarios();
    final disp = await _db.obtenerDispositivoUuid();
    final a = [p.inicioIso, p.finExclusivoIso];
    final filas = await db.rawQuery(
      'SELECT * FROM cierres_caja WHERE COALESCE(fecha_inicio, fecha) >= ? AND COALESCE(fecha_inicio, fecha) < ?'
      '${_filtroUsuario(usuarioId)} ORDER BY COALESCE(fecha_inicio, fecha) DESC',
      a,
    );
    final otras = <String>[];
    String nombreCaja(String? d) {
      if (d == null || d.isEmpty || d == disp) return 'Esta caja';
      if (!otras.contains(d)) otras.add(d);
      return 'Caja ${otras.indexOf(d) + 2}';
    }

    final lista = <CierreAuditoria>[];
    for (final c in filas) {
      final contado = _n(c['real_contado']);
      var dif = _n(c['diferencia']);
      // Cierre sin diferencia anotada pero que no cuadra con el sistema.
      if (dif == 0 && (contado - _n(c['total_sistema'])).abs() >= toleranciaCuadre) {
        dif = contado - _n(c['total_sistema']);
      }
      // El ajuste automático deja total_sistema igual a lo contado; lo que el
      // sistema esperaba antes del ajuste es contado − diferencia.
      final esperado = contado - dif;
      final estado = dif.abs() < toleranciaCuadre ? 'CUADRADO' : (dif < 0 ? 'FALTANTE' : 'SOBRANTE');
      final metodos = <String, double>{};
      final det = (c['detalle'] ?? '').toString();
      final i = det.indexOf('METODOS:');
      if (i >= 0) {
        try {
          final m = jsonDecode(det.substring(i + 8));
          if (m is Map) {
            m.forEach((k, v) => metodos[k.toString()] = (v as num).toDouble());
          }
        } catch (_) {}
      }
      lista.add(CierreAuditoria(
        id: c['id'] as int,
        cajero: _nombre(u, c['usuario_id']),
        caja: (c['caja_nombre'] ?? '').toString().trim().isNotEmpty
            ? c['caja_nombre'].toString()
            : nombreCaja(c['dispositivo_uuid'] as String?),
        estaCaja: c['dispositivo_uuid'] == null || c['dispositivo_uuid'] == disp,
        apertura: DateTime.tryParse(c['fecha_inicio']?.toString() ?? ''),
        cierre: DateTime.tryParse((c['fecha_fin'] ?? c['fecha'])?.toString() ?? ''),
        base: _n(c['base']),
        ventas: _n(c['ventas_turno']),
        ingresos: _n(c['ingresos_turno']),
        gastos: _n(c['gastos_turno']),
        esperado: esperado,
        contado: contado,
        diferencia: dif,
        estado: estado,
        metodos: metodos,
        dispositivo: c['dispositivo_uuid'] as String?,
      ));
    }

    // Turno abierto de esta caja, con cifras en vivo
    final hoy = DateTime.now();
    if (usuarioId == null && !hoy.isBefore(p.desde) && hoy.isBefore(DateTime(p.hasta.year, p.hasta.month, p.hasta.day + 1))) {
      final apertura = await _db.obtenerFechaAperturaActual();
      if (apertura != null && await _db.verificarCajaAbiertaHoy()) {
        final r = await _db.obtenerResumenCaja();
        final ap = await db.query('caja_movimientos',
            where: "tipo = 'APERTURA' AND fecha = ?", whereArgs: [apertura], limit: 1);
        lista.insert(
          0,
          CierreAuditoria(
            id: 0,
            cajero: _nombre(u, ap.isEmpty ? null : ap.first['usuario_id']),
            caja: await _db.nombreCaja(),
            estaCaja: true,
            apertura: DateTime.tryParse(apertura),
            cierre: null,
            base: r['base'] ?? 0,
            ventas: r['ventas_efectivo'] ?? 0,
            ingresos: r['ingresos_extra'] ?? 0,
            gastos: r['gastos'] ?? 0,
            esperado: r['total_en_caja'] ?? 0,
            contado: null,
            diferencia: null,
            estado: 'ABIERTO',
            metodos: const {},
            dispositivo: disp,
          ),
        );
      }
    }
    return Cierres(lista);
  }

  /// Movimientos de caja de un turno (para el detalle del cierre).
  Future<List<MovimientoTurno>> movimientosDeTurno(CierreAuditoria c) async {
    final db = await _db.database;
    final u = await _usuarios();
    final disp = await _db.obtenerDispositivoUuid();
    if (c.apertura == null) return [];
    final hasta = (c.cierre ?? DateTime.now()).add(const Duration(seconds: 1)).toIso8601String();
    final esta = c.dispositivo == null || c.dispositivo == disp;
    final filas = await db.rawQuery(
      'SELECT * FROM caja_movimientos WHERE fecha >= ? AND fecha <= ? AND '
      '${esta ? '(dispositivo_uuid IS NULL OR dispositivo_uuid = ?)' : 'dispositivo_uuid = ?'} ORDER BY fecha',
      [c.apertura!.toIso8601String(), hasta, esta ? disp : c.dispositivo],
    );
    return filas
        .map((m) => MovimientoTurno(
              DateTime.tryParse(m['fecha']?.toString() ?? ''),
              (m['tipo'] ?? '').toString(),
              CategoriasCaja.de(m),
              (m['descripcion'] ?? '').toString(),
              _n(m['monto']),
              _nombre(u, m['usuario_id']),
            ))
        .toList();
  }

  // ------------------------------------------------------------ VENTAS
  Future<HorasPico> horasPico(Periodo p, {int? usuarioId}) async {
    final db = await _db.database;
    final filas = await db.rawQuery(
        'SELECT fecha, total FROM ventas WHERE fecha >= ? AND fecha < ? AND anulada = 0${_filtroUsuario(usuarioId)}',
        [p.inicioIso, p.finExclusivoIso]);
    final celdas = List.generate(7, (_) => List<double>.filled(24, 0));
    final tickets = List.generate(7, (_) => List<int>.filled(24, 0));
    for (final f in filas) {
      final d = DateTime.tryParse(f['fecha']?.toString() ?? '');
      if (d == null) continue;
      celdas[d.weekday - 1][d.hour] += _n(f['total']);
      tickets[d.weekday - 1][d.hour]++;
    }
    final veces = List<int>.filled(7, 0);
    for (final d in p.listaDias) {
      veces[d.weekday - 1]++;
    }
    return HorasPico(celdas, tickets, veces);
  }

  Future<List<Map<String, dynamic>>> topProductos(Periodo p, {int? usuarioId, int limite = 10}) async {
    final db = await _db.database;
    return db.rawQuery(
      'SELECT d.nombre_producto, SUM(d.cantidad) AS cantidad_total, SUM(d.subtotal) AS dinero_total '
      'FROM detalle_ventas d JOIN ventas v ON v.id = d.venta_id '
      'WHERE v.fecha >= ? AND v.fecha < ? AND v.anulada = 0${_filtroUsuario(usuarioId, 'v.')} '
      'GROUP BY COALESCE(d.producto_id, d.nombre_producto) ORDER BY dinero_total DESC LIMIT $limite',
      [p.inicioIso, p.finExclusivoIso],
    );
  }

  /// Foto actual del negocio (no depende del período).
  Future<Map<String, double>> patrimonio() async {
    return {
      'inventario': await _db.obtenerValorInventario(),
      'cartera': await _db.obtenerTotalCuentasPorCobrar(),
    };
  }
}
