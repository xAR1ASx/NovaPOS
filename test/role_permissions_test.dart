import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/services/role_permissions.dart';

void main() {
  group('RolePermissions.permisosPara', () {
    test('ADMIN tiene todos los permisos del sistema', () {
      final permisos = RolePermissions.permisosPara('ADMIN');
      expect(permisos, containsAll([
        'VENTAS_CREAR',
        'VENTAS_VER',
        'VENTAS_ANULAR',
        'INVENTARIO_VER',
        'INVENTARIO_CREAR',
        'INVENTARIO_EDITAR',
        'INVENTARIO_ELIMINAR',
        'CAJA_ABRIR',
        'CAJA_CERRAR',
        'CAJA_MOVIMIENTOS',
        'REPORTES_VER',
        'COMPRAS_CREAR',
        'COMPRAS_VER',
        'CLIENTES_VER',
        'CLIENTES_EDITAR',
        'CLIENTES_ELIMINAR',
        'CONFIGURACION_GENERAL',
        'USUARIOS_GESTIONAR',
      ]));
    });

    test('CAJERO tiene permisos de venta y caja', () {
      final permisos = RolePermissions.permisosPara('CAJERO');
      expect(permisos, containsAll([
        'VENTAS_CREAR',
        'VENTAS_VER',
        'CAJA_ABRIR',
        'CAJA_CERRAR',
        'CAJA_MOVIMIENTOS',
        'CLIENTES_VER',
        'CLIENTES_EDITAR',
      ]));
    });

    test('CAJERO NO tiene permisos de administracion ni inventario', () {
      final permisos = RolePermissions.permisosPara('CAJERO');
      expect(permisos, isNot(contains('CONFIGURACION_GENERAL')));
      expect(permisos, isNot(contains('USUARIOS_GESTIONAR')));
      expect(permisos, isNot(contains('INVENTARIO_CREAR')));
      expect(permisos, isNot(contains('VENTAS_ANULAR')));
      expect(permisos, isNot(contains('CLIENTES_ELIMINAR')));
    });

    test('un rol desconocido no tiene permisos', () {
      expect(RolePermissions.permisosPara('GERENTE'), isEmpty);
      expect(RolePermissions.permisosPara(''), isEmpty);
    });
  });
}