import 'dart:convert';

/// Reporte Z (tirilla de cierre de caja).
///
/// Todo sale de UNA lista de renglones ([ReporteZ.renglones]) que se
/// convierte en líneas de texto de ancho fijo ([ReporteZ.lineas]): la vista
/// previa en pantalla y la impresión dibujan esas mismas líneas, así nunca se
/// diferencian. 80 mm = 42 columnas, 58 mm = 32.
///
/// Regla de oro (siempre cuadra en el papel):
///   base + ventas − ventas no efectivo + otras entradas − compras − gastos
///   − devoluciones = efectivo esperado.
class ReporteZ {
  static int columnasPara(int anchoMm) => anchoMm <= 58 ? 32 : 42;

  /// $12.500 / -$5.000, sin decimales.
  static String pesos(double v) {
    final r = v.round();
    final entero = r.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) b.write('.');
      b.write(entero[i]);
    }
    return '${r < 0 ? '-' : ''}\$$b';
  }

  static String _fecha(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(h12)}:${dos(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Los renglones de la tirilla, en el orden exacto del reporte.
  static List<RenglonZ> renglones(DatosZ d) {
    final r = <RenglonZ>[];
    // 1. Encabezado
    r.add(RenglonZ.titulo(d.negocio.isEmpty ? 'NovaPOS' : d.negocio));
    r.add(RenglonZ.titulo('CIERRE DE CAJA - REPORTE Z'));
    if (d.cierre == null) r.add(RenglonZ.texto('(TURNO ABIERTO - PARCIAL)', centrado: true));
    r.add(RenglonZ.raya());
    r.add(RenglonZ.fila('Turno', '#${d.turno}'));
    if (d.caja.isNotEmpty) r.add(RenglonZ.fila('Caja', d.caja));
    r.add(RenglonZ.fila('Cajero', d.cajero.isEmpty ? '-' : d.cajero));
    r.add(RenglonZ.fila('Apertura', _fecha(d.apertura)));
    r.add(RenglonZ.fila('Cierre', d.cierre == null ? 'Turno abierto' : _fecha(d.cierre!)));
    r.add(RenglonZ.raya());

    // 2. Base
    r.add(RenglonZ.fila('BASE INICIAL', pesos(d.base), negrita: true));

    // 3. Ventas y cómo se pagaron
    r.add(RenglonZ.fila('(+) VENTAS (${d.pedidos} ${d.pedidos == 1 ? 'pedido' : 'pedidos'})',
        pesos(d.ventasTotal), negrita: true));
    for (final m in d.mediosAMostrar) {
      r.add(RenglonZ.fila(m.key, pesos(m.value), sangria: true));
    }

    // 4. Lo que no entra al cajón
    if (d.ventasNoEfectivo.round() != 0) {
      r.add(RenglonZ.fila('(-) Ventas que no son efectivo', pesos(d.ventasNoEfectivo)));
      r.add(RenglonZ.texto('(no entran al cajón)', sangria: true));
    }
    // 5. Otras entradas
    if (d.otrasEntradas.round() != 0) {
      r.add(RenglonZ.fila('(+) Otras entradas de efectivo', pesos(d.otrasEntradas)));
    }
    // 6, 7, 8. Salidas
    r.add(RenglonZ.fila('(-) COMPRAS', pesos(d.compras)));
    r.add(RenglonZ.fila('(-) GASTOS', pesos(d.gastos)));
    if (d.devoluciones.round() != 0) {
      r.add(RenglonZ.fila('(-) Devoluciones en efectivo', pesos(d.devoluciones)));
    }
    r.add(RenglonZ.raya());

    // 9, 10, 11. Cuadre
    r.add(RenglonZ.fila('EFECTIVO ESPERADO', pesos(d.esperado), negrita: true));
    if (d.declarado == null) {
      r.add(RenglonZ.fila('EFECTIVO DECLARADO', '-'));
      r.add(RenglonZ.aviso('Sin efectivo declarado'));
    } else {
      r.add(RenglonZ.fila('EFECTIVO DECLARADO', pesos(d.declarado!), negrita: true));
      final dif = d.diferencia!.round();
      r.add(RenglonZ.fila('DIFERENCIA', '${dif > 0 ? '+' : ''}${pesos(dif.toDouble())}', negrita: true));
      r.add(RenglonZ.aviso(dif < 0
          ? 'FALTANTE DE ${pesos(-dif.toDouble())}'
          : dif > 0
              ? 'SOBRANTE DE ${pesos(dif.toDouble())}'
              : 'CAJA CUADRADA'));
    }
    r.add(RenglonZ.raya());

    // 12. Detalle de compras y gastos
    r.add(RenglonZ.titulo('DETALLE DE COMPRAS Y GASTOS'));
    if (d.detalle.isEmpty) {
      r.add(RenglonZ.texto('Sin compras ni gastos', sangria: true));
    } else {
      for (final m in d.detalle) {
        var concepto = m.concepto.trim().isEmpty ? 'Sin concepto' : m.concepto.trim();
        // "Compra Mercancía (X)" → "Compra: Mercancía (X)", sin repetir.
        if (m.esCompra && concepto.toLowerCase().startsWith('compra ')) {
          concepto = concepto.substring(7).trim();
        }
        r.add(RenglonZ.fila('${m.esCompra ? 'Compra' : 'Gasto'}: $concepto', pesos(m.monto), sangria: true));
      }
    }
    r.add(RenglonZ.raya());

    // 13. Otros datos (no cambian el efectivo)
    r.add(RenglonZ.titulo('OTROS DATOS'));
    r.add(RenglonZ.texto('(no cambian el efectivo)', centrado: true));
    if (d.ventaPorCategoria.isNotEmpty) {
      r.add(RenglonZ.texto('Venta por categoría:'));
      for (final c in d.ventaPorCategoria.entries) {
        r.add(RenglonZ.fila(c.key, pesos(c.value), sangria: true));
      }
    }
    r.add(RenglonZ.fila('Fiado en el turno', pesos(d.fiadoTurno)));
    r.add(RenglonZ.fila('Saldo por cobrar (clientes)', pesos(d.saldoPorCobrar)));
    r.add(RenglonZ.raya());

    // 14. Firmas
    r.add(RenglonZ.firmas());
    return r;
  }

  /// Convierte los renglones en líneas de exactamente [columnas] caracteres
  /// (o columnas/2 en el aviso grande, que se imprime a doble tamaño).
  static List<LineaZ> lineas(List<RenglonZ> renglones, int columnas) {
    final out = <LineaZ>[];
    for (final r in renglones) {
      switch (r.tipo) {
        case TipoRenglonZ.raya:
          out.add(LineaZ('-' * columnas));
          break;
        case TipoRenglonZ.titulo:
          for (final l in partir(r.texto, columnas)) {
            out.add(LineaZ(_centrar(l, columnas), negrita: true));
          }
          break;
        case TipoRenglonZ.texto:
          final pre = r.sangria ? '    ' : '';
          for (final l in partir(r.texto, columnas - pre.length)) {
            out.add(LineaZ(r.centrado ? _centrar(l, columnas) : (pre + l).padRight(columnas)));
          }
          break;
        case TipoRenglonZ.aviso:
          final ancho = columnas ~/ 2;
          for (final l in partir(r.texto, ancho)) {
            out.add(LineaZ(_centrar(l, ancho), negrita: true, grande: true));
          }
          break;
        case TipoRenglonZ.fila:
          out.addAll(_fila(r, columnas));
          break;
        case TipoRenglonZ.firmas:
          final raya = '_' * (columnas * 2 ~/ 3);
          // Espacio suficiente para firmar a mano.
          for (final quien in ['Cajero', 'Administrador']) {
            for (var i = 0; i < 4; i++) {
              out.add(LineaZ(' ' * columnas));
            }
            out.add(LineaZ(_centrar(raya, columnas)));
            out.add(LineaZ(_centrar(quien, columnas)));
          }
          break;
      }
    }
    return out;
  }

  /// Etiqueta a la izquierda y valor a la derecha. Si no caben juntos, la
  /// etiqueta se escribe completa (partida por palabras) y el valor va en el
  /// renglón de abajo, a la derecha: nunca se corta.
  static List<LineaZ> _fila(RenglonZ r, int columnas) {
    final pre = r.sangria ? '    ' : '';
    final valor = r.valor ?? '';
    final etiqueta = '$pre${r.texto}';
    if (etiqueta.length + 1 + valor.length <= columnas) {
      final espacios = columnas - etiqueta.length - valor.length;
      return [LineaZ('$etiqueta${' ' * espacios}$valor', negrita: r.negrita)];
    }
    final out = <LineaZ>[];
    for (final l in partir(r.texto, columnas - pre.length)) {
      out.add(LineaZ((pre + l).padRight(columnas), negrita: r.negrita));
    }
    for (final v in partir(valor, columnas)) {
      out.add(LineaZ(v.padLeft(columnas), negrita: r.negrita));
    }
    return out;
  }

  /// Parte un texto por palabras en líneas de máximo [ancho] (una palabra
  /// más larga que el ancho se parte por letras).
  static List<String> partir(String texto, int ancho) {
    final palabras = texto.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final lineas = <String>[];
    var actual = '';
    for (var p in palabras) {
      while (p.length > ancho) {
        if (actual.isNotEmpty) {
          lineas.add(actual);
          actual = '';
        }
        lineas.add(p.substring(0, ancho));
        p = p.substring(ancho);
      }
      if (actual.isEmpty) {
        actual = p;
      } else if (actual.length + 1 + p.length <= ancho) {
        actual = '$actual $p';
      } else {
        lineas.add(actual);
        actual = p;
      }
    }
    if (actual.isNotEmpty || lineas.isEmpty) lineas.add(actual);
    return lineas;
  }

  static String _centrar(String s, int ancho) {
    final izq = ((ancho - s.length) / 2).floor().clamp(0, ancho);
    return (' ' * izq + s).padRight(ancho);
  }
}

enum TipoRenglonZ { titulo, texto, fila, raya, aviso, firmas }

/// Un renglón lógico de la tirilla (antes de acomodarlo al ancho del papel).
class RenglonZ {
  final TipoRenglonZ tipo;
  final String texto;
  final String? valor;
  final bool sangria;
  final bool negrita;
  final bool centrado;

  const RenglonZ._(this.tipo, this.texto,
      {this.valor, this.sangria = false, this.negrita = false, this.centrado = false});

  factory RenglonZ.titulo(String t) => RenglonZ._(TipoRenglonZ.titulo, t, negrita: true);
  factory RenglonZ.texto(String t, {bool sangria = false, bool centrado = false}) =>
      RenglonZ._(TipoRenglonZ.texto, t, sangria: sangria, centrado: centrado);
  factory RenglonZ.fila(String etiqueta, String valor, {bool sangria = false, bool negrita = false}) =>
      RenglonZ._(TipoRenglonZ.fila, etiqueta, valor: valor, sangria: sangria, negrita: negrita);
  factory RenglonZ.raya() => const RenglonZ._(TipoRenglonZ.raya, '');
  factory RenglonZ.aviso(String t) => RenglonZ._(TipoRenglonZ.aviso, t, negrita: true);
  factory RenglonZ.firmas() => const RenglonZ._(TipoRenglonZ.firmas, '');
}

/// Una línea ya acomodada al ancho del papel. [grande]: doble tamaño (la
/// mitad de columnas).
class LineaZ {
  final String texto;
  final bool negrita;
  final bool grande;
  const LineaZ(this.texto, {this.negrita = false, this.grande = false});
}

class MovimientoZ {
  final bool esCompra;
  final String concepto;
  final double monto;
  const MovimientoZ({required this.esCompra, required this.concepto, required this.monto});

  Map<String, dynamic> toJson() => {'c': esCompra ? 1 : 0, 't': concepto, 'm': monto};
  factory MovimientoZ.fromJson(Map<String, dynamic> j) => MovimientoZ(
        esCompra: j['c'] == 1,
        concepto: (j['t'] ?? '').toString(),
        monto: (j['m'] as num?)?.toDouble() ?? 0,
      );
}

/// Los datos del Reporte Z de un turno. Al cerrar la caja se congelan (se
/// guardan en el cierre), así reimprimir un cierre viejo da exactamente lo
/// mismo aunque después cambien otros datos.
class DatosZ {
  final String negocio;
  final String caja;
  final String cajero;
  final int turno;
  final DateTime apertura;
  final DateTime? cierre;
  final double base;
  final int pedidos;

  /// Lo vendido por medio de pago, con "Efectivo" ya neto de devoluciones
  /// del mismo turno (lo que de verdad entró al cajón por ventas).
  final Map<String, double> ventasPorMedio;
  final double otrasEntradas;
  final double compras;
  final double gastos;
  final double esperado;
  final double? declarado;
  final List<MovimientoZ> detalle;
  final Map<String, double> ventaPorCategoria;
  final double fiadoTurno;
  final double saldoPorCobrar;

  const DatosZ({
    required this.negocio,
    required this.caja,
    required this.cajero,
    required this.turno,
    required this.apertura,
    required this.cierre,
    required this.base,
    required this.pedidos,
    required this.ventasPorMedio,
    required this.otrasEntradas,
    required this.compras,
    required this.gastos,
    required this.esperado,
    required this.declarado,
    required this.detalle,
    required this.ventaPorCategoria,
    required this.fiadoTurno,
    required this.saldoPorCobrar,
  });

  static const String efectivo = 'Efectivo';
  static const List<String> siempre = ['Efectivo', 'Transferencia', 'Tarjeta'];

  double get ventasEfectivo => ventasPorMedio[efectivo] ?? 0;
  double get ventasTotal => ventasPorMedio.values.fold(0.0, (a, b) => a + b);
  double get ventasNoEfectivo => ventasTotal - ventasEfectivo;

  /// Lo que falta para llegar al esperado: el efectivo entregado al devolver
  /// ventas de turnos anteriores (las del mismo turno ya restan de la venta).
  double get devoluciones =>
      (base + ventasEfectivo + otrasEntradas - compras - gastos) - esperado;

  double? get diferencia => declarado == null ? null : declarado! - esperado;

  /// Efectivo, Transferencia y Tarjeta siempre; los demás solo si hubo.
  List<MapEntry<String, double>> get mediosAMostrar => [
        for (final m in siempre) MapEntry(m, ventasPorMedio[m] ?? 0),
        for (final e in ventasPorMedio.entries)
          if (!siempre.contains(e.key) && e.value.round() != 0) e,
      ];

  DatosZ conCierre({required DateTime cierre, required double declarado}) => DatosZ(
        negocio: negocio, caja: caja, cajero: cajero, turno: turno, apertura: apertura,
        cierre: cierre, base: base, pedidos: pedidos, ventasPorMedio: ventasPorMedio,
        otrasEntradas: otrasEntradas, compras: compras, gastos: gastos, esperado: esperado,
        declarado: declarado, detalle: detalle, ventaPorCategoria: ventaPorCategoria,
        fiadoTurno: fiadoTurno, saldoPorCobrar: saldoPorCobrar,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        'negocio': negocio,
        'caja': caja,
        'cajero': cajero,
        'turno': turno,
        'apertura': apertura.toIso8601String(),
        'cierre': cierre?.toIso8601String(),
        'base': base,
        'pedidos': pedidos,
        'medios': ventasPorMedio,
        'otras': otrasEntradas,
        'compras': compras,
        'gastos': gastos,
        'esperado': esperado,
        'declarado': declarado,
        'detalle': [for (final m in detalle) m.toJson()],
        'categorias': ventaPorCategoria,
        'fiado': fiadoTurno,
        'por_cobrar': saldoPorCobrar,
      };

  factory DatosZ.fromJson(Map<String, dynamic> j) {
    Map<String, double> mapa(Object? o) => {
          if (o is Map)
            for (final e in o.entries) e.key.toString(): (e.value as num?)?.toDouble() ?? 0,
        };
    double n(Object? o) => (o as num?)?.toDouble() ?? 0;
    return DatosZ(
      negocio: (j['negocio'] ?? '').toString(),
      caja: (j['caja'] ?? '').toString(),
      cajero: (j['cajero'] ?? '').toString(),
      turno: (j['turno'] as num?)?.toInt() ?? 0,
      apertura: DateTime.tryParse((j['apertura'] ?? '').toString()) ?? DateTime(2000),
      cierre: DateTime.tryParse((j['cierre'] ?? '').toString()),
      base: n(j['base']),
      pedidos: (j['pedidos'] as num?)?.toInt() ?? 0,
      ventasPorMedio: mapa(j['medios']),
      otrasEntradas: n(j['otras']),
      compras: n(j['compras']),
      gastos: n(j['gastos']),
      esperado: n(j['esperado']),
      declarado: (j['declarado'] as num?)?.toDouble(),
      detalle: [
        for (final m in (j['detalle'] as List? ?? const []))
          if (m is Map) MovimientoZ.fromJson(Map<String, dynamic>.from(m)),
      ],
      ventaPorCategoria: mapa(j['categorias']),
      fiadoTurno: n(j['fiado']),
      saldoPorCobrar: n(j['por_cobrar']),
    );
  }

  /// Segmento que se guarda en cierres_caja.detalle ("Z:<base64>"), antes de
  /// "METODOS:" (los reportes leen METODOS como último segmento).
  String codificar() => 'Z:${base64Url.encode(utf8.encode(jsonEncode(toJson())))}';

  static DatosZ? desdeDetalle(String? detalle) {
    if (detalle == null) return null;
    for (final parte in detalle.split('|')) {
      if (!parte.startsWith('Z:')) continue;
      try {
        final j = jsonDecode(utf8.decode(base64Url.decode(parte.substring(2))));
        if (j is Map) return DatosZ.fromJson(Map<String, dynamic>.from(j));
      } catch (_) {}
    }
    return null;
  }
}

/// Cómo va una caja del negocio (Centro Financiero → Cajas en vivo).
class EstadoCaja {
  final String dispositivo;
  final String nombre;
  final bool esEstaCaja;
  final bool abierta;

  /// Reporte Z parcial del turno abierto (null si la caja está cerrada).
  final DatosZ? turno;
  final double ventasHoy;
  final int pedidosHoy;
  final DateTime? ultimaActividad;
  final DateTime? ultimoCierre;
  final double? ultimaDiferencia;

  const EstadoCaja({
    required this.dispositivo,
    required this.nombre,
    required this.esEstaCaja,
    required this.abierta,
    required this.turno,
    required this.ventasHoy,
    required this.pedidosHoy,
    required this.ultimaActividad,
    required this.ultimoCierre,
    required this.ultimaDiferencia,
  });
}
