import 'package:flutter/material.dart';
import '../services/pin_auth_service.dart';
import 'pin_login_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreNegocioCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _nombreAdminCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _cargando = false;
  int _pasoActual = 0;

  @override
  void dispose() {
    _nombreNegocioCtrl.dispose();
    _nitCtrl.dispose();
    _direccionCtrl.dispose();
    _nombreAdminCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _siguientePaso() async {
    if (_pasoActual == 0) {
      if (_formKey.currentState!.validate()) {
        setState(() => _pasoActual = 1);
      }
    } else {
      await _registrar();
    }
  }

  void _pasoAnterior() {
    if (_pasoActual > 0) {
      setState(() => _pasoActual--);
    }
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      Map<String, dynamic> resultado = await PinAuthService.crearNegocioAdmin(
        nombreNegocio: _nombreNegocioCtrl.text.trim(),
        nit: _nitCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        emailAdmin: _emailCtrl.text.trim(),
        passwordAdmin: _passwordCtrl.text,
        nombreAdmin: _nombreAdminCtrl.text.trim(),
      );

      if (!mounted) return;

      if (resultado['exito']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['mensaje']),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PinLoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['mensaje']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.store,
                        size: 64,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Bienvenido a NovaPOS',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configura tu negocio en pocos pasos',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildIndicadorPasos(),
                    const SizedBox(height: 32),
                    if (_pasoActual == 0) _buildPasoNegocio(),
                    if (_pasoActual == 1) _buildPasoAdmin(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (_pasoActual > 0)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _cargando ? null : _pasoAnterior,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Atras'),
                            ),
                          ),
                        if (_pasoActual > 0) const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _cargando ? null : _siguientePaso,
                            icon: _cargando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _pasoActual == 0
                                        ? Icons.arrow_forward
                                        : Icons.check,
                                  ),
                            label: Text(
                              _cargando
                                  ? 'Guardando...'
                                  : _pasoActual == 0
                                      ? 'Siguiente'
                                      : 'Crear negocio',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicadorPasos() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCirculoPaso(0, 'Negocio'),
        Container(width: 40, height: 2, color: Colors.grey.shade300),
        _buildCirculoPaso(1, 'Administrador'),
      ],
    );
  }

  Widget _buildCirculoPaso(int numero, String label) {
    bool activo = _pasoActual >= numero;
    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: activo ? Colors.green.shade700 : Colors.grey.shade300,
          child: Text(
            '${numero + 1}',
            style: TextStyle(
              color: activo ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: activo ? Colors.green.shade700 : Colors.grey,
            fontWeight: activo ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPasoNegocio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datos del negocio',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nombreNegocioCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del negocio',
            hintText: 'Ej: Fruver Don Pedro',
            prefixIcon: Icon(Icons.store),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nitCtrl,
          decoration: const InputDecoration(
            labelText: 'NIT',
            hintText: 'Ej: 900123456-7',
            prefixIcon: Icon(Icons.badge),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _direccionCtrl,
          decoration: const InputDecoration(
            labelText: 'Direccion',
            hintText: 'Ej: Carrera 15 # 45 - 23',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null,
        ),
      ],
    );
  }

  Widget _buildPasoAdmin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crear administrador',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Este usuario administrara el negocio y creara cajeros.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nombreAdminCtrl,
          decoration: const InputDecoration(
            labelText: 'Tu nombre completo',
            hintText: 'Ej: Pedro Perez',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Ej: admin@gmail.com',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Obligatorio';
            if (!v.contains('@') || !v.contains('.')) return 'Email invalido';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordCtrl,
          decoration: const InputDecoration(
            labelText: 'Contrasena',
            hintText: 'Minimo 6 caracteres',
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Obligatorio';
            if (v.length < 6) return 'Minimo 6 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tu contrasena sera tu PIN de administrador. Recuerdala.',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
