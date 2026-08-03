import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await initializeDateFormatting('es_CO', null);

  runApp(const MiFruverApp());
}

class MiFruverApp extends StatelessWidget {
  const MiFruverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mi Fruver POS',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const LoginScreen(),
    );
  }
}
