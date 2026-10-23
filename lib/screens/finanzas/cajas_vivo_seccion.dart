import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../database/db_helper.dart';
import '../../services/reporte_z.dart';
import '../../services/sync_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/finanzas_ui.dart';
import '../../widgets/reporte_z_vista.dart';
import '../reports_screen.dart';

/// Cajas en vivo: desde cualquier caja (normalmente la principal) el dueño
/// ve cómo va cada caja del negocio: turno abierto o cerrado, ventas,
/// efectivo que debería haber en el cajón y su Reporte Z parcial. Lo de las
/// otras cajas es lo que ya llegó por la sincronización.
class CajasVivoSeccion extends StatelessWidget {
  final String clave;
  const CajasVivoSeccion({super.key, required this.clave});

  @override
  Widget build(BuildContext context) {
    // Se recarga sola cuando llegan datos de otra caja.
    return ValueListenableBuilder<int>(
      valueListenable: SyncService.cambiosRemotosNotifier,
      builder: (context, cambios, _) => CargaSeccion<List<EstadoCaja>>(
        clave: '$clave|$cambios',
        cargar: () => DBHelper().estadoDeLasCajas(),
        construir: (context, cajas) => _contenido(context, cajas),
      ),
    );
  }

  Widget _contenido(BuildContext context, List<EstadoCaja> cajas) {
    final unaCaja = SyncService().unaCaja;
    final abiertas = cajas.where((c) => c.abierta).toList();
    final ventasHoy = cajas.fold(0.0, (a, c) => a + c.ventasHoy);
    final pedidosHoy = cajas.fold(0, (a, c) => a + c.pedidosHoy);
    final efectivo = abiertas.fold(0.0, (a, c) => a + (c.turno?.esperado ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Rejilla(anchoMinimo: 220, hijos: [
          KpiTile(
            etiqueta: ft('Ventas de hoy (todas las cajas)'),
            valor: dinero(ventasHoy),
            detalle: '$pedidosHoy ${ft('ventas')}',
            icono: Icons.storefront_rounded,
            color: FinColor.verde,
          ),
          KpiTile(
            etiqueta: ft('Cajas abiertas'),
            valor: '${abiertas.length} / ${cajas.length}',
            detalle: abiertas.isEmpty ? ft('Ninguna con turno abierto') : abiertas.map((c) => c.nombre).join(', '),
            icono: Icons.point_of_sale_rounded,
            color: FinColor.azul,
          ),
          KpiTile(
            etiqueta: ft('Efectivo en los cajones'),
            valor: dinero(efectivo),
            detalle: ft('Lo que deberían tener las cajas abiertas'),
            icono: Icons.payments_rounded,
            color: FinColor.violeta,
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          unaCaja
              ? ft('Este negocio está en modo una sola caja: solo se ve esta caja.')
              : ft('Lo de las otras cajas llega con la sincronización. Si una caja está sin internet, se ve lo último que subió.'),
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        const SizedBox(height: 10),
        for (final c in cajas) ...[
          _tarjeta(context, c),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _tarjeta(BuildContext context, EstadoCaja c) {
    final hora = DateFormat('dd/MM hh:mm a');
    final z = c.turno;
    final color = c.abierta ? FinColor.verde : FinColor.naranja;
    return FinCard(
      titulo: c.nombre,
      subtitulo: c.abierta && z != null
          ? '${ft('Turno abierto desde')} ${hora.format(z.apertura)}${z.cajero.isNotEmpty ? ' · ${z.cajero}' : ''}'
          : c.ultimoCierre != null
              ? '${ft('Cerrada')} · ${ft('último cierre')} ${hora.format(c.ultimoCierre!)}'
              : ft('Sin turnos todavía'),
      icono: c.abierta ? Icons.lock_open_rounded : Icons.lock_rounded,
      colorIcono: color,
      accion: Wrap(spacing: 6, children: [
        if (c.esEstaCaja) Insignia(ft('Esta caja'), FinColor.azul),
        Insignia(c.abierta ? ft('Abierta') : ft('Cerrada'), color),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LineaValor(ft('Ventas de hoy'), '${dinero(c.ventasHoy)}  (${c.pedidosHoy})'),
          if (z != null) ...[
            LineaValor('${ft('Ventas del turno')} (${z.pedidos})', dinero(z.ventasTotal), fuerte: true),
            for (final m in z.mediosAMostrar)
              if (m.value.round() != 0) LineaValor(m.key, dinero(m.value), sangria: 16),
            if (z.compras + z.gastos > 0)
              LineaValor(ft('Compras y gastos con el cajón'), dinero(z.compras + z.gastos)),
            if (z.otrasEntradas > 0) LineaValor(ft('Otras entradas de efectivo'), dinero(z.otrasEntradas)),
            LineaValor(ft('Efectivo que debería haber'), dinero(z.esperado), fuerte: true, color: FinColor.violeta),
          ],
          if (!c.abierta && c.ultimaDiferencia != null)
            LineaValor(
              ft('Diferencia del último cierre'),
              dinero(c.ultimaDiferencia!),
              color: c.ultimaDiferencia!.abs() < 1
                  ? FinColor.verde
                  : (c.ultimaDiferencia! < 0 ? FinColor.rojo : FinColor.ambar),
            ),
          if (c.ultimaActividad != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${ft('Último movimiento')}: ${hora.format(c.ultimaActividad!)}',
                style: TextStyle(fontSize: 11.5, color: context.textSecondary),
              ),
            ),
          if (z != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: Text(ft('Ver Reporte Z del turno')),
                  onPressed: () => mostrarReporteZ(context, z),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
