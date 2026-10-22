import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../services/excel_export_service.dart';
import '../services/finanzas_service.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../widgets/finanzas_ui.dart';
import 'finanzas/control_cierres_seccion.dart';
import 'finanzas/rentabilidad_ventas_seccion.dart';
import 'finanzas/resultados_seccion.dart';

/// Centro Financiero: panorama, estado de resultados, gastos y compras,
/// rentabilidad, ventas, control y auditoría de cierres de caja.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _Atajo { hoy, ayer, d7, d30, mes, mesPasado, anio, rango }

class _Seccion {
  final String id;
  final String titulo;
  final String ayuda;
  final IconData icono;
  final Color color;
  final bool usaPeriodo;
  const _Seccion(this.id, this.titulo, this.ayuda, this.icono, this.color, {this.usaPeriodo = true});
}

const _secciones = [
  _Seccion('PANORAMA', 'Panorama', 'Hoy, mes y año', Icons.dashboard_rounded, FinColor.azul, usaPeriodo: false),
  _Seccion('RESULTADOS', 'Resultados', 'Ganancia del período', Icons.account_balance_rounded, FinColor.verde),
  _Seccion('GASTOS', 'Gastos y compras', 'En qué se va la plata', Icons.receipt_long_rounded, FinColor.rosa),
  _Seccion('RENTABILIDAD', 'Rentabilidad', 'Qué deja más', Icons.trending_up_rounded, FinColor.ambar),
  _Seccion('VENTAS', 'Ventas', 'Productos y horas pico', Icons.storefront_rounded, FinColor.cian),
  _Seccion('CONTROL', 'Control', 'Anulaciones y mermas', Icons.shield_rounded, FinColor.naranja),
  _Seccion('CIERRES', 'Cierres de caja', 'Faltantes por cajero', Icons.point_of_sale_rounded, FinColor.violeta),
];

class _ReportsScreenState extends State<ReportsScreen> {
  final FinanzasService _fin = FinanzasService();
  String _seccion = 'RESULTADOS';
  _Atajo _atajo = _Atajo.d7;
  late Periodo _periodo = _rangoDe(_Atajo.d7);
  int? _usuarioId;
  int _version = 0;
  List<Map<String, dynamic>> _cajeros = [];

  @override
  void initState() {
    super.initState();
    DBHelper().obtenerCajeros().then((c) {
      if (mounted) setState(() => _cajeros = c);
    });
  }

  Periodo _rangoDe(_Atajo a) {
    final h = DateTime.now();
    DateTime d(int menos) => DateTime(h.year, h.month, h.day - menos);
    switch (a) {
      case _Atajo.ayer:
        return Periodo(d(1), d(1));
      case _Atajo.d7:
        return Periodo(d(6), d(0));
      case _Atajo.d30:
        return Periodo(d(29), d(0));
      case _Atajo.mes:
        return Periodo(DateTime(h.year, h.month, 1), d(0));
      case _Atajo.mesPasado:
        return Periodo(DateTime(h.year, h.month - 1, 1), DateTime(h.year, h.month, 0));
      case _Atajo.anio:
        return Periodo(DateTime(h.year, 1, 1), d(0));
      default:
        return Periodo(d(0), d(0));
    }
  }

  String _textoAtajo(_Atajo a) => {
        _Atajo.hoy: 'Hoy',
        _Atajo.ayer: 'Ayer',
        _Atajo.d7: '7 días',
        _Atajo.d30: '30 días',
        _Atajo.mes: 'Este mes',
        _Atajo.mesPasado: 'Mes pasado',
        _Atajo.anio: 'Este año',
        _Atajo.rango: 'Rango',
      }[a]!;

  Future<void> _elegirRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _periodo.desde, end: _periodo.hasta),
      builder: (context, child) => Theme(
        data: context.isDarkMode
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: FinColor.violeta, surface: Color(0xFF1F2937)))
            : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: FinColor.violeta)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _atajo = _Atajo.rango;
      _periodo = Periodo(picked.start, picked.end);
    });
  }

  String get _textoPeriodo {
    final f = DateFormat("EEE d 'de' MMM yyyy", 'es_CO');
    if (_periodo.dias == 1) return f.format(_periodo.desde);
    return '${f.format(_periodo.desde)}  →  ${f.format(_periodo.hasta)}  ·  ${_periodo.dias} días';
  }

  String get _clave => '$_seccion|${_periodo.inicioIso}|${_periodo.finExclusivoIso}|$_usuarioId|$_version';

  Future<void> _exportar() async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ft('Exportar a Excel'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.textPrimary)),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0x2210B981), child: Icon(Icons.auto_graph, color: FinColor.verde)),
                title: Text(ft('Informe financiero del período'),
                    style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                subtitle: Text('${ft('Resultados, gastos, compras, rentabilidad, control y cierres')} · $_textoPeriodo',
                    style: TextStyle(color: context.textSecondary, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'PERIODO'),
              ),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0x223B82F6), child: Icon(Icons.table_chart_outlined, color: FinColor.azul)),
                title: Text(ft('Otros reportes'), style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                subtitle: Text(ft('Inventario, ventas detalladas, mermas, compras y resumen Hoy/Mes/Año'),
                    style: TextStyle(color: context.textSecondary, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'CLASICOS'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || opcion == null) return;
    if (opcion == 'PERIODO') {
      String? nombreCajero;
      if (_usuarioId != null) {
        for (final c in _cajeros) {
          if (c['id'] == _usuarioId) {
            nombreCajero = (c['nombre'] ?? 'Cajero').toString();
            break;
          }
        }
      }
      await ExcelExportService().ejecutarExportacion(
        context,
        titulo: ft('Informe financiero del período'),
        accion: () => ExcelExportService().exportarInformePeriodo(
          fin: _fin,
          periodo: _periodo,
          usuarioId: _usuarioId,
          nombreCajero: nombreCajero,
        ),
      );
      return;
    }
    final hoy = await _fin.resultados(Periodo(DateTime.now(), DateTime.now()));
    final n = DateTime.now();
    final mes = await _fin.resultados(Periodo(DateTime(n.year, n.month, 1), n));
    final anio = await _fin.resultados(Periodo(DateTime(n.year, 1, 1), n));
    final pat = await _fin.patrimonio();
    if (!mounted) return;
    ExcelExportService().mostrarModalExportacion(
      context,
      hoy: resultadosComoMapa(hoy),
      mes: resultadosComoMapa(mes),
      anio: resultadosComoMapa(anio),
      inventarioValor: pat['inventario'],
      cartera: pat['cartera'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor = context.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFF1A1F2B);
    if (!PermissionService.can('REPORTES_VER')) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(title: Text(ft('Centro Financiero')), backgroundColor: appBarColor, foregroundColor: Colors.white),
        body: Center(
          child: Text(ft('No tienes permiso para ver los reportes'), style: TextStyle(color: context.textPrimary)),
        ),
      );
    }
    final sec = _secciones.firstWhere((s) => s.id == _seccion);
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.insights_rounded),
            const SizedBox(width: 10),
            Text(ft('Centro Financiero'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: ft('Actualizar'),
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _version++),
          ),
          IconButton(
            tooltip: ft('Exportar a Excel'),
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: _exportar,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        final ancho = c.maxWidth >= 1100;
        final contenido = Column(
          children: [
            if (!ancho) _barraSecciones(),
            if (sec.usaPeriodo) _cabeceraPeriodo(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: _contenido(),
                  ),
                ),
              ),
            ),
          ],
        );
        if (!ancho) return contenido;
        return Row(
          children: [
            _menuLateral(),
            Expanded(child: contenido),
          ],
        );
      }),
    );
  }

  Widget _contenido() {
    final args = (periodo: _periodo, usuarioId: _usuarioId, clave: _clave);
    switch (_seccion) {
      case 'PANORAMA':
        return PanoramaSeccion(fin: _fin, clave: _clave);
      case 'RESULTADOS':
        return ResultadosSeccion(fin: _fin, periodo: args.periodo, usuarioId: args.usuarioId, clave: args.clave);
      case 'GASTOS':
        return GastosSeccion(fin: _fin, periodo: args.periodo, usuarioId: args.usuarioId, clave: args.clave);
      case 'RENTABILIDAD':
        return RentabilidadSeccion(fin: _fin, periodo: args.periodo, usuarioId: args.usuarioId, clave: args.clave);
      case 'VENTAS':
        return VentasSeccion(fin: _fin, periodo: args.periodo, usuarioId: args.usuarioId, clave: args.clave);
      case 'CONTROL':
        return ControlSeccion(fin: _fin, periodo: args.periodo, usuarioId: args.usuarioId, clave: args.clave);
      default:
        return CierresSeccion(
          fin: _fin,
          periodo: args.periodo,
          usuarioId: args.usuarioId,
          clave: args.clave,
          alCambiar: () => setState(() => _version++),
        );
    }
  }

  Widget _menuLateral() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(right: BorderSide(color: context.borderSubtle)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 10),
            child: Text(ft('SECCIONES'),
                style: TextStyle(
                    fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w800, color: context.textSecondary)),
          ),
          ..._secciones.map((s) {
            final activa = s.id == _seccion;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: activa ? FinColor.fondo(context, s.color) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _seccion = s.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: activa ? FinColor.borde(context, s.color) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(s.icono, size: 20, color: activa ? FinColor.texto(context, s.color) : context.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ft(s.titulo),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: activa ? FinColor.texto(context, s.color) : context.textPrimary,
                                  )),
                              Text(ft(s.ayuda), style: TextStyle(fontSize: 11, color: context.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _barraSecciones() {
    return Container(
      color: context.cardBg,
      height: 58,
      child: ListView(
        key: const ValueKey('barra_secciones'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: _secciones.map((s) {
          final activa = s.id == _seccion;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(s.icono, size: 16, color: activa ? Colors.white : FinColor.texto(context, s.color)),
              label: Text(ft(s.titulo)),
              selected: activa,
              showCheckmark: false,
              selectedColor: s.color,
              backgroundColor: context.chipBg,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: activa ? Colors.white : context.textPrimary,
              ),
              onSelected: (_) => setState(() => _seccion = s.id),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _cabeceraPeriodo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(bottom: BorderSide(color: context.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 16, color: context.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _textoPeriodo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary, fontSize: 13),
                ),
              ),
              if (_cajeros.isNotEmpty)
                DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _usuarioId,
                    isDense: true,
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: context.cardBg,
                    icon: Icon(Icons.person_search_rounded, size: 18, color: context.textSecondary),
                    style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text(ft('Todos los cajeros'))),
                      ..._cajeros.map((u) => DropdownMenuItem<int?>(
                            value: u['id'] as int,
                            child: Text((u['nombre'] ?? 'Cajero').toString()),
                          )),
                    ],
                    onChanged: (v) => setState(() => _usuarioId = v),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._Atajo.values.where((a) => a != _Atajo.rango).map((a) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _chipAtajo(a, () => setState(() {
                            _atajo = a;
                            _periodo = _rangoDe(a);
                          })),
                    )),
                _chipAtajo(_Atajo.rango, _elegirRango, icono: Icons.date_range_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipAtajo(_Atajo a, VoidCallback onTap, {IconData? icono}) {
    final activo = _atajo == a;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? FinColor.violeta : context.chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: activo ? FinColor.violeta : context.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 14, color: activo ? Colors.white : context.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              ft(_textoAtajo(a)),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: activo ? Colors.white : context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resultados en el formato que usa la exportación clásica de Excel.
Map<String, double> resultadosComoMapa(Resultados r) => {
      'ventas': r.ventas,
      'costos': r.costoVentas,
      'utilidad_bruta': r.utilidadBruta,
      'gastos': r.gastos + r.descuadreNeto,
      'mermas': r.mermas,
      'utilidad_neta': r.utilidadNeta,
    };

/// Carga datos de una sección y conserva los anteriores mientras recarga.
class CargaSeccion<T> extends StatefulWidget {
  final String clave;
  final Future<T> Function() cargar;
  final Widget Function(BuildContext context, T datos) construir;
  const CargaSeccion({super.key, required this.clave, required this.cargar, required this.construir});

  @override
  State<CargaSeccion<T>> createState() => _CargaSeccionState<T>();
}

class _CargaSeccionState<T> extends State<CargaSeccion<T>> {
  T? _datos;
  Object? _error;
  bool _cargando = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant CargaSeccion<T> old) {
    super.didUpdateWidget(old);
    if (old.clave != widget.clave) _cargar();
  }

  Future<void> _cargar() async {
    final mio = ++_seq;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await widget.cargar();
      if (!mounted || mio != _seq) return;
      setState(() {
        _datos = d;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || mio != _seq) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_datos == null && _error == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_datos == null) {
      return FinCard(
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: FinColor.rojo),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${ft('No se pudo cargar')}: $_error', style: TextStyle(color: context.textPrimary)),
            ),
            TextButton(onPressed: _cargar, child: Text(ft('Reintentar'))),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedOpacity(
          opacity: _cargando ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        ),
        AnimatedOpacity(
          opacity: _cargando ? 0.55 : 1,
          duration: const Duration(milliseconds: 200),
          child: widget.construir(context, _datos as T),
        ),
      ],
    );
  }
}

/// Panorama: estado de resultados Hoy / Mes / Año y foto del negocio.
class PanoramaSeccion extends StatelessWidget {
  final FinanzasService fin;
  final String clave;
  const PanoramaSeccion({super.key, required this.fin, required this.clave});

  Future<Map<String, Object>> _cargar() async {
    final n = DateTime.now();
    return {
      'hoy': await fin.resultados(Periodo(n, n)),
      'mes': await fin.resultados(Periodo(DateTime(n.year, n.month, 1), n)),
      'anio': await fin.resultados(Periodo(DateTime(n.year, 1, 1), n)),
      'pat': await fin.patrimonio(),
      'caja': await DBHelper().obtenerResumenCaja(),
      'abierta': await DBHelper().verificarCajaAbiertaHoy(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return CargaSeccion<Map<String, Object>>(
      clave: clave,
      cargar: _cargar,
      construir: (context, d) {
        final hoy = d['hoy'] as Resultados;
        final mes = d['mes'] as Resultados;
        final anio = d['anio'] as Resultados;
        final pat = d['pat'] as Map<String, double>;
        final caja = d['caja'] as Map<String, double>;
        final abierta = d['abierta'] as bool;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Rejilla(anchoMinimo: 230, hijos: [
              KpiTile(
                etiqueta: ft('Ventas de hoy'),
                valor: dinero(hoy.ventas),
                detalle: '${hoy.cantidadVentas} ${ft('ventas')} · ${ft('ticket')} ${dinero(hoy.ticketPromedio)}',
                icono: Icons.today_rounded,
                color: FinColor.verde,
              ),
              KpiTile(
                etiqueta: hoy.utilidadNeta >= 0 ? ft('Ganancia de hoy') : ft('Pérdida de hoy'),
                valor: dinero(hoy.utilidadNeta),
                detalle: hoy.ventas > 0 ? '${ft('Margen')} ${porcentaje(hoy.margenNeto)}' : ft('Sin ventas todavía'),
                icono: Icons.savings_rounded,
                color: hoy.utilidadNeta >= 0 ? FinColor.verde : FinColor.rojo,
              ),
              KpiTile(
                etiqueta: ft('Efectivo en esta caja'),
                valor: abierta ? dinero(caja['total_en_caja'] ?? 0) : '—',
                detalle: abierta ? ft('Turno abierto') : ft('Caja cerrada'),
                icono: Icons.point_of_sale_rounded,
                color: FinColor.violeta,
              ),
              KpiTile(
                etiqueta: ft('Inventario al costo'),
                valor: dinero(pat['inventario'] ?? 0),
                detalle: ft('Mercancía en bodega'),
                icono: Icons.inventory_2_rounded,
                color: FinColor.azul,
              ),
              KpiTile(
                etiqueta: ft('Cartera por cobrar'),
                valor: dinero(pat['cartera'] ?? 0),
                detalle: ft('Fiados pendientes'),
                icono: Icons.people_alt_rounded,
                color: FinColor.ambar,
              ),
            ]),
            const SizedBox(height: 14),
            FinCard(
              titulo: ft('Estado de resultados'),
              subtitulo: ft('Hoy, lo que va del mes y lo que va del año'),
              icono: Icons.table_rows_rounded,
              colorIcono: FinColor.azul,
              child: _tabla(context, hoy, mes, anio),
            ),
          ],
        );
      },
    );
  }

  Widget _tabla(BuildContext context, Resultados hoy, Resultados mes, Resultados anio) {
    TableRow fila(String c, double Function(Resultados) v, {bool fuerte = false, bool resta = false}) {
      Widget celda(Resultados r) {
        final valor = v(r);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: Text(
            resta && valor != 0 ? '− ${dinero(valor)}' : dinero(valor),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: fuerte ? FontWeight.w900 : FontWeight.w600,
              fontSize: fuerte ? 14 : 13,
              color: fuerte
                  ? FinColor.texto(context, valor >= 0 ? FinColor.verde : FinColor.rojo)
                  : context.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      }

      return TableRow(
        decoration: fuerte
            ? BoxDecoration(color: context.cardSubtle, borderRadius: BorderRadius.circular(8))
            : BoxDecoration(border: Border(bottom: BorderSide(color: context.borderSubtle))),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
            child: Text(c,
                style: TextStyle(
                    fontWeight: fuerte ? FontWeight.w900 : FontWeight.w500, color: context.textPrimary, fontSize: 13)),
          ),
          celda(hoy),
          celda(mes),
          celda(anio),
        ],
      );
    }

    Widget enc(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Text(t,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.textSecondary, letterSpacing: 0.6)),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 560),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(1.6), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth()},
          children: [
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(ft('CONCEPTO'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.textSecondary)),
              ),
              enc(ft('HOY')),
              enc(ft('MES')),
              enc(ft('AÑO')),
            ]),
            fila(ft('Ventas'), (r) => r.ventas),
            fila(ft('Costo de lo vendido'), (r) => r.costoVentas, resta: true),
            fila(ft('= Utilidad bruta'), (r) => r.utilidadBruta, fuerte: true),
            fila(ft('Gastos'), (r) => r.gastos, resta: true),
            fila(ft('Mermas'), (r) => r.mermas, resta: true),
            fila(ft('Faltantes de caja (neto)'), (r) => r.descuadreNeto, resta: true),
            fila(ft('= UTILIDAD NETA'), (r) => r.utilidadNeta, fuerte: true),
          ],
        ),
      ),
    );
  }
}
