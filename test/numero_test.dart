import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/utils/numero.dart';

void main() {
  group('parseNumero (formato colombiano)', () {
    test('punto como separador de miles', () {
      expect(parseNumero('10.000'), 10000);
      expect(parseNumero('2.550'), 2550);
      expect(parseNumero('1.234.567'), 1234567);
    });

    test('coma como separador decimal', () {
      expect(parseNumero('10,000'), 10.0);
      expect(parseNumero('300,5'), 300.5);
    });

    test('mixto: punto de miles y coma decimal', () {
      expect(parseNumero('1.234,56'), 1234.56);
      expect(parseNumero('2.550,50'), 2550.50);
    });

    test('punto simple como decimal', () {
      expect(parseNumero('2.5'), 2.5);
      expect(parseNumero('1234.56'), 1234.56);
    });

    test('sin separadores', () {
      expect(parseNumero('100'), 100);
      expect(parseNumero('0'), 0);
    });

    test('texto inválido o vacío devuelve null', () {
      expect(parseNumero(null), null);
      expect(parseNumero(''), null);
      expect(parseNumero('   '), null);
      expect(parseNumero('abc'), null);
      expect(parseNumero('10.000a'), null);
    });
  });

  group('Cantidades (kilos y unidades)', () {
    test('punto o coma son decimales', () {
      expect(parseCantidad('0.750'), 0.75);
      expect(parseCantidad('0,750'), 0.75);
      expect(parseCantidad('1.5'), 1.5);
      expect(parseCantidad('12.750'), 12.75);
      expect(parseCantidad('3'), 3);
      expect(parseCantidad(''), isNull);
    });
    test('montos que empiezan por cero son decimales', () {
      expect(parseNumero('0.750'), 0.75);
      expect(parseNumero('10.000'), 10000);
    });
  });
}
