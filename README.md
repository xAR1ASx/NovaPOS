# NovaPOS 🍍🛒 Edición Especial Fruvers & Minimarkets

**Sistema de Punto de Venta (POS) e Inteligencia de Negocio de alto rendimiento.**

NovaPOS combina una arquitectura local ultrarrápida impulsada por **SQLite (100% offline-first)** con sincronización avanzada en tiempo real usando **Firebase & Cloudinary**. Desarrollado con **Flutter** para Windows y tablets Android.

---

## 🚀 Estado Actual del Proyecto (Versión 1.5.0)

El sistema se encuentra en su versión **1.5.0**, completamente blindado con seguridad nativa, auditoría integral, control estricto de inventarios y un módulo de caja y arqueo financiero de alto rendimiento. Modificaciones y capacidades destacadas:

* **Visualización Inmediata de Stock en Inventario**:
  * Badges dinámicos de color integrados directamente en cada fila de producto sin necesidad de entrar a editarlo.
  * Etiquetas visuales por nivel de existencia: **Sin stock (0 und/Kg)** en rojo, **Stock bajo (≤ 5)** en naranja y **Stock disponible** en verde.
* **Bloqueo Inteligente de Productos Agotados en POS**:
  * Los productos con stock en cero se atenúan automáticamente en escala de grises (50% de opacidad) y muestran la etiqueta destacada **AGOTADO**.
  * Bloqueo total de venta: ni por clic táctil, ni por escaneo de código de barras, ni por entrada con teclado numérico se permite agregar productos sin inventario al carrito, emitiendo una alerta inmediata en pantalla.
  * El control de `permitir_stock_negativo` viene deshabilitado por defecto (migración v12 en SQLite y ajustes).
* **Tirilla de Cierre / Arqueo Z Completa y con Firmas**:
  * Rediseño contable formal de la tirilla térmica (80 mm):
    * **Encabezado**: Razón social del negocio, fecha/hora de emisión y período del turno (`Turno Desde`).
    * **Ventas Totales**: Total facturado global del turno.
    * **Desglose por Métodos de Pago**: Segregación limpia y exacta de montos recibidos en Efectivo, Nequi, Daviplata, Tarjeta, Transferencia y pagos mixtos.
    * **Cuadre de Efectivo en Cajón (Flujo Físico)**: (+) Base inicial, (+) Ventas en efectivo, (+) Ingresos/Refuerzos, (-) Gastos/Salidas, (=) Total esperado en sistema vs. Real contado por cajero y Diferencia (Sobrante/Faltante).
    * **Estado del Cuadre**: Recuadro destacado `ESTADO CUADRE: OK / DESCUADRE`.
    * **Firmas de Auditoría**: Líneas para firma de Cajero y Administrador.
* **Impresión Inmediata y Reimpresión de Cierre**:
  * Modal interactivo al cerrar turno para imprimir la tirilla Z con un solo toque.
  * Historial de cierres para auditar y reimprimir arqueos pasados en cualquier momento.
* **Modo Oscuro Global y Sistema de Temas Dinámico**:
  * Implementación completa de temas Claro y Oscuro para el 100% de la aplicación.
  * Utiliza `ThemeContextExtension` con diseño de alto contraste en todas las pantallas (Home, POS, Caja, Inventario, Compras, Mermas, Combos, Reportes Financieros, Historiales, Usuarios y Login por PIN).
* **Inyección de Capital y Refuerzos de Caja**:
  * Botón nativo de "INGRESAR DINERO" para registrar aportes, préstamos, inyecciones de socios o bases extras en cualquier momento del turno.
* **Asistente Inteligente de Pago de Pedidos con Fondos Insuficientes**:
  * Guía interactiva si llega un pedido o gasto mayor al efectivo disponible en caja, registrando el refuerzo y la salida en una **única transacción atómica** de SQLite (`registrarIngresoYGasto`) para evitar descuadres.
* **Sistema de Combos y Ofertas**:
  * Módulo nativo para crear paquetes promocionales (ej. "Arroz + Aceite"). Se venden como un solo ítem en caja y descuentan simultáneamente el stock individual de cada producto componente.
* **Protección Estricta de Mermas**:
  * Registro de desperdicios/mermas protegido exclusivamente para el usuario `ADMIN`.
* **Devolución Parcial de Artículos**:
  * Permite devolver unidades o fracciones específicas de un ticket, reintegrando inventario y ajustando caja automáticamente.
* **Seguridad Estricta de Precios (H-01 Plus)**:
  * El backend intercepta la venta, valida en la BD oculta, evalúa promociones programadas del día y recalcula el importe exacto.
* **Banco de Pruebas Automatizadas (44 Tests)**:
  * Test suite integral verificando el 100% de la lógica de negocio: balanzas, promociones, permisos, cálculo de caja, arqueo Z y bloqueo de stock cero.

---

## 💡 Características Principales

### 👆 1. Punto de Venta (POS) Táctil
* **Lectura de Código de Barras y Balanzas**: Reconocimiento de prefijos 20/21 para balanzas etiquetadoras, cálculo de peso (`WWWWW / 1000 = Kg`) e importe. Compatibilidad con básculas RS-232/USB (COM).
* **Top 12 Favoritos de Acceso Rápido**: Accesos táctiles en grilla superior.
* **Promociones y Días de Plaza**: Motor potente de descuentos (porcentuales o fijos) programados por día de la semana, por categoría o por producto (ej. "Martes Campesino").
* **Multi-ticket & Pagos Mixtos**: Ventas en espera ilimitadas y soporte nativo para fraccionar un pago entre Efectivo y Digital (Nequi/Tarjeta).

### 📦 2. Inventario, Mermas y Nube
* **Catálogo Maestro y Stock Visual**: Existencias visibles en tiempo real con alertas de stock bajo y agotado.
* **Módulo de Mermas Inteligente**: Registro de pérdida de producto (maduración, avería, consumo). Permite tomar peso directo de la balanza, afecta el costo en contabilidad y sincroniza a la nube.
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

# Ejecutar banco de pruebas automatizadas (Test Suite: 44 tests)
flutter test
```

### 📁 Salida de Compilación e Instaladores

Los instaladores generados se ubican en:
* **Windows**: `installer/output/NovaPOS-Setup-1.5.0.exe`
* **Android**: `installer/output/NovaPOS-1.5.0.apk` (o `build/app/outputs/flutter-apk/app-release.apk`)