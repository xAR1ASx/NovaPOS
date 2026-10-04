# NovaPOS 🍍🛒 Edición Especial Fruvers & Minimarkets

**Sistema de Punto de Venta (POS) e Inteligencia de Negocio de alto rendimiento.**

NovaPOS combina una arquitectura local ultrarrápida impulsada por **SQLite (100% offline-first)** con sincronización avanzada en tiempo real usando **Firebase & Cloudinary**. Desarrollado con **Flutter** para Windows y tablets Android.

---

## 🚀 Estado Actual del Proyecto (Versión 1.5.0)

El sistema se encuentra en su versión **1.5.0**, completamente blindado con seguridad nativa, auditoría integral y un módulo de caja y arqueo financiero de alto rendimiento. Modificaciones recientes incluyen:

* **Modo Oscuro Global y Sistema de Temas Dinámico**: Implementación completa de temas Claro y Oscuro para el 100% de la aplicación. Con `ThemeContextExtension` y diseño de contraste óptimo en todas las pantallas (Home, POS, Caja, Inventario, Compras, Mermas, Combos, Reportes Financieros, Historiales, Usuarios y Login por PIN), garantizando legibilidad total sin textos perdidos o ilegibles.
* **Inyección de Capital y Refuerzos de Caja**: Nuevo botón nativo de "INGRESAR DINERO" para registrar aportes, préstamos, inyecciones de socios o bases extras en cualquier momento del turno.
* **Asistente Inteligente de Pago de Pedidos con Fondos Insuficientes**: Si llega un pedido de proveedor (ej. $300.000) y en caja solo hay una base menor (ej. $150.000), el sistema guía al cajero para inyectar el faltante y un colchón opcional, registrando la entrada y la salida en una **única transacción atómica** de SQLite (`registrarIngresoYGasto`) para evitar descuadres o cajas en negativo.
* **Tirilla de Cierre / Arqueo Z Completa y con Firmas**: Rediseño contable formal de la tirilla térmica con:
  * Total facturado del turno.
  * Desglose exacto y segregado por método de pago (Efectivo, Nequi, Daviplata, Tarjeta, Transferencia, Crédito), dividiendo limpiamente los pagos mixtos.
  * Cuadre de efectivo físico: Base inicial (+) Ventas en efectivo (+) Ingresos (-) Gastos (=) Total esperado vs. Real contado y diferencia.
  * Líneas para firma del cajero y del administrador.
* **Impresión Inmediata al Cerrar Turno**: Modal interactivo de confirmación que permite imprimir o reimprimir la tirilla Z con un solo toque desde la pantalla de caja o desde el historial.
* **Sistema de Combos y Ofertas**: Módulo nativo especializado para crear paquetes promocionales (Ej. "Arroz + Aceite" o "Anchetas"). Se venden como un solo ítem en el Punto de Venta, pero el sistema descuenta de forma inteligente y paralela el inventario exacto de cada producto que lo compone.
* **Protección Estricta de Mermas**: El módulo de registro de mermas y desperdicios ha sido blindado y bloqueado exclusivamente para el usuario `ADMIN`.
* **Devolución Parcial de Artículos**: Se puede devolver una fracción o unidad específica de un ticket, regresando el inventario automáticamente y ajustando caja/cartera.
* **Seguridad Estricta de Precios (H-01 Plus)**: El backend intercepta la venta, va a la BD oculta, evalúa las promociones del día y recalcula el importe exacto.
* **Banco de Pruebas Automatizadas (42 Tests)**: Test suite integral verificando el 100% de la lógica de negocio, balanzas, promociones, permisos, cálculo de caja y cierre Z.

---

## 💡 Características Principales

### 👆 1. Punto de Venta (POS) Táctil
* **Lectura de Código de Barras y Balanzas**: Reconocimiento de prefijos 20/21 para balanzas etiquetadoras, cálculo de peso (`WWWWW / 1000 = Kg`) e importe. Compatibilidad con básculas RS-232/USB (COM).
* **Top 12 Favoritos de Acceso Rápido**: Accesos táctiles en grilla superior.
* **Promociones y Días de Plaza**: Motor potente de descuentos (porcentuales o fijos) programados por día de la semana, por categoría o por producto (ej. "Martes Campesino").
* **Multi-ticket & Pagos Mixtos**: Ventas en espera ilimitadas y soporte nativo para fraccionar un pago entre Efectivo y Digital (Nequi/Tarjeta).

### 📦 2. Inventario, Mermas y Nube
* **Catálogo Maestro**: Precarga de referencias con PLU y conectividad a Cloudinary para fotos.
* **Módulo de Mermas Inteligente**: Registro de pérdida de producto (maduración, avería, consumo). Permite tomar peso directo de la balanza, afecta el costo en la contabilidad y sincroniza a la nube.
* **Recuperación Ante Desastres**: Si se rompe una tablet o PC, instalar la app en una nueva descarga automáticamente todo en 1 minuto (`_descargaInicial`).

### 🛡️ 3. Seguridad y Auditoría
* **Bloqueo Anti-Fuerza Bruta**: Bloquea y registra intentos fallidos de PIN.
* **Licencias Anti-Evasión**: Fallo seguro (Fail Closed). Evita manipulaciones de reloj del sistema.
* **Gestión de Permisos**: Control estricto; los cajeros no pueden ver utilidades, anular ventas globales ni alterar la configuración maestra del negocio.

---

## 💻 Requisitos de Entorno y Periféricos

| Periférico / Servicio | Compatibilidad |
|-----------------------|----------------|
| **Sistema Operativo** | Windows 10 / 11 (64-bit) o Android 8.0+ (Tablets) |
| **Báscula Serial** | Serial RS-232 o USB (Driver COM / Prolific / CH340 / FTDI) |
| **Balanza Etiquetadora**| EAN-13 (Prefijos 20 y 21) |
| **Impresora Térmica** | Térmica 58mm u 80mm vía USB, Red o Bluetooth (driver Windows POS) |
| **Lector de Códigos** | USB estándar tipo teclado (HID) 1D / 2D |
| **Nube** | Firebase (Firestore Blaze Plan) y Cloudinary |

---

## 🔨 Comandos para Desarrollo y Construcción

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