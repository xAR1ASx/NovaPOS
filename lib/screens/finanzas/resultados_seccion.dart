import 'package:flutter/material.dart';

import '../../services/finanzas_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/finanzas_ui.dart';
import '../reports_screen.dart';

/// Estado de resultados del período: cascada, reparto de cada peso,
/// detalle contable y evolución día a día.
class ResultadosSeccion extends StatelessWidget {
  final FinanzasService fin;
  final Periodo periodo;
  final int? usuarioId;
  final String clave;
  const ResultadosSeccion({
    super.key,
    required this.fin,
    required this.periodo,
    required this.usuarioId,
    required this.clave,
  });

  @override
  Widget build(BuildContext context) {
    return CargaSeccion<Resultados>(
      clave: clave,
      cargar: () => fin.resultados(periodo, usuarioId: usuarioId),
      construir: (context, r) {
        if (r.vacio) {
          return EstadoVacio(
            icono: Icons.savings_outlined,
            titulo: ft('No hay movimientos en estas fechas'),
            mensaje: ft('No se registraron ventas, gastos ni compras. Prueba con otro rango de días.'),
          );
        }
        final perdida = r.utilidadNeta < 0;
        final otrasPerdidas = r.mermas + (r.descuadreNeto > 0 ? r.descuadreNeto : 0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Cascada
            Rejilla(anchoMinimo: 240, hijos: [
              KpiTile(
                etiqueta: ft('Ventas'),
                valor: dinero(r.ventas),
                detalle: '${r.cantidadVentas} ${ft('ventas')} · ${ft('ticket promedio')} ${dinero(r.ticketPromedio)}',
                icono: Icons.trending_up_rounded,
                color: FinColor.verde,
                extra: Variacion(r.variacionVentas),
              ),
              KpiTile(
                etiqueta: ft('Costo de lo vendido'),
                signo: '−',
                valor: dinero(r.costoVentas),
                detalle: '${ft('Utilidad bruta')} ${dinero(r.utilidadBruta)} · ${porcentaje(r.margenBruto)}',
                icono: Icons.shopping_basket_rounded,
                color: FinColor.ambar,
              ),
              KpiTile(
                etiqueta: ft('Gastos y pérdidas'),
                signo: '−',
                valor: dinero(r.gastos + otrasPerdidas),
                detalle: '${ft('Gastos')} ${dinero(r.gastos)} · ${ft('Mermas')} ${dinero(r.mermas)}',
                icono: Icons.receipt_long_rounded,
                color: FinColor.rosa,
              ),
              KpiTile(
                etiqueta: perdida ? ft('Pérdida') : ft('Ganancia'),
                signo: '=',
                valor: dinero(r.utilidadNeta),
                detalle: '${ft('Margen neto')} ${porcentaje(r.margenNeto)}',
                icono: perdida ? Icons.trending_down_rounded : Icons.savings_rounded,
                color: perdida ? FinColor.rojo : FinColor.verde,
                grande: true,
                extra: Variacion(r.variacionUtilidad),
              ),
            ]),
            const SizedBox(height: 14),

            // 2. En qué se fue cada peso
            FinCard(
              titulo: ft('¿En qué se fue cada peso vendido?'),
              subtitulo: perdida
                  ? ft('Lo que costó la mercancía más los gastos superó lo vendido: la parte roja es lo que faltó.')
                  : ft('De cada \$100 que entraron por ventas, esto se fue en mercancía, en gastos y esto quedó.'),
              icono: Icons.pie_chart_rounded,
              colorIcono: FinColor.verde,
              child: _reparto(context, r),
            ),
            const SizedBox(height: 14),

            DosColumnas(
              // 3. Estado de resultados
              izquierda: FinCard(
                titulo: ft('Estado de resultados'),
                subtitulo: ft('Vista de gestión con el costo real de cada unidad vendida'),
                icono: Icons.account_balance_rounded,
                colorIcono: FinColor.azul,
                child: Column(
                  children: [
                    LineaValor(ft('Ventas netas'), dinero(r.ventas),
                        nota: r.devoluciones > 0 ? '${ft('Ya descontadas devoluciones por')} ${dinero(r.devoluciones)}' : null),
                    LineaValor('(−) ${ft('Costo de lo vendido')}', dinero(r.costoVentas), sangria: 10),
                    const Divider(height: 14),
                    LineaValor('= ${ft('Utilidad bruta')}', dinero(r.utilidadBruta),
                        fuerte: true, nota: '${ft('Margen bruto')} ${porcentaje(r.margenBruto)}'),
                    LineaValor('(−) ${ft('Gastos operativos')}', dinero(r.gastos), sangria: 10),
                    LineaValor('(−) ${ft('Mermas y desperdicios')}', dinero(r.mermas), sangria: 10),
                    if (r.descuadreNeto != 0)
                      LineaValor(
                        r.descuadreNeto > 0 ? '(−) ${ft('Faltantes de caja')}' : '(+) ${ft('Sobrantes de caja')}',
                        dinero(r.descuadreNeto.abs()),
                        sangria: 10,
                        nota: '${ft('Faltantes')} ${dinero(r.faltantesCaja)} · ${ft('sobrantes')} ${dinero(r.sobrantesCaja)}',
                      ),
                    const Divider(height: 14),
                    LineaValor(
                      '= ${ft('UTILIDAD NETA')}',
                      dinero(r.utilidadNeta),
                      fuerte: true,
                      color: FinColor.texto(context, perdida ? FinColor.rojo : FinColor.verde),
                      nota: '${ft('Margen neto')} ${porcentaje(r.margenNeto)}',
                    ),
                  ],
                ),
              ),
              // 4. Para tener en cuenta
              derecha: FinCard(
                titulo: ft('Para tener en cuenta'),
                subtitulo: ft('No cambian la utilidad, pero mueven la plata'),
                icono: Icons.info_outline_rounded,
                colorIcono: FinColor.cian,
                child: Column(
                  children: [
                    LineaValor(ft('Compras de mercancía'), dinero(r.compras),
                        nota: '${r.cantidadCompras} ${ft('facturas · se vuelven costo cuando se venden')}'),
                    LineaValor(ft('Vendido fiado'), dinero(r.ventasFiadas), nota: ft('Incluido en ventas; aún por cobrar')),
                    LineaValor(ft('Abonos de clientes'), dinero(r.abonosClientes), nota: ft('Cobro de fiados anteriores')),
                    LineaValor(ft('Devoluciones'), dinero(r.devoluciones), nota: '${r.cantidadDevoluciones} ${ft('artículos devueltos')}'),
                    LineaValor(ft('Ventas anuladas'), dinero(r.anuladas), nota: '${r.cantidadAnuladas} ${ft('ventas')}'),
                    if (r.prestamos > 0)
                      LineaValor(ft('Préstamos que salieron de caja'), dinero(r.prestamos), nota: ft('Deben volver')),
                    if (r.retiros > 0) LineaValor(ft('Retiros del dueño'), dinero(r.retiros)),
                  ],
                ),
              ),
            ),
            if (r.ventasSinCosto > 0) ...[
              const SizedBox(height: 14),
              _aviso(
                context,
                Icons.warning_amber_rounded,
                FinColor.ambar,
                '${dinero(r.ventasSinCosto)} ${ft('en ventas de productos sin costo registrado.')}',
                ft('Su utilidad aparece completa. Registra el costo en Inventario o con una compra para que la ganancia sea exacta (ver Rentabilidad).'),
              ),
            ],
            const SizedBox(height: 14),

            // 5. Día a día
            FinCard(
              titulo: ft('Día a día'),
              subtitulo: ft('Lo que entró por ventas frente a lo que costó y se gastó cada día'),
              icono: Icons.bar_chart_rounded,
              colorIcono: FinColor.violeta,
              child: r.diario.length <= 1
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: context.cardSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderSubtle),
                      ),
                      child: Text(ft('Elige un rango de varios días para ver la evolución.'),
                          textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary)),
                    )
                  : GraficaDiaria(dias: r.diario),
            ),
            const SizedBox(height: 10),
            Text(
              ft('Utilidad neta = Ventas − Costo de lo vendido − Gastos − Mermas − Faltantes de caja. '
                  'El costo es el de cada unidad al momento de venderla, así que las compras no restan el día que se pagan.'),
              style: TextStyle(fontSize: 11, color: context.textSecondary, height: 1.4),
            ),
          ],
        );
      },
    );
  }

  Widget _reparto(BuildContext context, Resultados r) {
    final otros = r.mermas + (r.descuadreNeto > 0 ? r.descuadreNeto : 0);
    final salidas = r.costoVentas + r.gastos + otros;
    final base = [r.ventas, salidas, 1.0].reduce((a, b) => a > b ? a : b);
    double p(double v) => v / base * 100;
    final ganancia = r.utilidadNeta > 0 ? r.utilidadNeta : 0.0;
    final segs = [
      Segmento(r.costoVentas, FinColor.ambar, ft('Mercancía')),
      Segmento(r.gastos, FinColor.rosa, ft('Gastos')),
      Segmento(otros, FinColor.naranja, ft('Mermas y faltantes')),
      Segmento(ganancia, FinColor.verde, ft('Ganancia')),
    ];
    Widget chip(Color c, String t, String v) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: context.cardSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderSubtle),
          ),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(child: Text(t, style: TextStyle(fontSize: 12.5, color: context.textPrimary))),
              Text(v, style: TextStyle(fontWeight: FontWeight.w900, color: FinColor.texto(context, c))),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BarraReparto(segmentos: segs),
        if (r.utilidadNeta < 0) ...[
          const SizedBox(height: 4),
          Row(children: [
            Expanded(flex: (100 - p(-r.utilidadNeta)).round().clamp(0, 100), child: const SizedBox()),
            Expanded(
              flex: p(-r.utilidadNeta).round().clamp(1, 100),
              child: Container(height: 6, decoration: BoxDecoration(color: FinColor.rojo, borderRadius: BorderRadius.circular(6))),
            ),
          ]),
        ],
        const SizedBox(height: 12),
        Rejilla(anchoMinimo: 200, espacio: 8, hijos: [
          chip(FinColor.ambar, ft('Mercancía vendida'), porcentaje(p(r.costoVentas))),
          chip(FinColor.rosa, ft('Gastos'), porcentaje(p(r.gastos))),
          chip(FinColor.naranja, ft('Mermas y faltantes'), porcentaje(p(otros))),
          r.utilidadNeta < 0
              ? chip(FinColor.rojo, ft('Pérdida'), dinero(-r.utilidadNeta))
              : chip(FinColor.verde, ft('Ganancia'), porcentaje(p(ganancia))),
        ]),
      ],
    );
  }
}

Widget _aviso(BuildContext context, IconData icono, Color color, String titulo, String texto) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FinColor.fondo(context, color),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: FinColor.borde(context, color)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: FinColor.texto(context, color)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary)),
              const SizedBox(height: 2),
              Text(texto, style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Gastos por categoría, compras por proveedor, flujo de efectivo y medios de pago.
class GastosSeccion extends StatefulWidget {
  final FinanzasService fin;
  final Periodo periodo;
  final int? usuarioId;
  final String clave;
  const GastosSeccion({
    super.key,
    required this.fin,
    required this.periodo,
    required this.usuarioId,
    required this.clave,
  });

  @override
  State<GastosSeccion> createState() => _GastosSeccionState();
}

class _GastosSeccionState extends State<GastosSeccion> {
  bool _verDetalle = false;

  @override
  Widget build(BuildContext context) {
    return CargaSeccion<GastosCompras>(
      clave: widget.clave,
      cargar: () => widget.fin.gastosCompras(widget.periodo, usuarioId: widget.usuarioId),
      construir: (context, g) {
        final maxCat = g.gastosPorCategoria.fold(1.0, (a, x) => x.total > a ? x.total : a);
        final maxProv = g.comprasPorProveedor.fold(1.0, (a, x) => x.total > a ? x.total : a);
        final maxMet = g.metodosPago.fold(1.0, (a, x) => x.total > a ? x.total : a);
        final totalMet = g.metodosPago.fold(0.0, (a, x) => a + x.total);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Rejilla(anchoMinimo: 240, hijos: [
              KpiTile(
                etiqueta: ft('Gastos del negocio'),
                valor: dinero(g.totalGastos),
                detalle: '${g.gastos.length} ${ft('salidas de caja')}',
                icono: Icons.receipt_long_rounded,
                color: FinColor.rosa,
              ),
              KpiTile(
                etiqueta: ft('Compras de mercancía'),
                valor: dinero(g.totalCompras),
                detalle: '${dinero(g.comprasConCaja)} ${ft('pagadas con la caja')}',
                icono: Icons.local_shipping_rounded,
                color: FinColor.ambar,
              ),
              KpiTile(
                etiqueta: ft('Flujo de efectivo'),
                valor: dinero(g.flujoNeto),
                detalle: '${ft('Entró')} ${dinero(g.totalEntradas)} · ${ft('salió')} ${dinero(g.totalSalidas)}',
                icono: Icons.swap_vert_rounded,
                color: g.flujoNeto >= 0 ? FinColor.verde : FinColor.rojo,
                grande: true,
              ),
            ]),
            const SizedBox(height: 14),
            DosColumnas(
              izquierda: FinCard(
                titulo: ft('Gastos por categoría'),
                icono: Icons.category_rounded,
                colorIcono: FinColor.rosa,
                accion: Text(dinero(g.totalGastos),
                    style: TextStyle(fontWeight: FontWeight.w900, color: FinColor.texto(context, FinColor.rosa))),
                child: g.gastosPorCategoria.isEmpty
                    ? _vacio(context, ft('No hubo gastos en estas fechas.'))
                    : Column(
                        children: g.gastosPorCategoria
                            .map((c) => FilaBarra(
                                  nombre: ft(c.nombre),
                                  detalle: '${c.cantidad} ${c.cantidad == 1 ? ft('vez') : ft('veces')}',
                                  valor: dinero(c.total),
                                  fraccion: c.total / maxCat,
                                  color: c.clave == 'DESCUADRE' ? FinColor.rojo : FinColor.rosa,
                                ))
                            .toList(),
                      ),
              ),
              derecha: FinCard(
                titulo: ft('Compras por proveedor'),
                icono: Icons.local_shipping_rounded,
                colorIcono: FinColor.ambar,
                accion: Text(dinero(g.totalCompras),
                    style: TextStyle(fontWeight: FontWeight.w900, color: FinColor.texto(context, FinColor.ambar))),
                child: g.comprasPorProveedor.isEmpty
                    ? _vacio(context, ft('No se registraron compras en estas fechas.'))
                    : Column(
                        children: g.comprasPorProveedor
                            .map((p) => FilaBarra(
                                  nombre: p.nombre,
                                  detalle: '${p.cantidad} ${p.cantidad == 1 ? ft('factura') : ft('facturas')}',
                                  valor: dinero(p.total),
                                  fraccion: p.total / maxProv,
                                  color: FinColor.ambar,
                                ))
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            DosColumnas(
              izquierda: FinCard(
                titulo: ft('Flujo de efectivo'),
                subtitulo: ft('Billetes que entraron y salieron de las cajas'),
                icono: Icons.payments_rounded,
                colorIcono: FinColor.verde,
                child: Column(
                  children: [
                    _encabezadoFlujo(context, ft('ENTRÓ'), g.totalEntradas, FinColor.verde),
                    LineaValor(ft('Ventas cobradas en efectivo'), dinero(g.entroVentas), sangria: 8),
                    LineaValor(ft('Abonos de clientes'), dinero(g.entroAbonos), sangria: 8),
                    LineaValor(ft('Bases extra, aportes y otros ingresos'), dinero(g.entroOtros), sangria: 8),
                    const SizedBox(height: 8),
                    _encabezadoFlujo(context, ft('SALIÓ'), g.totalSalidas, FinColor.rojo),
                    LineaValor(ft('Gastos'), dinero(g.salioGastos), sangria: 8),
                    LineaValor(ft('Compras pagadas con la caja'), dinero(g.salioCompras), sangria: 8),
                    LineaValor(ft('Devoluciones y anulaciones en efectivo'), dinero(g.salioDevoluciones), sangria: 8),
                    LineaValor(ft('Préstamos y retiros'), dinero(g.salioPrestamosRetiros), sangria: 8),
                    const Divider(height: 16),
                    LineaValor(
                      ft('= Neto del período'),
                      dinero(g.flujoNeto),
                      fuerte: true,
                      color: FinColor.texto(context, g.flujoNeto >= 0 ? FinColor.verde : FinColor.rojo),
                    ),
                  ],
                ),
              ),
              derecha: FinCard(
                titulo: ft('Ventas por medio de pago'),
                icono: Icons.credit_card_rounded,
                colorIcono: FinColor.azul,
                child: g.metodosPago.isEmpty
                    ? _vacio(context, ft('Sin ventas en el período'))
                    : Column(
                        children: g.metodosPago
                            .map((m) => FilaBarra(
                                  nombre: ft(m.nombre),
                                  detalle: totalMet > 0 ? porcentaje(m.total / totalMet * 100) : null,
                                  valor: dinero(m.total),
                                  fraccion: m.total / maxMet,
                                  color: _colorMetodo(m.clave),
                                ))
                            .toList(),
                      ),
              ),
            ),
            if (g.salidasNoGasto.isNotEmpty) ...[
              const SizedBox(height: 14),
              FinCard(
                titulo: ft('Salidas que no son gasto'),
                subtitulo: ft('Préstamos (deben volver) y retiros del dueño: no restan de la utilidad'),
                icono: Icons.compare_arrows_rounded,
                colorIcono: FinColor.cian,
                child: Column(
                  children: g.salidasNoGasto
                      .map((s) => LineaValor(ft(s.nombre), dinero(s.total), nota: '${s.cantidad} ${ft('movimientos')}'))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FinCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: g.gastos.isEmpty ? null : () => setState(() => _verDetalle = !_verDetalle),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.list_alt_rounded, size: 18, color: context.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(ft('Detalle de gastos'),
                                style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary)),
                          ),
                          Insignia(
                            g.gastos.isEmpty
                                ? ft('Sin gastos')
                                : (_verDetalle ? ft('Ocultar') : '${ft('Ver')} (${g.gastos.length})'),
                            FinColor.violeta,
                            icono: _verDetalle ? Icons.expand_less : Icons.expand_more,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_verDetalle)
                    ...g.gastos.map((x) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: context.borderSubtle))),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                      Insignia(ft(x.categoria), FinColor.rosa),
                                      Text(fechaHora(x.fecha), style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(x.descripcion.isEmpty ? ft('Sin descripción') : x.descripcion,
                                        style: TextStyle(color: context.textPrimary, fontSize: 13)),
                                    Text('${ft('Registró')}: ${x.usuario}',
                                        style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                  ],
                                ),
                              ),
                              Text(dinero(x.monto),
                                  style: TextStyle(fontWeight: FontWeight.w900, color: FinColor.texto(context, FinColor.rosa))),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _encabezadoFlujo(BuildContext context, String t, double v, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: FinColor.fondo(context, c), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(
              child: Text(t,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8, color: FinColor.texto(context, c)))),
          Text(dinero(v), style: TextStyle(fontWeight: FontWeight.w900, color: FinColor.texto(context, c))),
        ]),
      );
}

Color _colorMetodo(String m) {
  switch (m) {
    case 'EFECTIVO':
      return FinColor.verde;
    case 'CREDITO':
      return FinColor.ambar;
    case 'NEQUI':
      return FinColor.violeta;
    case 'DAVIPLATA':
      return FinColor.rojo;
    case 'TARJETA':
      return FinColor.azul;
    default:
      return FinColor.cian;
  }
}

Widget _vacio(BuildContext context, String t) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t, style: TextStyle(color: context.textSecondary)));
