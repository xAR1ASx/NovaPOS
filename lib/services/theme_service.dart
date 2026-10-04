import 'dart:io';
import 'package:flutter/material.dart';

class ThemeService {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  static bool get isDark => themeMode.value == ThemeMode.dark;

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

class AppColors {
  // Brand colors
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color darkNavy = Color(0xFF1A1F2B);

  // Dynamic colors by context
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? const Color(0xFF111827) : const Color(0xFFF1F5F9);

  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF1F2937) : Colors.white;

  static Color cardSubtle(BuildContext context) =>
      isDark(context) ? const Color(0xFF374151) : const Color(0xFFF8FAFC);

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFF9FAFB) : const Color(0xFF111827);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

  static Color inputBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);

  static Color chipBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF374151) : const Color(0xFFF3F4F6);

  static Color softBadge(BuildContext context, Color color) =>
      isDark(context) ? color.withValues(alpha: 0.22) : color.withValues(alpha: 0.12);

  static Color badgeText(BuildContext context, Color lightColor, Color darkColor) =>
      isDark(context) ? darkColor : lightColor;
}

extension ThemeContextExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get scaffoldBg => AppColors.bg(this);
  Color get cardBg => AppColors.card(this);
  Color get cardSubtle => AppColors.cardSubtle(this);
  Color get textPrimary => AppColors.textPrimary(this);
  Color get textSecondary => AppColors.textSecondary(this);
  Color get borderSubtle => AppColors.border(this);
  Color get inputBg => AppColors.inputBg(this);
  Color get chipBg => AppColors.chipBg(this);
}

class AppTheme {
  static ThemeData lightTheme(bool esTablet) {
    const primary = Color(0xFF10B981);
    const scaffoldBg = Color(0xFFF1F5F9);
    const cardBg = Colors.white;
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);
    const border = Color(0xFFE5E7EB);

    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.green,
      primaryColor: primary,
      useMaterial3: true,
      visualDensity: esTablet ? VisualDensity.comfortable : VisualDensity.standard,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        surface: cardBg,
        onSurface: textPrimary,
      ),
      cardTheme: const CardThemeData(
        color: cardBg,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1F2B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        labelStyle: const TextStyle(color: Color(0xFF4B5563)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
    );
  }

  static ThemeData darkTheme(bool esTablet) {
    const primary = Color(0xFF10B981);
    const scaffoldBg = Color(0xFF111827);
    const cardBg = Color(0xFF1F2937);
    const textPrimary = Color(0xFFF9FAFB);
    const textSecondary = Color(0xFF9CA3AF);
    const border = Color(0xFF374151);

    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.green,
      primaryColor: primary,
      useMaterial3: true,
      visualDensity: esTablet ? VisualDensity.comfortable : VisualDensity.standard,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: Colors.white,
        surface: cardBg,
        onSurface: textPrimary,
      ),
      cardTheme: const CardThemeData(
        color: cardBg,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F2937),
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
    );
  }
}
