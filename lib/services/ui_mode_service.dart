import 'dart:io';
import 'package:flutter/foundation.dart';

/// Decide si la interfaz corre en modo tablet (pantalla tactil, textos mas
/// grandes) o modo PC. El instalador escribe un archivo `interfaz.txt` en
/// `%LOCALAPPDATA%\NovaPOS\` con el valor "PC" o "Tablet".
class UIModeService {
  static final ValueNotifier<bool> tablet = ValueNotifier(false);

  static String _rutaArchivo() {
    if (Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) {
        return '$local\\NovaPOS\\interfaz.txt';
      }
    }
    return 'NovaPOS/interfaz.txt';
  }

  static Future<void> init() async {
    try {
      final file = File(_rutaArchivo());
      if (await file.exists()) {
        final contenido = (await file.readAsString()).trim();
        tablet.value = contenido.toLowerCase().contains('tablet');
      }
    } catch (e) {}
  }

  static Future<void> setEsTablet(bool valor) async {
    tablet.value = valor;
    try {
      final file = File(_rutaArchivo());
      await file.parent.create(recursive: true);
      await file.writeAsString(valor ? 'Tablet' : 'PC');
    } catch (e) {}
  }

  /// Factor de escala de texto para el modo tablet.
  static double get textScale => tablet.value ? 1.2 : 1.0;
}