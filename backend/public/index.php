<?php
declare(strict_types=1);
date_default_timezone_set('America/Bogota');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
function respond($data, int $status = 200): never { http_response_code($status); echo json_encode($status === 200 ? ['data'=>$data] : ['error'=>$data], JSON_UNESCAPED_UNICODE); exit; }
function required(array $r, array $keys): void { foreach ($keys as $key) if (!isset($r[$key]) || !is_string($r[$key]) || trim($r[$key]) === '' || strlen($r[$key]) > 500) respond('Campo inválido: '.$key, 422); }
function validDate(string $v): bool { $d = DateTimeImmutable::createFromFormat('!Y-m-d', $v); return $d && $d->format('Y-m-d') === $v; }
function billLayout(array $bill, array $input): array {
    $standard = ['date'=>'Fecha','vehicle'=>'Vehículo','driver'=>'Conductor','sheet'=>'Planilla','amount'=>'Valor'];
    $columns = $input['columns'] ?? array_map(fn($key,$label)=>['key'=>$key,'label'=>$label],array_keys($standard),array_values($standard));
    if (!is_array($columns) || !array_is_list($columns) || count($columns)<1 || count($columns)>10) respond('Selecciona entre 1 y 10 columnas.',422);
    $seen=[]; $clean=[];
    foreach ($columns as $column) {
        if (!is_array($column)) respond('Columna inválida.',422);
        $key=$column['key'] ?? null; $label=$column['label'] ?? null;
        if (!is_string($key) || (!isset($standard[$key]) && !preg_match('/^custom_[a-zA-Z0-9_]{1,50}$/D',$key)) || isset($seen[$key]) || !is_string($label) || trim($label)==='' || strlen($label)>240) respond('Nombre o identificador de columna inválido.',422);
        $seen[$key]=true;
        $clean[]=['key'=>$key,'label'=>$standard[$key] ?? trim($label)];
    }
    $values=$input['custom_values'] ?? [];
    if (!is_array($values)) respond('Valores personalizados inválidos.',422);
    foreach ($bill['rows'] as &$row) {
        $rowValues=$values[(string)$row['id']] ?? [];
        if (!is_array($rowValues)) respond('Valores de fila inválidos.',422);
        $custom=[];
        foreach ($clean as $column) {
            $key=$column['key'];
            if (isset($standard[$key])) continue;
            $value=$rowValues[$key] ?? '';
            if (!is_string($value) || strlen($value)>800) respond('El valor personalizado es demasiado largo o inválido.',422);
            $custom[$key]=trim($value);
        }
        $row['custom_values']=(object)$custom;
    }
    unset($row);
    $bill['columns']=$clean;
    return $bill;
}
try {
    // Deployed at public_html/grupocg/api/index.php; config stays outside the web root.
    $configPath = getenv('GRUPO_CG_CONFIG') ?: dirname(__DIR__, 3).'/grupocg-config.php';
    if (!is_file($configPath) || !is_readable($configPath)) respond('CONFIG-01: No se encuentra o no se puede leer grupocg-config.php. Debe estar en la carpeta superior a public_html.',500);
    $config = require $configPath;
    if (!is_array($config)) respond('CONFIG-02: grupocg-config.php debe devolver un arreglo de configuración.',500);
    foreach (['dsn','user','password','origin'] as $key) {
        if (!isset($config[$key]) || !is_string($config[$key]) || trim($config[$key]) === '') respond('CONFIG-02: Completa dsn, user, password y origin en grupocg-config.php.',500);
    }
    if ($config['password'] === 'YOUR_DATABASE_PASSWORD') respond('CONFIG-03: Falta reemplazar la contraseña MySQL en grupocg-config.php.',500);
    if (($_SERVER['HTTP_ORIGIN'] ?? '') === $config['origin']) { header('Access-Control-Allow-Origin: '.$config['origin']); header('Vary: Origin'); }
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') respond('Método no permitido',405);
    $raw = file_get_contents('php://input', false, null, 0, 3000001);
    if (strlen($raw) > 3000000) respond('Solicitud demasiado grande',413);
    $input = json_decode($raw,true,512,JSON_THROW_ON_ERROR);
    if (!is_array($input)) respond('Solicitud inválida',422);
    $db = new PDO($config['dsn'],$config['user'],$config['password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_EMULATE_PREPARES=>false]);
    $action = $input['action'] ?? '';
    if ($action === 'login') {
        required($input,['email','password']);
        $ip = hash('sha256',$_SERVER['REMOTE_ADDR'] ?? 'unknown');
        $db->prepare('INSERT INTO login_attempts(ip_hash,attempts,window_start) VALUES (?,1,NOW()) ON DUPLICATE KEY UPDATE attempts=IF(window_start < DATE_SUB(NOW(),INTERVAL 15 MINUTE),1,attempts+1), window_start=IF(window_start < DATE_SUB(NOW(),INTERVAL 15 MINUTE),NOW(),window_start)')->execute([$ip]);
        $q=$db->prepare('SELECT attempts FROM login_attempts WHERE ip_hash=?'); $q->execute([$ip]);
        if ((int)$q->fetchColumn()>10) respond('Demasiados intentos. Espera 15 minutos.',429);
        $q=$db->prepare('SELECT * FROM users WHERE email=?'); $q->execute([$input['email']]); $user=$q->fetch(PDO::FETCH_ASSOC);
        if (!$user || !password_verify($input['password'],$user['password_hash'])) respond('Credenciales incorrectas',401);
        $token=bin2hex(random_bytes(32));
        $db->prepare("INSERT INTO sessions VALUES (?,?,'9999-12-31 23:59:59')")->execute([hash('sha256',$token),$user['id']]);
        setcookie('grupocg_session',$token,['expires'=>time()+34560000,'path'=>'/grupocg/api/','secure'=>true,'httponly'=>true,'samesite'=>'Strict']);
        respond(['token'=>$token]);
    }
    $auth=$_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    $hash=hash('sha256',str_starts_with($auth,'Bearer ') ? substr($auth,7) : ($_COOKIE['grupocg_session'] ?? ''));
    $q=$db->prepare('SELECT user_id FROM sessions WHERE token_hash=? AND expires_at>NOW()'); $q->execute([$hash]);
    $currentUserId=(int)$q->fetchColumn();
    if (!$currentUserId) respond('Inicia sesión de nuevo',401);
    // A configured owner takes precedence over the legacy first-account default.
    if (isset($config['admin_email'])) {
        if (!is_string($config['admin_email']) || !filter_var($config['admin_email'],FILTER_VALIDATE_EMAIL)) respond('CONFIG-05: Revisa el correo admin_email en grupocg-config.php.',500);
        $q=$db->prepare('SELECT id FROM users WHERE email=?');
        $q->execute([strtolower(trim($config['admin_email']))]);
        $adminId=(int)$q->fetchColumn();
        if (!$adminId) respond('CONFIG-05: El correo admin_email no corresponde a un usuario existente.',500);
    } else {
        $adminId=(int)$db->query('SELECT MIN(id) FROM users')->fetchColumn();
    }
    if (in_array($action,['users_list','create_user','delete_user'],true)) {
        if ($currentUserId!==$adminId) respond('Solo la cuenta administradora puede gestionar usuarios.',403);
        if ($action==='users_list') respond($db->query('SELECT id,email FROM users ORDER BY id')->fetchAll(PDO::FETCH_ASSOC));
        if ($action==='create_user') {
            required($input,['email','password']);
            $email=strtolower(trim($input['email']));
            if (strlen($email)>190 || !filter_var($email,FILTER_VALIDATE_EMAIL)) respond('Escribe un correo válido.',422);
            if (strlen($input['password'])<8 || strlen($input['password'])>72) respond('La contraseña debe tener entre 8 y 72 bytes.',422);
            try {
                $db->prepare('INSERT INTO users(email,password_hash) VALUES (?,?)')->execute([$email,password_hash($input['password'],PASSWORD_BCRYPT)]);
            } catch (PDOException $e) {
                if ((int)($e->errorInfo[1] ?? 0)===1062) respond('Ya existe un usuario con ese correo.',409);
                throw $e;
            }
            respond(true);
        }
        $id=$input['id'] ?? null;
        if (!is_int($id) || $id<=0) respond('Usuario inválido.',422);
        if ($id===$adminId) respond('No puedes eliminar la cuenta administradora.',409);
        $db->beginTransaction();
        $q=$db->prepare('SELECT id FROM users WHERE id=? FOR UPDATE'); $q->execute([$id]);
        if (!$q->fetchColumn()) { $db->rollBack(); respond('El usuario ya no existe.',404); }
        $db->prepare('DELETE FROM sessions WHERE user_id=?')->execute([$id]);
        $db->prepare('DELETE FROM users WHERE id=?')->execute([$id]);
        $db->commit(); respond(true);
    }
    if ($action==='logout') {
        $db->prepare('DELETE FROM sessions WHERE token_hash=?')->execute([$hash]);
        setcookie('grupocg_session','',['expires'=>1,'path'=>'/grupocg/api/','secure'=>true,'httponly'=>true,'samesite'=>'Strict']);
        respond(true);
    }
    if (isset($_COOKIE['grupocg_session'])) {
        setcookie('grupocg_session',$_COOKIE['grupocg_session'],['expires'=>time()+34560000,'path'=>'/grupocg/api/','secure'=>true,'httponly'=>true,'samesite'=>'Strict']);
    }
    function state(PDO $db): array {
        $result=['clients'=>[],'charges'=>[],'signatures'=>[],'issuer'=>new stdClass(),'bills'=>[],'vehicles'=>[],'drivers'=>[],'planilla_photos'=>[],'ledger'=>[]];
        foreach($db->query('SELECT * FROM records ORDER BY id DESC') as $row) { $v=json_decode($row['payload'],true); $v['id']=(int)$row['id']; if($row['entity']==='planilla_photos') unset($v['image']); if($row['entity']==='issuer') $result['issuer']=$v; else $result[$row['entity']][]=$v; }
        $names=array_column($result['clients'],'name','id');
        foreach($result['charges'] as &$r) $r['client_name']=$names[$r['client_id']] ?? '';
        unset($r);
        foreach($db->query('SELECT id,payload FROM bills ORDER BY id DESC') as $row) { $bill=json_decode($row['payload'],true); $bill['id']=(int)$row['id']; $result['bills'][]=$bill; }
        return $result;
    }
    if ($action==='state') respond(state($db)+['current_user'=>['id'=>$currentUserId,'can_manage_users'=>$currentUserId===$adminId]]);
    if ($action==='photo_get') {
        $id=$input['id'] ?? null;
        if (!is_int($id) || $id<=0) respond('Foto inválida.',422);
        $q=$db->prepare("SELECT payload FROM records WHERE entity='planilla_photos' AND id=?"); $q->execute([$id]);
        $payload=$q->fetchColumn();
        if ($payload===false) respond('La foto ya no existe.',404);
        $photo=json_decode($payload,true,512,JSON_THROW_ON_ERROR); $photo['id']=$id;
        respond($photo);
    }
    if ($action==='save_photo') {
        required($input,['sheet']);
        if (!isset($input['image']) || !is_string($input['image']) || $input['image']==='') respond('Selecciona una foto.',422);
        $image=base64_decode($input['image'],true);
        $size=$image===false ? false : @getimagesizefromstring($image);
        if (!$size || strlen($image)>2097152 || !in_array($size['mime'],['image/jpeg','image/png'],true) || $size[0]>5000 || $size[1]>5000) respond('La foto debe ser JPG o PNG de máximo 2 MB.',422);
        $photo=['sheet'=>trim($input['sheet']),'image'=>base64_encode($image),'created_at'=>date(DATE_ATOM)];
        $db->prepare("INSERT INTO records(entity,payload) VALUES ('planilla_photos',?)")->execute([json_encode($photo,JSON_UNESCAPED_UNICODE)]);
        respond(true);
    }
    if ($action==='save_ledger') {
        required($input,['date','kind','detail','value']);
        if (!validDate($input['date']) || !in_array($input['kind'],['income','expense'],true)) respond('Fecha o tipo de movimiento inválido.',422);
        $value=str_replace(',','.',$input['value']);
        if (!preg_match('/^\d{1,9}(\.\d{1,2})?$/D',$value)) respond('Valor inválido. Usa hasta dos decimales, sin separadores de miles.',422);
        $parts=explode('.',$value); $amount=(int)$parts[0]*100+(int)str_pad($parts[1] ?? '',2,'0');
        if ($amount<0) respond('El valor no puede ser negativo.',422);
        $record=['date'=>$input['date'],'kind'=>$input['kind'],'detail'=>trim($input['detail']),'amount'=>$amount];
        $id=$input['id'] ?? null;
        if ($id===null) $db->prepare("INSERT INTO records(entity,payload) VALUES ('ledger',?)")->execute([json_encode($record,JSON_UNESCAPED_UNICODE)]);
        else {
            if (!is_int($id) || $id<=0) respond('Movimiento inválido.',422);
            $q=$db->prepare("UPDATE records SET payload=? WHERE entity='ledger' AND id=?");
            $q->execute([json_encode($record,JSON_UNESCAPED_UNICODE),$id]);
            if ($q->rowCount()===0) {
                $q=$db->prepare("SELECT id FROM records WHERE entity='ledger' AND id=?"); $q->execute([$id]);
                if (!$q->fetchColumn()) respond('El movimiento ya no existe.',404);
            }
        }
        respond(true);
    }
    if (in_array($action,['bill_edit_context','bill_edit'],true)) {
        $id=$input['id'] ?? null;
        if (!is_int($id) || $id<=0) respond('Cuenta inválida.',422);
        $db->beginTransaction();
        $q=$db->prepare('SELECT payload FROM bills WHERE id=? FOR UPDATE'); $q->execute([$id]);
        $payload=$q->fetchColumn();
        if ($payload===false) { $db->rollBack(); respond('La cuenta ya no existe.',404); }
        $bill=json_decode($payload,true,512,JSON_THROW_ON_ERROR); $bill['id']=$id;
        $revision=hash('sha256',$payload);
        if ($action==='bill_edit' && ($input['revision'] ?? '')!==$revision) { $db->rollBack(); respond('La cuenta cambió mientras la editabas. Cierra y vuelve a abrir el editor.',409); }
        $originals=[]; $editable=[];
        $billRows=$bill['rows'];
        usort($billRows,fn($a,$b)=>(int)$a['id']<=>(int)$b['id']);
        foreach ($billRows as $row) {
            $q=$db->prepare("SELECT payload FROM records WHERE entity='charges' AND id=? FOR UPDATE"); $q->execute([$row['id']]);
            $source=$q->fetchColumn();
            if ($source===false) { $db->rollBack(); respond('Una planilla de esta cuenta fue eliminada. No se puede actualizar su registro original.',409); }
            $charge=json_decode($source,true,512,JSON_THROW_ON_ERROR);
            if ((string)$charge['client_id']!==(string)$bill['client']['id']) { $db->rollBack(); respond('Una planilla ahora pertenece a otro cliente. Revisa los cobros antes de editar esta cuenta.',409); }
            $originals[(int)$row['id']]=['payload'=>$charge,'revision'=>hash('sha256',$source)];
            $editable[]=['id'=>(int)$row['id'],'date'=>$charge['date'],'sheet'=>$charge['sheet'],'value'=>number_format($charge['amount']/100,2,'.',''),'revision'=>hash('sha256',$source)];
        }
        if ($action==='bill_edit_context') {
            $catalogs=['vehicles'=>[], 'drivers'=>[]];
            foreach ($db->query("SELECT id,entity,payload FROM records WHERE entity IN ('vehicles','drivers') ORDER BY id") as $record) {
                $catalogs[$record['entity']][]=json_decode($record['payload'],true)+['id'=>(int)$record['id']];
            }
            $db->commit(); respond(['bill'=>$bill,'revision'=>$revision,'rows'=>$editable]+$catalogs);
        }
        required($input,['date']);
        if (!validDate($input['date'])) { $db->rollBack(); respond('Fecha de cuenta inválida.',422); }
        $changes=$input['rows'] ?? null;
        if (!is_array($changes) || !array_is_list($changes) || count($changes)!==count($originals)) { $db->rollBack(); respond('Debes conservar todas las planillas de la cuenta.',422); }
        $updated=[];
        foreach ($changes as $change) {
            if (!is_array($change) || !is_int($change['id'] ?? null) || !isset($originals[$change['id']]) || isset($updated[$change['id']])) { $db->rollBack(); respond('Planilla inválida o repetida.',422); }
            required($change,['date','sheet','value','revision']);
            if ($change['revision']!==$originals[$change['id']]['revision']) { $db->rollBack(); respond('Una planilla cambió mientras la editabas. Cierra y vuelve a abrir el editor.',409); }
            $value=str_replace(',','.',$change['value']);
            if (!validDate($change['date']) || !preg_match('/^\d{1,9}(\.\d{1,2})?$/D',$value)) { $db->rollBack(); respond('Fecha o valor de planilla inválido.',422); }
            $parts=explode('.',$value); $amount=(int)$parts[0]*100+(int)str_pad($parts[1] ?? '',2,'0');
            if ($amount<0) { $db->rollBack(); respond('El valor no puede ser negativo.',422); }
            $updated[$change['id']]=array_replace($originals[$change['id']]['payload'],['date'=>$change['date'],'sheet'=>trim($change['sheet']),'amount'=>$amount]);
        }
        $newRows=$input['new_rows'] ?? [];
        if (!is_array($newRows) || !array_is_list($newRows)) { $db->rollBack(); respond('Planillas adicionales inválidas.',422); }
        $additions=[];
        if ($newRows) {
            $q=$db->prepare("SELECT id FROM records WHERE entity='clients' AND id=? FOR UPDATE"); $q->execute([$bill['client']['id']]);
            if (!$q->fetchColumn()) { $db->rollBack(); respond('El cliente de la cuenta ya no existe.',409); }
        }
        foreach ($newRows as $newRow) {
            if (!is_array($newRow)) { $db->rollBack(); respond('Planilla adicional inválida.',422); }
            required($newRow,['date','sheet','vehicle_id','driver_id','value']);
            $value=str_replace(',','.',$newRow['value']);
            if (!validDate($newRow['date']) || !preg_match('/^\d{1,9}(\.\d{1,2})?$/D',$value)) { $db->rollBack(); respond('Fecha o valor de planilla inválido.',422); }
            $parts=explode('.',$value); $amount=(int)$parts[0]*100+(int)str_pad($parts[1] ?? '',2,'0');
            if ($amount<0) { $db->rollBack(); respond('El valor no puede ser negativo.',422); }
            $charge=['client_id'=>(string)$bill['client']['id'],'date'=>$newRow['date'],'sheet'=>trim($newRow['sheet']),'amount'=>$amount];
            foreach (['vehicle'=>'vehicles','driver'=>'drivers'] as $field=>$catalog) {
                if (!preg_match('/^[1-9][0-9]*$/D',$newRow[$field.'_id'])) { $db->rollBack(); respond('Vehículo o conductor inválido.',422); }
                $q=$db->prepare('SELECT payload FROM records WHERE entity=? AND id=? FOR UPDATE'); $q->execute([$catalog,$newRow[$field.'_id']]);
                $source=$q->fetchColumn();
                if ($source===false) { $db->rollBack(); respond('Vehículo o conductor inexistente.',422); }
                $charge[$field.'_id']=$newRow[$field.'_id'];
                $charge[$field]=json_decode($source,true,512,JSON_THROW_ON_ERROR)['name'];
            }
            $additions[]=$charge;
        }
        foreach ($updated as $chargeId=>$charge) $db->prepare("UPDATE records SET payload=? WHERE entity='charges' AND id=?")->execute([json_encode($charge,JSON_UNESCAPED_UNICODE),$chargeId]);
        foreach ($bill['rows'] as &$row) {
            $custom=$row['custom_values'] ?? new stdClass(); $chargeId=(int)$row['id'];
            $row=$updated[$chargeId]+['id'=>$chargeId,'custom_values'=>$custom,'client_name'=>$bill['client']['name']];
        }
        unset($row);
        foreach ($additions as $charge) {
            $db->prepare("INSERT INTO records(entity,payload) VALUES ('charges',?)")->execute([json_encode($charge,JSON_UNESCAPED_UNICODE)]);
            $custom=[];
            foreach ($bill['columns'] ?? [] as $column) {
                if (str_starts_with($column['key'],'custom_')) $custom[$column['key']]='';
            }
            $bill['rows'][]=$charge+['id'=>(int)$db->lastInsertId(),'custom_values'=>(object)$custom,'client_name'=>$bill['client']['name']];
        }
        usort($bill['rows'],fn($a,$b)=>[$a['date'],$a['id']]<=>[$b['date'],$b['id']]);
        $bill['date']=$input['date'];
        $bill['from']=min(array_column($bill['rows'],'date')); $bill['to']=max(array_column($bill['rows'],'date'));
        $bill['total']=array_sum(array_column($bill['rows'],'amount'));
        $bill['updated_at']=date(DATE_ATOM);
        $db->prepare('UPDATE bills SET payload=? WHERE id=?')->execute([json_encode($bill,JSON_UNESCAPED_UNICODE),$id]);
        $db->commit(); respond($bill);
    }
    if ($action==='bill_layout') {
        $id=$input['id'] ?? null;
        if (!is_int($id) || $id<=0) respond('Cuenta inválida.',422);
        $db->beginTransaction();
        $q=$db->prepare('SELECT payload FROM bills WHERE id=? FOR UPDATE'); $q->execute([$id]);
        $payload=$q->fetchColumn();
        if ($payload===false) { $db->rollBack(); respond('La cuenta ya no existe.',404); }
        $bill=billLayout(json_decode($payload,true,512,JSON_THROW_ON_ERROR),$input);
        $bill['id']=$id;
        $db->prepare('UPDATE bills SET payload=? WHERE id=?')->execute([json_encode($bill,JSON_UNESCAPED_UNICODE),$id]);
        $db->commit(); respond($bill);
    }
    if ($action==='delete') {
        $entity=$input['entity'] ?? null;
        $id=$input['id'] ?? null;
        if (!is_string($entity) || !in_array($entity,['clients','vehicles','drivers','charges','signatures','issuer','bills','planilla_photos','ledger'],true) || !is_int($id) || $id<=0) respond('Registro inválido',422);
        $db->beginTransaction();
        $table=$entity==='bills' ? 'bills' : 'records';
        $where=$entity==='bills' ? 'id=?' : 'id=? AND entity=?';
        $params=$entity==='bills' ? [$id] : [$id,$entity];
        $q=$db->prepare("SELECT id FROM $table WHERE $where FOR UPDATE"); $q->execute($params);
        if (!$q->fetchColumn()) { $db->rollBack(); respond('El registro ya no existe. Actualiza la lista.',404); }
        $reference=['clients'=>'client_id','vehicles'=>'vehicle_id','drivers'=>'driver_id'][$entity] ?? null;
        if ($reference!==null) {
            $q=$db->prepare("SELECT id FROM records WHERE entity='charges' AND JSON_UNQUOTE(JSON_EXTRACT(payload, '$.$reference'))=? LIMIT 1 FOR UPDATE");
            $q->execute([(string)$id]);
            if ($q->fetchColumn()) { $db->rollBack(); respond('No se puede eliminar: hay cobros asociados. Modifica o elimina primero esos cobros.',409); }
        }
        $db->prepare("DELETE FROM $table WHERE $where")->execute($params);
        $db->commit();
        respond(true);
    }
    if ($action==='save') {
        $entity=$input['entity'] ?? ''; $r=$input['record'] ?? [];
        $fields=['clients'=>['name','document','phone','email','address'],'charges'=>['date','client_id','vehicle_id','driver_id','sheet','value'],'signatures'=>['name','document'],'issuer'=>['name','document','phone','email','address','city'],'vehicles'=>['name','document'],'drivers'=>['name','document','phone']];
        if (!isset($fields[$entity]) || !is_array($r)) respond('Registro inválido',422);
        required($r,$fields[$entity]);
        if (isset($r['email']) && !filter_var($r['email'], FILTER_VALIDATE_EMAIL)) respond('Escribe un correo válido, por ejemplo nombre@correo.com.',422);
        if (isset($r['phone'])) {
            $digits = preg_replace('/[^0-9]/', '', $r['phone']);
            if (!preg_match('/^\+?[0-9 ()-]{7,25}$/D', $r['phone']) || strlen($digits)<7 || strlen($digits)>15) respond('Escribe un teléfono válido, por ejemplo 3001234567.',422);
        }
        $id=(int)($r['id'] ?? 0);
        $clean=array_intersect_key($r,array_flip($fields[$entity]));
        if ($entity==='charges') {
            if (!validDate($r['date'])) respond('Fecha inválida',422);
            // Lock referenced catalogs until the charge is saved, including against deletion.
            $db->beginTransaction();
            foreach(['vehicle'=>'vehicles','driver'=>'drivers'] as $field=>$catalog) {
                $q=$db->prepare('SELECT payload FROM records WHERE entity=? AND id=? FOR UPDATE');$q->execute([$catalog,$r[$field.'_id']]);$record=$q->fetchColumn();
                if(!$record) respond('Vehículo o conductor inexistente',422);
                $clean[$field]=json_decode($record,true)['name'];
            }
            $value=str_replace(',','.',$r['value']);
            if(!preg_match('/^\d{1,9}(\.\d{1,2})?$/D',$value)) respond('Valor inválido. Usa máximo dos decimales y sin separadores de miles.',422);
            $parts=explode('.',$value); $clean['amount']=(int)$parts[0]*100+(int)str_pad($parts[1] ?? '',2,'0'); unset($clean['value']);
            if($clean['amount']<0) respond('El valor no puede ser negativo',422);
            $q=$db->prepare("SELECT id FROM records WHERE entity='clients' AND id=? FOR UPDATE");$q->execute([$r['client_id']]);if(!$q->fetchColumn()) respond('Cliente inexistente',422);
        }
        if ($entity==='signatures') {
            $image=base64_decode($r['image'] ?? '',true);
            $size=$image === false ? false : @getimagesizefromstring($image);
            if(!$size || strlen($image)>2097152 || !in_array($size['mime'],['image/png','image/jpeg'],true) || $size[0]>6000 || $size[1]>6000) respond('Firma inválida. Usa PNG o JPG de hasta 2 MB y 6000 píxeles.',422);
            $clean['image']=base64_encode($image);
        }
        if ($entity==='issuer') { $id=(int)$db->query("SELECT id FROM records WHERE entity='issuer' LIMIT 1")->fetchColumn(); }
        $payload=json_encode($clean,JSON_UNESCAPED_UNICODE);
        if($id) { $q=$db->prepare('SELECT id FROM records WHERE id=? AND entity=?');$q->execute([$id,$entity]);if(!$q->fetchColumn()) respond('Registro inexistente',404);$db->prepare('UPDATE records SET payload=? WHERE id=? AND entity=?')->execute([$payload,$id,$entity]); }
        else $db->prepare('INSERT INTO records(entity,payload) VALUES (?,?)')->execute([$entity,$payload]);
        if ($db->inTransaction()) $db->commit();
        respond(true);
    }
    if($action==='generate') {
        required($input,['client_id','signature_id','from','to']);
        if(!validDate($input['from']) || !validDate($input['to']) || $input['from']>$input['to']) respond('Periodo inválido',422);
        $db->beginTransaction();
        // A consistent snapshot preserves the exact source data used in the account.
        $s=state($db);
        $clients=array_column($s['clients'],null,'id');$signatures=array_column($s['signatures'],null,'id');
        if(!isset($clients[$input['client_id']],$signatures[$input['signature_id']]) || !is_array($s['issuer'])) respond('Completa cliente, firma y emisor',422);
        $rows=array_values(array_filter($s['charges'],fn($r)=>(string)$r['client_id']===$input['client_id'] && $r['date']>=$input['from'] && $r['date']<=$input['to']));
        if(!$rows) respond('No hay cobros para el cliente en ese periodo',422);
        usort($rows,fn($a,$b)=>[$a['date'],$a['id']]<=>[$b['date'],$b['id']]);
        $bill=['client'=>$clients[$input['client_id']],'signature'=>$signatures[$input['signature_id']],'issuer'=>$s['issuer'],'rows'=>$rows,'total'=>array_sum(array_column($rows,'amount')),'concept'=>'RUTA: '.$clients[$input['client_id']]['name'],'from'=>$input['from'],'to'=>$input['to'],'date'=>date('Y-m-d'),
            'template'=>'equivalent_v1','document_city'=>'CARTAGENA',
            'recipient'=>['name'=>'COMERCIALIZADORA MULTIDROGAS DE COLOMBIA S.A.S.','document'=>'823.000.097'],
            'legal_legend'=>'ART.3ro. decreto 522 de marzo de 2003.'];
        $layoutInput=$input;
        $layoutInput['columns'] ??= [['key'=>'date','label'=>'Fecha'],['key'=>'sheet','label'=>'Planilla'],['key'=>'amount','label'=>'Valor']];
        $bill=billLayout($bill,$layoutInput);
        $db->exec("INSERT INTO bills(payload) VALUES ('{}')"); $id=(int)$db->lastInsertId();$bill['id']=$id;$bill['number']='CC-'.$id;
        $db->prepare('UPDATE bills SET payload=? WHERE id=?')->execute([json_encode($bill,JSON_UNESCAPED_UNICODE),$id]);$db->commit();respond($bill);
    }
    respond('Acción desconocida',404);
} catch (JsonException $e) { respond('JSON inválido',400); }
catch (PDOException $e) {
    if(isset($db) && $db->inTransaction()) $db->rollBack();
    error_log((string)$e);
    $driverCode = (int)($e->errorInfo[1] ?? 0);
    $message = match ($driverCode) {
        1045 => 'DB-01: MySQL rechazó el usuario o la contraseña. Revisa las credenciales MySQL en grupocg-config.php.',
        1044 => 'DB-02: El usuario MySQL no tiene permiso para esa base de datos. Revisa su asignación en Hostinger.',
        1049 => 'DB-03: La base de datos configurada no existe. Revisa dbname en grupocg-config.php.',
        1146 => 'DB-04: Falta una tabla requerida en la base de datos. Revisa el esquema instalado; no borres las tablas existentes.',
        1054, 1136 => 'DB-05: La estructura de las tablas no coincide con la aplicación. Revisa el esquema instalado.',
        2002, 2003, 2005 => 'DB-06: No se pudo conectar con MySQL. Revisa el servidor y el puerto configurados.',
        default => 'DB-07: Falló una operación de base de datos. Revisa el registro de errores PHP en Hostinger.',
    };
    if (str_contains($e->getMessage(), 'could not find driver')) $message = 'DB-08: Activa la extensión pdo_mysql en la configuración PHP de Hostinger.';
    respond($message,500);
}
catch (ParseError $e) { error_log((string)$e); respond('CONFIG-04: Hay un error de sintaxis en la configuración PHP. Revisa comillas, comas y punto y coma en grupocg-config.php.',500); }
catch (Throwable $e) { if(isset($db) && $db->inTransaction()) $db->rollBack(); error_log((string)$e); respond('No se pudo procesar la solicitud. Revisa la configuración del servidor.',500); }
