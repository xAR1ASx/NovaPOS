# Changelog

Todas las versiones notables de NovaPOS se documentan en este archivo.

## [1.0.0] - 2026-09-10

### Nuevo
- **Identidad de marca**: la aplicación pasa a llamarse **NovaPOS** (antes
  MiFruverPOS) en todo el proyecto (window's CMake, ejecutable, instalador,
  web, iconos y textos).
- **Icono y logo** propios: degrade verde (#2ECC71 → #145A32) con la "N" de
  NovaPOS, aplicado al ícono de Windows, Android, iOS y Web.
- **Pantalla de presentación (splash)**: carga con la marca y navega
  automáticamente al login.
- **Seguridad de acceso**: el PIN del usuario pasa a ser la **contraseña real
  de Firebase** (6 dígitos). Se elimina el almacenamiento de PIN en Firestore.
- **Login con sesión persistente**: el usuario queda guardado en el equipo (solo
  PIN en inicios siguientes) con opción de "Cambiar" de usuario.
- **Autocambio de PIN**: cada empleado cambia su propio PIN desde
  Configuración → Seguridad (con verificación del PIN actual).
- **Recuperación de PIN**: el administrador puede enviar un enlace de
  restablecimiento por correo al empleado.
- **Reglas de seguridad en Firestore**: permisos por negocio y por rol,
  publicadas en la consola de Firebase.
- **Impresión de tickets directa**: se detectan las impresoras de Windows y se
  puede imprimir sin diálogo a la impresora elegida (compatible con cualquier
  impresora térmica con driver).
- **Balanza serial**: soporte real de lectura por puerto COM para productos
  pesables, con peso en vivo en el POS, detección automática de formatos
  (ASCII, STX/ETX, g/kg) y filtro de ruido.
- **Pruebas automatizadas**: suite de tests para el arranque de la app, hashing
  de contraseñas, permisos por rol y el parser de peso de balanza.

### Mejorado
- Configuración del hardware más clara: botones "Detectar impresoras" y
  "Detectar puertos" y "Probar conexión" de la balanza.
- Manejo de errores de login (usuario desactivado, demasiados intentos, sin
  conexión) con mensajes claros.
- Bloqueo temporal de 30 segundos tras 3 intentos fallidos.

### Removido
- Accesos por demo (`admin` / `cajero` con PIN `1234`).
- Almacenamiento de `pin_hash` en Firestore.