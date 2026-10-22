import 'dart:async';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../services/locale_service.dart';
import '../services/auto_backup_service.dart';
import 'pin_login_screen.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Sistema Point of Sale': 'Point of Sale System',
  'No se pudo abrir la base de datos': 'The database could not be opened',
  'NovaPOS no puede abrir sus datos en este equipo. Para no trabajar con una caja vacía, no se continuará.':
      'NovaPOS cannot open its data on this computer. To avoid working with an empty register, it will not continue.',
  'Reinicia el equipo e intenta de nuevo. Si continúa, contacta a soporte con este detalle:':
      'Restart the computer and try again. If it continues, contact support with this detail:',
  'REINTENTAR': 'RETRY',
};

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  String? _errorBase;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _inicializarApp();
  }

  Future<void> _inicializarApp() async {
    // Sin base de datos no se entra: mejor un aviso claro que una caja vacía.
    try {
      await DBHelper().database;
    } catch (e) {
      debugPrint('Error abriendo la base de datos: $e');
      if (mounted) setState(() => _errorBase = e.toString());
      return;
    }
    try {
      // El catálogo maestro se precarga después de iniciar sesión y solo si
      // el negocio está vacío (ver SyncService.iniciar): precargarlo aquí
      // hacía que una caja nueva no descargara los productos del negocio.
      unawaited(
        AutoBackupService().ejecutarBackupSiCorresponde(motivo: 'inicio_app'),
      );
    } catch (e) {
      debugPrint('Error inicializando catalogo maestro: $e');
    }
    Timer(const Duration(milliseconds: 1500), _irAlLogin);
  }

  void _irAlLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _pantallaError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _t('No se pudo abrir la base de datos'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  'NovaPOS no puede abrir sus datos en este equipo. Para no trabajar con una caja vacía, no se continuará.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  'Reinicia el equipo e intenta de nuevo. Si continúa, contacta a soporte con este detalle:',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFFA9DFBF)),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _errorBase ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(_t('REINTENTAR')),
                onPressed: () {
                  setState(() => _errorBase = null);
                  _inicializarApp();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF145A32),
      body: _errorBase != null
          ? _pantallaError()
          : FadeTransition(
              opacity: _fade,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'N',
                        style: TextStyle(
                          fontSize: 74,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'NovaPOS',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t('Sistema Point of Sale'),
                      style: TextStyle(fontSize: 15, color: Color(0xFFA9DFBF)),
                    ),
                    const SizedBox(height: 34),
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2ECC71),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
