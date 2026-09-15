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

    Map<String, dynamic>? anterior;
    if (datos.containsKey('stock_actual')) {
      final resAnt = await db.query(
        'productos',
        columns: ['stock_actual'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (resAnt.isNotEmpty) {
        anterior = resAnt.first;
      }
    }

    final res = await db.update(
      'productos',
      datos,
      where: 'id = ?',
      whereArgs: [id],
    );

    // Sincronización: publicar edición de metadatos y, si cambió stock,
    // encolar la operación de stock correspondiente.
    try {
      final p = (await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      ));
      if (p.isNotEmpty) {
        await _dbHelper.encolarProductoCambio(p.first);
        if (datos.containsKey('stock_actual') && anterior != null) {
          final viejo = (anterior['stock_actual'] as num?)?.toDouble() ?? 0;
          final nuevo = (p.first['stock_actual'] as num?)?.toDouble() ?? 0;
          final delta = nuevo - viejo;
          if (delta.abs() > 0.000001) {
            await _dbHelper.encolarStockOp(id, delta);
          }
        }
      }
    } catch (e) {}

    return res;
  }

  /// Desactiva un producto
  Future<void> eliminarProducto(int id) async {
    if (!PermissionService.can("INVENTARIO_ELIMINAR")) {
      throw Exception("No tienes permiso para eliminar productos.");
    }

    await _dbHelper.desactivarProducto(id);
  }
}
