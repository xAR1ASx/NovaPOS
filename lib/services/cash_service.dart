import '../database/db_helper.dart';
import 'permission_service.dart';
import 'session_service.dart';

class CashService {
  final DBHelper _dbHelper = DBHelper();

  Future<int> registrarMovimiento({
    required String tipo,
    required double monto,
    required String descripcion,
  }) async {
    String permiso;

    switch (tipo) {
      case 'APERTURA':
        permiso = 'CAJA_ABRIR';
        break;

      case 'CIERRE':
        permiso = 'CAJA_CERRAR';
        break;

      default:
        permiso = 'CAJA_MOVIMIENTOS';
    }

    if (!PermissionService.can(permiso)) {
      throw Exception(
        'No tienes permiso para realizar esta operación de caja.',
      );
    }

    final usuarioId = SessionService.userId();

    if (usuarioId == null) {
      throw Exception('No hay un usuario autenticado.');
    }

    return await _dbHelper.registrarMovimientoCaja(
      tipo,
      monto,
      descripcion,
      usuarioId,
    );
  }

  /// Ingresa efectivo a la caja y paga un gasto en una sola operación atómica.
  /// Pensado para pedidos/pagos mayores al efectivo disponible.
  Future<Map<String, dynamic>> registrarIngresoYGasto({
    required double ingreso,
    required double gasto,
    required String descripcionIngreso,
    required String descripcionGasto,
  }) async {
    if (!PermissionService.can('CAJA_MOVIMIENTOS')) {
      throw Exception(
        'No tienes permiso para realizar esta operación de caja.',
      );
    }
    final usuarioId = SessionService.userId();
    if (usuarioId == null) {
      throw Exception('No hay un usuario autenticado.');
    }
    return await _dbHelper.registrarIngresoYGasto(
      ingreso: ingreso,
      gasto: gasto,
      descripcionIngreso: descripcionIngreso,
      descripcionGasto: descripcionGasto,
      usuarioId: usuarioId,
    );
  }
}

