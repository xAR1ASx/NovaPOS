import 'home_screen.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores para leer lo que escribe el usuario
  final AuthService _authService = AuthService();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  String _mensajeError = ""; // Para mostrar si la clave está mal

  // Lógica para intentar entrar
  void _iniciarSesion() async {
    String user = _userController.text.trim();
    String pass = _passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      setState(() {
        _mensajeError = "Por favor escribe usuario y contraseña";
      });
      return;
    }

    // Preguntamos a la base de datos
    var usuarioEncontrado = await _authService.login(
      usuario: user,
      password: pass,
    );

    if (usuarioEncontrado != null) {
      // ¡LOGIN EXITOSO! 🎉
      // Navegar a la pantalla principal y borrar el historial para no volver atrás
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // LOGIN FALLIDO ❌
      setState(() {
        _mensajeError = "Usuario o contraseña incorrectos";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50], // Fondo verdecito suave
      body: Center(
        child: SingleChildScrollView(
          // Por si el teclado tapa la pantalla
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. EL LOGO (Icono por ahora)
              const Icon(Icons.storefront, size: 100, color: Colors.green),
              const SizedBox(height: 20),

              const Text(
                "MI FRUVER POS",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Text(
                "Grupo Arias Software",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 40),

              // 2. CAJA DE USUARIO
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: "Usuario",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // 3. CAJA DE CONTRASEÑA
              TextField(
                controller: _passController,
                obscureText: true, // Ocultar texto con puntitos
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              // MENSAJE DE ERROR (Rojo)
              Text(
                _mensajeError,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // 4. BOTÓN DE ENTRAR
              SizedBox(
                width: double.infinity, // Que ocupe todo el ancho
                height: 50,
                child: ElevatedButton(
                  onPressed: _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                  child: const Text(
                    "INICIAR SESIÓN",
                    style: TextStyle(color: Colors.white, fontSize: 18),
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
