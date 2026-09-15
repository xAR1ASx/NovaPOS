# Notas técnicas: fotos de productos entre cajas

> Documentación interna de la funcionalidad. La configuración del lado
> servidor la administra el proveedor del sistema; no requiere acción del
> usuario final.

## Qué hace la app
- Los productos se sincronizan entre todas las cajas del negocio junto con
  sus imágenes.
- La foto de cada producto se asocia al producto y se comparte con las demás
  cajas automáticamente (con reintentos si no hay conexión).
- Sin internet, pero con la sincronización ya hecha, cada caja sigue operando
  con los datos locales.

## Cómo verificar que funciona
1. En una caja, edite o cree un producto y asígnele una foto.
2. Espere unos segundos.
3. En la otra caja, Inventario → el producto debe mostrar la foto.

## Notas
- Las fotos de productos que ya existían solo se comparten si el producto se
  vuelve a guardar.
- La configuración de sincronización está en Ajustes → Sincronización entre cajas.