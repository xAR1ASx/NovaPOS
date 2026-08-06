class SessionService {
  // Usuario que tiene la sesión iniciada
  static Map<String, dynamic>? _currentUser;

  /// Guarda el usuario que inició sesión
  static Future<void> login(Map<String, dynamic> usuario) async {
    _currentUser = usuario;
  }

  /// Devuelve el usuario completo
  static Map<String, dynamic>? currentUser() {
    return _currentUser;
  }

  /// Indica si existe una sesión activa
  static bool isLogged() {
    return _currentUser != null;
  }

  /// ID del usuario
  static int? userId() {
    return _currentUser?["id"] as int?;
  }

  /// Usuario (login)
  static String username() {
    return _currentUser?["usuario"] ?? "";
  }

  /// Nombre completo
  static String userName() {
    return _currentUser?["nombre_completo"] ?? "";
  }

  /// Rol del usuario
  static String userRole() {
    return _currentUser?["rol"] ?? "";
  }

  /// Cerrar sesión
  static Future<void> logout() async {
    _currentUser = null;
  }
}
