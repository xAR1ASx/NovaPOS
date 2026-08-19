class SessionService {
  static Map<String, dynamic>? _currentUser;
  static String? _negocioId;

  static Future<void> login(Map<String, dynamic> usuario, {String? negocioId}) async {
    _currentUser = usuario;
    _negocioId = negocioId;
  }

  static Map<String, dynamic>? currentUser() {
    return _currentUser;
  }

  static bool isLogged() {
    return _currentUser != null;
  }

  static int? userId() {
    return _currentUser?["id"] as int?;
  }

  static String username() {
    return _currentUser?["usuario"] ?? "";
  }

  static String userName() {
    return _currentUser?["nombre_completo"] ?? "";
  }

  static String userRole() {
    return _currentUser?["rol"] ?? "";
  }

  static String? negocioId() {
    return _negocioId;
  }

  static Future<void> logout() async {
    _currentUser = null;
    _negocioId = null;
  }
}
