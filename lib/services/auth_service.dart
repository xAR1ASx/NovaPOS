import '../database/db_helper.dart';

class AuthService {
  final DBHelper _dbHelper = DBHelper();

  /// Iniciar sesión
  Future<Map<String, dynamic>?> login({
    required String usuario,
    required String password,
  }) async {
    return await _dbHelper.login(usuario, password);
  }
}
