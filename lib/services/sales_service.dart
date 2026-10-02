import '../database/db_helper.dart';
import 'permission_service.dart';
import 'session_service.dart';
import 'promociones_service.dart';

class SalesService {
  final DBHelper _dbHelper = DBHelper();

  Future<Map<String, dynamic>> registrarVenta({
    required double total,
    required String metodoPago,
    required List<Map<String, dynamic>> items,
    int clienteId = 0,
    String? metodoPagoDetalle,
  }) async {
    if (!PermissionService.can("VENTAS_CREAR")) {
      throw Exception("No tienes permiso para crear ventas.");
    }

    final String rol = SessionService.userRole();
    if (rol != 'ADMIN') {
      // H-01 Plus: Validación Estricta (Nivel Militar) para CAJEROS.
      // Recalcula el precio de cada producto directo de la BD y aplica promociones.
      // Si el subtotal enviado por la UI es menor al calculado, se bloquea por fraude.
      final db = await _dbHelper.database;
      final promocionesActivas = await PromocionesService().obtenerPromocionesActivasHoy();

      for (var i in items) {
        final pList = await db.query('productos', where: 'id = ?', whereArgs: [i['id']], limit: 1);
        if (pList.isEmpty) throw Exception("Alerta: Producto inválido detectado.");
        
        final pDB = pList.first;
        final descInfo = PromocionesService().calcularDescuentoProducto(pDB, promocionesActivas);
        
        final double precioUnitarioReal = descInfo != null 
            ? (descInfo['precio_con_descuento'] as num).toDouble() 
            : (pDB['precio_venta'] as num).toDouble();
            
        final double subtotalEsperado = precioUnitarioReal * (i['cantidad'] as num).toDouble();
        final double subtotalUI = (i['subtotal'] as num).toDouble();

        // Si el cajero cobra MENOS del valor estricto (permitiendo $2 pesos de margen de redondeo), es fraude.
        if (subtotalUI < subtotalEsperado - 2.0) {
          throw Exception("ALERTA ANTI-FRAUDE: El precio del producto '${pDB['nombre']}' fue alterado o tiene un descuento no autorizado.");
        }
      }
    }

    int usuarioId = SessionService.userId() ?? 1;

    return await _dbHelper.registrarVenta(
      total,
      metodoPago,
      items,
      clienteId: clienteId,
      usuarioId: usuarioId,
      metodoPagoDetalle: metodoPagoDetalle,
    );
  }
}
