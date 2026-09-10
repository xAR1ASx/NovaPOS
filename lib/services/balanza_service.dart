import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../database/db_helper.dart';

/// Servicio de balanza por puerto serial (COM en Windows, /dev/tty* en Linux).
/// Compatible con formatos comunes: ASCII continuo, STX...ETX y prefijos P/N.
class BalanzaService {
  static SerialPort? _puerto;
  static bool _leyendo = false;
  static double? _ultimoPesoKg;
  static String _buffer = '';

  static final StreamController<double?> _pesoController =
      StreamController.broadcast();
  static Stream<double?> get pesoStream => _pesoController.stream;

  static bool get estaConectada => _puerto != null && _puerto!.isOpen;

  static List<String> puertosDisponibles() {
    try {
      if (Platform.isWindows || Platform.isLinux) {
        return SerialPort.availablePorts;
      }
    } catch (e) {}
    return [];
  }

  /// Conecta al puerto y arranca la lectura continua.
  static Future<String> conectar() async {
    await desconectar();

    try {
      final config = await DBHelper().obtenerConfiguracion();
      String puerto = config['balanza_puerto'] ?? 'COM1';
      int baudios = int.tryParse(config['balanza_velocidad'] ?? '9600') ?? 9600;

      final port = SerialPort(puerto);
      final ok = port.openRead();
      if (!ok) {
        return 'No se pudo abrir el puerto $puerto';
      }

      final cfg = SerialPortConfig();
      cfg.baudRate = baudios;
      cfg.bits = 8;
      cfg.parity = SerialPortParity.none;
      cfg.stopBits = 1;
      port.config = cfg;
      cfg.dispose();

      _puerto = port;
      _leyendo = true;
      _buffer = '';
      _iniciarLectura();
      return 'Conectado a $puerto ($baudios baudios)';
    } catch (e) {
      return 'Error de conexion: $e';
    }
  }

  static Future<void> desconectar() async {
    _leyendo = false;
    try {
      _puerto?.close();
    } catch (e) {}
    _puerto = null;
    _buffer = '';
  }

  static double? get ultimoPesoKg => _ultimoPesoKg;

  static Future<double?> leerPesoUnaVez({
    Duration espera = const Duration(milliseconds: 800),
  }) async {
    if (!estaConectada) return null;
    _ultimoPesoKg = null;
    await Future.delayed(espera);
    return _ultimoPesoKg;
  }

  static void _iniciarLectura() {
    Future.doWhile(() async {
      if (!_leyendo || _puerto == null) return false;
      try {
        final Uint8List data = _puerto!.read(1024, timeout: 200);
        if (data.isNotEmpty) {
          _procesarChunk(ascii.decode(data, allowInvalid: true));
        }
      } catch (e) {}
      await Future.delayed(const Duration(milliseconds: 100));
      return _leyendo;
    });
  }

  /// Extrae el peso de cualquier formato generico.
  static void _procesarChunk(String chunk) {
    _buffer += chunk;

    // Buscar patron STX (0x02) ... ETX (0x03)
    final stx = _buffer.indexOf('\x02');
    if (stx >= 0) {
      final etx = _buffer.indexOf('\x03', stx);
      if (etx > stx) {
        _extraerPeso(_buffer.substring(stx + 1, etx));
        _buffer = _buffer.substring(etx + 1);
        return;
      }
    }

    if (_buffer.contains(RegExp(r'\d'))) {
      _extraerPeso(_buffer);
      // Conservar el final del buffer por si el peso viene partido
      if (_buffer.length > 60) {
        _buffer = _buffer.substring(_buffer.length - 20);
      }
    }

    if (_buffer.length > 200) _buffer = '';
  }

  static void _extraerPeso(String data) {
    final peso = parsearPeso(data);
    if (peso != null) {
      _ultimoPesoKg = peso;
      _pesoController.add(peso);
    }
  }

  /// Parsea una linea generica de una balanza y devuelve el peso en Kg.
  ///
  /// Acepta formatos ASCII continuo ("001234 g"), paquetes STX (0x02) ... ETX
  /// (0x03) y enteros sin unidad (interpretados como gramos).
  /// Devuelve `null` si no hay un peso valido.
  static double? parsearPeso(String linea) {
    String data = linea;

    // Extraer el contenido entre STX (0x02) y ETX (0x03)
    final stx = data.indexOf('\x02');
    final etx = data.indexOf('\x03');
    if (stx >= 0 && etx > stx) {
      data = data.substring(stx + 1, etx);
    }

    final regex = RegExp(r'(\d{1,7}[.,]\d{1,3}|\d{2,7})\s*(g|kg|Kg|KG)?');
    final matches = regex.allMatches(data);
    if (matches.isEmpty) return null;
    final match = matches.last;

    try {
      String numero = match.group(1) ?? '';
      if (numero.contains(',')) numero = numero.replaceAll(',', '.');
      double valor = double.parse(numero);
      double enKg = (match.group(2) ?? '').toLowerCase() == 'kg'
          ? valor
          : valor / 1000.0;

      // Filtro de ruido: pesos absurdos se ignoran
      if (enKg < 0.001 || enKg > 500) return null;

      return double.parse(enKg.toStringAsFixed(3));
    } catch (e) {
      return null;
    }
  }
}