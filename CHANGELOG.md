# Changelog

Todas las versiones notables de NovaPOS se documentan en este archivo.

## [1.9.2] - 2026-10-23

### Corregido
- **NovaPOS se cerraba al entrar por segunda vez** en el PC del cliente (excepción 0xc000001d, instrucción ilegal, dentro de NovaPOS.exe, donde va Firebase). La primera entrada funcionaba; la segunda leía la caché en disco de Firestore. En Windows esa caché queda apagada (`persistenceEnabled: false`): NovaPOS guarda todo en SQLite y tiene su propia cola de subida (`sync_pendientes`).

## [1.9.1] - 2026-10-23

### Corregido (primera instalación en cliente)
- **Combos y ofertas no se encontraban al vender**: se creaban pero quedaban perdidos entre todos los productos. Ahora el POS muestra la pestaña **Combos** junto a Favoritos cuando hay alguno.
- **Impresora de 58 mm**: el ticket de venta y el ticket de prueba eran siempre de 80 mm y se cortaban a la derecha. Ahora usan el ancho de Ajustes → Hardware → Ancho del papel; en 58 mm dejan 5 mm a cada lado (estas impresoras solo imprimen unos 48 mm). El Reporte Z en 58 mm también deja 5 mm.
- **NovaPOS se cerraba al iniciar sesión** en un PC con Visual C++ Runtime viejo (MSVCP140.dll 14.29, excepción 0xc0000005). El instalador ahora lleva las DLL de Visual C++ junto a `NovaPOS.exe`.

## [1.9.0] - 2026-10-23

### Nuevo
- **Reporte Z** (tirilla de cierre) para 80 mm (42 columnas) y 58 mm (32), con vista previa en pantalla. Vista previa e impresión salen de una sola lista de renglones (`lib/services/reporte_z.dart`). Regla de oro: base + ventas − no efectivo + otras entradas − compras − gastos − devoluciones = esperado. Aviso grande FALTANTE / SOBRANTE / CAJA CUADRADA (o "Sin efectivo declarado"). Detalle de compras y gastos con concepto partido por palabras y valor abajo a la derecha.
- Los datos del Z se congelan en el cierre (`detalle`, segmento `Z:` en base64 antes de `METODOS:`): la reimpresión es idéntica. Cierres anteriores se rearman con sus movimientos.
- **Centro Financiero → Cajas en vivo**: estado de cada caja (abierta/cerrada, ventas, desglose, efectivo esperado, última diferencia, Reporte Z parcial). Los movimientos de caja sincronizados llevan `caja_nombre`.
- **Ajustes → Hardware → Ancho del papel** (80 / 58 mm).

### Cambiado
- El desglose `METODOS` del cierre es el de esa caja en el turno (antes sumaba todas las cajas).

### Pruebas
- 153 en total (`test/reporte_z_test.dart`, Cajas en vivo en `test/sync_auditoria_test.dart`, Centro Financiero y vista previa en `test/centro_financiero_widget_test.dart`).

## [1.8.2] - 2026-10-23

### Corregido
- Ajustes → Empresa & Ticket: el título "Borrador en Vivo (80 mm)" desbordaba la tarjeta en ventanas angostas (RenderFlex overflow).

### Compilación
- `actions/checkout` y `actions/upload-artifact` a v5 (retiro de Node.js 20 en GitHub Actions).

## [1.8.1] - 2026-10-23

### Corregido (auditoría de Antigravity, verificada en el código)
- `registrarVenta` aceptaba cantidades negativas o cero, carrito vacío, NaN e infinito (una cantidad -1 sumaba stock y restaba caja). Nueva validación `validarItemsVenta`.
- H-01 solo comparaba Σ subtotal con el total (ambos de la UI): ahora cada línea debe cumplir subtotal = cantidad × precio (±$1). El precio no se compara con el inventario porque promociones, paquetes y precios especiales lo cambian legítimamente.
- El total guardado era la suma de las líneas, pero la nube y la deuda del fiado usaban el de la UI (hasta $1 de diferencia): ahora todo usa la suma.
- `registrarMerma` aceptaba cantidad negativa (sumaba stock) o mayor al inventario aunque `permitir_stock_negativo` estuviera apagado. Lanza `OperacionInvalida` y la pantalla de mermas muestra el mensaje.
- `registrarCompra` aceptaba total negativo (la caja subía) o distinto de la suma de los productos.

### Pruebas
- 13 nuevas en `test/validaciones_operaciones_test.dart` (146 en total), verificadas desactivando la validación a propósito.

### Pendiente
- Hallazgo 5 (cola de sincronización fuera de la transacción): real pero de muy baja probabilidad; queda para una versión aparte (DOCUMENTO_DE_LA_VERDAD 11.10).

## [1.8.0] - 2026-10-23

### Nuevo
- **Modo del negocio una caja / varias cajas** (`negocios/<id>.modo_sync`: `una_caja` o `multicaja`; sin el campo = `multicaja`, así los negocios instalados siguen igual). Solo lo cambia el proveedor desde la consola. En una caja no se sube nada en vivo: pasa de ~1.800 escrituras diarias a ~10-20. Quedan el inicio de sesión, la licencia, las fotos en Cloudinary y la copia diaria.
- **Copia diaria en la nube** (`CopiaNubeService`): al cerrar caja la base se comprime (gzip) y se sube a Firestore en pedazos de 900 KB (`negocios/<id>/respaldos/indice` + `partes`). Solo queda la más reciente; la anterior se borra cuando la nueva está completa. Huella SHA-256, reintento automático si no había internet y botón "Subir copia ahora" en Ajustes.
- **Traer la copia de la nube a un equipo vacío** al iniciar sesión: caja nueva (identidad y cajón propios) o PC que reemplaza a uno dañado (misma caja). Sin duplicar ventas, stock ni fiados.
- **Paso de una caja a varias**: la caja existente sube productos (stock exacto), clientes (deuda exacta) y promociones, sin el historial venta por venta, y una copia marcada como lista para varias cajas.
- Fotos de productos que faltan en el equipo se bajan solas de Cloudinary.

### Corregido (auditoría con dos cajas)
- Una caja que se unió bajando todo de la nube volvía a subir en su segundo arranque todas las ventas y clientes descargados: borraba en la nube anulaciones hechas por otra caja y pisaba la deuda de los clientes (`marcarSubidaInicialHecha`).
- Producto o cliente editado en dos cajas: ganaba el que subía de último; ahora gana la edición más reciente (transacción que compara `actualizado_epoch`), sin tocar stock ni deuda.
- La subida inicial no llevaba la foto (`imagen_path` vs `imagen_path_local`) ni los paquetes de cada producto.
- Cada edición de un producto con foto la volvía a subir a Cloudinary, y cambiar la foto no llegaba a las otras cajas (las subidas sin firma no reemplazan un `public_id` existente). Ahora solo se sube si cambió y con `public_id` único.

### Seguridad (firestore.rules)
- `modo_sync` protegido como la licencia (solo consola).
- Copia en la nube: índice y pedazos de la copia vigente no se pueden borrar ni modificar; el índice solo apunta a una copia con todos sus pedazos.

### Pruebas
- 10 pruebas en `test/copia_nube_test.dart`, 9 de auditoría en `test/sync_auditoria_test.dart` (133 en total) y 31 casos de reglas en el emulador de Firebase.

## [1.7.3] - 2026-10-22

### Mejorado
- **Cajón monedero por orden directa**: `PrinterService.abrirCajon()` envía el pulso ESC/POS (`ESC p`, pines 2 y 5) en modo RAW a la impresora de tickets mediante la cola de Windows (`ImpresoraRaw`). Ya no depende de que el controlador tenga activada la apertura del cajón; si la orden directa falla, usa el método anterior.

### Corregido
- Si no se puede acceder a la carpeta Documentos, la app ya no abre una base vacía en la carpeta temporal: el arranque muestra un aviso con el detalle y el botón REINTENTAR. La carpeta temporal queda solo para las pruebas automáticas.

## [1.7.2] - 2026-10-22

### Nuevo
- **Reimpresión de tickets**: botón "REIMPRIMIR TICKET" desde el modal de detalle en el Historial de Ventas, respetando la fecha original de la venta y el desglose de productos.
- **Apertura de cajón monedero**: método integrado en `PrinterService.abrirCajon()` para enviar la señal de apertura vía cola de impresión a la impresora térmica por RJ11, con botón de prueba en Ajustes y confirmación visual en el POS.
- **Identificación multi-caja en tickets**: el encabezado del ticket ahora imprime el nombre de la terminal (ej. `Caja 1 - Ticket #45`) y el nombre del cajero responsable, evitando confusiones de numeración en negocios con varias terminales.
- **Soporte de firma Release en Android**: `build.gradle.kts` preparado para cargar `key.properties` si existe, con plantilla de ejemplo `key.properties.example` y protección en `.gitignore`.
- **Detección de VC++ Redistributable en Windows**: el instalador Inno Setup verifica la presencia de `vcruntime140.dll` y avisa al usuario si requiere instalar el componente gratuito de Microsoft.

### Corregido
- Advertencia de tipos en `SyncService.mantenimiento()` (`body_might_complete_normally_catch_error`).
- Import huérfano en `splash_screen.dart` y advertencia de contexto asíncrono en `license_monitor.dart`.

## [1.7.1] - 2026-10-21

### Nuevo
- **Inicio de sesión sin internet**: un usuario que ya entró con internet en el equipo puede
  volver a entrar con su PIN sin conexión (hasta 7 días). Se guarda una huella cifrada del PIN,
  nunca el PIN. Respeta la licencia guardada (bloqueada, vencida y 72 h de los financiados) y al
  volver el internet se reconecta sola a la nube.
- **El cajero puede devolver artículos** (con motivo obligatorio, queda en Control); anular una
  venta completa sigue siendo solo del administrador.

### Corregido
- El POS se caía cuando un producto favorito tenía una promoción activa.
- El cajero podía entrar a Inventario y Combos desde el POS (precios y stock), subir el cupo de
  crédito de un cliente y crear clientes con $500.000 de cupo.
- "0.750" en kilos se leía como 750 (mermas, inventario, compras, devoluciones).
- Un abono con la caja cerrada no quedaba en ningún turno: ahora exige la caja abierta.
- Tirilla Z contradictoria con faltante/sobrante: ya no se registra un gasto o ingreso de ajuste;
  la diferencia se calcula en el cierre y el Centro Financiero la toma de ahí.
- Licencia: sin internet, la copia guardada de Firebase contaba como revisión exitosa y el bloqueo
  de 72 horas nunca llegaba; ahora siempre se consulta el servidor.

## [1.7.0] - 2026-10-21

### Nuevo
- **Peso manual o con balanza** (Ajustes → Balanza): para fruvers sin balanza conectada. En el
  POS se escribe el peso en kilos, gramos o **por valor** ("deme $2.000"), con atajos y la cuenta
  visible antes de agregar. Con balanza, se puede escribir a mano si hace falta y la balanza se
  **conecta sola** al abrir NovaPOS.
- **Asistente de primer uso** para el administrador: datos del ticket (precargados desde la
  nube), nombre de la caja, balanza e impresora con ticket de prueba. También en Ajustes →
  Asistente.
- **Nombre de cada caja** ("Caja principal", "Caja frutas"), visible en los cierres de todas las cajas.
- **Copia de seguridad extra** en una USB o en Google Drive / OneDrive, copia diaria y aviso en
  el inicio cuando la copia está vieja o solo existe en el PC.
- **Mensajes de inicio de sesión claros** (perfil faltante, usuario desactivado, sin internet,
  correo mal escrito…). Un perfil faltante ya no se confunde con un PIN incorrecto.

### Nube (plan gratuito de Firebase)
- **Sincronización incremental**: cada caja descarga solo lo que cambió desde la última vez
  (marca de hora del servidor `sync_ts`), en lugar de releer todo el historial al abrir.
- Una caja nueva no descarga los movimientos de stock históricos (ya vienen en cada producto).
- Las fotos del catálogo maestro no se suben a Cloudinary (vienen en cada instalación).
- Limpieza diaria: se borran de la nube los movimientos de stock de más de 60 días y, en el
  equipo, los registros ya subidos; una caja que vuelve tras más de 45 días sin conexión toma
  el stock de cada producto desde la nube.
- Subidas sin duplicados: un reintento o una copia restaurada no suma dos veces el stock ni
  la deuda de un cliente, ni un ajuste de inventario viejo pisa el stock actual.

### Corregido
- Una caja nueva de un negocio existente quedaba con todos los productos AGOTADOS y pisaba en la
  nube los precios del dueño (el catálogo se precargaba antes de iniciar sesión).
- Combos y paquetes (presentaciones) no llegaban completos a las otras cajas.
- Crear, editar, activar o desactivar promociones fallaba; eliminar una promoción no la quitaba
  de las otras cajas.
- "Restablecer de fábrica" dejaba datos pendientes por subir que iban a parar al siguiente negocio.
- El stock con decimales (kilos) se truncaba al sincronizar.
- El botón de prueba "SIMULAR PESO" se mostraba a los cajeros.
- Las copias de seguridad copiaban el archivo en uso y podían quedar incompletas: ahora son una
  foto consistente (VACUUM INTO) y se verifican; restaurar valida el archivo y guarda antes la
  base actual.

### Técnico
- Base de datos v14 (nombre de la caja en los cierres). 101 pruebas, incluidas dos cajas
  sincronizándose contra una nube simulada (`fake_cloud_firestore`, solo para pruebas).
- Todas las cajas de un negocio deben tener la misma versión (las anteriores no marcan `sync_ts`).

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