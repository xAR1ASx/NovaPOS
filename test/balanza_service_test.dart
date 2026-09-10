import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/services/balanza_service.dart';

void main() {
  group('BalanzaService.parsearPeso', () {
    test('peso en gramos', () {
      expect(BalanzaService.parsearPeso('001234 g'), 1.234);
      expect(BalanzaService.parsearPeso('500'), 0.5);
    });

    test('peso en kilogramos', () {
      expect(BalanzaService.parsearPeso('2.500 kg'), 2.5);
      expect(BalanzaService.parsearPeso('50 KG'), 50.0);
      expect(BalanzaService.parsearPeso('0.350 Kg'), 0.35);
    });

    test('coma decimal', () {
      expect(BalanzaService.parsearPeso('1234,5 g'), 1.234);
      expect(BalanzaService.parsearPeso('1,200 kg'), 1.2);
    });

    test('paquete STX/ETX con prefijo', () {
      expect(BalanzaService.parsearPeso('\x02PACK000500g\x03'), 0.5);
      expect(BalanzaService.parsearPeso('\x02ST,GS,002500,g\x03'), 2.5);
    });

    test('ruido sin numeros devuelve null', () {
      expect(BalanzaService.parsearPeso('NUESTRA BALANZA'), isNull);
      expect(BalanzaService.parsearPeso(''), isNull);
    });

    test('pesos fuera de rango se ignoran', () {
      expect(BalanzaService.parsearPeso('999999 g'), isNull);
      expect(BalanzaService.parsearPeso('0.0001 g'), isNull);
      expect(BalanzaService.parsearPeso('600 kg'), isNull);
    });

    test('ignora texto de relleno alrededor del peso', () {
      expect(BalanzaService.parsearPeso('=01234 g SUT'), 1.234);
      expect(BalanzaService.parsearPeso('x 3.4 kg y'), 3.4);
    });
  });
}