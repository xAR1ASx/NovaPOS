/// Categorías de los movimientos de caja. Ordenan los gastos para el
/// estado de resultados y separan lo que sale de la caja sin ser gasto
/// (préstamos, retiros del dueño).
class CategoriasCaja {
  CategoriasCaja._();

  static const Map<String, String> gastos = {
    'NOMINA': 'Nómina y pagos de turno',
    'ADELANTO': 'Adelanto a empleado',
    'ARRIENDO': 'Arriendo',
    'SERVICIOS': 'Servicios públicos',
    'TRANSPORTE': 'Transporte y domicilios',
    'PROVEEDOR': 'Pago a proveedor sin factura',
    'INSUMOS': 'Bolsas, aseo e insumos',
    'MANTENIMIENTO': 'Mantenimiento y reparaciones',
    'IMPUESTOS': 'Impuestos y trámites',
    'DESCUADRE': 'Faltante de caja',
    'PRESTAMO': 'Préstamo (debe volver)',
    'RETIRO': 'Retiro del dueño',
    'OTRO': 'Otros gastos',
  };

  static const Map<String, String> ingresos = {
    'BASE_EXTRA': 'Base o sencillo extra',
    'APORTE': 'Aporte del dueño o socio',
    'PRESTAMO_RECIBIDO': 'Préstamo recibido',
    'DEVOLUCION_PRESTAMO': 'Devolución de un préstamo',
    'ABONO_CLIENTE': 'Abono de cliente (fiado)',
    'SOBRANTE': 'Sobrante de caja',
    'OTRO': 'Otro ingreso',
  };

  /// Salidas que no restan de la utilidad: el dinero vuelve (préstamo) o
  /// es del dueño (retiro).
  static const Set<String> noSonGasto = {'PRESTAMO', 'RETIRO'};

  /// Las que el cajero elige al registrar un gasto (el faltante lo pone el
  /// cierre de caja).
  static List<String> get gastosElegibles =>
      gastos.keys.where((k) => k != 'DESCUADRE').toList();

  static List<String> get ingresosElegibles =>
      ingresos.keys.where((k) => k != 'SOBRANTE' && k != 'ABONO_CLIENTE').toList();

  static String? porDefecto(String tipo) {
    switch (tipo) {
      case 'GASTO':
      case 'INGRESO':
        return 'OTRO';
      case 'APERTURA':
        return 'BASE';
      case 'COMPRA':
        return 'COMPRA';
      case 'DEVOLUCION':
        return 'DEVOLUCION';
      case 'ANULACION':
        return 'ANULACION';
      case 'CIERRE':
        return 'CIERRE';
      default:
        return null;
    }
  }

  /// Categoría de un movimiento. Los anteriores a las categorías se
  /// reconocen por la descripción que les ponía el sistema.
  static String de(Map<String, dynamic> mov) {
    final cat = (mov['categoria'] ?? '').toString();
    final tipo = (mov['tipo'] ?? '').toString();
    final desc = (mov['descripcion'] ?? '').toString().toLowerCase();
    final esLegado = cat.isEmpty || (cat == 'OTRO' && desc.isNotEmpty);
    if (esLegado && tipo == 'GASTO' && desc.contains('descuadre')) return 'DESCUADRE';
    if (esLegado && tipo == 'INGRESO' && desc.contains('sobrante')) return 'SOBRANTE';
    if (esLegado && tipo == 'INGRESO' && desc.startsWith('abono')) return 'ABONO_CLIENTE';
    if (cat.isNotEmpty) return cat;
    return porDefecto(tipo) ?? 'OTRO';
  }

  static String nombre(String tipo, String categoria) {
    if (tipo == 'INGRESO') return ingresos[categoria] ?? categoria;
    return gastos[categoria] ?? categoria;
  }
}
