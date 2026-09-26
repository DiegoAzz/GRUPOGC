<?php
declare(strict_types=1);
// Only provisions the isolated database on this computer. Never deploy this script.
if (PHP_SAPI !== 'cli') exit(1);
$root = dirname(__DIR__);
$path = $root.'/.local/config.php';
$options = [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION];
if (!file_exists($path)) {
    $db = new PDO('mysql:host=127.0.0.1;port=3307;charset=utf8mb4', 'root', '', $options);
    $password = bin2hex(random_bytes(24));
    $db->exec('CREATE DATABASE IF NOT EXISTS grupo_cg_local CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
    $db->exec("CREATE USER IF NOT EXISTS 'grupo_cg_local'@'127.0.0.1' IDENTIFIED BY ".$db->quote($password));
    $db->exec("ALTER USER 'grupo_cg_local'@'127.0.0.1' IDENTIFIED BY ".$db->quote($password));
    $db->exec("GRANT ALL PRIVILEGES ON grupo_cg_local.* TO 'grupo_cg_local'@'127.0.0.1'");
    $config = ['dsn'=>'mysql:host=127.0.0.1;port=3307;dbname=grupo_cg_local;charset=utf8mb4','user'=>'grupo_cg_local','password'=>$password,'origin'=>'http://localhost:5300'];
    file_put_contents($path, "<?php\nreturn ".var_export($config, true).";\n");
    // Save this private local administration credential before changing the root password.
    $adminPassword = bin2hex(random_bytes(24));
    file_put_contents($root.'/.local/mysql-admin.json', json_encode(['user'=>'root','password'=>$adminPassword]));
    $db->exec("ALTER USER 'root'@'localhost' IDENTIFIED BY ".$db->quote($adminPassword));
}
$config = require $path;
$db = new PDO($config['dsn'], $config['user'], $config['password'], $options);
$count = (int)$db->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='grupo_cg_local'")->fetchColumn();
if ($count === 0) $db->exec(file_get_contents($root.'/backend/schema.sql'));
$q = $db->prepare('SELECT id FROM users WHERE email=?');
$q->execute(['admin@grupocg.local']);
if (!$q->fetchColumn()) {
    $db->prepare('INSERT INTO users(email,password_hash) VALUES (?,?)')->execute(['admin@grupocg.local', password_hash('GrupoCG-Local2026!', PASSWORD_DEFAULT)]);
}
echo "Base local y usuario listos.\n";
