import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finanzas_service.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';

/// Componentes visuales del Centro Financiero (claro y oscuro).

String ft(String es) => LocaleService().esEspanol ? es : (_en[es] ?? es);

const Map<String, String> _en = {
  'Centro Financiero': 'Financial Center',
  'Panorama': 'Overview',
  'Resultados': 'Results',
  'Gastos y compras': 'Expenses & purchases',
  'Rentabilidad': 'Profitability',
  'Ventas': 'Sales',
  'Control': 'Control',
  'Cierres de caja': 'Cash closures',
  'Hoy': 'Today',
  'Ayer': 'Yesterday',
  '7 días': '7 days',
  '30 días': '30 days',
  'Este mes': 'This month',
  'Mes pasado': 'Last month',
  'Este año': 'This year',
  'Rango': 'Range',
  'Todos los cajeros': 'All cashiers',
  'Ganancia': 'Profit',
  'Pérdida': 'Loss',
  'Costo de lo vendido': 'Cost of goods sold',
  'Gastos': 'Expenses',
  'Mermas': 'Waste',
  'Utilidad bruta': 'Gross profit',
  'Utilidad neta': 'Net profit',
  'Margen': 'Margin',
  'Ticket promedio': 'Average ticket',
  'No hay movimientos en estas fechas': 'No activity in this period',
  'Prueba con otro rango de días.': 'Try another date range.',
  'Exportar a Excel': 'Export to Excel',
  'Actualizando…': 'Updating…',
  'No se pudo cargar': 'Could not load',
  'Reintentar': 'Retry',
};

final NumberFormat _moneda = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

String dinero(num v) => _moneda.format(v);

/// $1,2 M · $350 mil · $8.500
String dineroCorto(num v) {
  final a = v.abs();
  final s = v < 0 ? '-' : '';
  if (a >= 1000000) {
    return '$s\$${(a / 1000000).toStringAsFixed(a >= 10000000 ? 0 : 1).replaceAll('.', ',')} M';
  }
  if (a >= 10000) return '$s\$${(a / 1000).toStringAsFixed(0)} mil';
  return '$s${_moneda.format(a)}';
}

String porcentaje(num v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} %';

String cantidad(num v) => v == v.roundToDouble()
    ? NumberFormat.decimalPattern('es_CO').format(v)
    : v.toStringAsFixed(2).replaceAll('.', ',');

String fechaCorta(DateTime? d) => d == null ? '—' : DateFormat('dd MMM', 'es_CO').format(d);
String fechaHora(DateTime? d) => d == null ? '—' : DateFormat('dd MMM · hh:mm a', 'es_CO').format(d);
String hora(DateTime? d) => d == null ? '—' : DateFormat('hh:mm a', 'es_CO').format(d);

/// Colores de la paleta financiera.
class FinColor {
  static const verde = Color(0xFF10B981);
  static const ambar = Color(0xFFF59E0B);
  static const rosa = Color(0xFFEC4899);
  static const rojo = Color(0xFFEF4444);
  static const azul = Color(0xFF3B82F6);
  static const violeta = Color(0xFF8B5CF6);
  static const cian = Color(0xFF06B6D4);
  static const naranja = Color(0xFFF97316);

  static Color texto(BuildContext c, Color base) =>
      c.isDarkMode ? Color.lerp(base, Colors.white, 0.35)! : Color.lerp(base, Colors.black, 0.25)!;
  static Color fondo(BuildContext c, Color base) =>
      base.withValues(alpha: c.isDarkMode ? 0.14 : 0.07);
  static Color borde(BuildContext c, Color base) =>
      base.withValues(alpha: c.isDarkMode ? 0.45 : 0.30);
}

/// Tarjeta contenedora de una sección.
class FinCard extends StatelessWidget {
  final String? titulo;
  final String? subtitulo;
  final IconData? icono;
  final Color? colorIcono;
  final Widget? accion;
  final Widget child;
  final EdgeInsets padding;
  const FinCard({
    super.key,
    this.titulo,
    this.subtitulo,
    this.icono,
    this.colorIcono,
    this.accion,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderSubtle),
        boxShadow: context.isDarkMode
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null) ...[
            Row(
              children: [
                if (icono != null) ...[
                  Icon(icono, size: 18, color: FinColor.texto(context, colorIcono ?? FinColor.violeta)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    titulo!,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.textPrimary),
                  ),
                ),
                if (accion != null) accion!,
              ],
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 2),
              Text(subtitulo!, style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ],
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Indicador grande con tono de color.
class KpiTile extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String? detalle;
  final IconData icono;
  final Color color;
  final String? signo;
  final bool grande;
  final Widget? extra;
  const KpiTile({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.detalle,
    required this.icono,
    required this.color,
    this.signo,
    this.grande = false,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FinColor.fondo(context, color),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FinColor.borde(context, color), width: grande ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDarkMode ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icono, size: 16, color: FinColor.texto(context, color)),
              ),
              const SizedBox(width: 8),
              if (signo != null)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Text(signo!,
                      style: TextStyle(fontWeight: FontWeight.w900, color: context.textSecondary, fontSize: 12)),
                ),
              Expanded(
                child: Text(
                  etiqueta.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: context.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: grande ? 28 : 22,
                fontWeight: FontWeight.w900,
                color: FinColor.texto(context, color),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 3),
            Text(detalle!, style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
          ],
          if (extra != null) ...[const SizedBox(height: 6), extra!],
        ],
      ),
    );
  }
}

/// Cuadrícula que reparte tarjetas según el ancho disponible.
class Rejilla extends StatelessWidget {
  final List<Widget> hijos;
  final double anchoMinimo;
  final double espacio;
  const Rejilla({super.key, required this.hijos, this.anchoMinimo = 220, this.espacio = 12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columnas = (c.maxWidth / anchoMinimo).floor().clamp(1, hijos.length.clamp(1, 6));
      final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
      return Wrap(
        spacing: espacio,
        runSpacing: espacio,
        children: hijos.map((h) => SizedBox(width: ancho, child: h)).toList(),
      );
    });
  }
}

/// Dos columnas en pantalla ancha, una en angosta.
class DosColumnas extends StatelessWidget {
  final Widget izquierda;
  final Widget derecha;
  final double corte;
  const DosColumnas({super.key, required this.izquierda, required this.derecha, this.corte = 860});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < corte) {
        return Column(children: [izquierda, const SizedBox(height: 14), derecha]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: izquierda),
          const SizedBox(width: 14),
          Expanded(child: derecha),
        ],
      );
    });
  }
}

class Segmento {
  final double valor;
  final Color color;
  final String etiqueta;
  const Segmento(this.valor, this.color, this.etiqueta);
}

/// Barra horizontal apilada (por ejemplo, en qué se fue cada peso).
class BarraReparto extends StatelessWidget {
  final List<Segmento> segmentos;
  final double alto;
  const BarraReparto({super.key, required this.segmentos, this.alto = 22});

  @override
  Widget build(BuildContext context) {
    final total = segmentos.fold(0.0, (a, s) => a + (s.valor > 0 ? s.valor : 0));
    return ClipRRect(
      borderRadius: BorderRadius.circular(alto),
      child: Container(
        height: alto,
        color: context.chipBg,
        child: total <= 0
            ? null
            : Row(
                children: segmentos
                    .where((s) => s.valor > 0)
                    .map((s) => Expanded(
                          flex: (s.valor / total * 1000).round().clamp(1, 1000),
                          child: Tooltip(
                            message: '${s.etiqueta}: ${porcentaje(s.valor / total * 100)}',
                            child: Container(color: s.color),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

/// Fila con nombre, valor y barra proporcional.
class FilaBarra extends StatelessWidget {
  final String nombre;
  final String? detalle;
  final String valor;
  final double fraccion;
  final Color color;
  final Widget? insignia;
  const FilaBarra({
    super.key,
    required this.nombre,
    this.detalle,
    required this.valor,
    required this.fraccion,
    required this.color,
    this.insignia,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: nombre,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.textPrimary),
                    ),
                    if (detalle != null)
                      TextSpan(
                        text: '  $detalle',
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (insignia != null) ...[insignia!, const SizedBox(width: 6)],
              Text(
                valor,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: context.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraccion.isNaN ? 0 : fraccion.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: context.chipBg,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class Insignia extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData? icono;
  const Insignia(this.texto, this.color, {super.key, this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FinColor.fondo(context, color),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FinColor.borde(context, color)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: FinColor.texto(context, color)),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FinColor.texto(context, color)),
          ),
        ],
      ),
    );
  }
}

/// ↑ 12,5 % frente al período anterior. Con [alReves] subir es malo.
class Variacion extends StatelessWidget {
  final double? pct;
  final bool alReves;
  const Variacion(this.pct, {super.key, this.alReves = false});

  @override
  Widget build(BuildContext context) {
    if (pct == null || pct!.isNaN || pct!.isInfinite) {
      return Text(ft('Sin período anterior para comparar'),
          style: TextStyle(fontSize: 11, color: context.textSecondary));
    }
    final sube = pct! >= 0;
    final bueno = alReves ? !sube : sube;
    final color = pct!.abs() < 0.05 ? Colors.grey : (bueno ? FinColor.verde : FinColor.rojo);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(sube ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 13, color: FinColor.texto(context, color)),
        Text(
          ' ${porcentaje(pct!.abs())}',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: FinColor.texto(context, color)),
        ),
        Text(' ${ft('vs. período anterior')}', style: TextStyle(fontSize: 11, color: context.textSecondary)),
      ],
    );
  }
}

class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  const EstadoVacio({super.key, required this.icono, required this.titulo, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return FinCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icono, size: 42, color: context.textSecondary.withValues(alpha: 0.6)),
            const SizedBox(height: 10),
            Text(titulo,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.textPrimary)),
            const SizedBox(height: 4),
            Text(mensaje, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Una línea "concepto ........ valor" para listas tipo estado de cuenta.
class LineaValor extends StatelessWidget {
  final String concepto;
  final String valor;
  final bool fuerte;
  final Color? color;
  final String? nota;
  final double sangria;
  const LineaValor(this.concepto, this.valor,
      {super.key, this.fuerte = false, this.color, this.nota, this.sangria = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: sangria, top: 5, bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(concepto,
                    style: TextStyle(
                      fontSize: fuerte ? 14 : 13,
                      fontWeight: fuerte ? FontWeight.w900 : FontWeight.w500,
                      color: context.textPrimary,
                    )),
                if (nota != null)
                  Text(nota!, style: TextStyle(fontSize: 11, color: context.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: fuerte ? 15 : 13,
              fontWeight: fuerte ? FontWeight.w900 : FontWeight.w700,
              color: color ?? context.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barras por día: ventas (verde) frente a costo + gastos + mermas.
class GraficaDiaria extends StatelessWidget {
  final List<DiaFinanzas> dias;
  const GraficaDiaria({super.key, required this.dias});

  @override
  Widget build(BuildContext context) {
    double maximo = 1;
    for (final d in dias) {
      final salida = d.costo + d.gastos + d.mermas;
      if (d.ventas > maximo) maximo = d.ventas;
      if (salida > maximo) maximo = salida;
    }
    final pocos = dias.length <= 14;
    final cada = dias.length <= 14 ? 1 : (dias.length <= 31 ? 5 : 15);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _leyenda(context, FinColor.verde, ft('Ventas')),
            _leyenda(context, FinColor.ambar, ft('Costo de lo vendido')),
            _leyenda(context, FinColor.rosa, ft('Gastos')),
            _leyenda(context, FinColor.naranja, ft('Mermas')),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final minAncho = dias.length * (pocos ? 34.0 : 12.0);
          final ancho = c.maxWidth > minAncho ? c.maxWidth : minAncho;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: ancho,
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(dias.length, (i) {
                  final d = dias[i];
                  final u = d.utilidad;
                  return Expanded(
                    child: Tooltip(
                      message: '${DateFormat('EEEE d MMM', 'es_CO').format(d.fecha)}\n'
                          'Ventas: ${dinero(d.ventas)}\nCosto: ${dinero(d.costo)}\n'
                          'Gastos: ${dinero(d.gastos)}\nMermas: ${dinero(d.mermas)}\n'
                          '${u >= 0 ? 'Ganancia' : 'Pérdida'}: ${dinero(u)}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (pocos)
                              FittedBox(
                                child: Text(
                                  d.sinMovimiento ? '—' : dineroCorto(u),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: d.sinMovimiento
                                        ? context.textSecondary
                                        : FinColor.texto(context, u >= 0 ? FinColor.verde : FinColor.rojo),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 3),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(child: _barra([Segmento(d.ventas, FinColor.verde, '')], maximo)),
                                  const SizedBox(width: 1),
                                  Expanded(
                                    child: _barra([
                                      Segmento(d.costo, FinColor.ambar, ''),
                                      Segmento(d.gastos, FinColor.rosa, ''),
                                      Segmento(d.mermas, FinColor.naranja, ''),
                                    ], maximo),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: d.sinMovimiento
                                    ? context.borderSubtle
                                    : (u >= 0 ? FinColor.verde : FinColor.rojo),
                              ),
                            ),
                            SizedBox(
                              height: 14,
                              child: (i % cada == 0 || i == dias.length - 1)
                                  ? FittedBox(
                                      child: Text('${d.fecha.day}',
                                          style: TextStyle(fontSize: 10, color: context.textSecondary)),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        Text(
          ft('Los números de abajo son el día del mes. Pasa el mouse o mantén presionada una barra para ver el detalle.'),
          style: TextStyle(fontSize: 11, color: context.textSecondary),
        ),
      ],
    );
  }

  Widget _barra(List<Segmento> partes, double maximo) {
    final total = partes.fold(0.0, (a, s) => a + s.valor);
    return LayoutBuilder(builder: (context, c) {
      final alto = c.maxHeight * (total / maximo);
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            child: SizedBox(
              height: total > 0 ? alto.clamp(2.0, c.maxHeight) : 0,
              child: Column(
                children: partes.reversed
                    .where((s) => s.valor > 0)
                    .map((s) => Expanded(
                          flex: (s.valor / total * 1000).round().clamp(1, 1000),
                          child: Container(color: s.color),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _leyenda(BuildContext c, Color color, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(t, style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ],
      );
}

/// Mapa de calor de ventas por día de la semana y hora.
class MapaCalor extends StatelessWidget {
  final HorasPico datos;
  const MapaCalor({super.key, required this.datos});

  static const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    // Solo las horas en que hubo ventas, de la primera a la última.
    int desde = 24, hasta = -1;
    for (var h = 0; h < 24; h++) {
      for (var d = 0; d < 7; d++) {
        if (datos.celdas[d][h] > 0) {
          if (h < desde) desde = h;
          if (h > hasta) hasta = h;
        }
      }
    }
    if (hasta < 0) {
      return Text(ft('Sin ventas en el período'), style: TextStyle(color: context.textSecondary));
    }
    final max = datos.maximo;
    final horas = [for (var h = desde; h <= hasta; h++) h];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 36),
              ...horas.map((h) => SizedBox(
                    width: 34,
                    child: Center(
                      child: Text(_hora(h), style: TextStyle(fontSize: 9.5, color: context.textSecondary)),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 4),
          ...List.generate(7, (d) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(dias[d],
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textSecondary)),
                  ),
                  ...horas.map((h) {
                    final v = datos.celdas[d][h];
                    final t = max > 0 ? v / max : 0.0;
                    return Tooltip(
                      message: '${dias[d]} ${_hora(h)}: ${dinero(v)} · ${datos.tickets[d][h]} ventas',
                      child: Container(
                        width: 31,
                        height: 24,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: v <= 0
                              ? context.chipBg
                              : Color.lerp(
                                  FinColor.verde.withValues(alpha: 0.15),
                                  FinColor.verde,
                                  t,
                                ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _hora(int h) {
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12${h < 12 ? 'a' : 'p'}';
  }
}
