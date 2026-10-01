import 'dart:math';
import '../database/db_helper.dart';

/// Servicio de gestión de Días de Plaza y Promociones Especiales para Fruvers.
/// Permite al Administrador / Dueño configurar descuentos por día de la semana,
/// por categoría (ej. Frutas, Verduras), por producto o en toda la tienda.
class PromocionesService {
  static final PromocionesService _instance = PromocionesService._internal();
  factory PromocionesService() => _instance;
  PromocionesService._internal();

  /// Nombres de los días de la semana (1 = Lunes, 7 = Domingo)
  static const Map<int, String> nombresDias = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
    7: 'Domingo',
  };

  /// Abrev. cortas de los días de la semana
  static const Map<int, String> diasAbrev = {
    1: 'Lun',
    2: 'Mar',
    3: 'Mié',
    4: 'Jue',
    5: 'Vie',
    6: 'Sáb',
    7: 'Dom',
  };

  /// Verifica si el motor de promociones está activado globalmente por el dueño.
  Future<bool> estanPromocionesHabilitadasGlobalmente() async {
    final cfg = await DBHelper().obtenerConfiguracion();
    return (cfg['promociones_activas'] ?? '1') != '0';
  }

  /// Permite al dueño encender o apagar el motor completo de promociones con 1 clic.
  Future<void> setPromocionesHabilitadasGlobalmente(bool habilitar) async {
    await DBHelper().guardarConfiguracion(
      'promociones_activas',
      habilitar ? '1' : '0',
    );
  }

  /// Obtiene todas las promociones registradas en el sistema.
  Future<List<Map<String, dynamic>>> obtenerTodasLasPromociones() async {
    return await DBHelper().obtenerPromociones();
  }

  /// Obtiene las promociones vigentes y activas para el día de hoy (o una fecha de referencia).
  Future<List<Map<String, dynamic>>> obtenerPromocionesActivasHoy({
    DateTime? fechaRef,
  }) async {
    final globalActivo = await estanPromocionesHabilitadasGlobalmente();
    if (!globalActivo) return [];

    final todas = await obtenerTodasLasPromociones();
    final fecha = fechaRef ?? DateTime.now();
    final diaSemana = fecha.weekday; // 1: Lunes, ..., 7: Domingo

    return todas.where((p) {
      final estaActiva = (p['esta_activa'] as num?)?.toInt() == 1;
      if (!estaActiva) return false;

      final forzarHoy = (p['forzar_hoy'] as num?)?.toInt() == 1;
      if (forzarHoy) return true; // Habilitada manualmente por el dueño para hoy

      final diasStr = (p['dias_semana'] ?? '').toString();
      final diasList = diasStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      return diasList.contains(diaSemana.toString());
    }).toList();
  }

  /// Guarda o actualiza una promoción.
  Future<int> guardarPromocion(Map<String, dynamic> promo) async {
    return await DBHelper().guardarPromocion(promo);
  }

  /// Elimina una promoción por ID.
  Future<int> eliminarPromocion(int id) async {
    return await DBHelper().eliminarPromocion(id);
  }

  /// Alterna el estado activa / inactiva de una promoción.
  Future<void> toggleActiva(int id, bool activa) async {
    await DBHelper().togglePromocionActiva(id, activa);
  }

  /// Alterna el estado "Forzar HOY" de una promoción (para activar un día fuera de calendario).
  Future<void> toggleForzarHoy(int id, bool forzar) async {
    await DBHelper().togglePromocionForzarHoy(id, forzar);
  }

  /// Evalúa un producto contra la lista de promociones activas y retorna el descuento aplicable.
  /// Si no califica para ninguna promoción, retorna null.
  /// En caso de que califiquen varias, selecciona la de mayor descuento para el cliente.
  Map<String, dynamic>? calcularDescuentoProducto(
    Map<String, dynamic> producto,
    List<Map<String, dynamic>> promocionesActivas,
  ) {
    if (promocionesActivas.isEmpty) return null;

    final precioVenta = ((producto['precio_venta'] as num?)?.toDouble() ?? 0.0);
    if (precioVenta <= 0) return null;

    final prodCat = (producto['categoria'] ?? '').toString().trim().toLowerCase();
    final prodId = (producto['id'] ?? '').toString().trim();
    final prodPlu = (producto['codigo_plu'] ?? '').toString().trim();

    Map<String, dynamic>? mejorPromo;
    double maxDescuento = 0.0;
    double porcentajeEfectivo = 0.0;

    for (final promo in promocionesActivas) {
      final tipoAlcance = (promo['tipo_alcance'] ?? 'TODOS').toString().toUpperCase();
      final alcanceValor = (promo['alcance_valor'] ?? '').toString().trim();
      bool aplica = false;

      if (tipoAlcance == 'TODOS') {
        aplica = true;
      } else if (tipoAlcance == 'CATEGORIA') {
        if (prodCat.isNotEmpty && alcanceValor.toLowerCase() == prodCat) {
          aplica = true;
        }
      } else if (tipoAlcance == 'PRODUCTO') {
        final ids = alcanceValor.split(',').map((s) => s.trim()).toSet();
        if (ids.contains(prodId) || (prodPlu.isNotEmpty && ids.contains(prodPlu))) {
          aplica = true;
        }
      }

      if (aplica) {
        final tipoDescuento = (promo['tipo_descuento'] ?? 'PORCENTAJE').toString().toUpperCase();
        final valorDesc = ((promo['valor_descuento'] as num?)?.toDouble() ?? 0.0);
        double descuentoCalculado = 0.0;
        double pct = 0.0;

        if (tipoDescuento == 'PORCENTAJE') {
          pct = valorDesc;
          descuentoCalculado = precioVenta * (pct / 100.0);
        } else {
          descuentoCalculado = valorDesc;
          pct = precioVenta > 0 ? ((descuentoCalculado / precioVenta) * 100.0) : 0.0;
        }

        descuentoCalculado = min(descuentoCalculado, precioVenta);

        if (descuentoCalculado > maxDescuento) {
          maxDescuento = descuentoCalculado;
          porcentajeEfectivo = pct;
          mejorPromo = promo;
        }
      }
    }

    if (mejorPromo == null || maxDescuento <= 0) return null;

    final precioConDescuento = max(0.0, precioVenta - maxDescuento);

    return {
      'tiene_descuento': true,
      'promo_id': mejorPromo['id'],
      'promo_nombre': mejorPromo['nombre'],
      'precio_original': precioVenta,
      'precio_con_descuento': precioConDescuento,
      'descuento_por_unidad': maxDescuento,
      'porcentaje': double.parse(porcentajeEfectivo.toStringAsFixed(1)),
    };
  }
}
