import '../database/db_helper.dart';
import 'permission_service.dart';

class InventoryService {
  final DBHelper _dbHelper = DBHelper();

  /// Crea un producto nuevo
  Future<int> crearProducto(Map<String, dynamic> datos) async {
    if (!PermissionService.can("INVENTARIO_CREAR")) {
      throw Exception("No tienes permiso para crear productos.");
    }

    return await _dbHelper.insertProduct(datos);
  }

  /// Actualiza un producto existente
  Future<int> actualizarProducto(int id, Map<String, dynamic> datos) async {
    if (!PermissionService.can("INVENTARIO_EDITAR")) {
      throw Exception("No tienes permiso para editar productos.");
    }

    final db = await _dbHelper.database;

    return await db.update(
      'productos',
      datos,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Desactiva un producto
  Future<void> eliminarProducto(int id) async {
    if (!PermissionService.can("INVENTARIO_ELIMINAR")) {
      throw Exception("No tienes permiso para eliminar productos.");
    }

    await _dbHelper.desactivarProducto(id);
  }
}
