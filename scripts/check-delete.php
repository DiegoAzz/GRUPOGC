<?php
declare(strict_types=1);
// CLI only: uses an ephemeral database on the local test MySQL server, never production.
if (PHP_SAPI !== 'cli') exit(1);
$root=dirname(__DIR__);
$admin=json_decode(file_get_contents($root.'/.local/mysql-admin.json'),true,512,JSON_THROW_ON_ERROR);
$db=new PDO('mysql:host=127.0.0.1;port=3307;charset=utf8mb4',$admin['user'],$admin['password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
$database='cg_delete_test_'.bin2hex(random_bytes(6));
$configPath=$root.'/.local/'.$database.'.php';
$server=null;
$token='';
$cookieToken='';
function api(array $body,int $expected=200): mixed {
    global $token, $cookieToken;
    $authHeader=$token!=='' ? "Authorization: Bearer $token\r\n" : '';
    $cookieHeader=$cookieToken!=='' ? "Cookie: grupocg_session=$cookieToken\r\n" : '';
    $context=stream_context_create(['http'=>['method'=>'POST','header'=>"Content-Type: application/json\r\n".$authHeader.$cookieHeader,'content'=>json_encode($body),'ignore_errors'=>true,'timeout'=>10]]);
    $raw=file_get_contents('http://127.0.0.1:8087/index.php',false,$context);
    if (!str_contains($http_response_header[0]," $expected ")) throw new RuntimeException($http_response_header[0].' '.$raw);
    $body=json_decode($raw,true,512,JSON_THROW_ON_ERROR);
    return $body['data'] ?? $body['error'];
}
function check(bool $value,string $message): void { if (!$value) throw new RuntimeException($message); }
function save(string $entity,array $record): int {
    api(['action'=>'save','entity'=>$entity,'record'=>$record]);
    $state=api(['action'=>'state']);
    return $entity==='issuer' ? $state[$entity]['id'] : $state[$entity][0]['id'];
}
function removeRecord(string $entity,int $id,int $expected=200): void { api(['action'=>'delete','entity'=>$entity,'id'=>$id],$expected); }
try {
    // Refuse to reuse any existing HTTP service on the test port.
    $socket=@fsockopen('127.0.0.1',8087,$errno,$error,1);
    if ($socket) { fclose($socket); throw new RuntimeException('El puerto de pruebas 8087 está ocupado.'); }
    $db->exec("CREATE DATABASE `$database`");
    $db->exec("USE `$database`");
    $db->exec(file_get_contents($root.'/backend/schema.sql'));
    $password=bin2hex(random_bytes(16));
    $db->prepare('INSERT INTO users(email,password_hash) VALUES (?,?)')->execute(['legacy@example.com',password_hash(bin2hex(random_bytes(16)),PASSWORD_DEFAULT)]);
    $db->prepare('INSERT INTO users(email,password_hash) VALUES (?,?)')->execute(['delete-test@example.com',password_hash($password,PASSWORD_DEFAULT)]);
    file_put_contents($configPath,'<?php return '.var_export(['dsn'=>"mysql:host=127.0.0.1;port=3307;dbname=$database;charset=utf8mb4",'user'=>$admin['user'],'password'=>$admin['password'],'origin'=>'http://localhost:5300','admin_email'=>'delete-test@example.com'],true).';');
    $environment=getenv(); $environment['GRUPO_CG_CONFIG']=$configPath;
    $server=proc_open([PHP_BINARY,'-n','-d','extension_dir='.$root.'/.local/php/ext','-d','extension=pdo_mysql','-S','127.0.0.1:8087','-t',$root.'/backend/public'],[0=>['pipe','r'],1=>['file',$root.'/.local/delete-test.log','a'],2=>['file',$root.'/.local/delete-test.log','a']],$pipes,$root,$environment,['bypass_shell'=>true,'create_no_window'=>true]);
    if (!is_resource($server)) throw new RuntimeException('No se pudo iniciar PHP.');
    for ($i=0;$i<50;$i++) {
        $socket=@fsockopen('127.0.0.1',8087,$errno,$error,0.1);
        if ($socket) { fclose($socket); break; }
        usleep(100000);
    }
    removeRecord('clients',1,401);
    $token=api(['action'=>'login','email'=>'delete-test@example.com','password'=>$password])['token'];
    $adminToken=$token;
    $photoBytes=base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
    api(['action'=>'save_photo','sheet'=>'PLAN-001','image'=>base64_encode($photoBytes)]);
    $photoState=api(['action'=>'state']);
    check(count($photoState['planilla_photos'])===1 && !isset($photoState['planilla_photos'][0]['image']),'La lista de fotos expone imágenes completas.');
    $photoId=$photoState['planilla_photos'][0]['id'];
    check(api(['action'=>'photo_get','id'=>$photoId])['image']===base64_encode($photoBytes),'La foto no se pudo consultar.');
    api(['action'=>'save_photo','sheet'=>'PLAN-002','image'=>'invalid'],422);
    api(['action'=>'save_ledger','date'=>'2026-09-28','kind'=>'income','detail'=>'Venta','value'=>'100,00']);
    api(['action'=>'save_ledger','date'=>'2026-09-28','kind'=>'expense','detail'=>'Combustible','value'=>'25,50']);
    $finance=api(['action'=>'state'])['ledger'];
    check(count($finance)===2 && $finance[0]['amount']===2550 && $finance[1]['amount']===10000,'Importes de contabilidad incorrectos.');
    api(['action'=>'save_ledger','id'=>$finance[0]['id'],'date'=>'2026-09-28','kind'=>'expense','detail'=>'Combustible y peaje','value'=>'30']);
    $finance=api(['action'=>'state'])['ledger'];
    check($finance[1]['amount']-$finance[0]['amount']===7000,'El saldo no descuenta el gasto editado.');
    api(['action'=>'save_ledger','date'=>'2026-09-28','kind'=>'expense','detail'=>'Error','value'=>'-1'],422);
    removeRecord('ledger',$finance[0]['id']);
    removeRecord('ledger',$finance[1]['id']);
    removeRecord('planilla_photos',$photoId);
    check(api(['action'=>'state'])['ledger']===[] && api(['action'=>'state'])['planilla_photos']===[],'No se eliminaron los datos de los módulos nuevos.');
    check($db->query('SELECT expires_at FROM sessions LIMIT 1')->fetchColumn()==='9999-12-31 23:59:59','La sesión todavía caduca.');
    $cookieToken=$token; $token='';
    check(api(['action'=>'state'])['current_user']['can_manage_users']===true,'No se restaura la sesión por cookie.');
    api(['action'=>'logout']);
    api(['action'=>'state'],401);
    $cookieToken='';
    $token=api(['action'=>'login','email'=>'delete-test@example.com','password'=>$password])['token'];
    $adminToken=$token;
    $adminUserId=api(['action'=>'state'])['current_user']['id'];
    api(['action'=>'create_user','email'=>'new-user@example.com','password'=>'Usuario-Test-123']);
    api(['action'=>'create_user','email'=>'new-user@example.com','password'=>'Usuario-Test-123'],409);
    api(['action'=>'create_user','email'=>'invalid','password'=>'Usuario-Test-123'],422);
    $users=api(['action'=>'users_list']);
    check(count($users)===3 && !isset($users[0]['password_hash']),'Lista de usuarios inválida.');
    $newUserId=(int)$users[2]['id'];
    api(['action'=>'delete_user','id'=>$adminUserId],409);
    $token=api(['action'=>'login','email'=>'new-user@example.com','password'=>'Usuario-Test-123'])['token'];
    $newToken=$token;
    check(api(['action'=>'state'])['current_user']['can_manage_users']===false,'El usuario nuevo obtuvo permisos de administrador.');
    api(['action'=>'users_list'],403);
    api(['action'=>'create_user','email'=>'forbidden@example.com','password'=>'Usuario-Test-123'],403);
    api(['action'=>'delete_user','id'=>$adminUserId],403);
    $token=$adminToken;
    api(['action'=>'delete_user','id'=>$newUserId]);
    $token=$newToken;
    api(['action'=>'state'],401);
    $token=$adminToken;
    api(['action'=>'delete','entity'=>'users','id'=>1],422);
    api(['action'=>'delete','entity'=>'clients','id'=>'1 OR 1=1'],422);
    $client=save('clients',['name'=>'Prueba','document'=>'123','phone'=>'3001234567','email'=>'test@example.com','address'=>'Prueba']);
    $vehicle=save('vehicles',['name'=>'TEST01','document'=>'Prueba']);
    $driver=save('drivers',['name'=>'Prueba','document'=>'123','phone'=>'3001234567']);
    $issuer=save('issuer',['name'=>'Emisor prueba','document'=>'123','phone'=>'3001234567','email'=>'test@example.com','address'=>'Prueba','city'=>'Bogotá']);
    $signature=save('signatures',['name'=>'Firma prueba','document'=>'123','image'=>'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=']);
    $charge=['date'=>'2026-09-27','client_id'=>(string)$client,'vehicle_id'=>(string)$vehicle,'driver_id'=>(string)$driver,'sheet'=>'TEST','value'=>'123,45'];
    $chargeId=save('charges',$charge);
    $secondChargeId=save('charges',array_replace($charge,['sheet'=>'SECOND','value'=>'12,34']));
    foreach (['clients'=>$client,'vehicles'=>$vehicle,'drivers'=>$driver] as $entity=>$id) removeRecord($entity,$id,409);
    removeRecord('vehicles',$client,404);
    $db->exec('ALTER TABLE bills AUTO_INCREMENT=476');
    $bill=api(['action'=>'generate','client_id'=>(string)$client,'signature_id'=>(string)$signature,'from'=>'2026-09-27','to'=>'2026-09-27']);
    check($bill['number']==='CC-476' && $bill['concept']==='RUTA: Prueba' && $bill['template']==='equivalent_v1','Documento o consecutivo incorrecto.');
    $billId=api(['action'=>'state'])['bills'][0]['id'];
    check($bill['id']===$billId,'Falta identificador de cuenta generada.');
    $layout=['action'=>'bill_layout','id'=>$billId,'columns'=>[['key'=>'date','label'=>'Fecha'],['key'=>'sheet','label'=>'Planilla'],['key'=>'amount','label'=>'Valor'],['key'=>'custom_route','label'=>'Ruta']],'custom_values'=>[(string)$chargeId=>['custom_route'=>'Cartagena - Barranquilla']]];
    $updated=api($layout);
    check($updated['total']===$bill['total'] && $updated['rows'][0]['amount']===$bill['rows'][0]['amount'],'Cambió un importe al configurar columnas.');
    check($updated['rows'][0]['custom_values']['custom_route']==='Cartagena - Barranquilla','No se guardó el campo personalizado.');
    check(api(['action'=>'state'])['bills'][0]==$updated,'La configuración no persistió.');
    api(array_replace($layout,['columns'=>[]]),422);
    api(array_replace($layout,['columns'=>[['key'=>'unknown','label'=>'Inválido']]]),422);
    api(array_replace($layout,['columns'=>[['key'=>'sheet','label'=>'Planilla'],['key'=>'sheet','label'=>'Duplicada']]]),422);
    $bill=$updated;
    $otherBill=api(['action'=>'generate','client_id'=>(string)$client,'signature_id'=>(string)$signature,'from'=>'2026-09-27','to'=>'2026-09-27']);
    $edit=api(['action'=>'bill_edit_context','id'=>$billId]);
    $editRequest=['action'=>'bill_edit','id'=>$billId,'revision'=>$edit['revision'],'date'=>'2026-09-28','rows'=>$edit['rows']];
    $editRequest['rows'][0]['sheet']='CORREGIDA'; $editRequest['rows'][0]['value']='200,50';
    $badRequest=$editRequest; $badRequest['rows'][1]['value']='invalid';
    api($badRequest,422);
    check(api(['action'=>'state'])['charges'][1]['sheet']==='TEST','Se guardaron cambios parciales tras un error.');
    save('charges',array_replace($charge,['id'=>$chargeId,'sheet'=>'CONCURRENT']));
    api($editRequest,409);
    $edit=api(['action'=>'bill_edit_context','id'=>$billId]);
    $editRequest['revision']=$edit['revision']; $editRequest['rows']=$edit['rows'];
    $editRequest['rows'][0]['sheet']='CORREGIDA'; $editRequest['rows'][0]['value']='200,50';
    $bill=api($editRequest);
    check($bill['number']==='CC-476' && $bill['total']===21284,'Consecutivo o total editado incorrecto.');
    check($bill['rows'][0]['custom_values']['custom_route']==='Cartagena - Barranquilla','Se perdió un campo personalizado.');
    $state=api(['action'=>'state']);
    check($state['charges'][1]['amount']===20050 && $state['charges'][1]['sheet']==='CORREGIDA','La cuenta no actualizó la planilla original.');
    check($state['bills'][0]==$otherBill,'Cambió otra cuenta al editar la seleccionada.');
    api($editRequest,409);
    $edit=api(['action'=>'bill_edit_context','id'=>$billId]);
    $deleteRequest=['action'=>'bill_edit','id'=>$billId,'revision'=>$edit['revision'],'date'=>'2026-09-28','rows'=>[$edit['rows'][0]],'deleted_rows'=>[$edit['rows'][1]]];
    $badDelete=$deleteRequest; $badDelete['deleted_rows'][0]['revision']='stale';
    api($badDelete,409);
    $badDelete=$deleteRequest; $badDelete['deleted_rows'][0]['id']=PHP_INT_MAX;
    api($badDelete,422);
    $badDelete=$deleteRequest; $badDelete['deleted_rows']=[$edit['rows'][0]];
    api($badDelete,422);
    $badDelete=$deleteRequest; $badDelete['rows']=[]; $badDelete['deleted_rows']=$edit['rows'];
    api($badDelete,422);
    check(count(api(['action'=>'state'])['charges'])===2,'Una eliminación inválida alteró los cobros.');
    $bill=api($deleteRequest);
    check(count($bill['rows'])===1 && $bill['rows'][0]['id']===$chargeId && $bill['total']===20050 && $bill['number']==='CC-476','La eliminación no conservó la planilla, total o consecutivo correctos.');
    check($bill['rows'][0]['custom_values']['custom_route']==='Cartagena - Barranquilla','Se perdió el campo personalizado al eliminar.');
    $state=api(['action'=>'state']);
    check(count($state['charges'])===1 && $state['charges'][0]['id']===$chargeId,'No se eliminó únicamente el cobro seleccionado.');
    check($state['bills'][0]==$otherBill,'Se modificó otra cuenta al eliminar.');
    api($deleteRequest,409);
    removeRecord('bills',$otherBill['id']);
    removeRecord('charges',$chargeId);
    removeRecord('charges',$chargeId,404);
    api(['action'=>'bill_edit_context','id'=>$billId],409);
    removeRecord('charges',$secondChargeId,404);
    foreach (['clients'=>$client,'vehicles'=>$vehicle,'drivers'=>$driver,'signatures'=>$signature,'issuer'=>$issuer] as $entity=>$id) removeRecord($entity,$id);
    $state=api(['action'=>'state']);
    $stored=$state['bills'][0];
    // MySQL JSON normalizes object key order; compare the complete data structurally.
    check($stored==$bill,'La cuenta emitida cambió al borrar sus fuentes.');
    check($state['clients']===[] && $state['charges']===[] && $state['issuer']===[],'Quedaron registros eliminados.');
    api(['action'=>'save','entity'=>'charges','record'=>$charge],422);
    removeRecord('bills',$billId);
    check(api(['action'=>'state'])['bills']===[],'No se eliminó la cuenta.');
    echo "OK: autenticación, validación, relaciones, borrado de los siete módulos e historial independiente.\n";
} finally {
    if (is_resource($server)) { proc_terminate($server); proc_close($server); }
    if (is_file($configPath)) unlink($configPath);
    $db->exec("DROP DATABASE IF EXISTS `$database`");
}
