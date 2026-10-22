/// Interpreta un número escrito por el usuario en formato colombiano:
/// "10.000" -> 10000, "2.550" -> 2550, "1.234,56" -> 1234.56,
/// "2.5" -> 2.5 (punto con 1-2 dígitos es decimal), "1234,56" -> 1234.56.
/// Devuelve null si el texto no es un número válido.
double? parseNumero(String? texto) {
  if (texto == null) return null;
  String t = texto.trim();
  if (t.isEmpty) return null;

  final bool tieneComa = t.contains(',');
  final bool tienePunto = t.contains('.');

  if (tieneComa && tienePunto) {
    // El punto es separador de miles y la coma es decimal.
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (tieneComa) {
    t = t.replaceAll(',', '.');
  } else if (tienePunto) {
    final List<String> partes = t.split('.');
    // "0.750" es decimal: ningún número en miles empieza por cero.
    if (partes.length == 2 && (partes[0] == '0' || partes[0] == '-0' || partes[0].isEmpty)) {
      return double.tryParse(t);
    }
    if (partes.length > 2) {
      // Varios puntos = separador de miles.
      t = t.replaceAll('.', '');
    } else if (partes.length == 2 && partes[1].length == 3) {
      // Un solo punto con 3 dígitos finales ("2.550" -> 2550) es de miles.
      t = t.replaceAll('.', '');
    }
    // De lo contrario ("2.5", "1234.56") se deja como decimal.
  }

  return double.tryParse(t);
}

/// Cantidades (kilos, unidades, stock): el punto y la coma son decimales,
/// "0.750" y "0,750" son 0,75 kg y "1.5" es 1,5. Solo un número con ambos
/// separadores ("1.234,5") se lee como en pesos.
double? parseCantidad(String? texto) {
  if (texto == null) return null;
  final t = texto.trim();
  if (t.isEmpty) return null;
  if (t.contains(',') && t.contains('.')) return parseNumero(t);
  return double.tryParse(t.replaceAll(',', '.'));
}
