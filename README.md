# NovaPOS 🥦 — Edición Especial Fruvers & Minimarkets

**Sistema de Punto de Venta (POS) e Inteligencia de Negocio de alto rendimiento, optimizado para fruterías, verdulerías y minimarkets.**

NovaPOS combina una arquitectura local ultrarrápida impulsada por **SQLite (100% offline-first)** con sincronización opcional en la nube mediante **Firebase & Cloudinary** para gestión multi-caja, auditoría y control de licencias. Desarrollado con **Flutter** para Windows y tablets Android.

---

## 🚀 Estado Actual del Proyecto (Versión 1.2.0 — Edición Fruver Avanzada)

El sistema se encuentra en su versión **1.2.0**, completamente funcional, blindado con pruebas unitarias automatizadas y optimizado para la operación ágil y pesaje en tiempo real:

* **Base de datos local**: SQLite versión 10 con migración transparente automática (incluye soporte de promociones, días de plaza y balanzas etiquetadoras).
* **Cobertura de pruebas**: **37 tests unitarios automatizados aprobados al 100%** (`flutter test`).
* **Arquitectura Offline-First**: Funciona de forma totalmente autónoma y rápida sin depender de conexión a internet para ventas, cobros, balanza o impresión de tickets.

---

## ✨ Características Principales

### 🛒 1. Punto de Venta (POS) Táctil de Alta Velocidad
* **⭐ Top 12 Favoritos de Acceso Rápido**:
  * Barra superior táctil con los productos de mayor rotación (Tomate, Cebolla, Papa, Plátano, Limón, Aguacate, etc.).
  * **Un solo toque**: Abre de inmediato el pesaje por balanza o añade la unidad al carrito.
  * Pestaña dorada `⭐ FAVORITOS` en la barra de categorías para visualización en grilla completa.
  * Muestra el precio promocional destacado en naranja con icono `🔥` si el producto está en oferta.
  * Atajo interactivo: Mantén presionado cualquier producto en la grilla para marcarlo o desmarcarlo de tus favoritos.
* **🏷️ Balanzas Etiquetadoras con Código de Barras (EAN-13)**:
  * Decodificación automática de etiquetas adhesivas de balanzas pesadoras de fruver y supermercado (**Torrey, CAS, Systel, Dibal, Ishida**).
  * **Prefijo 20 (Peso)**: Extrae el PLU de 5 dígitos y el peso en gramos (`WWWWW / 1000 = Kg`), agregándolo de inmediato al carrito.
  * **Prefijo 21 (Precio / Importe)**: Extrae el PLU de 5 dígitos y el valor total en pesos, calculando la cantidad correspondiente.
  * Notificación visual instantánea al cajero con el peso exacto escaneado.
  * Probador interactivo de códigos en *Ajustes ➔ Hardware* con retroalimentación en vivo.
* **🎯 Motor de Promociones & Días de Plaza (Control Exclusivo del Dueño)**:
  * Acceso protegido por rol: **exclusivo para administradores (`ADMIN`)**, cajeros restringidos.
  * Programación por día de la semana (ej. *Martes Campesino 10% en Verduras*, *Miércoles de Cosecha 15% en Frutas*).
  * **Interruptor "Forzar HOY"**: Permite al dueño activar promociones relámpago de inmediato cualquier día para rotar producto perecedero sin alterar la configuración del calendario.
  * Descuentos en porcentaje (`%`) o monto fijo (`$`), aplicables a categorías completas, productos específicos o toda la tienda.
  * **Experiencia visual en POS**: Banner superior de promociones del día, etiquetas `🔥 -X%`, precio regular tachado, cálculo en tiempo real de ahorros en el carrito (`🔥 Ahorro Días de Plaza: -$X.XXX`) y desglose en la tirilla térmica impresa.
* **Cobro con Pagos Mixtos**:
  * Permite cobrar ventas combinando múltiples métodos (ej. parte en Efectivo y el resto por Nequi, Daviplata o Tarjeta/Datafono).
  * Apertura inteligente del cajón monedero: solo se dispara si la transacción involucró efectivo.
* **Pesaje en Tiempo Real (Balanza Serial USB)**:
  * Compatible con básculas de conexión serial (USB→COM / RS-232) mediante filtrado de paquetes ASCII continuo y STX/ETX.
  * Modal interactivo de pesaje con detección de peso estable y simulación en caso de básculas no conectadas.
* **Lector de Código de Barras Instantáneo**:
  * Detección automática por emulación de teclado (HID) sin importar la marca del escáner.
* **Ventas en Espera (Multi-ticket)**:
  * Permite pausar una venta y atender al siguiente cliente en fila sin perder los productos marcados.

---

### 📦 2. Catálogo Maestro y Control de Inventario
* **Catálogo Maestro Fruver Colombia (~120 Referencias con Fotos)**:
  * Precarga automática al primer inicio de la app o a demanda con un solo clic.
  * Incluye frutas, verduras, tubérculos, hierbas aromáticas, lácteos y abarrotes con códigos PLU colombianos oficiales, estimación de costos y precios sugeridos.
* **Módulo de Mermas y Bajas de Inventario**:
  * Bitácora diaria de producto perecedero dado de baja (fruta podrida, madura, golpeada, vencida o degustación).
  * Conexión directa con la balanza para pesar el desperdicio.
  * **Impacto real en el P&L**: Descuenta las mermas directamente del Estado de Resultados para obtener la **Utilidad Neta Real**.
* **Gestión de Presentaciones y Packs**:
  * Venta por kilogramo, gramos, unidades sueltas o canastillas/bultos enteros.
* **Stock Negativo Configurable**:
  * Interruptor en Ajustes para permitir seguir facturando rápidamente aunque no se haya ingresado la compra física del día.

---

### 🚚 3. Recepción Inteligente de Mercancía (Compras)
* **Diseñado para la Central de Abastos**:
  * Entrada rápida por número de bultos o canastillas y peso promedio por bulto.
  * Cálculo dinámico de costo por kilo y recálculo automático del precio de venta según el margen de ganancia deseado (%).
  * Cuadre rápido contra el total de la factura física en papel del proveedor.

---

### 📊 4. Inteligencia de Negocio y Exportación a Excel
* **Estado de Resultados (P&L)**:
  * Comparativo en vivo: Hoy, Mes y Año.
  * Ventas Brutas (-) Costos (-) Gastos Operativos (-) Mermas (=) **Utilidad Neta**.
* **Exportación Completa a Microsoft Excel (.xlsx)**:
  * Botón directo en la barra superior de Reportes e Inventario.
  * Formato contable con cabeceras estilizadas y cálculos de márgenes.
  * Genera reportes de:
    1. *Inventario Valorizado al Costo y Venta*.
    2. *Ventas Detalladas Ítem por Ítem*.
    3. *Estado de Resultados y Balances*.
    4. *Historial de Mermas y Pérdidas*.
    5. *Compras a Proveedores*.
  * **Integración con Windows**: Botón *"ABRIR CARPETA"* que resalta automáticamente el archivo generado en el Explorador de Windows (`Documentos/NovaPOS_Reportes/`).

---

### 💾 5. Seguridad y Copias de Respaldo Automáticas
* **Backups Automáticos Locales**:
  * La base de datos se respalda automáticamente en `Documentos/NovaPOS_Backups/` en cada cierre de caja o apertura del sistema.
  * Rotación inteligente de copias (conserva las últimas 3 versiones para proteger el almacenamiento).
  * Opciones de exportación manual a memorias USB y restauración con 1 clic.
* **Control de Usuarios y Roles**:
  * Login mediante PIN individual.
  * Perfil **ADMIN** (acceso total, auditoría, márgenes, promociones y configuración).
  * Perfil **CAJERO** (restringido únicamente al cobro y caja, sin acceso a costos, utilidades ni promociones).
* **Tirilla Térmica Personalizada para Colombia**:
  * Soporte de impresión directa en impresoras de 58 mm y 80 mm (Epson, Xprinter, Hasar, etc.).
  * Encabezado con Nombre del negocio, NIT, Régimen (*No responsable de IVA / Común*), Dirección, Teléfono, Ciudad, pie de ticket y leyenda DIAN.
  * Desglose destacado del ahorro obtenido por promociones y días de plaza.
  * Función de *Imprimir Ticket de Prueba*.

---

## 🛠️ Requisitos de Hardware y Entorno

| Dispositivo / Periférico | Compatibilidad |
|--------------------------|----------------|
| **Sistema Operativo** | Windows 10 / Windows 11 (64-bit) o Android 8.0+ (Tablets) |
| **Báscula / Balanza Serial** | Serial RS-232 o USB (Driver COM / Prolific / CH340 / FTDI) |
| **Balanza Etiquetadora** | EAN-13 (Prefijos 20 y 21 para peso e importe con código PLU) |
| **Impresora Térmica** | Térmica 58mm u 80mm vía USB, Red o Bluetooth (driver Windows) |
| **Cajón Monedero** | Conexión RJ11 a la impresora térmica (apertura automática) |
| **Lector de Códigos** | USB estándar tipo teclado (HID) 1D / 2D |
| **Conexión a Internet** | Opcional. No se requiere para operar en local (100% Offline-First). |

---

## 📋 Tareas Pendientes para Futura Expansión (Fase 2)

Las siguientes funcionalidades quedaron acordadas y proyectadas para implementarse en la siguiente etapa de crecimiento del negocio:

1. **📲 1. Envío Automático del Cierre Diario por WhatsApp al Dueño**:
   * Botón al momento de cerrar la caja que genera un resumen financiero listo para enviar al WhatsApp del propietario: *Ventas totales, Efectivo en cajón, Recaudos Nequi/Daviplata, Gastos del día y Pérdidas por Mermas*.
2. **🌐 2. Panel Web / App Móvil Remoto para el Propietario (Dashboard)**:
   * Tablero de control remoto en tiempo real para que el dueño consulte las ventas, movimientos de caja e inventario desde su teléfono celular fuera del negocio (utilizando la sincronización de Firebase).
3. **🧪 3. Banco de Pruebas Físico de Periféricos (Hardware Bench)**:
   * Calibración final en sitio con los modelos físicos específicos de balanza serial e impresora térmica instalados en el local comercial.
4. **🧾 4. Integración Facturación Electrónica DIAN**:
   * Módulo opcional para emisión de documentos equivalentes electrónicos (POS electrónico DIAN) mediante proveedor tecnológico para cuando el fruver supere los topes tributarios.

---

## 🧑‍💻 Comandos para Desarrollo y Mantenimiento

```bash
# Instalar dependencias
flutter pub get

# Ejecutar banco de pruebas automatizadas (37 tests)
flutter test

# Verificar análisis estático de código
flutter analyze

# Ejecutar la aplicación en modo desarrollo (Windows)
flutter run -d windows

# Compilar ejecutable Release para Windows
flutter build windows --release

# Compilar instalador final para Windows (PowerShell con Inno Setup 6)
& "C:\Users\jhona\AppData\Local\Programs\Inno Setup 6\ISCC.exe" .\installer\NovaPOS_setup.iss

# Compilar paquete APK Release para Tablet Android
flutter build apk --release
```

---

**NovaPOS** · *Tecnología ágil, robusta y confiable para el comercio colombiano.*