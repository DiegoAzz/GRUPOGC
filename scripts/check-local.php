<?php
declare(strict_types=1);
// Runs against the isolated local API only. Leaves clearly labelled sample records for manual testing.
if (PHP_SAPI !== 'cli') exit(1);
$token = '';
function callApi(array $body, int $expected = 200): mixed {
    global $token;
    $headers = "Content-Type: application/json\r\nOrigin: http://localhost:5300\r\n";
    if ($token !== '') $headers .= "Authorization: Bearer $token\r\n";
    $context = stream_context_create(['http'=>['method'=>'POST','header'=>$headers,'content'=>json_encode($body),'ignore_errors'=>true,'timeout'=>10]]);
    $response = file_get_contents('http://127.0.0.1:8085/index.php', false, $context);
    if (!str_contains($http_response_header[0], ' '.$expected.' ')) throw new RuntimeException('Unexpected HTTP status: '.$http_response_header[0].' '.$response);
    if (!in_array('Access-Control-Allow-Origin: http://localhost:5300', $http_response_header, true)) throw new RuntimeException('CORS local incorrecto');
    $result = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
    return $result['data'] ?? $result['error'];
}
function verify(bool $ok, string $message): void { if (!$ok) throw new RuntimeException($message); }
function saveRecord(string $entity, array $record): void { callApi(['action'=>'save','entity'=>$entity,'record'=>$record]); }
callApi(['action'=>'state'], 401);
$token = callApi(['action'=>'login','email'=>'admin@grupocg.local','password'=>'GrupoCG-Local2026!'])['token'];
$state = callApi(['action'=>'state']);
foreach (['clients','vehicles','drivers','charges','signatures','bills'] as $entity) {
    if (count($state[$entity]) > 0) { echo "Acceso, estado y CORS correctos. Ya hay datos: no se modificaron registros.\n"; callApi(['action'=>'logout']); exit; }
}
saveRecord('clients', ['name'=>'Cliente de prueba local','document'=>'900000001','phone'=>'3000000000','email'=>'cliente@example.com','address'=>'Dirección de prueba']);
saveRecord('vehicles', ['name'=>'ABC123','document'=>'Vehículo de prueba']);
saveRecord('drivers', ['name'=>'Conductor de prueba','document'=>'100000001','phone'=>'3000000000']);
saveRecord('issuer', ['name'=>'Emisor de prueba Grupo CG','document'=>'100000002','phone'=>'3000000000','email'=>'emisor@example.com','address'=>'Dirección de prueba','city'=>'Cartagena']);
$image = imagecreatetruecolor(480,100);
imagefill($image,0,0,imagecolorallocate($image,255,255,255));
imagestring($image,5,30,40,'FIRMA DE PRUEBA - SIN VALIDEZ',imagecolorallocate($image,0,60,120));
ob_start(); imagepng($image); $png=ob_get_clean();
file_put_contents(dirname(__DIR__).'/.local/firma-prueba.png', $png);
saveRecord('signatures', ['name'=>'Firmante de prueba','document'=>'100000002','image'=>base64_encode($png)]);
$state = callApi(['action'=>'state']);
$record = ['date'=>date('Y-m-d'),'client_id'=>(string)$state['clients'][0]['id'],'vehicle_id'=>(string)$state['vehicles'][0]['id'],'driver_id'=>(string)$state['drivers'][0]['id'],'sheet'=>'LOCAL-001','value'=>'25000,50'];
callApi(['action'=>'save','entity'=>'charges','record'=>array_replace($record,['value'=>'-10'])],422);
callApi(['action'=>'save','entity'=>'charges','record'=>array_replace($record,['date'=>'2026-02-30'])],422);
saveRecord('charges', $record);
saveRecord('charges', array_replace($record,['sheet'=>'LOCAL-002','value'=>'40000']));
$request = ['action'=>'generate','client_id'=>$record['client_id'],'signature_id'=>(string)$state['signatures'][0]['id'],'concept'=>'Transporte de prueba local','from'=>$record['date'],'to'=>$record['date']];
callApi(array_replace($request,['from'=>'2000-01-01','to'=>'2000-01-02']),422);
$bill = callApi($request);
verify($bill['total'] === 6500050, 'El total decimal es incorrecto');
verify(count($bill['rows']) === 2, 'El rango no es inclusivo');
verify($bill['signature']['image'] === base64_encode($png), 'No se conservó la firma');
$client = $state['clients'][0];
saveRecord('clients', array_replace($client,['name'=>'Nombre temporal para comprobar historial']));
$updated = callApi(['action'=>'state']);
verify($updated['bills'][0]['client']['name'] === $client['name'], 'El historial cambió al editar el cliente');
saveRecord('clients', $client);
callApi(['action'=>'logout']);
callApi(['action'=>'state'],401);
echo "OK: acceso, CORS, catálogos, firma, validación, fechas inclusivas, total decimal, historial inmutable y cierre de sesión.\n";
echo "Se dejaron dos cobros y una cuenta de prueba para revisar desde Chrome.\n";
