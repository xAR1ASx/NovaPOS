import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/services/balanza_barcode_service.dart';

void main() {
  group('BalanzaBarcodeService', () {
    test('Calcula checksum EAN-13 correctamente', () {
      // 20 00101 01250 -> cuerpo de 12 dígitos
      final check = BalanzaBarcodeService.calcularEan13Checksum('200010101250');
      expect(check, greaterThanOrEqualTo(0));
      expect(check, lessThanOrEqualTo(9));

      // Verificamos con un código conocido
      final completo = '200010101250$check';
      expect(BalanzaBarcodeService.validarEan13Checksum(completo), isTrue);
    });

    test('Decodifica código de balanza por PESO (Prefijo 20)', () {
      // Prefijo: 20
      // PLU: 00101 -> Aguacate Hass (PLU 101)
      // Peso: 01250 -> 1.250 Kg
      final codigo = BalanzaBarcodeService.generarCodigoEjemplo(
        prefijo: '20',
        plu: '101',
        valor: 1.250,
        esPeso: true,
      );

      final resultado = BalanzaBarcodeService.parsearCodigo(codigo);
      expect(resultado.esValido, isTrue);
      expect(resultado.tipo, equals('PESO'));
      expect(resultado.plu, equals('101'));
      expect(resultado.plu5, equals('00101'));
      expect(resultado.pesoKg, closeTo(1.250, 0.0001));
      expect(resultado.checksumValido, isTrue);
    });

    test('Decodifica código de balanza por PRECIO / IMPORTE (Prefijo 21)', () {
      // Prefijo: 21
      // PLU: 00201 -> Tomate Chonto (PLU 201)
      // Precio: 05400 -> $5,400 COP
      final codigo = BalanzaBarcodeService.generarCodigoEjemplo(
        prefijo: '21',
        plu: '201',
        valor: 5400,
        esPeso: false,
      );

      final resultado = BalanzaBarcodeService.parsearCodigo(codigo);
      expect(resultado.esValido, isTrue);
      expect(resultado.tipo, equals('PRECIO'));
      expect(resultado.plu, equals('201'));
      expect(resultado.precioTotal, equals(5400.0));
      expect(resultado.checksumValido, isTrue);
    });

    test('Soporta códigos de 12 dígitos (sin checksum o omitido por lector)', () {
      // 20 + 00105 + 00850 = 12 dígitos
      const codigo12 = '200010500850';
      final resultado = BalanzaBarcodeService.parsearCodigo(codigo12);
      expect(resultado.esValido, isTrue);
      expect(resultado.tipo, equals('PESO'));
      expect(resultado.plu, equals('105'));
      expect(resultado.pesoKg, closeTo(0.850, 0.0001));
    });

    test('Rechaza códigos con longitudes incorrectas o texto', () {
      expect(BalanzaBarcodeService.parsearCodigo('12345').esValido, isFalse);
      expect(BalanzaBarcodeService.parsearCodigo('2000101ABCDE9').esValido, isFalse);
      expect(BalanzaBarcodeService.parsearCodigo('').esValido, isFalse);
    });

    test('Rechaza códigos con peso cero', () {
      const codigoPesoCero = '2000101000005';
      final resultado = BalanzaBarcodeService.parsearCodigo(codigoPesoCero);
      expect(resultado.esValido, isFalse);
    });

    test('Respeta configuración personalizada de prefijos', () {
      // Supongamos que la balanza está configurada con prefijo 28 para peso
      final config = {
        'balanza_etiqueta_activa': '1',
        'balanza_etiqueta_prefijo_peso': '28',
      };
      final codigo = BalanzaBarcodeService.generarCodigoEjemplo(
        prefijo: '28',
        plu: '305',
        valor: 2.100,
        esPeso: true,
      );

      final res = BalanzaBarcodeService.parsearCodigo(codigo, config: config);
      expect(res.esValido, isTrue);
      expect(res.tipo, equals('PESO'));
      expect(res.plu, equals('305'));
      expect(res.pesoKg, closeTo(2.100, 0.0001));
    });

    test('No parsea si la función está deshabilitada en configuración', () {
      final config = {'balanza_etiqueta_activa': '0'};
      final codigo = BalanzaBarcodeService.generarCodigoEjemplo(
        prefijo: '20',
        plu: '101',
        valor: 1.0,
      );

      final res = BalanzaBarcodeService.parsearCodigo(codigo, config: config);
      expect(res.esValido, isFalse);
      expect(res.error, contains('desactivada'));
    });
  });
}
