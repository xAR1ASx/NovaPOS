import 'package:flutter_test/flutter_test.dart';
import 'package:novapos/services/password_service.dart';

void main() {
  group('PasswordService.hashPassword', () {
    test('genera un hash SHA-256 correcto', () {
      expect(PasswordService.hashPassword('123456'),
          '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92');
    });

    test('genera hashes distintos para contrasenas distintas', () {
      expect(PasswordService.hashPassword('123456'),
          isNot(PasswordService.hashPassword('654321')));
    });

    test('es determinista', () {
      expect(PasswordService.hashPassword('miclave'),
          PasswordService.hashPassword('miclave'));
    });
  });

  group('PasswordService.verifyPassword', () {
    test('devuelve true con la contrasena correcta', () {
      final hash = PasswordService.hashPassword('987654');
      expect(PasswordService.verifyPassword('987654', hash), isTrue);
    });

    test('devuelve false con una contrasena incorrecta', () {
      final hash = PasswordService.hashPassword('987654');
      expect(PasswordService.verifyPassword('123456', hash), isFalse);
    });
  });
}