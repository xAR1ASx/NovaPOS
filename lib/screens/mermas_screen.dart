import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';
import '../services/balanza_service.dart';
import '../utils/numero.dart';
import '../services/locale_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Mermas y Bajas de Inventario': 'Shrinkage & Inventory Losses',
  'Registrar Merma': 'Record Shrinkage',
  'Total Pérdidas': 'Total Losses',
  'No hay mermas registradas': 'No shrinkage recorded',
  'Selecciona un producto': 'Select a product',
  'Producto': 'Product',
  'Cantidad a dar de baja': 'Quantity to write off',
  'Motivo de la merma': 'Reason for shrinkage',
  'Maduración / Podrido': 'Overripe / Spoiled',
  'Golpeado / Deteriorado': 'Damaged / Bruised',
  'Vencimiento': 'Expired',
  'Avería de empaque': 'Packaging Damage',
  'Consumo interno / Degustación': 'Internal Use / Tasting',
  'Otro': 'Other',
  'Pérdida estimada:': 'Estimated loss:',
  'CONFIRMAR BAJA': 'CONFIRM WRITE-OFF',
  'Cancelar': 'Cancel',
  '✅ Merma registrada exitosamente': '✅ Shrinkage recorded successfully',
  '⚠️ Ingresa una cantidad válida': '⚠️ Enter a valid quantity',
  '⚠️ Selecciona un producto': '⚠️ Select a product',
  'Usar peso de balanza': 'Use scale weight',
};

class MermasScreen extends StatefulWidget {
  const MermasScreen({super.key});

  @override
  State<MermasScreen> createState() => _MermasScreenState();
}

class _MermasScreenState extends State<MermasScreen> {
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  List<Map<String, dynamic>> _mermas = [];
  double _totalPerdida = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarMermas();
  }

  Future<void> _cargarMermas() async {
    setState(() => _cargando = true);
    final db = DBHelper();
    final lista = await db.obtenerMermas();
    double tot = 0;
    for (var m in lista) {
      tot += (m['total_perdida'] as num?)?.toDouble() ?? 0;
    }
    if (!mounted) return;
    setState(() {
      _mermas = lista;
      _totalPerdida = tot;
      _cargando = false;
    });
  }

  void _abrirDialogoRegistrar() async {
    final db = DBHelper();
    final productos = await db.obtenerTodoElInventario();
    if (!mounted) return;

    Map<String, dynamic>? productoSeleccionado;
    final cantidadCtrl = TextEditingController();
    String motivoSeleccionado = 'Maduración / Podrido';

    final motivos = [
      'Maduración / Podrido',
      'Golpeado / Deteriorado',
      'Vencimiento',
      'Avería de empaque',
      'Consumo interno / Degustación',
      'Otro',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cant = parseNumero(cantidadCtrl.text) ?? 0;
          final costo = productoSeleccionado != null
              ? (productoSeleccionado!['precio_costo'] as num?)?.toDouble() ?? 0
              : 0.0;
          final totalPerdida = cant * costo;
          final esPesable = productoSeleccionado != null &&
              (productoSeleccionado!['es_pesable'] == 1);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.remove_circle, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  _t('Registrar Merma'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Producto'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      hint: Text(_t('Selecciona un producto')),
                      initialValue: productoSeleccionado?['id'],
                      items: productos.map((p) {
                        final esPes = (p['es_pesable'] == 1);
                        final stock = (p['stock_actual'] as num?)?.toDouble() ?? 0;
                        return DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text(
                            "${p['nombre']} (Stock: ${stock.toStringAsFixed(esPes ? 2 : 0)} ${esPes ? 'Kg' : 'unds'})",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        setDialogState(() {
                          productoSeleccionado = productos.firstWhere(
                            (p) => p['id'] == id,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "${_t('Cantidad a dar de baja')} ${esPesable ? '(Kg)' : '(Unidades)'}",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cantidadCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: esPesable ? "Ej: 2.5" : "Ej: 5",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        if (esPesable && BalanzaService.estaConectada) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.scale, size: 18),
                            label: const Text("Balanza"),
                            onPressed: () {
                              final peso = BalanzaService.ultimoPesoKg;
                              if (peso != null && peso > 0) {
                                setDialogState(() {
                                  cantidadCtrl.text = peso.toStringAsFixed(3);
                                });
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _t('Motivo de la merma'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      initialValue: motivoSeleccionado,
                      items: motivos.map((m) {
                        return DropdownMenuItem<String>(
                          value: m,
                          child: Text(_t(m)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => motivoSeleccionado = v);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _t('Pérdida estimada:'),
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            formater.format(totalPerdida),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_t('Cancelar')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: () async {
                  if (productoSeleccionado == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t('⚠️ Selecciona un producto')),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  if (cant <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t('⚠️ Ingresa una cantidad válida')),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  final usuarioId = SessionService.userId() ?? 1;
                  await DBHelper().registrarMerma(
                    productoId: productoSeleccionado!['id'] as int,
                    cantidad: cant,
                    motivo: motivoSeleccionado,
                    usuarioId: usuarioId,
                  );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_t('✅ Merma registrada exitosamente')),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _cargarMermas();
                },
                child: Text(_t('CONFIRMAR BAJA')),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _colorMotivo(String motivo) {
    switch (motivo) {
      case 'Maduración / Podrido':
        return Colors.red.shade700;
      case 'Golpeado / Deteriorado':
        return Colors.orange.shade800;
      case 'Vencimiento':
        return Colors.purple.shade700;
      case 'Consumo interno / Degustación':
        return Colors.blue.shade700;
      case 'Avería de empaque':
        return Colors.brown.shade600;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('Mermas y Bajas de Inventario'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  color: Colors.orange.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('Total Pérdidas'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formater.format(_totalPerdida),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(_t('Registrar Merma')),
                        onPressed: _abrirDialogoRegistrar,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _mermas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sentiment_satisfied_alt,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _t('No hay mermas registradas'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _mermas.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final m = _mermas[i];
                            final fechaStr = m['fecha']?.toString() ?? '';
                            DateTime? fecha;
                            try {
                              fecha = DateTime.parse(fechaStr);
                            } catch (_) {}
                            final fechaFmt = fecha != null
                                ? DateFormat('dd/MM/yyyy hh:mm a').format(fecha)
                                : fechaStr;
                            final cant = (m['cantidad'] as num?)?.toDouble() ?? 0;
                            final perdida =
                                (m['total_perdida'] as num?)?.toDouble() ?? 0;
                            final motivo = m['motivo']?.toString() ?? 'Otro';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _colorMotivo(motivo).withValues(alpha: 0.15),
                                child: Icon(
                                  Icons.eco,
                                  color: _colorMotivo(motivo),
                                ),
                              ),
                              title: Text(
                                m['nombre_producto']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _colorMotivo(motivo).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _t(motivo),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _colorMotivo(motivo),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    fechaFmt,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "- ${cant.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    formater.format(perdida),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_t('Registrar Merma')),
        onPressed: _abrirDialogoRegistrar,
      ),
    );
  }
}
