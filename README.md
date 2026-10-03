# NovaPOS 🍎🛒 Edición Especial Fruvers & Minimarkets

**Sistema de Punto de Venta (POS) e Inteligencia de Negocio de alto rendimiento.**

NovaPOS combina una arquitectura local ultrarrápida impulsada por **SQLite (100% offline-first)** con sincronización avanzada en tiempo real usando **Firebase & Cloudinary**. Desarrollado con **Flutter** para Windows y tablets Android.

---

## 🚀 Estado Actual del Proyecto (Versión 1.3.0)

El sistema se encuentra en su versión **1.3.0**, completamente blindado con seguridad nativa, arquitectura escalable y nuevas funcionalidades financieras. Modificaciones recientes incluyen:

* **Devolución Parcial de Artículos**: Ya no es necesario anular toda la venta; se puede devolver una fracción o unidad específica de un ticket, regresando el inventario automáticamente y ajustando caja/cartera.
* **Desglose de Métodos de Pago en Arqueo**: La tirilla de cierre de caja (Z) ahora detalla de manera exacta los ingresos segregados por Efectivo, Nequi, Daviplata, Tarjeta y Transferencia (incluso separando automáticamente las porciones de los pagos mixtos).
* **Identificadores Visuales de Pago**: El historial de ventas incorpora iconografía y colores dedicados para cada método de pago, permitiendo auditoría visual en milisegundos.
* **Seguridad Estricta de Precios (H-01 Plus)**: Nivel militar. Un CAJERO ya no puede manipular o inyectar descuentos. El backend intercepta la venta, va a la BD oculta, evalúa las promociones del día y recalcula el importe exacto.
* **Arquitectura Offline-First y Multi-Caja**: Funciona de forma totalmente autónoma sin internet. Lee y guarda todo localmente a velocidad nativa. Al volver la conexión, Firebase sube los deltas (mermas, ventas, cierres) en ráfagas.
* **Seguridad Nativa Android (Kiosk Mode)**: Integración con Android Device Admin. Bloquea la tablet en una "Pantalla Roja" impidiendo salir al menú si se incumple el pago de licencia o queda offline 72h.

---

## 📦 Características Principales

### 💻 1. Punto de Venta (POS) Táctil
* **Lectura de Código de Barras y Balanzas**: Reconocimiento de prefijos 20/21 para balanzas etiquetadoras, cálculo de peso (`WWWWW / 1000 = Kg`) e importe. Compatibilidad con básculas RS-232/USB (COM).
* **Top 12 Favoritos de Acceso Rápido**: Accesos táctiles en grilla superior.
* **Promociones y Días de Plaza**: Motor potente de descuentos (porcentuales o fijos) programados por día de la semana, por categoría o por producto (ej. "Martes Campesino").
* **Multi-ticket & Pagos Mixtos**: Ventas en espera ilimitadas y soporte nativo para fraccionar un pago entre Efectivo y Digital (Nequi/Tarjeta).

### 🛒 2. Inventario, Mermas y Nube
* **Catálogo Maestro**: Precarga de referencias con PLU y conectividad a Cloudinary para fotos.
* **Módulo de Mermas Inteligente**: Registro de pérdida de producto (maduración, avería, consumo). Permite tomar peso directo de la balanza, afecta el costo en la contabilidad y sincroniza a la nube.
* **Recuperación Ante Desastres**: Si se rompe una tablet o PC, instalar la app en una nueva descarga automáticamente todo en 1 minuto (`_descargaInicial`).

### 🛡️ 3. Seguridad y Auditoría
* **Bloqueo Anti-Fuerza Bruta**: Bloquea y registra intentos fallidos de PIN.
* **Licencias Anti-Evasión**: Fallo seguro (Fail Closed). Evita manipulaciones de reloj del sistema.
* **Gestión de Permisos**: Control estricto; los cajeros no pueden ver utilidades, anular ventas globales ni alterar la configuración maestra del negocio.

---

## 🖥️ Requisitos de Entorno y Periféricos

| Periférico / Servicio | Compatibilidad |
|-----------------------|----------------|
| **Sistema Operativo** | Windows 10 / 11 (64-bit) o Android 8.0+ (Tablets) |
| **Báscula Serial** | Serial RS-232 o USB (Driver COM / Prolific / CH340 / FTDI) |
| **Balanza Etiquetadora**| EAN-13 (Prefijos 20 y 21) |
| **Impresora Térmica** | Térmica 58mm u 80mm vía USB, Red o Bluetooth (driver Windows POS) |
| **Lector de Códigos** | USB estándar tipo teclado (HID) 1D / 2D |
| **Nube** | Firebase (Firestore Blaze Plan) y Cloudinary |

---

## ⚙️ Comandos para Desarrollo y Construcción

```bash
# Compilar ejecutable Release para Windows
flutter build windows --release

# Compilar instalador final para Windows (Requiere Inno Setup 6)
& "C:\Users\jhona\AppData\Local\Programs\Inno Setup 6\ISCC.exe" .\installer\NovaPOS_setup.iss

# Compilar paquete APK Release para Tablet Android
flutter build apk --release

# Ejecutar banco de pruebas automatizadas (Test Suite)
flutter test
```