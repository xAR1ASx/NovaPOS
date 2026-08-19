class RolePermissions {
  static const Map<String, List<String>> _permisosPorRol = {
    'ADMIN': [
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
    ],
    'CAJERO': [
      'VENTAS_CREAR',
      'VENTAS_VER',
      'CAJA_ABRIR',
      'CAJA_CERRAR',
      'CAJA_MOVIMIENTOS',
      'CLIENTES_VER',
      'CLIENTES_EDITAR',
    ],
  };

  static List<String> permisosPara(String rol) {
    return _permisosPorRol[rol] ?? [];
  }
}
