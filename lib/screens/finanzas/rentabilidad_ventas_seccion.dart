import 'package:flutter/material.dart';

import '../../services/finanzas_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/finanzas_ui.dart';
import '../reports_screen.dart';

Color colorMargen(double m) => m >= 25 ? FinColor.verde : (m >= 10 ? FinColor.ambar : FinColor.rojo);

/// Qué deja más plata: margen por categoría y por producto.
class RentabilidadSeccion extends StatelessWidget {
  final FinanzasService fin;
  final Periodo periodo;
  final int? usuarioId;
  final String clave;
  const RentabilidadSeccion({
    super.key,
    required this.fin,
    required this.periodo,
    required this.usuarioId,
    required this.clave,
  });

  @override
  Widget build(BuildContext context) {
    return CargaSeccion<Rentabilidad>(
      clave: clave,
      cargar: () => fin.rentabilidad(periodo, usuarioId: usuarioId),
      construir: (context, r) {
        if (r.productos.isEmpty) {
          return EstadoVacio(
            icono: Icons.trending_up_rounded,
            titulo: ft('Sin ventas en el período'),
            mensaje: ft('Prueba con otro rango de días.'),
          );
        }
        final maxCat = r.categorias.fold(1.0, (a, c) => c.utilidad.abs() > a ? c.utilidad.abs() : a);
        final mejores = r.masUtilidad;
        final maxProd = mejores.fold(1.0, (a, p) => p.utilidad > a ? p.utilidad : a);
        final bajos = r.margenBajo;
        final sinCosto = r.sinCosto;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinCard(
              titulo: ft('Rentabilidad por categoría'),
              subtitulo: ft('Cuánto deja cada categoría después de pagar la mercancía'),
              icono: Icons.category_rounded,
              colorIcono: FinColor.ambar,
              child: Column(
                children: r.categorias
                    .map((c) => FilaBarra(
                          nombre: c.nombre,
                          detalle: '${ft('vendió')} ${dinero(c.ventas)}',
                          valor: dinero(c.utilidad),
                          fraccion: c.utilidad.abs() / maxCat,
                          color: c.utilidad < 0 ? FinColor.rojo : FinColor.verde,
                          insignia: c.sinCosto
                              ? Insignia(ft('costo incompleto'), FinColor.ambar, icono: Icons.warning_amber_rounded)
                              : Insignia(porcentaje(c.margen), colorMargen(c.margen)),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            DosColumnas(
              izquierda: FinCard(
                titulo: ft('Productos que más dejan'),
                subtitulo: ft('Ganancia en pesos en el período'),
                icono: Icons.emoji_events_rounded,
                colorIcono: FinColor.verde,
                child: mejores.isEmpty
                    ? Text(ft('Registra el costo de los productos para ver su ganancia.'),
                        style: TextStyle(color: context.textSecondary))
                    : Column(
                        children: mejores
                            .map((p) => FilaBarra(
                                  nombre: p.nombre,
                                  detalle: '${cantidad(p.cantidad)} · ${dinero(p.ventas)}',
                                  valor: dinero(p.utilidad),
                                  fraccion: p.utilidad / maxProd,
                                  color: FinColor.verde,
                                  insignia: Insignia(porcentaje(p.margen), colorMargen(p.margen)),
                                ))
                            .toList(),
                      ),
              ),
              derecha: FinCard(
                titulo: ft('Margen bajo o en pérdida'),
                subtitulo: ft('Dejan menos del 10 %: revisa el precio de venta o el costo de compra'),
                icono: Icons.report_problem_rounded,
                colorIcono: FinColor.rojo,
                child: bajos.isEmpty
                    ? Row(children: [
                        const Icon(Icons.check_circle_rounded, color: FinColor.verde, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(ft('Todos los productos vendidos dejan más del 10 %.'),
                              style: TextStyle(color: context.textSecondary)),
                        ),
                      ])
                    : Column(
                        children: bajos
                            .map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.nombre,
                                                style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary)),
                                            Text(
                                              '${ft('Vendió')} ${dinero(p.ventas)} · ${ft('costó')} ${dinero(p.costo)}',
                                              style: TextStyle(fontSize: 11, color: context.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Insignia(porcentaje(p.margen), colorMargen(p.margen)),
                                          const SizedBox(height: 3),
                                          Text(dinero(p.utilidad),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: FinColor.texto(
                                                      context, p.utilidad < 0 ? FinColor.rojo : FinColor.ambar))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
              ),
            ),
            if (sinCosto.isNotEmpty) ...[
              const SizedBox(height: 14),
              FinCard(
                titulo: '${ft('Productos sin costo registrado')} (${sinCosto.length})',
                subtitulo: ft('Su ganancia aparece como el 100 % de la venta. Asigna el costo en Inventario o registra una compra.'),
                icono: Icons.warning_amber_rounded,
                colorIcono: FinColor.ambar,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sinCosto
                      .take(40)
                      .map((p) => Insignia('${p.nombre} · ${dineroCorto(p.ventas)}', FinColor.ambar))
                      .toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Productos más vendidos, horas pico y días fuertes.
class VentasSeccion extends StatelessWidget {
  final FinanzasService fin;
  final Periodo periodo;
  final int? usuarioId;
  final String clave;
  const VentasSeccion({
    super.key,
    required this.fin,
    required this.periodo,
    required this.usuarioId,
    required this.clave,
  });

  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  Future<Map<String, Object>> _cargar() async => {
        'res': await fin.resultados(periodo, usuarioId: usuarioId),
        'top': await fin.topProductos(periodo, usuarioId: usuarioId, limite: 12),
        'horas': await fin.horasPico(periodo, usuarioId: usuarioId),
      };

  @override
  Widget build(BuildContext context) {
    return CargaSeccion<Map<String, Object>>(
      clave: clave,
      cargar: _cargar,
      construir: (context, d) {
        final r = d['res'] as Resultados;
        final top = d['top'] as List<Map<String, dynamic>>;
        final h = d['horas'] as HorasPico;
        if (r.cantidadVentas == 0) {
          return EstadoVacio(
            icono: Icons.storefront_outlined,
            titulo: ft('Sin ventas en el período'),
            mensaje: ft('Prueba con otro rango de días.'),
          );
        }
        final maxTop = top.fold(1.0, (a, t) => ((t['dinero_total'] as num?)?.toDouble() ?? 0) > a
            ? (t['dinero_total'] as num).toDouble()
            : a);
        final hp = h.horaPico;
        final dp = h.diaPico;
        final prom = h.promedioDia;
        final maxProm = prom.fold(1.0, (a, b) => b > a ? b : a);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Rejilla(anchoMinimo: 220, hijos: [
              KpiTile(
                etiqueta: ft('Vendido'),
                valor: dinero(r.ventas),
                detalle: '${ft('Promedio por día')} ${dinero(r.ventas / periodo.dias)}',
                icono: Icons.payments_rounded,
                color: FinColor.verde,
                extra: Variacion(r.variacionVentas),
              ),
              KpiTile(
                etiqueta: ft('Ventas realizadas'),
                valor: cantidad(r.cantidadVentas),
                detalle: '${ft('Ticket promedio')} ${dinero(r.ticketPromedio)}',
                icono: Icons.receipt_rounded,
                color: FinColor.azul,
              ),
              KpiTile(
                etiqueta: ft('Hora pico'),
                valor: hp == null ? '—' : '${horaLarga(hp)} – ${horaLarga(hp + 1)}',
                detalle: hp == null ? null : '${dinero(h.porHora[hp])} ${ft('en esa hora')}',
                icono: Icons.schedule_rounded,
                color: FinColor.violeta,
              ),
              KpiTile(
                etiqueta: ft('Mejor día'),
                valor: dp == null ? '—' : ft(_dias[dp]),
                detalle: dp == null ? null : '${ft('Promedio')} ${dinero(prom[dp])}',
                icono: Icons.event_available_rounded,
                color: FinColor.cian,
              ),
            ]),
            const SizedBox(height: 14),
            DosColumnas(
              izquierda: FinCard(
                titulo: ft('Productos más vendidos'),
                subtitulo: ft('Por dinero vendido'),
                icono: Icons.emoji_events_rounded,
                colorIcono: FinColor.ambar,
                child: Column(
                  children: top.asMap().entries.map((e) {
                    final t = e.value;
                    final dinero_ = (t['dinero_total'] as num?)?.toDouble() ?? 0;
                    return FilaBarra(
                      nombre: '${e.key + 1}. ${t['nombre_producto']}',
                      detalle: cantidad((t['cantidad_total'] as num?) ?? 0),
                      valor: dinero(dinero_),
                      fraccion: dinero_ / maxTop,
                      color: e.key < 3 ? FinColor.ambar : FinColor.azul,
                    );
                  }).toList(),
                ),
              ),
              derecha: FinCard(
                titulo: ft('Promedio por día de la semana'),
                subtitulo: ft('Ventas ÷ cuántos de ese día tiene el período'),
                icono: Icons.calendar_view_week_rounded,
                colorIcono: FinColor.cian,
                child: Column(
                  children: List.generate(7, (i) => FilaBarra(
                        nombre: ft(_dias[i]),
                        detalle: '${h.vecesDia[i]} ${h.vecesDia[i] == 1 ? ft('día') : ft('días')}',
                        valor: dinero(prom[i]),
                        fraccion: prom[i] / maxProm,
                        color: i == dp ? FinColor.cian : FinColor.azul.withValues(alpha: 0.6),
                      )),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FinCard(
              titulo: ft('Mapa de calor: cuándo se vende'),
              subtitulo: ft('Más oscuro = más ventas. Úsalo para programar turnos y surtido.'),
              icono: Icons.grid_on_rounded,
              colorIcono: FinColor.verde,
              child: MapaCalor(datos: h),
            ),
          ],
        );
      },
    );
  }
}

String horaLarga(int h) {
  final x = h % 24;
  final h12 = x % 12 == 0 ? 12 : x % 12;
  return '$h12 ${x < 12 ? 'a. m.' : 'p. m.'}';
}
