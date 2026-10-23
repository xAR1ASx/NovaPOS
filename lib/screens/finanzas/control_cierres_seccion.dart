import 'dart:convert';
import 'package:flutter/material.dart';

import '../../database/db_helper.dart';
import '../../services/finanzas_service.dart';
import '../../widgets/reporte_z_vista.dart';
import '../../services/theme_service.dart';
import '../../utils/categorias_caja.dart';
import '../../widgets/finanzas_ui.dart';
import '../reports_screen.dart';

const Map<String, (String, IconData, Color)> _tipos = {
  'ANULACION': ('Anulaciones', Icons.block_rounded, FinColor.rojo),
  'DEVOLUCION': ('Devoluciones', Icons.undo_rounded, FinColor.naranja),
  'MERMA': ('Mermas', Icons.delete_sweep_rounded, FinColor.ambar),
  'DESCUADRE': ('Descuadres', Icons.report_rounded, FinColor.violeta),
};

/// Anulaciones, devoluciones, mermas y descuadres, con quién los hizo.
class ControlSeccion extends StatefulWidget {
  final FinanzasService fin;
  final Periodo periodo;
  final int? usuarioId;
  final String clave;
  const ControlSeccion({super.key, required this.fin, required this.periodo, required this.usuarioId, required this.clave});

  @override
  State<ControlSeccion> createState() => _ControlSeccionState();
}

class _ControlSeccionState extends State<ControlSeccion> {
  String? _filtro;

  @override
  Widget build(BuildContext context) {
    return CargaSeccion<Control>(
      clave: widget.clave,
      cargar: () => widget.fin.control(widget.periodo, usuarioId: widget.usuarioId),
      construir: (context, c) {
        if (c.eventos.isEmpty) {
          return EstadoVacio(
            icono: Icons.verified_user_rounded,
            titulo: ft('Sin novedades en estas fechas'),
            mensaje: ft('No hubo anulaciones, devoluciones, mermas ni descuadres.'),
          );
        }
        final visibles = c.eventos.where((e) => _filtro == null || e.tipo == _filtro).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Rejilla(
              anchoMinimo: 200,
              hijos: _tipos.entries.map((t) {
                final activo = _filtro == t.key;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _filtro = activo ? null : t.key),
                  child: KpiTile(
                    etiqueta: ft(t.value.$1),
                    valor: dinero(c.monto(t.key)),
                    detalle: '${c.cantidad(t.key)} ${ft('casos')}${activo ? ' · ${ft('filtrando')}' : ''}',
                    icono: t.value.$2,
                    color: t.value.$3,
                    grande: activo,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            FinCard(
              titulo: ft('Por persona'),
              icono: Icons.people_alt_rounded,
              colorIcono: FinColor.naranja,
              child: Column(
                children: c.porPersona
                    .map((p) => LineaValor(
                          p.usuario,
                          dinero(p.monto),
                          nota: _tipos.keys
                              .where((k) => (p.porTipo[k] ?? 0) > 0)
                              .map((k) => '${p.porTipo[k]} ${ft(_tipos[k]!.$1).toLowerCase()}')
                              .join(' · '),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            FinCard(
              titulo: '${ft('Detalle')} (${visibles.length})',
              icono: Icons.list_alt_rounded,
              colorIcono: FinColor.violeta,
              child: Column(
                children: visibles.map((e) {
                  final t = _tipos[e.tipo]!;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.borderSubtle))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                Insignia(ft(t.$1), t.$3, icono: t.$2),
                                Text(fechaHora(e.fecha), style: TextStyle(fontSize: 11, color: context.textSecondary)),
                              ]),
                              const SizedBox(height: 4),
                              Text(e.titulo, style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary)),
                              Text(e.detalle, style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
                              Text(
                                '${ft('Hizo')}: ${e.usuario}${e.motivo.isEmpty ? '' : ' · ${ft('Motivo')}: ${e.motivo}'}',
                                style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(dinero(e.monto),
                              style: TextStyle(fontWeight: FontWeight.w900, color: FinColor.texto(context, t.$3))),
                          if (e.efectivo > 0)
                            Text('${ft('efectivo')} ${dinero(e.efectivo)}',
                                style: TextStyle(fontSize: 11, color: context.textSecondary)),
                        ]),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Auditoría de cierres: estado de cada turno y acumulado por cajero.
class CierresSeccion extends StatelessWidget {
  final FinanzasService fin;
  final Periodo periodo;
  final int? usuarioId;
  final String clave;
  final VoidCallback alCambiar;
  const CierresSeccion({
    super.key,
    required this.fin,
    required this.periodo,
    required this.usuarioId,
    required this.clave,
    required this.alCambiar,
  });

  static (String, Color) _estado(String e) => switch (e) {
        'CUADRADO' => ('Cuadrado', FinColor.verde),
        'FALTANTE' => ('Faltante', FinColor.rojo),
        'SOBRANTE' => ('Sobrante', FinColor.azul),
        _ => ('En curso', FinColor.violeta),
      };

  @override
  Widget build(BuildContext context) {
    return CargaSeccion<Cierres>(
      clave: clave,
      cargar: () => fin.cierresDe(periodo, usuarioId: usuarioId),
      construir: (context, c) {
        if (c.cierres.isEmpty) {
          return EstadoVacio(
            icono: Icons.point_of_sale_outlined,
            titulo: ft('No hay turnos en estas fechas'),
            mensaje: ft('Prueba con otro rango de días.'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Rejilla(anchoMinimo: 200, hijos: [
              KpiTile(
                etiqueta: ft('Turnos'),
                valor: '${c.cierres.length}',
                detalle: '${c.contar('CUADRADO')} ${ft('cuadrados')}',
                icono: Icons.point_of_sale_rounded,
                color: FinColor.violeta,
              ),
              KpiTile(
                etiqueta: ft('Faltante total'),
                valor: dinero(c.totalFaltante),
                detalle: '${c.contar('FALTANTE')} ${ft('turnos')}',
                icono: Icons.trending_down_rounded,
                color: FinColor.rojo,
              ),
              KpiTile(
                etiqueta: ft('Sobrante total'),
                valor: dinero(c.totalSobrante),
                detalle: '${c.contar('SOBRANTE')} ${ft('turnos')}',
                icono: Icons.trending_up_rounded,
                color: FinColor.azul,
              ),
            ]),
            const SizedBox(height: 14),
            FinCard(
              titulo: ft('Por cajero'),
              icono: Icons.person_rounded,
              colorIcono: FinColor.violeta,
              child: Column(
                children: c.porCajero
                    .map((p) => LineaValor(
                          p.cajero,
                          p.neto == 0 ? dinero(0) : (p.neto < 0 ? '− ${dinero(-p.neto)}' : '+ ${dinero(p.neto)}'),
                          color: FinColor.texto(context, p.neto < 0 ? FinColor.rojo : (p.neto > 0 ? FinColor.azul : FinColor.verde)),
                          nota: '${p.turnos} ${ft('turnos')} · ${p.cuadrados} ${ft('cuadrados')} · '
                              '${ft('faltó')} ${dinero(p.faltante)} · ${ft('sobró')} ${dinero(p.sobrante)}',
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            FinCard(
              titulo: ft('Turnos'),
              subtitulo: ft('Toca un turno para ver todos sus movimientos de caja o reimprimir la tirilla Z'),
              icono: Icons.history_rounded,
              colorIcono: FinColor.violeta,
              child: Column(
                children: c.cierres.map((t) {
                  final e = _estado(t.estado);
                  final dif = t.diferencia ?? 0;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _mostrarDetalleTurno(context, t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.borderSubtle))),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                  Text(t.cajero, style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary)),
                                  Insignia(ft(t.caja), FinColor.cian),
                                ]),
                                Text('${fechaHora(t.apertura)} → ${t.cierre == null ? ft('abierto') : hora(t.cierre)}',
                                    style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
                                Text(
                                  '${ft('Esperado')} ${dinero(t.esperado)}${t.contado == null ? '' : ' · ${ft('contado')} ${dinero(t.contado!)}'}',
                                  style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Insignia(
                            t.estado == 'FALTANTE' || t.estado == 'SOBRANTE'
                                ? '${ft(e.$1)} ${dinero(dif.abs())}'
                                : ft(e.$1),
                            e.$2,
                          ),
                          if (t.id > 0) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: ft('Reimprimir tirilla de cierre'),
                              icon: Icon(Icons.print_outlined, size: 18, color: context.textSecondary),
                              onPressed: () => _reimprimirCierre(context, t),
                            ),
                          ] else ...[
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right_rounded, size: 20, color: context.textSecondary),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reimprimirCierre(BuildContext context, CierreAuditoria t) async {
    if (t.id <= 0) return;
    final db = await DBHelper().database;
    final filas = await db.query('cierres_caja', where: 'id = ?', whereArgs: [t.id], limit: 1);
    final mapa = filas.isNotEmpty
        ? filas.first
        : <String, dynamic>{
            'id': t.id,
            'fecha': t.cierre?.toIso8601String() ?? DateTime.now().toIso8601String(),
            'fecha_inicio': t.apertura?.toIso8601String(),
            'fecha_fin': t.cierre?.toIso8601String(),
            'base': t.base,
            'ventas_turno': t.ventas,
            'ingresos_turno': t.ingresos,
            'gastos_turno': t.gastos,
            'total_sistema': t.esperado,
            'real_contado': t.contado ?? t.esperado,
            'diferencia': t.diferencia ?? 0,
            'estado': t.estado == 'CUADRADO' ? 'OK' : t.estado,
            if (t.metodos.isNotEmpty) 'detalle': 'METODOS:${jsonEncode(t.metodos)}',
          };
    final z = await DBHelper().datosZDeCierre(mapa);
    if (!context.mounted) return;
    await mostrarReporteZ(context, z);
  }

  static (String, Color) _metaMovimiento(MovimientoTurno m) {
    switch (m.tipo) {
      case 'APERTURA':
        return ('Apertura', FinColor.azul);
      case 'INGRESO':
        return (CategoriasCaja.nombre('INGRESO', m.categoria), FinColor.verde);
      case 'GASTO':
        return (CategoriasCaja.nombre('GASTO', m.categoria), m.categoria == 'DESCUADRE' ? FinColor.rojo : FinColor.rosa);
      case 'COMPRA':
        return ('Compra con caja', FinColor.ambar);
      case 'DEVOLUCION':
        return ('Devolución', FinColor.naranja);
      case 'ANULACION':
        return ('Anulación', FinColor.rojo);
      case 'CIERRE':
        return ('Cierre de turno', FinColor.violeta);
      default:
        return (m.tipo, FinColor.cian);
    }
  }

  void _mostrarDetalleTurno(BuildContext context, CierreAuditoria t) {
    final e = _estado(t.estado);
    final dif = t.diferencia ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text(t.cajero,
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.textPrimary)),
                            Insignia(ft(t.caja), FinColor.cian),
                            Insignia(
                              t.estado == 'FALTANTE' || t.estado == 'SOBRANTE'
                                  ? '${ft(e.$1)} ${dinero(dif.abs())}'
                                  : ft(e.$1),
                              e.$2,
                            ),
                          ]),
                          const SizedBox(height: 3),
                          Text(
                            '${fechaHora(t.apertura)} → ${t.cierre == null ? ft('Turno abierto') : fechaHora(t.cierre)}',
                            style: TextStyle(fontSize: 12, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: context.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.cardSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ft('Cuadre de efectivo en cajón'),
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: context.textPrimary)),
                              const SizedBox(height: 6),
                              LineaValor('(+) ${ft('Base inicial')}', dinero(t.base)),
                              LineaValor('(+) ${ft('Ventas en efectivo')}', dinero(t.ventas)),
                              LineaValor('(+) ${ft('Ingresos y refuerzos')}', dinero(t.ingresos)),
                              LineaValor('(−) ${ft('Gastos y salidas')}', dinero(t.gastos)),
                              const Divider(height: 14),
                              LineaValor('= ${ft('Esperado por el sistema')}', dinero(t.esperado), fuerte: true),
                              if (t.contado != null) ...[
                                LineaValor(ft('Contado por el cajero'), dinero(t.contado!), fuerte: true),
                                LineaValor(
                                  dif < 0 ? ft('Faltante') : (dif > 0 ? ft('Sobrante') : ft('Diferencia')),
                                  dif == 0 ? dinero(0) : (dif < 0 ? '− ${dinero(-dif)}' : '+ ${dinero(dif)}'),
                                  fuerte: true,
                                  color: FinColor.texto(context, e.$2),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (t.metodos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.cardSubtle,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: context.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ft('Ventas del turno por medio de pago'),
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: context.textPrimary)),
                                const SizedBox(height: 6),
                                ...t.metodos.entries
                                    .where((m) => m.value > 0)
                                    .map((m) => LineaValor(ft(FinanzasService.nombreMetodo(m.key)), dinero(m.value))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(ft('Movimientos de caja del turno'),
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: context.textPrimary)),
                        const SizedBox(height: 6),
                        FutureBuilder<List<MovimientoTurno>>(
                          future: fin.movimientosDeTurno(t),
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final movs = snap.data ?? [];
                            if (movs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(ft('No hay movimientos registrados para este turno.'),
                                    style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
                              );
                            }
                            return Column(
                              children: movs.map((m) {
                                final meta = _metaMovimiento(m);
                                final esSalida = m.tipo == 'GASTO' ||
                                    m.tipo == 'COMPRA' ||
                                    m.tipo == 'DEVOLUCION' ||
                                    m.tipo == 'ANULACION';
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: context.borderSubtle)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Insignia(ft(meta.$1), meta.$2),
                                                Text(hora(m.fecha),
                                                    style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                              ],
                                            ),
                                            if (m.descripcion.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(m.descripcion,
                                                  style: TextStyle(fontSize: 12.5, color: context.textPrimary)),
                                            ],
                                            Text('${ft('Registró')}: ${m.usuario}',
                                                style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        esSalida ? '− ${dinero(m.monto)}' : dinero(m.monto),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: FinColor.texto(context, meta.$2),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (t.id > 0) ...[
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _reimprimirCierre(context, t);
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: Text(ft('Ver e imprimir Reporte Z')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FinColor.violeta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
