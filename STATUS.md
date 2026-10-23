# NovaPOS - Estado del Proyecto y Siguientes Pasos

**Fecha de última actualización:** 2026-10-23
**Versión Actual:** 1.8.0

## 🎯 Hitos Completados
- [x] **v1.8.0**: modo una caja / varias cajas (`modo_sync`), copia diaria comprimida en la nube al cerrar caja (solo la última), equipo vacío que trae la copia sin duplicar nada y paso de una caja a varias. Reglas de Firestore actualizadas y publicadas (23-oct). Auditoría con dos cajas: 4 errores de sincronización y Cloudinary corregidos. 133 tests pasando.
- [x] **v1.7.3**: cajón monedero con orden ESC/POS directa a la impresora y aviso claro (sin base vacía en carpeta temporal) si no se puede abrir la base de datos. 114 tests pasando.
- [x] **v1.7.2 lista para producción**: Identificación multi-caja en tickets, apertura de cajón por software, reimpresión de tickets en historial, CI/CD GitHub Actions para Windows .exe, firma release en Android y detección de VC++ Redistributable. 112 tests pasando.
- [x] **v1.7.1**: inicio de sesión sin internet con PIN cifrado, devoluciones para cajeros y correcciones de auditoría.
- [x] **Centro Financiero v1.6.0**: Panorama, Resultados, Gastos y compras, Rentabilidad, Ventas, Control y Cierres de caja, con informe Excel del período.
- [x] **Cuadre de caja como flujo de efectivo** (base de datos v13): devoluciones/anulaciones de otros turnos o cajas sin descuadre, pagos mixtos exactos, combos y paquetes correctos, gastos con categoría.
- [x] **Sincronización financiera**: movimientos de caja, cierres, devoluciones y combos entre cajas.
- [x] Suite de pruebas: 66 tests pasando.
- [x] **Modo Oscuro Global y Sistema de Temas Unificado**: Soporte total Claro/Oscuro en el 100% de las pantallas y componentes, contraste asegurado y tipografía adaptable.
- [x] **Auditoría Integral y Suite de Pruebas de Caja**: 42 pruebas automatizadas en `flutter test` pasando al 100%.
- [x] **Inyecciones de Dinero en Caja**: Botón nativo de "INGRESAR DINERO" para registrar bases adicionales, préstamos o inyecciones de capital.
- [x] **Asistente Inteligente de Pago de Pedidos con Fondos Insuficientes**: Resuelve el caso de pedidos mayores al saldo en caja mediante la operación atómica `registrarIngresoYGasto` (ingreso + pago en una sola transacción SQLite).
- [x] **Tirilla de Cierre / Arqueo Z Completa**: Desglose contable exacto por método de pago (Efectivo, Nequi, Daviplata, Tarjeta, Transferencia, Crédito), segregación de pagos mixtos sin ambigüedad y firmas de auditoría.
- [x] **Conexión Directa de Impresión de Cierre**: Modal interactivo de éxito que permite imprimir la tirilla Z inmediatamente tras confirmar el cierre.
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

0. **Validar v1.6.0 en hardware real** antes de instalar en clientes: abrir una caja, vender, devolver de un turno anterior, cerrar y revisar el Centro Financiero en Windows y en la tablet, con dos cajas sincronizadas.

1. **Inyección de Administrador Android (Hardware Real)**
   - Esperando que llegue la pantalla Android física.
   - Cuando llegue, conectar la tablet por USB al PC.
   - Ejecutar el comando para activar Kiosk Mode:
     `adb shell dpm set-device-owner com.example.mi_fruver_pos/com.example.mi_fruver_pos.security.NovaDeviceAdminReceiver`

2. **Compilación de Producción (Release)**
   - Ejecutar `flutter build windows --release`.
   - Generar el instalador `.exe` utilizando Inno Setup (`installer/NovaPOS_setup.iss`).
   - Ejecutar `flutter build apk --release` (o `.aab` si se requiere) para las tablets.

3. **Plan de Firebase**: el sistema funciona en el plan gratuito (Spark). Con muchos clientes conviene un proyecto de Firebase por cliente (cada uno con su cuota gratis). Pendiente a futuro: juntar los movimientos de stock dentro de la venta para reducir escrituras.
4. **Alertas de Presupuesto en Google Cloud** (solo si se activa Blaze)
   - Ir a la consola de Google Cloud (asociada al proyecto Firebase "PruebaPOS" o Producción).
   - Configurar Alerta de Facturación de $5 USD (Blaze Plan).
