import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/locale_service.dart';
import 'services/license_monitor.dart';
import 'services/ui_mode_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Windows: sin caché en disco de Firestore. En el PC del primer cliente la
  // app se cerraba al entrar por segunda vez (instrucción ilegal 0xc000001d
  // dentro de Firebase, al leer esa caché). NovaPOS guarda todo en SQLite y
  // tiene su propia cola de subida, así que no la necesita.
  if (Platform.isWindows) {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
  }

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await UIModeService.init();
  await ThemeService.init();
  await LocaleService().cargarInicial();
  await initializeDateFormatting('es_CO', null);
  await initializeDateFormatting('en_US', null);

  runApp(const NovaPOSApp());
}

class NovaPOSApp extends StatelessWidget {
  const NovaPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: UIModeService.tablet,
      builder: (context, esTablet, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeMode,
          builder: (context, themeMode, child) {
            return ListenableBuilder(
              listenable: LocaleService(),
              builder: (context, child) {
                final idioma = LocaleService().idioma;
                return MaterialApp(
                  navigatorKey: appNavigatorKey,
                  debugShowCheckedModeBanner: false,
                  title: 'NovaPOS',
                  locale: Locale(idioma),
                  supportedLocales: const [Locale('es'), Locale('en')],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  themeMode: themeMode,
                  theme: AppTheme.lightTheme(esTablet),
                  darkTheme: AppTheme.darkTheme(esTablet),
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(UIModeService.textScale),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const SplashScreen(),
            );
          },
        );
          },
        );
      },
    );
  }
}
