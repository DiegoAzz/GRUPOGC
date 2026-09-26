# Grupo CG — Cobros

Flutter Android/web + API PHP 8.1+ + MySQL. Incluye clientes, vehículos, conductores, cobros, firmas PNG/JPG, datos del emisor e historial de cuentas con impresión y compartir PDF.

## Hostinger

1. En MySQL, seleccionar `u243355059_grupoo_cg` e importar `backend/schema.sql` mediante phpMyAdmin. Usuario MySQL: `u243355059_grupoo_cg`.
2. Copiar `backend/config.example.php` como `grupocg-config.php` fuera de `public_html`, en su directorio padre. Sustituir `YOUR_DATABASE_PASSWORD` por la contraseña MySQL. Se asume servidor MySQL `localhost`; confirmar en hPanel. El origen CORS es `https://appzplay.online`, sin ruta ni barra final.
3. Copiar el contenido de `backend/public/` a `public_html/grupocg/api/`. Endpoint: `https://appzplay.online/grupocg/api/index.php`. El PHP busca el archivo privado tres niveles por encima de la carpeta de la API. Habilitar HTTPS.
4. Copiar `backend/create_user.php` junto a `grupocg-config.php`. Ejecutar por SSH `php create_user.php correo@ejemplo.com` e introducir por entrada estándar una contraseña de al menos 12 caracteres. Este usuario de acceso a la app es diferente al usuario MySQL. Sin SSH: generar un hash con `password_hash` en un entorno PHP confiable e insertar correo/hash en `users` mediante phpMyAdmin. No publicar scripts de creación de administradores.
5. Ejecutar:

```sh
flutter pub get
flutter run -d chrome
flutter build web --base-href=/grupocg/
flutter build apk
```

La URL de la API ya está configurada por defecto; se puede cambiar con `--dart-define=API_URL=...`. Para desarrollo web local, ajustar temporalmente `origin` al origen local exacto en una configuración de pruebas.

Subir el contenido de `build/web` a `public_html/grupocg/` conservando la carpeta `api/`. Abrir https://appzplay.online/grupocg/. La compilación debe incluir `--base-href=/grupocg/` para cargar los recursos desde esa subcarpeta. Configurar firma Android de lanzamiento antes de distribuir. Las credenciales MySQL permanecen en el servidor.

Distribución en Hostinger:

```text
directorio del dominio/
  grupocg-config.php          (privado: contraseña MySQL)
  create_user.php             (solo CLI)
  public_html/
    grupocg/
      index.html             (y demás archivos de build/web)
      api/
        index.php
        .htaccess
```

## Uso y alcance

Registrar emisor, clientes, vehículos, conductores y firmas (PNG/JPG, máximo 2 MB). Registrar cobros; escribir valor sin separador de miles. Para emitir, seleccionar cliente, firma, concepto y periodo inclusivo. Se genera consecutivo, total, importe en letras, detalle y firma. Abrir el historial permite reimprimir sin crear otra cuenta.

El historial conserva copias de los datos y la firma. Generar otra vez el mismo periodo crea otra cuenta: esta versión no marca pagos ni impide volver a incluir cobros. No incluye eliminación, conciliación ni roles. Los usuarios autorizados comparten los registros de la empresa. Sesión de 8 horas en memoria.

El PDF se titula Cuenta de cobro, con distribución basada en la referencia; no copia sus datos personales ni leyendas normativas. La firma es una imagen digitalizada.

## Verificación

`flutter analyze` y `flutter test`. Antes de producción verificar en Hostinger acceso, altas y cambios, rechazo de valores/fechas/firmas inválidos, periodo vacío, límites de fechas, total decimal y reimpresión tras editar datos originales. Respaldar MySQL, que contiene firmas e historial.

Referencias: [PHP/MySQL en Hostinger](https://www.hostinger.com/my/tutorials/how-to-connect-php-to-mysql), [PDF Flutter](https://pub.dev/packages/pdf).
