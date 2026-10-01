import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/services/promociones_service.dart';

void main() {
  group('PromocionesService - Cálculo y Evaluación de Descuentos', () {
    final service = PromocionesService();

    test('Aplica descuento por CATEGORÍA correctamente (10% en Verduras)', () {
      final promosActivas = [
        {
          'id': 1,
          'nombre': 'Martes Campesino',
          'tipo_alcance': 'CATEGORIA',
          'alcance_valor': 'Verduras',
          'tipo_descuento': 'PORCENTAJE',
          'valor_descuento': 10.0,
        },
      ];

      final tomate = {
        'id': 10,
        'nombre': 'Tomate Chonto',
        'categoria': 'Verduras',
        'precio_venta': 4000.0,
        'codigo_plu': '201',
      };

      final res = service.calcularDescuentoProducto(tomate, promosActivas);
      expect(res, isNotNull);
      expect(res!['tiene_descuento'], isTrue);
      expect(res['precio_original'], equals(4000.0));
      expect(res['descuento_por_unidad'], equals(400.0));
      expect(res['precio_con_descuento'], equals(3600.0));
      expect(res['porcentaje'], equals(10.0));
      expect(res['promo_nombre'], equals('Martes Campesino'));

      // Manzana es de categoría Frutas: no debe tener descuento
      final manzana = {
        'id': 11,
        'nombre': 'Manzana Royal',
        'categoria': 'Frutas',
        'precio_venta': 3000.0,
        'codigo_plu': '103',
      };
      final resManzana = service.calcularDescuentoProducto(manzana, promosActivas);
      expect(resManzana, isNull);
    });

    test('Aplica descuento por PRODUCTO específico (ID o PLU)', () {
      final promosActivas = [
        {
          'id': 2,
          'nombre': 'Súper Oferta Aguacate',
          'tipo_alcance': 'PRODUCTO',
          'alcance_valor': '101, 105',
          'tipo_descuento': 'VALOR_FIJO',
          'valor_descuento': 1000.0,
        },
      ];

      final aguacate = {
        'id': 1,
        'nombre': 'Aguacate Hass',
        'categoria': 'Frutas',
        'precio_venta': 5800.0,
        'codigo_plu': '101',
      };

      final res = service.calcularDescuentoProducto(aguacate, promosActivas);
      expect(res, isNotNull);
      expect(res!['descuento_por_unidad'], equals(1000.0));
      expect(res['precio_con_descuento'], equals(4800.0));
    });

    test('Aplica descuento para TODA la tienda', () {
      final promosActivas = [
        {
          'id': 3,
          'nombre': 'Gran Día de Plaza',
          'tipo_alcance': 'TODOS',
          'alcance_valor': 'TODOS',
          'tipo_descuento': 'PORCENTAJE',
          'valor_descuento': 15.0,
        },
      ];

      final producto = {
        'id': 99,
        'nombre': 'Cilantro',
        'categoria': 'Hierbas',
        'precio_venta': 2000.0,
      };

      final res = service.calcularDescuentoProducto(producto, promosActivas);
      expect(res, isNotNull);
      expect(res!['precio_con_descuento'], equals(1700.0));
      expect(res['descuento_por_unidad'], equals(300.0));
      expect(res['porcentaje'], equals(15.0));
    });

    test('Selecciona el mayor descuento si coinciden múltiples promociones', () {
      final promosActivas = [
        {
          'id': 1,
          'nombre': 'Promo General (5%)',
          'tipo_alcance': 'TODOS',
          'tipo_descuento': 'PORCENTAJE',
          'valor_descuento': 5.0,
        },
        {
          'id': 2,
          'nombre': 'Martes Campesino (10%)',
          'tipo_alcance': 'CATEGORIA',
          'alcance_valor': 'Verduras',
          'tipo_descuento': 'PORCENTAJE',
          'valor_descuento': 10.0,
        },
      ];

      final cebolla = {
        'id': 20,
        'nombre': 'Cebolla Cabezona',
        'categoria': 'Verduras',
        'precio_venta': 3000.0,
      };

      final res = service.calcularDescuentoProducto(cebolla, promosActivas);
      expect(res, isNotNull);
      expect(res!['promo_nombre'], equals('Martes Campesino (10%)'));
      expect(res['precio_con_descuento'], equals(2700.0));
      expect(res['descuento_por_unidad'], equals(300.0));
    });

    test('El descuento no puede hacer que el precio sea negativo', () {
      final promosActivas = [
        {
          'id': 4,
          'nombre': 'Super Bono',
          'tipo_alcance': 'TODOS',
          'tipo_descuento': 'VALOR_FIJO',
          'valor_descuento': 10000.0, // Mayor que el precio
        },
      ];

      final producto = {
        'id': 5,
        'nombre': 'Ajo',
        'categoria': 'Verduras',
        'precio_venta': 1500.0,
      };

      final res = service.calcularDescuentoProducto(producto, promosActivas);
      expect(res, isNotNull);
      expect(res!['precio_con_descuento'], equals(0.0));
      expect(res['descuento_por_unidad'], equals(1500.0));
    });

    test('Retorna null si no hay promociones activas o producto no tiene precio', () {
      expect(service.calcularDescuentoProducto({'precio_venta': 1000}, []), isNull);
      expect(
        service.calcularDescuentoProducto(
          {'precio_venta': 0},
          [{'tipo_alcance': 'TODOS', 'tipo_descuento': 'PORCENTAJE', 'valor_descuento': 10}],
        ),
        isNull,
      );
    });
  });
}
