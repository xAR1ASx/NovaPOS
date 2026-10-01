/// Servicio de decodificación para códigos de barras emitidos por balanzas
/// pesadoras y etiquetadoras (EAN-13 de peso variable o precio variable).
///
/// Compatible con balanzas comerciales como Torrey, Dibal, Systel, CAS, Toledo, etc.
/// Estructuras estándar soportadas (13 dígitos):
///   - Formato por Peso (prefijo habitual 20, 28, 02):
///       PP CCCCC WWWWW C
///       PP = Prefijo (ej. 20)
///       CCCCC = Código PLU del producto (ej. 00101 -> 101)
///       WWWWW = Peso en gramos (ej. 01250 -> 1.250 Kg)
///       C = Dígito de control EAN-13
///   - Formato por Importe / Precio (prefijo habitual 21):
///       PP CCCCC PPPPP C
///       PP = Prefijo (ej. 21)
///       CCCCC = Código PLU del producto (ej. 00101 -> 101)
///       PPPPP = Total en pesos (ej. 05400 -> $5,400)
///       C = Dígito de control EAN-13
class BalanzaEtiquetaResultado {
  final bool esValido;
  final String tipo; // 'PESO' o 'PRECIO'
  final String plu; // PLU normalizado sin ceros a la izquierda (ej. "101")
  final String plu5; // PLU en 5 dígitos con ceros (ej. "00101")
  final String plu4; // PLU en 4 dígitos (ej. "0101")
  final double pesoKg; // Peso interpretado en Kilogramos (ej. 1.250)
  final double precioTotal; // Total interpretado en pesos (ej. 5400.0)
  final String codigoOriginal;
  final bool checksumValido;
  final String? error;

  const BalanzaEtiquetaResultado({
    required this.esValido,
    this.tipo = '',
    this.plu = '',
    this.plu5 = '',
    this.plu4 = '',
    this.pesoKg = 0.0,
    this.precioTotal = 0.0,
    this.codigoOriginal = '',
    this.checksumValido = false,
    this.error,
  });

  factory BalanzaEtiquetaResultado.invalido(String codigo, [String? error]) {
    return BalanzaEtiquetaResultado(
      esValido: false,
      codigoOriginal: codigo,
      error: error ?? 'Código no corresponde a una balanza etiquetadora',
    );
  }

  @override
  String toString() {
    if (!esValido) return 'BalanzaEtiquetaResultado.invalido($error)';
    if (tipo == 'PESO') {
      return 'BalanzaEtiquetaResultado(PESO, PLU: $plu, Peso: ${pesoKg.toStringAsFixed(3)} Kg, original: $codigoOriginal)';
    } else {
      return 'BalanzaEtiquetaResultado(PRECIO, PLU: $plu, Total: \$$precioTotal, original: $codigoOriginal)';
    }
  }
}

class BalanzaBarcodeService {
  static const String defaultPrefijoPeso = '20';
  static const String defaultPrefijoPrecio = '21';

  /// Valida y calcula el dígito verificador estándar EAN-13.
  static int calcularEan13Checksum(String primeros12Digitos) {
    if (primeros12Digitos.length < 12) return -1;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int d = int.tryParse(primeros12Digitos[i]) ?? 0;
      sum += (i % 2 == 0) ? d : (d * 3);
    }
    return (10 - (sum % 10)) % 10;
  }

  /// Verifica si el dígito de control de un EAN-13 de 13 dígitos es matemáticamente correcto.
  static bool validarEan13Checksum(String ean13) {
    if (ean13.length != 13 || int.tryParse(ean13) == null) return false;
    final digitoEsperado = calcularEan13Checksum(ean13.substring(0, 12));
    final digitoReal = int.tryParse(ean13[12]);
    return digitoEsperado == digitoReal;
  }

  /// Determina si una cadena preliminar parece ser un código de balanza
  static bool esCodigoBalanzaEtiquetadora(
    String codigo, {
    Map<String, String>? config,
  }) {
    final limpio = codigo.trim();
    if (limpio.length != 12 && limpio.length != 13) return false;
    if (int.tryParse(limpio) == null) return false;

    final prefijoPeso = (config?['balanza_etiqueta_prefijo_peso'] ?? defaultPrefijoPeso).trim();
    final prefijoPrecio = (config?['balanza_etiqueta_prefijo_precio'] ?? defaultPrefijoPrecio).trim();

    return limpio.startsWith(prefijoPeso) ||
        limpio.startsWith(prefijoPrecio) ||
        limpio.startsWith('28') ||
        limpio.startsWith('02');
  }

  /// Parsea un código de barras de 12 o 13 dígitos emitido por una balanza.
  /// Si el código no es de balanza o tiene formato incorrecto, devuelve [BalanzaEtiquetaResultado.invalido].
  static BalanzaEtiquetaResultado parsearCodigo(
    String rawCodigo, {
    Map<String, String>? config,
  }) {
    // 0. Revisar si la función está deshabilitada por configuración
    if (config != null && config['balanza_etiqueta_activa'] == '0') {
      return BalanzaEtiquetaResultado.invalido(
        rawCodigo,
        'La lectura de etiquetas de balanza está desactivada',
      );
    }

    final limpio = rawCodigo.trim();

    // Longitud esperada: 13 dígitos estándar (o 12 si el escáner omitió el checksum)
    if (limpio.length != 12 && limpio.length != 13) {
      return BalanzaEtiquetaResultado.invalido(
        rawCodigo,
        'Longitud debe ser de 12 o 13 dígitos numéricos',
      );
    }

    if (int.tryParse(limpio) == null) {
      return BalanzaEtiquetaResultado.invalido(
        rawCodigo,
        'El código debe contener únicamente números',
      );
    }

    final prefijoPeso = (config?['balanza_etiqueta_prefijo_peso'] ?? defaultPrefijoPeso).trim();
    final prefijoPrecio = (config?['balanza_etiqueta_prefijo_precio'] ?? defaultPrefijoPrecio).trim();

    // Determinar si es tipo PESO o tipo PRECIO
    bool esPeso = false;
    bool esPrecio = false;

    if (limpio.startsWith(prefijoPeso) || limpio.startsWith('28') || limpio.startsWith('02')) {
      esPeso = true;
    } else if (limpio.startsWith(prefijoPrecio)) {
      esPrecio = true;
    }

    if (!esPeso && !esPrecio) {
      return BalanzaEtiquetaResultado.invalido(
        rawCodigo,
        'El prefijo no coincide con los prefijos configurados de balanza ($prefijoPeso / $prefijoPrecio)',
      );
    }

    // Extracción de componentes
    // Índice 0..1: Prefijo (2 dígitos)
    // Índice 2..6: PLU de 5 dígitos (ej. 00101)
    // Índice 2..5: PLU de 4 dígitos (ej. 0101)
    // Índice 7..11: Valor numérico de 5 dígitos (gramos o importe)
    final plu5 = limpio.substring(2, 7);
    final plu4 = limpio.substring(2, 6);
    String pluLimpio = plu5.replaceFirst(RegExp(r'^0+'), '');
    if (pluLimpio.isEmpty) {
      pluLimpio = '0';
    }

    final valorStr = limpio.substring(7, 12);
    final valorInt = int.tryParse(valorStr) ?? 0;

    if (valorInt <= 0) {
      return BalanzaEtiquetaResultado.invalido(
        rawCodigo,
        'El peso o precio contenido en la etiqueta es cero o inválido',
      );
    }

    final bool checksumOk = (limpio.length == 13)
        ? validarEan13Checksum(limpio)
        : true;

    if (esPeso) {
      // 5 dígitos representan gramos con 3 decimales en Kg (ej. 01250 -> 1.250 Kg)
      final pesoKg = valorInt / 1000.0;
      if (pesoKg > 150.0) {
        return BalanzaEtiquetaResultado.invalido(
          rawCodigo,
          'Peso fuera de rango comercial ($pesoKg Kg)',
        );
      }

      return BalanzaEtiquetaResultado(
        esValido: true,
        tipo: 'PESO',
        plu: pluLimpio,
        plu5: plu5,
        plu4: plu4,
        pesoKg: pesoKg,
        precioTotal: 0.0,
        codigoOriginal: limpio,
        checksumValido: checksumOk,
      );
    } else {
      // PRECIO: 5 dígitos representan el valor total en pesos (ej. 05400 -> $5,400)
      final precio = valorInt.toDouble();

      return BalanzaEtiquetaResultado(
        esValido: true,
        tipo: 'PRECIO',
        plu: pluLimpio,
        plu5: plu5,
        plu4: plu4,
        pesoKg: 0.0,
        precioTotal: precio,
        codigoOriginal: limpio,
        checksumValido: checksumOk,
      );
    }
  }

  /// Generador utilitario para crear códigos de prueba / etiquetas de simulación.
  static String generarCodigoEjemplo({
    String prefijo = defaultPrefijoPeso,
    required String plu,
    required double valor,
    bool esPeso = true,
  }) {
    final prefijoNorm = prefijo.padLeft(2, '0').substring(0, 2);
    final pluNorm = plu.padLeft(5, '0').substring(plu.length > 5 ? plu.length - 5 : 0).padLeft(5, '0');
    final int valorInt = esPeso ? (valor * 1000).round() : valor.round();
    final valorNorm = valorInt.toString().padLeft(5, '0').substring(0, 5);

    final cuerpo12 = '$prefijoNorm$pluNorm$valorNorm';
    final check = calcularEan13Checksum(cuerpo12);
    return '$cuerpo12$check';
  }
}
