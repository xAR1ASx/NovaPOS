# Changelog

Todas las versiones notables de NovaPOS se documentan en este archivo.

## [1.6.0] - 2026-10-21

### Nuevo
- **Centro Financiero** (reemplaza Reportes, conserva todo lo anterior): selector de
  período (Hoy, Ayer, 7 días, 30 días, Este mes, Mes pasado, Este año o rango libre),
  filtro por cajero y siete secciones:
  - **Panorama**: estado de resultados Hoy / Mes / Año, inventario al costo, cartera y
    efectivo de la caja.
  - **Resultados**: cascada Ventas − Costo − Gastos = Ganancia, comparación con el
    período anterior, "¿en qué se fue cada peso?", estado de resultados y gráfica día a día.
  - **Gastos y compras**: gastos por categoría, compras por proveedor, flujo de efectivo
    y ventas por medio de pago.
  - **Rentabilidad**: margen por categoría y producto, productos con margen bajo y
    productos sin costo registrado.
  - **Ventas**: más vendidos, hora pico, mejor día y mapa de calor.
  - **Control**: anulaciones, devoluciones, mermas y descuadres, con quién y por qué.
  - **Cierres de caja**: cuadrado / faltante / sobrante por turno y por cajero, detalle
    del turno y reimpresión de la tirilla Z.
- **Informe Excel del período** con hojas de resultados, gastos, compras, rentabilidad,
  control y cierres.
- **Categorías de gastos e ingresos** en Caja (nómina, arriendo, servicios, proveedor,
  préstamo, retiro del dueño…). Préstamos y retiros no restan de la utilidad.
- **Motivo** en devoluciones y anulaciones; la anulación guarda quién y cuándo.
- Sincronización entre cajas de movimientos de caja, cierres, devoluciones y combos.

### Corregido
- Devolver o anular una venta de un turno anterior (o de otra caja) dejaba un faltante
  falso: el cuadre ahora es flujo de efectivo real y el dinero sale del turno abierto,
  validando caja abierta y fondos suficientes.
- La devolución se calcula sobre lo realmente cobrado (respeta promociones); en pagos
  mixtos se devuelve primero el efectivo; el efectivo entregado de más en un pago mixto
  ya no infla la caja (era cambio).
- Devolver un paquete (ej. 6 unidades) devolvía 1 unidad al inventario.
- Los combos vendidos en el POS no descontaban sus componentes y su costo quedaba en $0.
- El stock de los combos se sincronizaba al combo y no a sus componentes.
- Cerrar turno sin escribir el efectivo contado registraba todo como faltante.
- Compras pagadas con caja sin fondos dejaban la caja en negativo.
- Las ventas recibidas de otra caja perdían el desglose del pago mixto; las devoluciones
  no llegaban a las demás cajas.
- Eliminar un combo lo borraba solo en esa caja; ahora se desactiva en todas.

### Técnico
- Base de datos v13 (migración automática y sin pérdida de datos): `efectivo_cobrado`,
  auditoría de anulación, tabla `devoluciones`, categoría y caja en `caja_movimientos`,
  índices por fecha.
- 66 pruebas automatizadas (23 nuevas de caja, devoluciones y reportes).

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