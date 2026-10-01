import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../services/promociones_service.dart';
import '../services/session_service.dart';
import '../services/locale_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : es;

class PromocionesScreen extends StatefulWidget {
  const PromocionesScreen({super.key});

  @override
  State<PromocionesScreen> createState() => _PromocionesScreenState();
}

class _PromocionesScreenState extends State<PromocionesScreen> {
  final PromocionesService _promoService = PromocionesService();
  bool _cargando = true;
  bool _promocionesGlobalesActivas = true;
  List<Map<String, dynamic>> _promociones = [];
  List<String> _categoriasDisponibles = [];
  int _promocionesHoyCount = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final globalActivo = await _promoService.estanPromocionesHabilitadasGlobalmente();
    final promos = await _promoService.obtenerTodasLasPromociones();
    final categorias = await DBHelper().obtenerCategorias();
    final hoyActivas = await _promoService.obtenerPromocionesActivasHoy();

    if (!mounted) return;
    setState(() {
      _promocionesGlobalesActivas = globalActivo;
      _promociones = promos;
      _categoriasDisponibles = categorias;
      _promocionesHoyCount = hoyActivas.length;
      _cargando = false;
    });
  }

  bool _esAdmin() {
    return SessionService.userRole() == 'ADMIN';
  }

  void _mostrarAvisoRestriccion() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ Solo el Administrador / Dueño puede modificar los Días de Plaza.'),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  Future<void> _cambiarEstadoGlobal(bool nuevoEstado) async {
    if (!_esAdmin()) {
      _mostrarAvisoRestriccion();
      return;
    }
    await _promoService.setPromocionesHabilitadasGlobalmente(nuevoEstado);
    await _cargarDatos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nuevoEstado
              ? '✅ Motor de Días de Plaza HABILITADO por el dueño'
              : '⏸️ Motor de Días de Plaza DESACTIVADO por el dueño',
        ),
        backgroundColor: nuevoEstado ? Colors.green : Colors.blueGrey,
      ),
    );
  }

  Future<void> _toggleActiva(Map<String, dynamic> promo) async {
    if (!_esAdmin()) {
      _mostrarAvisoRestriccion();
      return;
    }
    final int id = promo['id'];
    final bool nueva = (promo['esta_activa'] as num?)?.toInt() != 1;
    await _promoService.toggleActiva(id, nueva);
    await _cargarDatos();
  }

  Future<void> _toggleForzarHoy(Map<String, dynamic> promo) async {
    if (!_esAdmin()) {
      _mostrarAvisoRestriccion();
      return;
    }
    final int id = promo['id'];
    final bool nueva = (promo['forzar_hoy'] as num?)?.toInt() != 1;
    await _promoService.toggleForzarHoy(id, nueva);
    await _cargarDatos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nueva
              ? '🔥 "${promo['nombre']}" forzada y ACTIVA para el día de HOY'
              : 'ℹ️ "${promo['nombre']}" volvió a su programación normal de días',
        ),
        backgroundColor: nueva ? Colors.orange[800] : Colors.blueGrey,
      ),
    );
  }

  Future<void> _eliminarPromocion(Map<String, dynamic> promo) async {
    if (!_esAdmin()) {
      _mostrarAvisoRestriccion();
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Promoción'),
        content: Text('¿Seguro que deseas eliminar "${promo['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _promoService.eliminarPromocion(promo['id']);
      await _cargarDatos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promoción eliminada')),
      );
    }
  }

  void _abrirModalFormulario([Map<String, dynamic>? promoExistente]) {
    if (!_esAdmin()) {
      _mostrarAvisoRestriccion();
      return;
    }

    final esEdicion = promoExistente != null;
    final nombreCtrl = TextEditingController(text: promoExistente?['nombre'] ?? '');
    final valorDescCtrl = TextEditingController(
      text: promoExistente != null ? (promoExistente['valor_descuento'] as num).toString() : '10',
    );
    String tipoAlcance = promoExistente?['tipo_alcance'] ?? 'CATEGORIA';
    String categoriaSeleccionada = (promoExistente?['alcance_valor'] != null && _categoriasDisponibles.contains(promoExistente!['alcance_valor']))
        ? promoExistente['alcance_valor']
        : (_categoriasDisponibles.isNotEmpty ? _categoriasDisponibles.first : 'Verduras');
    final alcanceValorCtrl = TextEditingController(
      text: tipoAlcance == 'PRODUCTO' ? (promoExistente?['alcance_valor'] ?? '') : '',
    );
    String tipoDescuento = promoExistente?['tipo_descuento'] ?? 'PORCENTAJE';

    // Días de la semana seleccionados (1..7)
    final Set<int> diasSeleccionados = {};
    if (promoExistente != null) {
      final diasStr = (promoExistente['dias_semana'] ?? '').toString();
      for (final d in diasStr.split(',')) {
        final parsed = int.tryParse(d.trim());
        if (parsed != null && parsed >= 1 && parsed <= 7) {
          diasSeleccionados.add(parsed);
        }
      }
    } else {
      // Por defecto Martes (2)
      diasSeleccionados.add(2);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: Text(
              esEdicion ? 'Editar Día de Plaza / Promoción' : 'Nueva Promoción / Día de Plaza',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la promoción',
                        hintText: 'Ej. Martes Campesino, Miércoles de Frutas',
                        prefixIcon: Icon(Icons.campaign),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Días de la semana en que aplica:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(7, (i) {
                        final diaNum = i + 1;
                        final abrev = PromocionesService.diasAbrev[diaNum]!;
                        final nombreCompleto = PromocionesService.nombresDias[diaNum]!;
                        final isSelected = diasSeleccionados.contains(diaNum);

                        return FilterChip(
                          label: Text(abrev),
                          tooltip: nombreCompleto,
                          selected: isSelected,
                          selectedColor: Colors.green[100],
                          checkmarkColor: Colors.green[800],
                          labelStyle: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.green[900] : Colors.black87,
                          ),
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                diasSeleccionados.add(diaNum);
                              } else {
                                if (diasSeleccionados.length > 1) {
                                  diasSeleccionados.remove(diaNum);
                                }
                              }
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Alcance del Descuento:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Categoría')),
                            selected: tipoAlcance == 'CATEGORIA',
                            onSelected: (val) {
                              if (val) setModalState(() => tipoAlcance = 'CATEGORIA');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Toda la Tienda')),
                            selected: tipoAlcance == 'TODOS',
                            onSelected: (val) {
                              if (val) setModalState(() => tipoAlcance = 'TODOS');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Por Producto')),
                            selected: tipoAlcance == 'PRODUCTO',
                            onSelected: (val) {
                              if (val) setModalState(() => tipoAlcance = 'PRODUCTO');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (tipoAlcance == 'CATEGORIA') ...[
                      DropdownButtonFormField<String>(
                        value: _categoriasDisponibles.contains(categoriaSeleccionada)
                            ? categoriaSeleccionada
                            : (_categoriasDisponibles.isNotEmpty ? _categoriasDisponibles.first : null),
                        items: _categoriasDisponibles.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => categoriaSeleccionada = val);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Selecciona la categoría',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else if (tipoAlcance == 'PRODUCTO') ...[
                      TextField(
                        controller: alcanceValorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Códigos PLU o IDs separados por coma',
                          hintText: 'Ej. 101, 103, 201',
                          prefixIcon: Icon(Icons.qr_code_scanner),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber[300]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.stars, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Aplica a TODOS los productos del fruver en los días seleccionados.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      'Tipo y Valor del Descuento:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: tipoDescuento,
                            items: const [
                              DropdownMenuItem(
                                value: 'PORCENTAJE',
                                child: Text('Porcentaje (%)'),
                              ),
                              DropdownMenuItem(
                                value: 'VALOR_FIJO',
                                child: Text('Valor Fijo (\$)'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => tipoDescuento = val);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Modo',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: valorDescCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: InputDecoration(
                              labelText: tipoDescuento == 'PORCENTAJE' ? '%' : '\$',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final nombre = nombreCtrl.text.trim();
                  if (nombre.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa un nombre para la promoción')),
                    );
                    return;
                  }
                  final valorDesc = double.tryParse(valorDescCtrl.text.trim()) ?? 0.0;
                  if (valorDesc <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa un valor de descuento mayor a 0')),
                    );
                    return;
                  }

                  String alcanceValorFinal = 'TODOS';
                  if (tipoAlcance == 'CATEGORIA') {
                    alcanceValorFinal = categoriaSeleccionada;
                  } else if (tipoAlcance == 'PRODUCTO') {
                    alcanceValorFinal = alcanceValorCtrl.text.trim();
                  }

                  final Map<String, dynamic> datos = {
                    if (esEdicion) 'id': promoExistente['id'],
                    'nombre': nombre,
                    'dias_semana': diasSeleccionados.join(','),
                    'tipo_alcance': tipoAlcance,
                    'alcance_valor': alcanceValorFinal,
                    'tipo_descuento': tipoDescuento,
                    'valor_descuento': valorDesc,
                    'esta_activa': promoExistente?['esta_activa'] ?? 1,
                    'forzar_hoy': promoExistente?['forzar_hoy'] ?? 0,
                  };

                  await _promoService.guardarPromocion(datos);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _cargarDatos();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(esEdicion ? 'Promoción actualizada' : 'Promoción creada con éxito'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.check),
                label: Text(esEdicion ? 'Guardar Cambios' : 'Crear Promoción'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _agregarPlantillaFruver(String nombre, int dia, String categoria, double porcentaje) async {
    if (!_esAdmin()) {
      _mostrarAvisoRestriccion();
      return;
    }

    final nueva = {
      'nombre': nombre,
      'dias_semana': dia.toString(),
      'tipo_alcance': 'CATEGORIA',
      'alcance_valor': categoria,
      'tipo_descuento': 'PORCENTAJE',
      'valor_descuento': porcentaje,
      'esta_activa': 1,
      'forzar_hoy': 0,
    };

    await _promoService.guardarPromocion(nueva);
    await _cargarDatos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Plantilla "$nombre" agregada y activada'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoyDiaSemana = DateTime.now().weekday;
    final nombreHoy = PromocionesService.nombresDias[hoyDiaSemana] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_offer, color: Colors.amber),
            SizedBox(width: 10),
            Text('Días de Plaza y Promociones', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF145A32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. TARJETA DE CONTROL MAESTRO DEL DUEÑO
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _promocionesGlobalesActivas ? Colors.green[100] : Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _promocionesGlobalesActivas ? Icons.campaign : Icons.campaign_outlined,
                                color: _promocionesGlobalesActivas ? Colors.green[800] : Colors.grey[600],
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Control Maestro del Propietario',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  Text(
                                    _promocionesGlobalesActivas
                                        ? 'El motor de Días de Plaza está ACTIVO. Los descuentos se aplican automáticamente en el POS.'
                                        : 'El motor está APAGADO. Ningún descuento de día de plaza se aplicará en las cajas.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _promocionesGlobalesActivas,
                              activeColor: Colors.green[700],
                              onChanged: _cambiarEstadoGlobal,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        // Estado en vivo de hoy
                        Row(
                          children: [
                            Icon(
                              _promocionesHoyCount > 0 ? Icons.check_circle : Icons.info_outline,
                              color: _promocionesHoyCount > 0 ? Colors.green[700] : Colors.blueGrey,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hoy es $nombreHoy: ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _promocionesGlobalesActivas
                                  ? (_promocionesHoyCount > 0
                                      ? '$_promocionesHoyCount promoción(es) activa(s) ahora mismo.'
                                      : 'No hay promociones programadas para hoy.')
                                  : 'Desactivado globalmente por el dueño.',
                              style: TextStyle(
                                fontSize: 13,
                                color: _promocionesHoyCount > 0 ? Colors.green[800] : Colors.grey[700],
                                fontWeight: _promocionesHoyCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. ENCABEZADO Y BOTONES DE ACCIÓN RÁPIDA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Promociones Programadas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _abrirModalFormulario(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva Promoción'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF145A32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3. LISTA DE PROMOCIONES
                if (_promociones.isEmpty) ...[
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.storefront, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'No tienes promociones ni días de plaza creados.',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Aprovecha las plantillas sugeridas a continuación para activarlas con 1 solo toque:',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.eco, color: Colors.green),
                                label: const Text('🥬 Martes Campesino (10% en Verduras)'),
                                onPressed: () => _agregarPlantillaFruver('Martes Campesino', 2, 'Verduras', 10.0),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.apple, color: Colors.red),
                                label: const Text('🍎 Miércoles de Cosecha (10% en Frutas)'),
                                onPressed: () => _agregarPlantillaFruver('Miércoles de Cosecha', 3, 'Frutas', 10.0),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.stars, color: Colors.amber),
                                label: const Text('🌽 Viernes de Plaza (5% en Todo)'),
                                onPressed: () => _agregarPlantillaFruver('Viernes de Plaza', 5, 'TODOS', 5.0),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  ..._promociones.map((p) => _tarjetaPromocion(p)),
                ],

                const SizedBox(height: 20),

                // 4. PLANTILLAS RÁPIDAS SI YA TIENE PROMOCIONES
                ExpansionTile(
                  title: const Text(
                    '💡 Plantillas Típicas para Fruvers en Colombia',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text('Toca para crear rápidamente días de descuento clásicos'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.eco, color: Colors.green, size: 18),
                            label: const Text('+ Martes Campesino (10% Verduras)'),
                            onPressed: () => _agregarPlantillaFruver('Martes Campesino', 2, 'Verduras', 10.0),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.apple, color: Colors.red, size: 18),
                            label: const Text('+ Miércoles de Cosecha (10% Frutas)'),
                            onPressed: () => _agregarPlantillaFruver('Miércoles de Cosecha', 3, 'Frutas', 10.0),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.shopping_bag, color: Colors.orange, size: 18),
                            label: const Text('+ Jueves de Abarrotes (5% Abarrotes)'),
                            onPressed: () => _agregarPlantillaFruver('Jueves de Abarrotes', 4, 'Abarrotes', 5.0),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.celebration, color: Colors.amber, size: 18),
                            label: const Text('+ Viernes de Plaza (5% en Todo)'),
                            onPressed: () => _agregarPlantillaFruver('Viernes de Plaza', 5, 'TODOS', 5.0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _tarjetaPromocion(Map<String, dynamic> p) {
    final estaActiva = (p['esta_activa'] as num?)?.toInt() == 1;
    final forzarHoy = (p['forzar_hoy'] as num?)?.toInt() == 1;
    final tipoDescuento = (p['tipo_descuento'] ?? 'PORCENTAJE').toString();
    final valorDesc = (p['valor_descuento'] as num?)?.toDouble() ?? 0.0;
    final tipoAlcance = (p['tipo_alcance'] ?? 'CATEGORIA').toString();
    final alcanceValor = (p['alcance_valor'] ?? '').toString();

    // Días activos
    final diasStr = (p['dias_semana'] ?? '').toString();
    final diasActivos = diasStr.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toSet();

    final hoyDiaSemana = DateTime.now().weekday;
    final bool aplicaHoy = _promocionesGlobalesActivas && estaActiva && (forzarHoy || diasActivos.contains(hoyDiaSemana));

    return Card(
      elevation: aplicaHoy ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: aplicaHoy
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: estaActiva ? (aplicaHoy ? Colors.green[700] : Colors.teal[600]) : Colors.grey[500],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tipoDescuento == 'PORCENTAJE'
                        ? '${valorDesc.toInt()}% OFF'
                        : '-\$${valorDesc.toInt()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p['nombre'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: estaActiva ? Colors.black87 : Colors.grey,
                      decoration: estaActiva ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),
                if (aplicaHoy)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.flash_on, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'ACTIVA HOY',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                  tooltip: 'Editar',
                  onPressed: () => _abrirModalFormulario(p),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Eliminar',
                  onPressed: () => _eliminarPromocion(p),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Alcance info
            Row(
              children: [
                Icon(
                  tipoAlcance == 'TODOS'
                      ? Icons.store
                      : (tipoAlcance == 'CATEGORIA' ? Icons.category : Icons.sell),
                  size: 16,
                  color: Colors.grey[700],
                ),
                const SizedBox(width: 6),
                Text(
                  tipoAlcance == 'TODOS'
                      ? 'Aplica a: Toda la tienda'
                      : (tipoAlcance == 'CATEGORIA'
                          ? 'Aplica a: Categoría "$alcanceValor"'
                          : 'Aplica a productos: $alcanceValor'),
                  style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Chips de días de la semana
            Row(
              children: [
                const Text('Días: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 4),
                ...List.generate(7, (i) {
                  final diaNum = i + 1;
                  final abrev = PromocionesService.diasAbrev[diaNum]!;
                  final isActivo = diasActivos.contains(diaNum);
                  final isHoy = diaNum == hoyDiaSemana;

                  return Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActivo
                          ? (isHoy ? Colors.green[700] : Colors.blueGrey[100])
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: isHoy && isActivo ? Border.all(color: Colors.green[900]!, width: 1.5) : null,
                    ),
                    child: Text(
                      abrev,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActivo ? FontWeight.bold : FontWeight.normal,
                        color: isActivo
                            ? (isHoy ? Colors.white : Colors.blueGrey[900])
                            : Colors.grey[400],
                      ),
                    ),
                  );
                }),
              ],
            ),

            const Divider(height: 20),

            // Controles para el dueño
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Switch 1: Activa / Inactiva
                Row(
                  children: [
                    Switch.adaptive(
                      value: estaActiva,
                      activeColor: Colors.green[700],
                      onChanged: (_) => _toggleActiva(p),
                    ),
                    Text(
                      estaActiva ? 'Habilitada' : 'Pausada',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: estaActiva ? Colors.green[800] : Colors.grey,
                      ),
                    ),
                  ],
                ),

                // Switch 2: Forzar HOY
                Row(
                  children: [
                    Text(
                      'Forzar HOY:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: forzarHoy ? Colors.deepOrange : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch.adaptive(
                      value: forzarHoy,
                      activeColor: Colors.deepOrange,
                      onChanged: (_) => _toggleForzarHoy(p),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
