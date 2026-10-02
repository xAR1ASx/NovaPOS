import 'dart:io';
import 'package:flutter/material.dart';

class ThemeService {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  static String _rutaArchivo() {
    if (Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) {
        return '$local\\NovaPOS\\theme.txt';
      }
    }
    return 'NovaPOS/theme.txt';
  }

  static Future<void> init() async {
    try {
      final file = File(_rutaArchivo());
      if (await file.exists()) {
        final contenido = (await file.readAsString()).trim().toLowerCase();
        if (contenido == 'dark') {
          themeMode.value = ThemeMode.dark;
        } else if (contenido == 'system') {
          themeMode.value = ThemeMode.system;
        } else {
          themeMode.value = ThemeMode.light;
        }
      }
    } catch (e) {
      // Ignorar errores de lectura
    }
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    try {
      final file = File(_rutaArchivo());
      await file.parent.create(recursive: true);
      String text = 'light';
      if (mode == ThemeMode.dark) text = 'dark';
      if (mode == ThemeMode.system) text = 'system';
      await file.writeAsString(text);
    } catch (e) {
      // Ignorar
    }
  }
}
