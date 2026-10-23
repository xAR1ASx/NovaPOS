import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/copia_nube_service.dart';
import '../services/sync_service.dart';

/// Ajustes → modo del negocio (una caja / varias) y estado de la copia
/// diaria en la nube, con un botón para subirla en el momento.
class CopiaNubeTile extends StatefulWidget {
  final String Function(String) t;
  const CopiaNubeTile({super.key, required this.t});

  @override
  State<CopiaNubeTile> createState() => _CopiaNubeTileState();
}

class _CopiaNubeTileState extends State<CopiaNubeTile> {
  Map<String, String> _cfg = {};
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    CopiaNubeService.cambios.addListener(_cargar);
    SyncService.modoNotifier.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    CopiaNubeService.cambios.removeListener(_cargar);
    SyncService.modoNotifier.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    final cfg = await DBHelper().obtenerConfiguracion();
    if (mounted) setState(() => _cfg = cfg);
  }

  Future<void> _subirAhora() async {
    setState(() => _subiendo = true);
    final error = await CopiaNubeService().subir(motivo: 'manual');
    if (!mounted) return;
    setState(() => _subiendo = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? widget.t('Copia subida a la nube. La anterior se borró.')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final unaCaja = SyncService.normalizarModo(_cfg['modo_sync']) == SyncService.modoUnaCaja;
    final ultima = DateTime.tryParse(_cfg['copia_nube_ultima'] ?? '');
    final error = (_cfg['copia_nube_error'] ?? '').trim();
    final pendiente = _cfg['copia_nube_pendiente'] == '1';
    final kb = int.tryParse(_cfg['copia_nube_kb'] ?? '') ?? 0;
    final tam = kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '$kb KB';

    final String linea;
    if (ultima == null) {
      linea = t('Todavía no se ha subido ninguna copia (se sube sola al cerrar caja)');
    } else {
      linea = '${t('Última copia')}: ${DateFormat('dd/MM/yyyy hh:mm a').format(ultima)} · $tam';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          leading: Icon(unaCaja ? Icons.point_of_sale : Icons.devices,
              color: Theme.of(context).colorScheme.primary),
          title: Text(unaCaja
              ? t('Modo del negocio: una sola caja')
              : t('Modo del negocio: varias cajas')),
          subtitle: Text(unaCaja
              ? t('No se sube nada en vivo (ahorra la cuota gratuita). Los datos quedan en este equipo y en la copia diaria en la nube.')
              : t('Las cajas comparten productos, ventas y clientes en tiempo real.')),
        ),
        ListTile(
          dense: true,
          leading: Icon(
            error.isNotEmpty || pendiente ? Icons.cloud_upload_outlined : Icons.cloud_done,
            color: error.isNotEmpty || pendiente ? Colors.orange : Colors.green,
          ),
          title: Text(t('Copia en la nube')),
          subtitle: Text(error.isNotEmpty ? '$linea\n⚠️ $error' : linea),
          isThreeLine: error.isNotEmpty,
          trailing: _subiendo
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  tooltip: t('Subir copia ahora'),
                  icon: const Icon(Icons.backup),
                  onPressed: _subirAhora,
                ),
        ),
      ],
    );
  }
}
