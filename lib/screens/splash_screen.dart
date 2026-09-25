import 'dart:async';
import 'package:flutter/material.dart';
import '../services/locale_service.dart';
import '../database/db_helper.dart';
import '../services/auto_backup_service.dart';
import 'pin_login_screen.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Sistema Point of Sale': 'Point of Sale System',
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
    try {
      await DBHelper().precargarCatalogoMaestro(forzar: false);
      unawaited(AutoBackupService().ejecutarBackupSiCorresponde(motivo: 'inicio_app'));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF145A32),
      body: FadeTransition(
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
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFA9DFBF),
                ),
              ),
              const SizedBox(height: 34),
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}