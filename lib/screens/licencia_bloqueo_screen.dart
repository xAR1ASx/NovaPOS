import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/license_monitor.dart';
import '../services/locale_service.dart';
import 'pin_login_screen.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Licencia no activa': 'License not active',
  'Esta cuenta fue desactivada porque su licencia venció o fue bloqueada. Renueva la licencia con tu administrador para continuar.':
      'This account was disabled because its license expired or was blocked. Renew the license with your administrator to continue.',
  'Reintentar': 'Retry',
  'Salir': 'Exit',
  'Aun no renovada': 'Not renewed yet',
  'La licencia sigue vencida o bloqueada. Contacta a tu administrador para renovarla.':
      'The license is still expired or blocked. Contact your administrator to renew it.',
};

class LicenciaBloqueoScreen extends StatefulWidget {
  final String mensaje;
  const LicenciaBloqueoScreen({super.key, required this.mensaje});

  @override
  State<LicenciaBloqueoScreen> createState() => _LicenciaBloqueoScreenState();
}

class _LicenciaBloqueoScreenState extends State<LicenciaBloqueoScreen> {
  bool _cargando = false;

  Future<void> _reintentar() async {
    final nid = LicenseMonitor.instance.negocioId;
    if (nid == null) return;
    setState(() => _cargando = true);
    final r = await LicenseMonitor.instance.revisar(nid);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (r.valida) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PinLoginScreen()),
        (route) => false,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('La licencia sigue vencida o bloqueada. Contacta a tu administrador para renovarla.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_clock,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _t('Licencia no activa'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.mensaje.isEmpty
                      ? _t('Esta cuenta fue desactivada porque su licencia venció o fue bloqueada. Renueva la licencia con tu administrador para continuar.')
                      : widget.mensaje,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[350],
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _cargando ? null : _reintentar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      child: _cargando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_t('Reintentar')),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (Platform.isAndroid) {
                          SystemNavigator.pop();
                        } else {
                          exit(0);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      child: Text(_t('Salir')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}