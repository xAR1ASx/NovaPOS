# NovaPOS 🥦

**Sistema de Punto de Venta (POS) para fruterías y tiendas de barrio.**

NovaPOS es una aplicación de escritorio para **Windows** construida con
**Flutter**. Combina una base de datos **local en SQLite** (rápida y funcional
sin internet) con **Firebase** (autenticación segura de usuarios y respaldo de
cuentas/licencia en la nube).

---

## ✨ Funcionalidades

- **Ventas rapidas**: busca por nombre, PLU o **código de barras**, agrega al
  carrito y cobra en efectivo o fiado (clientes).
- **Productos por peso (balanza)**: los productos marcados como pesables se
  venden por peso, leyendo el peso en **tiempo real** desde la balanza serial,
  o con ingreso manual/simulado.
- **Lectores de código de barras**: compatible con **cualquier** lector USB
  (HID) — funciona como teclado: escanea en el campo activo y presiona Enter.
- **Impresión de tickets**: ticket PDF en formato 80 mm. Imprime con el diálogo
  del sistema o **directo a la impresora** que elijas (compatible con cualquier
  impresora instalada en Windows: Epson TM, Hasar, Xprinter, etc.).
- **Inventario**: productos, categorías, PLU, código de barras, costo/precio,
  y **carga masiva desde Excel**.
- **Compras**: registro de entradas de mercancía con aumento de stock.
- **Arqueo de caja**: apertura/cierre y movimientos de caja.
- **Reportes**: ventas, totales y utilidades.
- **Clientes y fiados**: cartera de clientes con ventas a crédito.
- **Múltiples cajeros** con roles y permisos.
- **Seguridad real**: el PIN de cada empleado es su contraseña de Firebase
  (mínimo 6 dígitos). Sin PIN en texto plano ni en la base local.

---

## 🖥️ Requisitos

| Requisito | Detalle |
|-----------|---------|
| Sistema operativo | Windows 10/11 (64 bits) |
| Internet | Necesario solo para el **inicio de sesión** y la gestión de usuarios |
| Funcionamiento | Sin internet, la app trabaja con los datos locales ya sincronizados |
| Impresora (opcional) | Cualquier impresora térmica instalada en Windows |
| Balanza (opcional) | Cualquier balanza por puerto serial (COM) |
| Lector de barras (opcional) | Cualquier lector USB tipo teclado (HID) |

---

## 🚀 Puesta en marcha (para desarrollo)

### 1. Clonar e instalar dependencias

```bash
flutter pub get
```

### 2. Configurar Firebase

El proyecto ya incluye la configuración de Firebase necesaria
(`lib/firebase_options.dart` y `android/app/google-services.json`). No se
necesita hacer nada más para compilar y ejecutar la app.

### 3. Servidor

La seguridad y los datos del lado servidor los administra el proveedor del
sistema. El usuario final no necesita configurar nada.

### 4. Compilar y ejecutar

```bash
flutter run -d windows        # desarrollo
flutter build windows --release   # compilación para producción
```

El ejecutable queda en:

```
build\windows\x64\runner\Release\NovaPOS.exe
```

Para distribuirlo, copia **toda la carpeta `Release`** (incluye las DLL de
Firebase, SQLite y libserialport que la app necesita).

### 5. Pruebas

```bash
flutter test        # suite de pruebas unitarias
flutter analyze     # análisis estático de código
```

---

## 🔐 Cómo funciona el acceso

### El PIN es la contraseña

Cada cuenta se crea en **Firebase Authentication** con un contraseña igual al
**PIN del empleado** (siempre **6 dígitos**). La app nunca guarda el PIN en
texto plano ni en la base local.

### Pantalla de login

- **Primer inicio**: debes escribir tu **correo electrónico** y luego el **PIN**
  de 6 dígitos.
- **Inicios siguientes**: la sesión queda guardada en el equipo y basta con
  ingresar **solo el PIN**. Puedes cambiarte de usuario con el enlace
  **"Cambiar"**.
- **Seguridad**: tras **3 intentos fallidos** el login se bloquea **30 segundos**.

### Crear el primer administrador (una sola vez)

> Las cuentas de administrador y de la empresa las crea el **proveedor del
> sistema** cuando instala y habilita el software. El usuario final no necesita
> crear cuentas desde ninguna consola externa.

### Crear empleados (en la app)

El **ADMIN** entra a *Usuarios → Nuevo usuario*: ahí se crea la cuenta de
Firebase y el documento de Firestore automáticamente. Si un empleado olvida su
PIN, el administrador usa **"Recuperar PIN"** (envía un correo de
restablecimiento) y el empleado puede **cambiar su propio PIN** desde
*Configuración → Seguridad → Cambiar mi PIN*.

---

## 👥 Roles y permisos

| Permiso | ADMIN | CAJERO |
|---------|:-----:|:------:|
| Crear/ver ventas | ✅ | ✅ |
| Anular ventas | ✅ | ❌ |
| Abrir/cerrar/movimientos de caja | ✅ | ✅ |
| Inventario (ver/crear/editar/eliminar) | ✅ | ❌ |
| Reportes | ✅ | ❌ |
| Compras (crear/ver) | ✅ | ❌ |
| Clientes (ver/editar) | ✅ | ✅ |
| Eliminar clientes | ✅ | ❌ |
| Configuración general | ✅ | ❌ |
| Gestión de usuarios | ✅ | ❌ |

---

## 🖨️ Impresora

1. Instala el **driver de tu impresora** en Windows (Epson TM, etc.).
2. En la app: **Configuración → Impresora**.
3. Pulsa **"Detectar impresoras"** y elige tu impresora de la lista.
4. Activa **"Impresión directa (sin diálogo)"** para que el ticket se imprima
   automáticamente, sin ventanas. Si está desactivado, se abre el diálogo de
   impresión de Windows.

Formato de ticket: **80 mm térmico** (encabezado con nombre/NIT/dirección del
negocio, lista de productos, total y método de pago).

---

## 📟 Lector de código de barras

No requiere configuración: **cualquier lector USB** que funcione como teclado
escribe el código en el campo activo del POS y presiona Enter, exactamente como
si un cajero tipeara el código.

---

## ⚖️ Balanza

Compatible con balanzas que transmiten por **puerto serial (RS-232 / USB→COM)**.

1. Conecta la balanza y anota el puerto (ej. `COM3`) y los **baudios**.
2. En **Configuración → Balanza**: pulsa **"Detectar puertos"**, elige puerto y
   velocidad (usualmente **9600**).
3. Pulsa **"Probar conexión"**; si el puerto se abre verás el estado.
4. En el POS, al agregar un producto **pesable**, se mostrará el **peso en
   tiempo real** con botón *"Usar peso"*. Si no hay balanza, usa *"Simular
   peso"*.

### Formatos de peso soportados

La app detecta automáticamente el peso en gramos o kilogramos, con o sin
unidad, incluyendo tramas **ASCII continuo** (`001234 g`) y paquetes
**STX (0x02) ... ETX (0x03)**. Pesos fuera del rango 0.001–500 kg se ignoran
(filtro contra ruido).

---

## 🗄️ Datos

- **Local**: SQLite (archivo en el directorio de datos de la aplicación).
  Contiene productos, ventas, compras, clientes, caja y configuración.
- **Nube (Firebase)**: solo cuentas de usuario, roles y datos del negocio
  (nombre/NIT) y licencia. Sin internet no se puede iniciar sesión, pero una vez
  iniciada la app trabaja con el inventario y ventas locales.

---

## 🏗️ Estructura del proyecto

```
lib/
├── main.dart                     # Inicialización (Firebase + SQLite) y app
├── firebase_options.dart         # Configuración de Firebase por plataforma
├── database/db_helper.dart       # Base de datos local SQLite
├── services/
│   ├── pin_auth_service.dart     # Autenticación Firebase (login, cuentas, PIN)
│   ├── session_service.dart      # Usuario en sesión
│   ├── role_permissions.dart     # Permisos por rol
│   ├── permission_service.dart   # Gestión de permisos en memoria
│   ├── sales_service.dart        # Lógica de ventas
│   ├── printer_service.dart      # Tickets 80 mm (diálogo o directo)
│   ├── balanza_service.dart      # Lectura de balanza por puerto serial
│   └── password_service.dart     # Hash SHA-256 (legado/respaldo)
└── screens/
    ├── splash_screen.dart        # Splash con la marca
    ├── pin_login_screen.dart     # Login con correo + PIN
    ├── home_screen.dart          # Menú principal
    ├── pos_screen.dart           # Punto de venta
    ├── inventory_screen.dart     # Inventario
    ├── purchases_screen.dart     # Compras
    ├── cash_control_screen.dart  # Arqueo de caja
    ├── reports_screen.dart       # Reportes
    ├── sales_history_screen.dart # Historial de ventas
    ├── clients_screen.dart       # Clientes y fiados
    ├── users_screen.dart         # Gestión de usuarios
    └── settings_screen.dart      # Configuración (negocio, impresora, balanza)
```

---

## 🧪 Pruebas

```
test/
├── widget_test.dart              # Inicio: splash → login
├── password_service_test.dart    # Hash y verificación de contraseñas
├── role_permissions_test.dart    # Permisos de ADMIN y CAJERO
└── balanza_service_test.dart     # Parser de pesos (gramos, kg, STX/ETX)
```

---

## 📦 Versiones

Ver [`CHANGELOG.md`](CHANGELOG.md).

NovaPOS · v1.0.0