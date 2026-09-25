import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../database/db_helper.dart';

class AutoBackupService {
  AutoBackupService._();
  static final AutoBackupService _instance = AutoBackupService._();
  factory AutoBackupService() => _instance;

  static const String carpetaBackupsNombre = 'NovaPOS_Backups';
  static const int defaultMaxArchivos = 3;

  /// Obtiene la carpeta oficial de backups dentro de Documentos del usuario
  Future<Directory> obtenerCarpetaBackups() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(join(docsDir.path, carpetaBackupsNombre));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Obtiene un resumen del estado actual de las copias automáticas
  Future<Map<String, dynamic>> obtenerEstadoBackups() async {
    try {
      final dir = await obtenerCarpetaBackups();
      final archivos = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList();

      archivos.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

      int bytesTotales = 0;
      for (final a in archivos) {
        bytesTotales += a.lengthSync();
      }

      final ultimoArchivo = archivos.isNotEmpty ? archivos.first : null;
      String? fechaUltimo;
      if (ultimoArchivo != null) {
        fechaUltimo = DateFormat('dd/MM/yyyy hh:mm a').format(
          ultimoArchivo.lastModifiedSync(),
        );
      }

      final config = await DBHelper().obtenerConfiguracion();
      final activo = (config['backup_auto_activo'] ?? '1') == '1';
      final frecuencia = config['backup_auto_frecuencia'] ?? 'cierre_caja';
      final maxArchivos = int.tryParse(config['backup_max_archivos'] ?? '3') ??
          defaultMaxArchivos;

      return {
        'rutaCarpeta': dir.path,
        'totalArchivos': archivos.length,
        'tamanoTotalMb': (bytesTotales / (1024 * 1024)).toStringAsFixed(2),
        'ultimoBackup': fechaUltimo,
        'activo': activo,
        'frecuencia': frecuencia,
        'maxArchivos': maxArchivos,
        'archivos': archivos.map((f) {
          final tamKb = (f.lengthSync() / 1024).toStringAsFixed(1);
          final fecha = DateFormat('dd/MM/yyyy hh:mm a').format(
            f.lastModifiedSync(),
          );
          return {
            'path': f.path,
            'nombre': basename(f.path),
            'fecha': fecha,
            'tamano': '$tamKb KB',
          };
        }).toList(),
      };
    } catch (e) {
      debugPrint('Error obteniendo estado de backups: $e');
      return {
        'rutaCarpeta': '',
        'totalArchivos': 0,
        'tamanoTotalMb': '0.00',
        'ultimoBackup': null,
        'activo': true,
        'frecuencia': 'cierre_caja',
        'maxArchivos': defaultMaxArchivos,
        'archivos': [],
      };
    }
  }

  /// Ejecuta el respaldo automático si las condiciones de frecuencia se cumplen.
  /// [motivo]: 'cierre_caja', 'inicio_app', o 'manual'
  Future<bool> ejecutarBackupSiCorresponde({
    String motivo = 'manual',
    bool forzar = false,
  }) async {
    try {
      final config = await DBHelper().obtenerConfiguracion();
      final activo = (config['backup_auto_activo'] ?? '1') == '1';
      final frecuencia = config['backup_auto_frecuencia'] ?? 'cierre_caja';
      final maxArchivos = int.tryParse(config['backup_max_archivos'] ?? '3') ??
          defaultMaxArchivos;

      if (!forzar) {
        if (!activo) return false;

        if (frecuencia == 'semanal') {
          final ultimaFechaStr = config['ultimo_backup_auto_fecha'];
          if (ultimaFechaStr != null && ultimaFechaStr.isNotEmpty) {
            final ultima = DateTime.tryParse(ultimaFechaStr);
            if (ultima != null &&
                DateTime.now().difference(ultima).inDays < 7) {
              return false; // Aún no han pasado 7 días
            }
          }
        } else if (frecuencia == 'cierre_caja') {
          if (motivo != 'cierre_caja') {
            return false; // Solo se dispara en el cierre de caja
          }
        }
      }

      // Proceder a realizar el backup
      final dir = await obtenerCarpetaBackups();
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final nombreArchivo = 'NovaPOS_AutoBackup_$timestamp.db';
      final rutaDestino = join(dir.path, nombreArchivo);

      final ok = await DBHelper().exportarBackup(rutaDestino);
      if (!ok) {
        debugPrint('Fallo al exportar backup automático');
        return false;
      }

      // Guardar fecha en configuración
      await DBHelper().guardarConfiguracion(
        'ultimo_backup_auto_fecha',
        DateTime.now().toIso8601String(),
      );

      // Rotación de archivos: Eliminar los más viejos para no llenar el disco
      await _purgarCopiasAntiguas(dir, maxArchivos);

      debugPrint('✅ Backup automático generado con éxito: $nombreArchivo');
      return true;
    } catch (e) {
      debugPrint('Error en backup automático: $e');
      return false;
    }
  }

  /// Elimina los archivos de backup que superen el límite configurado
  /// para garantizar que nunca haya acumulación excesiva de archivos.
  Future<void> _purgarCopiasAntiguas(Directory dir, int maxArchivos) async {
    try {
      final archivos = dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              basename(f.path).startsWith('NovaPOS_AutoBackup_') &&
              f.path.endsWith('.db'))
          .toList();

      if (archivos.length <= maxArchivos) return;

      // Ordenar de más reciente a más antiguo
      archivos.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

      // Eliminar los que sobrepasen el cupo permitido
      for (int i = maxArchivos; i < archivos.length; i++) {
        try {
          await archivos[i].delete();
          debugPrint('🗑️ Backup antiguo purgado: ${basename(archivos[i].path)}');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error purgando backups antiguos: $e');
    }
  }

  /// Abre la carpeta de backups en el Explorador de Windows
  Future<void> abrirCarpetaEnExplorador() async {
    try {
      final dir = await obtenerCarpetaBackups();
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [dir.path]);
      }
    } catch (e) {
      debugPrint('Error abriendo carpeta de backups: $e');
    }
  }
}
