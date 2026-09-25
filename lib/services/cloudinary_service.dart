import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';

/// Servicio para subir fotos a Cloudinary usando un Upload Preset Unsigned
/// (Sin exponer llaves privadas, sin requerir tarjeta de crédito, y organizando
/// por carpetas según el negocioId del cliente).
class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._();
  factory CloudinaryService() => _instance;
  CloudinaryService._();

  // Valores predeterminados vinculados con la cuenta oficial NovaPOS
  static const String defaultCloudName = 'v6xzaqu8';
  static const String defaultUploadPreset = 'novapos_preset';

  Future<String> obtenerCloudName() async {
    final cfg = await DBHelper().obtenerConfiguracion();
    final val = (cfg['cloudinary_cloud_name'] ?? '').toString().trim();
    return val.isNotEmpty ? val : defaultCloudName;
  }

  Future<String> obtenerUploadPreset() async {
    final cfg = await DBHelper().obtenerConfiguracion();
    final val = (cfg['cloudinary_upload_preset'] ?? '').toString().trim();
    return val.isNotEmpty ? val : defaultUploadPreset;
  }

  Future<void> guardarCredenciales({
    required String cloudName,
    required String uploadPreset,
  }) async {
    await DBHelper().guardarConfiguracion('cloudinary_cloud_name', cloudName.trim());
    await DBHelper().guardarConfiguracion('cloudinary_upload_preset', uploadPreset.trim());
  }

  /// Sube la imagen a Cloudinary en la carpeta `negocios/<negocioId>/productos/`
  /// con identificador público igual al uuid del producto.
  /// Retorna la URL HTTPS segura generada por Cloudinary CDN.
  Future<String?> subirImagen({
    required String localPath,
    required String negocioId,
    required String productoUuid,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) return null;

    final cloudName = await obtenerCloudName();
    final uploadPreset = await obtenerUploadPreset();

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url);

    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = 'negocios/$negocioId/productos';
    request.fields['public_id'] = productoUuid;

    request.files.add(await http.MultipartFile.fromPath('file', localPath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = data['secure_url'] as String?;
      return secureUrl;
    } else {
      debugPrint('Cloudinary upload error (${response.statusCode}): ${response.body}');
      throw Exception('Cloudinary error: ${response.statusCode} - ${response.body}');
    }
  }
}
