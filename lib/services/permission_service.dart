class PermissionService {
  static final Set<String> _permissions = {};

  /// Carga todos los permisos del usuario
  static Future<void> loadPermissions(List<String> permisos) async {
    _permissions.clear();
    _permissions.addAll(permisos);
  }

  /// Verifica si existe un permiso
  static bool can(String permiso) {
    return _permissions.contains(permiso);
  }

  /// Limpia permisos al cerrar sesión
  static Future<void> clear() async {
    _permissions.clear();
  }

  /// Devuelve todos los permisos (útil para depuración)
  static List<String> all() {
    return _permissions.toList();
  }
}
