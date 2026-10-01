# NovaPOS - Estado del Proyecto y Siguientes Pasos

**Fecha de última actualización:** 2026-10-01
**Versión Actual:** 1.2.0

## 🎯 Hitos Completados
- [x] Migración a **Sqflite v10** para compatibilidad con Windows y Android.
- [x] Sincronización **Offline-First** (SQLite -> Firestore) optimizada para Blaze Plan.
- [x] Subida de imágenes a **Cloudinary** segregada por negocioId.
- [x] **Seguridad Nativa Android (Kiosk Mode)**: `LockScreenActivity` y `DeviceAdminReceiver` implementados y listos para inyección ADB.
- [x] **Dead Man's Switch (72h sin internet)**: Fallback para Windows en Dart puro implementado en `license_monitor.dart`.
- [x] **Auditoría de Seguridad Exhaustiva**:
  - [x] C-01: Bloqueo de PIN persistente implementado (Anti-fuerza bruta).
  - [x] C-02: Reglas Firestore blindadas para los campos `financiado`, `estado`, `licencia_fin`.
  - [x] H-01: Anti-fraude de precios añadido a `db_helper.dart` (recalcula total).
  - [x] H-02: Dead Man's Switch falla cerrado si borran SQLite cache.
  - [x] H-03: CAJERO no puede leer perfiles (emails) de ADMIN en Firestore Rules.
  - [x] M-02: Creación de negocios protegida por `NOVAPOS-MASTER-KEY`.
  - [x] M-03: Rechazo de PINs débiles (`123456`, `000000`, etc.).
  - [x] M-04: Tabla `mermas` añadida al ciclo completo de `sync_service.dart`.
  - [x] L-02: Login usa `LicenseMonitor.instance.revisar` para consistencia total.
  - [x] L-03: Archivo `novapos_sesion.json` encriptado (Base64+UTF8).

## ⏳ Tareas Pendientes Inmediatas (Pausa Actual)

1. **Inyección de Administrador Android (Hardware Real)**
   - Esperando que llegue la pantalla Android física.
   - Cuando llegue, conectar la tablet por USB al PC.
   - Ejecutar el comando para activar Kiosk Mode:
     `adb shell dpm set-device-owner com.example.mi_fruver_pos/com.example.mi_fruver_pos.security.NovaDeviceAdminReceiver`

2. **Compilación de Producción (Release)**
   - Ejecutar `flutter build windows --release`.
   - Generar el instalador `.exe` utilizando Inno Setup (`installer/NovaPOS_setup.iss`).
   - Ejecutar `flutter build apk --release` (o `.aab` si se requiere) para las tablets.

3. **Alertas de Presupuesto en Google Cloud**
   - Ir a la consola de Google Cloud (asociada al proyecto Firebase "PruebaPOS" o Producción).
   - Configurar Alerta de Facturación de $5 USD (Blaze Plan).
