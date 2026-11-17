<?php

return [
    'admin_email' => getenv('ADMIN_EMAIL') ?: '',
    'dsn' => 'mysql:host=' . (getenv('DB_HOST') ?: '10.0.1.1')
        . ';dbname=' . (getenv('DB_NAME') ?: 'grupocg')
        . ';charset=utf8mb4',
    'user' => getenv('DB_USER') ?: 'grupocg_app',
    'password' => getenv('DB_PASS') ?: '',
    'origin' => getenv('APP_ORIGIN') ?: 'https://grupocg.appzplay.online',
];
