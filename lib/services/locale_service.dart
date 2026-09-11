import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';

/// Servicio global de idioma (Español / English).
///
/// Cada pantalla traduce sus textos con su propio diccionario ES->EN y
/// consulta aqui el idioma activo. [setIdioma] persiste la eleccion en la
/// tabla `configuracion` para que sobreviva al reinicio.
class LocaleService extends ChangeNotifier {
  static final LocaleService _inst = LocaleService._internal();
  factory LocaleService() => _inst;
  LocaleService._internal();

  String _idioma = 'es';

  String get idioma => _idioma;

  bool get esIngles => _idioma == 'en';

  bool get esEspanol => _idioma == 'es';

  Future<void> cargarInicial() async {
    try {
      final cfg = await DBHelper().obtenerConfiguracion();
      final v = cfg['idioma'];
      if (v == 'en' || v == 'es') _idioma = v!;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setIdioma(String nuevo) async {
    if (nuevo != 'es' && nuevo != 'en') return;
    if (_idioma == nuevo) {
      notifyListeners();
      return;
    }
    _idioma = nuevo;
    notifyListeners();
    try {
      await DBHelper().guardarConfiguracion('idioma', nuevo);
    } catch (_) {}
  }

  Future<void> cambiarIdioma() async {
    await setIdioma(esIngles ? 'es' : 'en');
  }
}