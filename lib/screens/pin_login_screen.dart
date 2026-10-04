import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/locale_service.dart';
import '../services/pin_auth_service.dart';
import '../services/session_service.dart';
import '../services/permission_service.dart';
import '../services/role_permissions.dart';
import '../services/sync_service.dart';
import '../services/license_monitor.dart';
import '../database/db_helper.dart';
import 'home_screen.dart';
import '../services/theme_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Ingresa tu correo electronico': 'Enter your email',
  'PIN incorrecto': 'Incorrect PIN',
  'Correo o PIN incorrectos': 'Incorrect email or PIN',
  'Usuario sin negocio asignado': 'User without an assigned business',
  'Negocio no encontrado': 'Business not found',
  'Licencia bloqueada. Contacte al administrador.':
      'License blocked. Contact the administrator.',
  'Tu licencia de NovaPOS ha vencido. Renueva para continuar.':
      'Your NovaPOS license has expired. Renew to continue.',
  'Error de conexion': 'Connection error',
  'Usuario desactivado por el administrador':
      'User disabled by the administrator',
  'Demasiados intentos fallidos. Espera unos minutos':
      'Too many failed attempts. Wait a few minutes',
  'Sin conexion a internet': 'No internet connection',
  'Cambiar': 'Change',
  'Intentos agotados': 'Attempts exhausted',
  'segundos': 'seconds',
  'Ingresa tu PIN para acceder': 'Enter your PIN to access',
  'Ingresa tu correo y PIN': 'Enter your email and PIN',
  'Correo electronico': 'Email',
  'ENTRAR': 'ENTER',
};

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  bool _cargando = true;
  String? _error;
  bool _bloqueado = false;
  int _segundosBloqueo = 0;
  bool _soloPin = false;
  String _emailGuardado = '';

  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    bool haySesion = await PinAuthService.haySesion();
    if (!mounted) return;

    if (haySesion) {
      String? email = await PinAuthService.emailGuardado();
      setState(() {
        _soloPin = true;
        _emailGuardado = email ?? '';
        _cargando = false;
      });
    } else {
      setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _agregarDigito(String digito) {
    if (_bloqueado || _pin.length >= 6) return;
    setState(() {
      _pin += digito;
      _error = null;
    });
  }

  void _limpiarPin() {
    setState(() {
      _pin = '';
      _error = null;
    });
  }

  void _cambiarUsuario() async {
    await PinAuthService.cerrarSesion();
    setState(() {
      _soloPin = false;
      _emailGuardado = '';
      _pin = '';
      _error = null;
    });
  }

  Future<void> _intentarLogin() async {
    if (!_soloPin && _emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa tu correo electronico');
      return;
    }

    // Verificar bloqueo persistente primero
    final cfg = await DBHelper().obtenerConfiguracion();
    final bloqueoHastaStr = cfg['login_bloqueo_hasta'] ?? '0';
    final bloqueoHasta = int.tryParse(bloqueoHastaStr) ?? 0;
    final ahora = DateTime.now().millisecondsSinceEpoch;
    
    if (ahora < bloqueoHasta) {
      int segundos = ((bloqueoHasta - ahora) / 1000).ceil();
      setState(() {
        _bloqueado = true;
        _segundosBloqueo = segundos;
      });
      _iniciarContadorBloqueo();
      return;
    }

    setState(() => _cargando = true);

    try {
      Map<String, dynamic>? usuario;

      if (_soloPin) {
        usuario = await PinAuthService.loginConPin(_pin);
      } else {
        usuario = await PinAuthService.loginConEmailPin(_emailCtrl.text.trim(), _pin);
      }

      if (!mounted) return;

      if (usuario == null) {
        int intentosPrevios = int.tryParse(cfg['login_intentos_fallidos'] ?? '0') ?? 0;
        int nuevosIntentos = intentosPrevios + 1;
        await DBHelper().guardarConfiguracion('login_intentos_fallidos', nuevosIntentos.toString());

        setState(() {
          _error = _soloPin ? 'PIN incorrecto' : 'Correo o PIN incorrectos';
          _pin = '';
          _cargando = false;
        });

        if (nuevosIntentos >= 3) {
          _bloquearPorIntentos();
        }
        return;
      }

      // Éxito: limpiar intentos
      await DBHelper().guardarConfiguracion('login_intentos_fallidos', '0');
      
      String? negocioId = usuario['negocio_id'];
      if (negocioId == null) {
        setState(() {
          _error = 'Usuario sin negocio asignado';
          _pin = '';
          _cargando = false;
        });
        return;
      }

      // L-02: Unificar verificación de licencia usando LicenseMonitor
      LicenciaResult licencia = await LicenseMonitor.instance.revisar(negocioId);

      if (!mounted) return;

      if (!licencia.valida) {
        setState(() {
          _error = licencia.mensaje;
          _pin = '';
          _cargando = false;
        });
        return;
      }

      // Conteo local de días disponibles (sirve de respaldo sin internet)
      await LicenseMonitor.instance.guardarCacheLocal(negocioId);

      await SessionService.login(usuario, negocioId: negocioId);

      String rol = usuario['rol'] ?? '';
      await PermissionService.loadPermissions(RolePermissions.permisosPara(rol));

      if (!_soloPin) {
        await PinAuthService.guardarSesion(_emailCtrl.text.trim(), usuario['uid']);
      }

      if (!mounted) return;

      unawaited(
        SyncService()
            .iniciar(
              negocioId: negocioId,
              usuarioUid: (usuario['uid'] ?? '').toString(),
            )
            .catchError((e) {}),
      );

      unawaited(LicenseMonitor.instance.iniciar(negocioId));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String mensaje;
      switch (e.code) {
        case 'user-disabled':
          mensaje = 'Usuario desactivado por el administrador';
          break;
        case 'too-many-requests':
          mensaje = 'Demasiados intentos fallidos. Espera unos minutos';
          _bloquearPorIntentos(); // Bloqueo local preventivo
          break;
        case 'network-request-failed':
          mensaje = 'Sin conexion a internet';
          break;
        default:
          mensaje = 'Error de conexion';
      }
      setState(() {
        _error = mensaje;
        _pin = '';
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error de conexion';
        _pin = '';
        _cargando = false;
      });
    }
  }

  Future<void> _bloquearPorIntentos() async {
    final bloqueoHasta = DateTime.now().millisecondsSinceEpoch + (30 * 1000);
    await DBHelper().guardarConfiguracion('login_bloqueo_hasta', bloqueoHasta.toString());
    
    if (!mounted) return;
    setState(() {
      _bloqueado = true;
      _segundosBloqueo = 30;
    });
    _iniciarContadorBloqueo();
  }

  void _iniciarContadorBloqueo() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _segundosBloqueo--);
      if (_segundosBloqueo <= 0) {
        await DBHelper().guardarConfiguracion('login_intentos_fallidos', '0');
        await DBHelper().guardarConfiguracion('login_bloqueo_hasta', '0');
        setState(() {
          _bloqueado = false;
        });
        return false;
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.isDarkMode ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.store,
                      size: 56,
                      color: context.isDarkMode ? Colors.greenAccent : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NovaPOS',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.isDarkMode ? Colors.greenAccent : Colors.green.shade800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_soloPin) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, size: 16, color: context.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _emailGuardado,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _cambiarUsuario,
                          child: Text(
                            'Cambiar',
                            style: TextStyle(
                              color: context.isDarkMode ? Colors.lightBlueAccent : Colors.blue.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    _bloqueado
                        ? '${_t('Intentos agotados')}. Espera $_segundosBloqueo ${_t('segundos')}'
                        : _soloPin
                            ? _t('Ingresa tu PIN para acceder')
                            : _t('Ingresa tu correo y PIN'),
                    style: TextStyle(
                      color: _bloqueado ? Colors.redAccent : context.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_soloPin) ...[
                    TextField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        hintText: _t('Correo electronico'),
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildPuntosPin(),
                  const SizedBox(height: 8),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _t(_error!),
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                  const SizedBox(height: 32),
                  _buildTeclado(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPuntosPin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        bool lleno = index < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lleno
                ? Colors.green.shade700
                : (context.isDarkMode ? const Color(0xFF374151) : Colors.grey.shade200),
            border: Border.all(
              color: lleno
                  ? Colors.green.shade700
                  : (context.isDarkMode ? const Color(0xFF4B5563) : Colors.grey.shade400),
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTeclado() {
    return Column(
      children: [
        for (var fila in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['C', '0', 'ENTRAR'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: fila.map((tecla) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildTecla(tecla),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTecla(String tecla) {
    bool esEntrar = tecla == 'ENTRAR';
    bool deshabilitado = esEntrar && _pin.length < 6;

    return SizedBox(
      width: esEntrar ? 160 : 72,
      height: 56,
      child: ElevatedButton(
        onPressed: _bloqueado || deshabilitado
            ? null
            : () {
                if (tecla == 'C') {
                  _limpiarPin();
                } else if (tecla == 'ENTRAR') {
                  _intentarLogin();
                } else {
                  _agregarDigito(tecla);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: esEntrar
              ? (_pin.length >= 6
                  ? Colors.green.shade700
                  : (context.isDarkMode ? const Color(0xFF374151) : Colors.grey.shade300))
              : (context.isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade100),
          foregroundColor: esEntrar ? Colors.white : context.textPrimary,
          elevation: esEntrar ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: context.borderSubtle,
              width: 1,
            ),
          ),
        ),
        child: Text(
          _t(tecla),
          style: TextStyle(
            fontSize: esEntrar ? 16 : 22,
            fontWeight: FontWeight.w700,
            color: esEntrar
                ? (_pin.length >= 6 ? Colors.white : Colors.grey.shade500)
                : tecla == 'C'
                    ? (context.isDarkMode ? Colors.redAccent.shade100 : Colors.red)
                    : context.textPrimary,
          ),
        ),
      ),
    );
  }
}
