<?php
declare(strict_types=1);
date_default_timezone_set('America/Bogota');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
function respond($data, int $status = 200): never { http_response_code($status); echo json_encode($status === 200 ? ['data'=>$data] : ['error'=>$data], JSON_UNESCAPED_UNICODE); exit; }
function required(array $r, array $keys): void { foreach ($keys as $key) if (!isset($r[$key]) || !is_string($r[$key]) || trim($r[$key]) === '' || strlen($r[$key]) > 500) respond('Campo inválido: '.$key, 422); }
function validDate(string $v): bool { $d = DateTimeImmutable::createFromFormat('!Y-m-d', $v); return $d && $d->format('Y-m-d') === $v; }
try {
    // Deployed at public_html/grupocg/api/index.php; config stays outside the web root.
    $configPath = getenv('GRUPO_CG_CONFIG') ?: dirname(__DIR__, 3).'/grupocg-config.php';
    $config = require $configPath;
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
        $db->prepare('INSERT INTO sessions VALUES (?,?,DATE_ADD(NOW(),INTERVAL 8 HOUR))')->execute([hash('sha256',$token),$user['id']]);
        respond(['token'=>$token]);
    }
    $auth=$_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    $hash=hash('sha256',str_starts_with($auth,'Bearer ') ? substr($auth,7) : '');
    $q=$db->prepare('SELECT user_id FROM sessions WHERE token_hash=? AND expires_at>NOW()'); $q->execute([$hash]);
    if (!$q->fetchColumn()) respond('Inicia sesión de nuevo',401);
    if ($action==='logout') { $db->prepare('DELETE FROM sessions WHERE token_hash=?')->execute([$hash]); respond(true); }
    function state(PDO $db): array {
        $result=['clients'=>[],'charges'=>[],'signatures'=>[],'issuer'=>new stdClass(),'bills'=>[],'vehicles'=>[],'drivers'=>[]];
        foreach($db->query('SELECT * FROM records ORDER BY id DESC') as $row) { $v=json_decode($row['payload'],true); $v['id']=(int)$row['id']; if($row['entity']==='issuer') $result['issuer']=$v; else $result[$row['entity']][]=$v; }
        $names=array_column($result['clients'],'name','id');
        foreach($result['charges'] as &$r) $r['client_name']=$names[$r['client_id']] ?? '';
        unset($r);
        foreach($db->query('SELECT payload FROM bills ORDER BY id DESC') as $row) $result['bills'][]=json_decode($row['payload'],true);
        return $result;
    }
    if ($action==='state') respond(state($db));
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
            foreach(['vehicle'=>'vehicles','driver'=>'drivers'] as $field=>$catalog) {
                $q=$db->prepare('SELECT payload FROM records WHERE entity=? AND id=?');$q->execute([$catalog,$r[$field.'_id']]);$record=$q->fetchColumn();
                if(!$record) respond('Vehículo o conductor inexistente',422);
                $clean[$field]=json_decode($record,true)['name'];
            }
            $value=str_replace(',','.',$r['value']);
            if(!preg_match('/^\d{1,9}(\.\d{1,2})?$/D',$value)) respond('Valor inválido. Usa máximo dos decimales y sin separadores de miles.',422);
            $parts=explode('.',$value); $clean['amount']=(int)$parts[0]*100+(int)str_pad($parts[1] ?? '',2,'0'); unset($clean['value']);
            if($clean['amount']<=0) respond('El valor debe ser mayor que cero',422);
            $q=$db->prepare("SELECT id FROM records WHERE entity='clients' AND id=?");$q->execute([$r['client_id']]);if(!$q->fetchColumn()) respond('Cliente inexistente',422);
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
        respond(true);
    }
    if($action==='generate') {
        required($input,['client_id','signature_id','concept','from','to']);
        if(!validDate($input['from']) || !validDate($input['to']) || $input['from']>$input['to']) respond('Periodo inválido',422);
        $db->beginTransaction();
        // A consistent snapshot preserves the exact source data used in the account.
        $s=state($db);
        $clients=array_column($s['clients'],null,'id');$signatures=array_column($s['signatures'],null,'id');
        if(!isset($clients[$input['client_id']],$signatures[$input['signature_id']]) || !is_array($s['issuer'])) respond('Completa cliente, firma y emisor',422);
        $rows=array_values(array_filter($s['charges'],fn($r)=>(string)$r['client_id']===$input['client_id'] && $r['date']>=$input['from'] && $r['date']<=$input['to']));
        if(!$rows) respond('No hay cobros para el cliente en ese periodo',422);
        usort($rows,fn($a,$b)=>[$a['date'],$a['id']]<=>[$b['date'],$b['id']]);
        $bill=['client'=>$clients[$input['client_id']],'signature'=>$signatures[$input['signature_id']],'issuer'=>$s['issuer'],'rows'=>$rows,'total'=>array_sum(array_column($rows,'amount')),'concept'=>$input['concept'],'from'=>$input['from'],'to'=>$input['to'],'date'=>date('Y-m-d')];
        $db->exec("INSERT INTO bills(payload) VALUES ('{}')"); $id=(int)$db->lastInsertId();$bill['number']='CG-'.str_pad((string)$id,6,'0',STR_PAD_LEFT);
        $db->prepare('UPDATE bills SET payload=? WHERE id=?')->execute([json_encode($bill,JSON_UNESCAPED_UNICODE),$id]);$db->commit();respond($bill);
    }
    respond('Acción desconocida',404);
} catch (JsonException $e) { respond('JSON inválido',400); }
catch (Throwable $e) { if(isset($db) && $db->inTransaction()) $db->rollBack(); error_log((string)$e); respond('No se pudo procesar la solicitud. Revisa la configuración del servidor.',500); }
