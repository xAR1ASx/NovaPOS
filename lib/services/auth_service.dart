import '../database/db_helper.dart';
import 'permission_service.dart';

class AuthService {
  final DBHelper _dbHelper = DBHelper();

  /// Iniciar sesión
  Future<Map<String, dynamic>?> login({
    required String usuario,
    required String password,
  }) async {
    final user = await _dbHelper.login(usuario, password);

    if (user == null) {
      return null;
    }

    final permisos = await _dbHelper.getPermissionsByRole(
      user["rol"].toString(),
    );

    await PermissionService.loadPermissions(permisos);

    return user;
  }

  Future<void> logout() async {
    await PermissionService.clear();
  }
}
