# NovaPOS 🥦 — Edición Especial Fruvers & Minimarkets

**Sistema de Punto de Venta (POS) e Inteligencia de Negocio de alto rendimiento.**

NovaPOS combina una arquitectura local ultrarrápida impulsada por **SQLite (100% offline-first)** con sincronización avanzada en tiempo real usando **Firebase & Cloudinary**. Desarrollado con **Flutter** para Windows y tablets Android.

---

## 🚀 Estado Actual del Proyecto (Versión 1.2.1)

El sistema se encuentra en su versión **1.2.1**, completamente blindado con seguridad nativa y arquitectura escalable. Modificaciones recientes incluyen:

* **Modo Oscuro / Claro**: Nueva opción en configuración para cambiar la apariencia de la UI y guardarla localmente.
* **Seguridad Estricta de Precios (H-01 Plus)**: Nivel militar. Un CAJERO ya no puede manipular o inyectar descuentos. El backend intercepta la venta, va a la BD oculta, evalúa las promociones del día y recalcula el importe exacto.
* **Sincronización de Promociones Multi-caja**: Las promociones creadas en la Caja 1 ahora se propagan y aplican instantáneamente en la Caja 2 y Caja 3.
* **Matemáticas de Inventario Perfectas**: Resolución de bugs de tolerancia de punto flotante en básculas (0.001 de margen) y erradicación del "Inventario Fantasma".
* **Arquitectura Offline-First**: Funciona de forma totalmente autónoma sin internet. Lee y guarda todo localmente a velocidad nativa.
* **Sincronización en Tiempo Real (Firebase Blaze)**: Multi-caja instantáneo. Actualiza precios, productos, promociones y ventas entre 3-5 cajas al mismo tiempo en milisegundos.
* **Seguridad Nativa Android (Kiosk Mode)**: Integración con Android Device Admin (Device Owner). Bloquea la tablet en una "Pantalla Roja" impidiendo salir al menú si se incumple el pago de licencia o si queda offline por más de 72h.
* **Copias de Seguridad Ante Desastres**: Si se rompe una tablet o PC, instalar la app en una nueva descarga automáticamente todo en 1 minuto (`_descargaInicial`).

---

## ✨ Características Principales

### 🛒 1. Punto de Venta (POS) Táctil
* **Top 12 Favoritos de Acceso Rápido**: Accesos táctiles en grilla superior.
* **Lectura de Código de Barras y Balanzas**: Reconocimiento de prefijos 20/21 para balanzas etiquetadoras de supermercado, cálculo de peso (`WWWWW / 1000 = Kg`) e importe.
* **Promociones y Días de Plaza**: Motor potente de descuentos programados por día o forzados (`Forzar HOY`).
* **Multi-ticket**: Ventas en espera ilimitadas.

### 📦 2. Inventario y Nube
* **Catálogo Maestro**: Precarga de referencias colombianas con PLU.
* **Módulo de Mermas**: Registro de pérdida de producto y daño. Ahora sincronizado al 100% con Firebase.
* **Sync Inteligente**: Cola de datos offline (`sync_pendientes`). Si se cae el internet, la tienda sigue operando. Al volver la conexión, se suben miles de registros en ráfaga.

### 💾 3. Seguridad de Nube y Dispositivo (Auditoría C/H/M/L)
El sistema ha pasado una estricta auditoría, blindando:
* **Fuerza Bruta**: El PIN se bloquea y persiste en disco tras 3 intentos. Bloquea PINs obvios (`123456`, `000000`).
* **Firebase Rules**: Un cajero no puede leer datos confidenciales del negocio. Nadie puede quitar el flag de `financiado` excepto el dueño de NovaPOS desde la consola de Firebase.
* **Anti-Fraude de Precios**: El servidor local recalcula el total exacto del carrito; rechaza cualquier manipulación local del archivo de base de datos que intente cobrar $0.
* **Licencias Anti-Evasión**: Fallo seguro (Fail Closed). Si un cajero intenta borrar los registros de tiempo de la base de datos para engañar al sistema, se bloquea por "Hackeo de Caché".
* **Creación de Negocios**: Protegida con `NOVAPOS-MASTER-KEY` para evitar bases de datos fantasma.

---

## 🛠️ Requisitos de Hardware y Entorno

| Dispositivo / Periférico | Compatibilidad |
|--------------------------|----------------|
| **Sistema Operativo** | Windows 10 / Windows 11 (64-bit) o Android 8.0+ (Tablets) |
| **Nube** | Firebase (Blaze Plan requerido para tráfico offline-burst) y Cloudinary |
| **Báscula / Balanza Serial** | Serial RS-232 o USB (Driver COM / Prolific / CH340 / FTDI) |
| **Balanza Etiquetadora** | EAN-13 (Prefijos 20 y 21 para peso e importe con código PLU) |
| **Impresora Térmica** | Térmica 58mm u 80mm vía USB, Red o Bluetooth (driver Windows) |
| **Lector de Códigos** | USB estándar tipo teclado (HID) 1D / 2D |

---

## 🧑‍💻 Comandos para Desarrollo y Mantenimiento

```bash
# Ejecutar banco de pruebas automatizadas (37 tests)
flutter test

# Compilar ejecutable Release para Windows
flutter build windows --release

# Compilar instalador final para Windows (PowerShell con Inno Setup 6)
& "C:\Users\jhona\AppData\Local\Programs\Inno Setup 6\ISCC.exe" .\installer\NovaPOS_setup.iss

# Compilar paquete APK Release para Tablet Android
flutter build apk --release
```