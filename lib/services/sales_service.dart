import '../database/db_helper.dart';
import 'permission_service.dart';

class SalesService {
  final DBHelper _dbHelper = DBHelper();

  Future<int> registrarVenta({
    required double total,
    required String metodoPago,
    required List<Map<String, dynamic>> items,
    int clienteId = 0,
  }) async {
    if (!PermissionService.can("VENTAS_CREAR")) {
      throw Exception("No tienes permiso para crear ventas.");
    }

    return await _dbHelper.registrarVenta(
      total,
      metodoPago,
      items,
      clienteId: clienteId,
    );
  }
}
