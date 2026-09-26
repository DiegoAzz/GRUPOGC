<?php
// Execute only from the server CLI, outside public_html.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
$config=require __DIR__.'/grupocg-config.php';
$email=$argv[1] ?? '';
if(!filter_var($email,FILTER_VALIDATE_EMAIL)) exit("Usage: php create_user.php email@example.com\nPassword is read from standard input.\n");
$password=trim(fgets(STDIN));
if(strlen($password)<12) exit("Use at least 12 characters.\n");
$db=new PDO($config['dsn'],$config['user'],$config['password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
$db->prepare('INSERT INTO users(email,password_hash) VALUES (?,?)')->execute([$email,password_hash($password,PASSWORD_DEFAULT)]);
echo "User created.\n";
