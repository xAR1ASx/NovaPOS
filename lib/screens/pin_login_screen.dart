import 'package:flutter/material.dart';
import '../services/pin_auth_service.dart';
import '../services/session_service.dart';
import '../services/permission_service.dart';
import '../services/role_permissions.dart';
import 'home_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  bool _cargando = true;
  String? _error;
  int _intentosFallidos = 0;
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
    await PinAuthService.limpiarSesion();
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
        _intentosFallidos++;
        setState(() {
          _error = _soloPin ? 'PIN incorrecto' : 'Correo o PIN incorrectos';
          _pin = '';
          _cargando = false;
        });

        if (_intentosFallidos >= 3) {
          _bloquearPorIntentos();
        }
        return;
      }

      String? negocioId = usuario['negocio_id'];
      if (negocioId == null) {
        setState(() {
          _error = 'Usuario sin negocio asignado';
          _pin = '';
          _cargando = false;
        });
        return;
      }

      Map<String, dynamic> licencia = await PinAuthService.verificarLicencia(negocioId);

      if (!mounted) return;

      if (!licencia['valida']) {
        setState(() {
          _error = licencia['mensaje'];
          _pin = '';
          _cargando = false;
        });
        return;
      }

      await SessionService.login(usuario, negocioId: negocioId);

      String rol = usuario['rol'] ?? '';
      await PermissionService.loadPermissions(RolePermissions.permisosPara(rol));

      if (!_soloPin) {
        await PinAuthService.guardarSesion(_emailCtrl.text.trim(), usuario['uid']);
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error de conexion';
        _pin = '';
        _cargando = false;
      });
    }
  }

  void _bloquearPorIntentos() {
    setState(() {
      _bloqueado = true;
      _segundosBloqueo = 30;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _segundosBloqueo--);
      if (_segundosBloqueo <= 0) {
        setState(() {
          _bloqueado = false;
          _intentosFallidos = 0;
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
      backgroundColor: Colors.white,
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
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.store,
                      size: 56,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NovaPOS',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_soloPin) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          _emailGuardado,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _cambiarUsuario,
                          child: Text(
                            'Cambiar',
                            style: TextStyle(
                              color: Colors.blue.shade600,
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
                        ? 'Intentos agotados. Espera $_segundosBloqueo segundos'
                        : _soloPin
                            ? 'Ingresa tu PIN para acceder'
                            : 'Ingresa tu correo y PIN',
                    style: TextStyle(
                      color: _bloqueado ? Colors.red : Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_soloPin) ...[
                    TextField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        hintText: 'Correo electronico',
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
                        _error!,
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
            color: lleno ? Colors.green.shade700 : Colors.grey.shade200,
            border: Border.all(
              color: lleno ? Colors.green.shade700 : Colors.grey.shade400,
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
    bool deshabilitado = esEntrar && _pin.length < 4;

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
              ? (_pin.length >= 4 ? Colors.green.shade700 : Colors.grey.shade300)
              : Colors.grey.shade100,
          foregroundColor: esEntrar ? Colors.white : Colors.black87,
          elevation: esEntrar ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          tecla,
          style: TextStyle(
            fontSize: esEntrar ? 16 : 22,
            fontWeight: FontWeight.w700,
            color: esEntrar
                ? (_pin.length >= 4 ? Colors.white : Colors.grey.shade500)
                : tecla == 'C'
                    ? Colors.red
                    : Colors.black87,
          ),
        ),
      ),
    );
  }
}
