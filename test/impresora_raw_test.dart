import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/services/impresora_raw.dart';

void main() {
  test(
    'La orden del cajón es ESC p por los dos conectores (pin 2 y pin 5)',
    () {
      expect(ImpresoraRaw.pulsoCajon, [
        0x1B, 0x70, 0x00, 0x19, 0xFA, //
        0x1B, 0x70, 0x01, 0x19, 0xFA,
      ]);
    },
  );

  test('Sin impresora elegida no se envía nada', () {
    expect(ImpresoraRaw.enviar('', ImpresoraRaw.pulsoCajon), isFalse);
  });

  test('Una impresora que no existe no rompe la app', () {
    expect(
      ImpresoraRaw.enviar(
        'Impresora que no existe 123',
        ImpresoraRaw.pulsoCajon,
      ),
      isFalse,
    );
  }, skip: !Platform.isWindows);
}
