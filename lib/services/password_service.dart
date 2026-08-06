import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordService {
  /// Genera el hash SHA-256 de una contraseña
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Compara una contraseña ingresada con un hash almacenado
  static bool verifyPassword(
    String password,
    String storedHash,
  ) {
    return hashPassword(password) == storedHash;
  }
}