# Instalación web de Grupo CG

## Añadir planillas a una cuenta existente

Abrir la cuenta desde **Cuentas de cobro**, pulsar **Editar cuenta** y luego **Añadir planilla**. Completar fecha, número de planilla, vehículo, conductor y valor. La planilla nueva queda pendiente hasta pulsar **Guardar cuenta y planillas**; se puede quitar antes de guardar y **Cancelar** descarta los cambios.

Al guardar, se crea el cobro para el cliente de la cuenta y se incluye en esa misma cuenta. Se conserva su consecutivo y se recalculan total, periodo y PDF. Las columnas personalizadas de las filas nuevas quedan vacías y pueden completarse desde **Columnas**. Volver a descargar el PDF después de guardar.

Actualizar la web y `api/index.php` juntos. No se requieren cambios de SQL.

## Fotos de planillas y contabilidad

**Añadir fotos** permite seleccionar varias imágenes de la galería o tomar varias fotos, una por una, para el mismo número de planilla. Antes de guardar se muestran las miniaturas y se pueden quitar imágenes seleccionadas. En la lista, las fotos se agrupan por número de planilla; desplegar el grupo permite abrir o eliminar cada foto y añadir más con el número ya completado. Las fotos anteriores se agrupan automáticamente sin cambiar los datos guardados. Cada imagen se guarda por separado; si una carga falla se informa cuántas se guardaron para evitar volver a cargar esas fotos.

Esta mejora de fotos utiliza la API existente y no necesita cambios de SQL. El paquete actualizado también incluye la mejora de añadir planillas a cuentas existentes, que sí requiere actualizar `api/index.php`.

El menú incluye **Fotos de planillas**. Cada registro guarda número de planilla e imagen. Se puede tomar una foto con la cámara del dispositivo o escoger una imagen, buscar por número y abrir la foto después. La cámara necesita permiso del navegador y acceso HTTPS. Las fotos se comprimen a JPG de hasta 2 MB antes de subirlas; en la lista solo se envían sus datos, y la imagen completa se consulta al abrirla. Se pueden guardar varias fotos con el mismo número y eliminar cada una por separado.

El menú **Contabilidad** permite anotar ingresos y gastos con fecha, detalle y valor. Muestra sumas de ingresos y gastos y saldo (`ingresos - gastos`). Un movimiento se puede editar tocándolo o eliminar con confirmación; el saldo se recalcula de inmediato. Los movimientos son independientes de las cuentas de cobro y planillas, y son compartidos por los usuarios con acceso. El saldo puede ser negativo si los gastos superan los ingresos.

Ambos módulos usan la tabla `records` existente. Subir la web y `api/index.php` incluidos en el ZIP; no importar SQL ni modificar los datos previos.

## Editar cuentas y sus planillas

Abrir una cuenta desde el historial y pulsar **Editar cuenta** sobre el PDF. Se pueden corregir fecha del documento, fecha de cada planilla, número de planilla y valor. Los cambios de cada fila quedan pendientes hasta pulsar **Guardar cuenta y planillas**; Cancelar los descarta. El servidor guarda la cuenta y las planillas originales en una única transacción, recalcula total y periodo, y conserva el consecutivo, la ruta, firma, encabezado, columnas y campos personalizados. El PDF se actualiza al guardar, incluidos el importe y las letras.

La edición se inicia con los datos actuales de las planillas originales. Si otra persona modifica la cuenta o una planilla mientras el editor está abierto, el servidor pide cerrar y abrir de nuevo el editor. Si se eliminó una planilla original o pertenece ahora a otro cliente, se informa el problema y no se guardan cambios parciales. Otras cuentas ya emitidas conservan su copia de los datos. Los PDF descargados anteriormente deben descargarse de nuevo después de corregir la cuenta.

Esta actualización requiere subir la web y la API; no necesita importar SQL ni reiniciar consecutivos.

## Documento equivalente y acceso persistente

Las nuevas cuentas usan el título DOCUMENTO EQUIVALENTE A FACTURA, número CC-[id], fecha en español y la leyenda transcrita de la referencia: ART.3ro. decreto 522 de marzo de 2003. El destinatario predeterminado es COMERCIALIZADORA MULTIDROGAS DE COLOMBIA S.A.S., NIT 823.000.097, en CARTAGENA. El concepto se genera como RUTA: [cliente elegido] con el total en números y letras. Las cuentas anteriores conservan su formato y numeración.

Antes de generar la primera cuenta con esta actualización, ejecutar una sola vez `CONSECUTIVO_476.sql` en phpMyAdmin. No elimina cuentas ni cambia sus IDs. Si ya existen IDs iguales o superiores a 476, MySQL conserva un siguiente ID libre superior; consultar el resultado del SQL. No volver a ejecutar el script para reiniciar números ya utilizados.

En la web HTTPS, el acceso nuevo crea una cookie Secure, HttpOnly y SameSite=Strict. La sesión del servidor ya no tiene el límite de ocho horas. La cookie se renueva con el uso y permite restaurar la sesión al recargar, abrir otra pestaña o volver a abrir el navegador. Cerrar sesión o eliminar el usuario revoca el acceso. Borrar los datos del navegador, usar otro perfil o la caducidad impuesta por el navegador puede requerir entrar nuevamente. Iniciar sesión una vez después de actualizar para obtener la cookie persistente. El formulario muestra grupocg@gmail.com por defecto y no guarda la contraseña.

## Columnas de cuentas y usuarios

Las cuentas nuevas tienen seleccionadas únicamente Fecha, Planilla y Valor. Vehículo, Conductor y los campos personalizados siguen disponibles como opciones. Este cambio no modifica las columnas guardadas en cuentas anteriores ni requiere volver a ejecutar el SQL del consecutivo.

Al generar una cuenta, después de seleccionar el periodo se eligen las columnas del detalle. Se pueden quitar o añadir Fecha, Vehículo, Conductor, Planilla y Valor, y crear campos personalizados con un valor por fila. El total siempre se conserva. Se admiten hasta 10 columnas; con más de 5 se usa una página horizontal.

Desde el historial, abrir una cuenta y pulsar **Columnas** permite modificar y guardar su presentación. Las cuentas anteriores siguen mostrando las cinco columnas originales hasta que se cambien. Los campos personalizados pertenecen a esa cuenta; no modifican los cobros originales ni se aplican automáticamente a otras cuentas. Los PDF que ya se descargaron no cambian: hay que descargarlos de nuevo.

El menú **Usuarios** permite crear accesos con correo y contraseña, y eliminarlos con confirmación. La cuenta inicial (el usuario con menor `id` en `users`) es la administradora y no se puede eliminar desde la aplicación. Solo ella puede gestionar usuarios; los nuevos usuarios comparten los datos operativos de la empresa. Al eliminar un usuario se revocan sus sesiones y se conservan los registros.

Esta actualización requiere reemplazar tanto los archivos web como `api/index.php`. No requiere cambios en las tablas ni importar SQL.

Para designar una cuenta administradora existente, añadir `'admin_email' => 'grupocg@gmail.com',` dentro del arreglo de `grupocg-config.php`. Esta selección tiene prioridad sobre el usuario de menor ID. Actualizar también `api/index.php` y recargar los datos o iniciar sesión de nuevo. No cambiar los IDs de los usuarios.

Compilar desde la raíz del proyecto:

```sh
powershell -ExecutionPolicy Bypass -File scripts/build-web.ps1
```

Subir el contenido de `build/web/` a `public_html/grupocg/`, conservando la carpeta `api/`. Si se publica en la raíz del dominio, compilar con `--base-href=/`.

Actualizar también `backend/public/index.php` en `public_html/grupocg/api/index.php` para habilitar la eliminación de registros. No se necesita reimportar el esquema ni borrar datos existentes.

Los formularios de edición de clientes, conductores, vehículos, cobros, firmas y emisor incluyen **Eliminar** cuando el registro ya existe. También hay una papelera en las listas y en el historial de cuentas. Cada eliminación requiere confirmación. Si un cliente, vehículo o conductor tiene cobros asociados, primero se deben modificar o eliminar esos cobros.

Para actualizar desde `build/GRUPOCG-ACTUALIZACION.zip`, extraer su contenido directamente dentro de `public_html/grupocg/` y reemplazar los archivos existentes. El ZIP incluye la web compilada y `api/`; no incluye la configuración privada ni modifica la base de datos. Mantener `grupocg-config.php` en la carpeta superior a `public_html`. Después de subir, recargar la aplicación; en escritorio usar Ctrl+F5 si siguen apareciendo los botones antiguos.

Servir mediante HTTPS con certificado válido. El manifiesto y sus iconos deben ser públicos y devolver sus archivos, sin redirecciones al inicio de sesión.

En navegadores compatibles, el aviso «Instalar» aparece cuando el navegador comunica que permite la instalación. Solo el clic del usuario abre la confirmación nativa. El navegador decide cuándo ofrecerla; también puede estar disponible desde su menú. Cerrar el aviso lo oculta durante la sesión de esa pestaña.

En iPhone/iPad se muestran instrucciones para Safari: Compartir → Añadir a pantalla de inicio. El aviso se oculta cuando la aplicación está abierta en modo instalado.

La instalación no incluye funcionamiento sin conexión: el acceso y los datos necesitan la API. Los iconos actuales son los de Flutter; pueden sustituirse por los de la empresa manteniendo los tamaños y dejando margen seguro en las variantes maskable.

Después de publicar, verificar desde un dispositivo sin la aplicación instalada:

- Abrir `https://appzplay.online/grupocg/` en Chrome o Edge, interactuar con la página y comprobar la instalación desde el aviso o el menú del navegador.
- Cancelar la confirmación y comprobar que se puede seguir usando la aplicación.
- Instalar, abrir desde el icono y comprobar que se abre en ventana independiente sin el aviso.
- En Safari de iPhone, seguir las instrucciones y abrir desde la pantalla de inicio.
- Revisar en DevTools → Application → Manifest que no existan errores de manifiesto ni iconos.

Referencias: https://web.dev/articles/customize-install y https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable
