# NovaPOS 🥦 — Edición Especial Fruvers & Minimarkets

**Sistema de Punto de Venta (POS) e Inteligencia de Negocio de alto rendimiento, optimizado para fruterías, verdulerías y minimarkets.**

NovaPOS combina una arquitectura local ultrarrápida impulsada por **SQLite (100% offline-first)** con sincronización en la nube mediante **Firebase & Cloudinary** para gestión multi-caja, auditoría y control de licencias. Desarrollado con **Flutter** para Windows y tablets Android.

---

## 🚀 Estado Actual del Proyecto (Versión 1.1.0 — Piloto Listo)

El sistema se encuentra en su versión **1.1.0**, completamente funcional, blindado con pruebas unitarias automatizadas y con su instalador oficial de Windows compilado:

* **Instalador generado**: `installer/output/NovaPOS-Setup-1.1.0.exe` (22.2 MB).
* **Base de datos local**: SQLite versión 9 con migración transparente automática.
* **Cobertura de pruebas**: 23 tests unitarios automatizados aprobados al 100%.

---

## ✨ Características Principales

### 🛒 1. Punto de Venta (POS) Táctil de Alta Velocidad
* **⭐ Top 12 Favoritos de Acceso Rápido**:
  * Barra superior táctil con los productos de mayor rotación (Tomate, Cebolla, Papa, Plátano, Limón, Aguacate, etc.).
  * **Un solo toque**: Abre de inmediato el pesaje por balanza o añade la unidad al carrito.
  * Pestaña dorada `⭐ FAVORITOS` en la barra de categorías para visualización en grilla completa.
  * Atajo interactivo: Mantén presionado cualquier producto en la grilla para marcarlo o desmarcarlo de tus favoritos.
* **Cobro con Pagos Mixtos**:
  * Permite cobrar ventas combinando múltiples métodos (ej. parte en Efectivo y el resto por Nequi, Daviplata o Tarjeta/Datafono).
  * Apertura inteligente del cajón monedero: solo se dispara si la transacción involucró efectivo.
* **Pesaje en Tiempo Real (Balanza)**:
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
  * Perfil **ADMIN** (acceso total, auditoría, márgenes y configuración).
  * Perfil **CAJERO** (restringido únicamente al cobro y caja, sin acceso a costos ni utilidades).
* **Tirilla Térmica Personalizada para Colombia**:
  * Soporte de impresión directa en impresoras de 58 mm y 80 mm (Epson, Xprinter, Hasar, etc.).
  * Encabezado con Nombre del negocio, NIT, Régimen (*No responsable de IVA / Común*), Dirección, Teléfono, Ciudad, pie de ticket y leyenda DIAN.
  * Función de *Imprimir Ticket de Prueba*.

---

## 🛠️ Requisitos de Hardware y Entorno

| Dispositivo / Periférico | Compatibilidad |
|--------------------------|----------------|
| **Sistema Operativo** | Windows 10 / Windows 11 (64-bit) o Android 8.0+ (Tablets) |
| **Báscula / Balanza** | Serial RS-232 o USB (Driver COM / Prolific / CH340 / FTDI) |
| **Impresora Térmica** | Térmica 58mm u 80mm vía USB, Red o Bluetooth (driver Windows) |
| **Cajón Monedero** | Conexión RJ11 a la impresora térmica (apertura automática) |
| **Lector de Códigos** | USB estándar tipo teclado (HID) 1D / 2D |
| **Conexión a Internet** | Opcional para operar. Se requiere únicamente para login inicial y sincronización en la nube. |

---

## 💻 Guía de Despliegue para Prueba Piloto

Los instaladores listos para producción se encuentran en la carpeta `installer/output/`:
* **PC Windows**: `NovaPOS-Setup-1.1.0.exe` (~22 MB)
* **Tablet Android**: `NovaPOS-Tablet-1.1.0.apk` (~71 MB)

---

### 🖥️ Caja 1: Instalación en el Computador Principal (Windows)
1. Copia `NovaPOS-Setup-1.1.0.exe` a una memoria USB y conéctala al PC del fruver.
2. Ejecuta el instalador: el asistente instalará la aplicación en *Archivos de Programa* y creará el acceso directo en el Escritorio.
3. Abre NovaPOS: el **Catálogo Maestro de ~120 referencias con fotos** se precargará de inmediato.
4. Inicia sesión con la cuenta de administrador.
5. Ve a **Ajustes**:
   * Configura Nombre comercial, NIT, Ciudad, Dirección y Teléfono (aparecerán en el encabezado del ticket).
   * En **Impresora**: selecciona la impresora térmica instalada y pulsa *"Imprimir Ticket de Prueba"*.
   * En **Balanza**: selecciona el puerto COM de la báscula y valida el peso en vivo.
6. En **Gestión de Usuarios**: crea el cajero principal asignándole su nombre y PIN de acceso.

---

### 📱 Caja 2: Instalación en la Tablet (Android)
1. Copia `NovaPOS-Tablet-1.1.0.apk` a la tablet (vía cable USB, WhatsApp Web, Google Drive o tarjeta microSD).
2. Abre el archivo en el explorador de la tablet y pulsa **Instalar** (permite *"Instalar aplicaciones de orígenes desconocidos"* si el sistema lo solicita).
3. Abre NovaPOS e inicia sesión con el **mismo correo del negocio** que se usó en el PC.
4. En **Gestión de Usuarios**: crea el cajero para la tablet con su propio PIN de 4 dígitos.
5. ¡Listo! La interfaz táctil con la barra superior de 12 favoritos está optimizada para venta táctil ultra rápida en orientación horizontal.

---

### ⚡ Sincronización Multi-Caja en Tiempo Real (PC ↔ Tablet)
NovaPOS opera con una arquitectura **Offline-First + Cloud Realtime**:
* **En vivo y automático**: Cuando una caja vende (ej. 2 kg de Tomate), la operación de stock viaja a Firestore y la otra caja descuenta el inventario y refresca sus tarjetas en pantalla en cuestión de milisegundos.
* **Catálogo unificado**: Cualquier cambio de precio o producto nuevo se replica automáticamente en ambos dispositivos.
* **Ventas y reportes consolidados**: El historial y las exportaciones a Excel consolidan las ventas de ambas cajas.
* **Arqueo independiente**: Por diseño de seguridad, cada caja física maneja su propio cajón monedero, base de apertura y cierre de turno individual.
* **Tolerancia a fallos**: Si la conexión a Internet se cae momentáneamente, ambas cajas continúan vendiendo en local sobre SQLite sin detenerse; al reconectar, se sincronizan solas.

---

## 🔮 Roadmap y Posibles Mejoras a Futuro

Para las siguientes etapas después de la inauguración y validación del piloto, se tienen proyectadas las siguientes mejoras de alto impacto:

1. **📲 Envío de Cierre Diario por WhatsApp al Dueño**:
   * Botón al momento de cerrar la caja que genera un enlace directo a WhatsApp (`api.whatsapp.com/send`) con el resumen financiero del turno listo para enviar al dueño: *Ventas totales, Efectivo en cajón, Recaudos Nequi/Daviplata, Gastos del día y Pérdidas por Mermas*.
2. **🏷️ Soporte para Básculas Etiquetadoras con Código de Barras**:
   * Interpretación de códigos de barras generados por balanzas pesadoras (prefijo 20/21 con código de producto y peso/precio embebido en el código de 13 dígitos).
3. **🌐 Panel Web / App Móvil para el Propietario**:
   * Tablero de control remoto para que el dueño consulte las ventas en vivo y el inventario de su fruver desde su teléfono celular sin estar físicamente en el local.
4. **🎯 Promociones y Días Especiales de Plaza**:
   * Motor de descuentos programados (ej. *"Martes de Cítricos 10% OFF"*, *"Miércoles Campesino de Papa y Plátano"*).
5. **🧾 Integración Facturación Electrónica DIAN**:
   * Módulo opcional para emisión de documentos equivalentes electrónicos (POS electrónico DIAN) mediante proveedor tecnológico para fruvers que superen los topes tributarios.

---

## 🧑‍💻 Comandos para Desarrollo y Mantenimiento

```bash
# Instalar dependencias
flutter pub get

# Ejecutar banco de pruebas automatizadas
flutter test

# Verificar análisis estático de código
flutter analyze

# Compilar ejecutable Release para Windows
flutter build windows --release

# Compilar instalador final para Windows (PowerShell con Inno Setup 6)
& "C:\Users\jhona\AppData\Local\Programs\Inno Setup 6\ISCC.exe" .\installer\NovaPOS_setup.iss

# Compilar paquete APK Release para Tablet Android
flutter build apk --release
```

---

**NovaPOS** · *Tecnología ágil, robusta y confiable para el comercio colombiano.*