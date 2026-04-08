<?php
use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

if (file_exists($maintenance = __DIR__.'/../core/storage/framework/maintenance.php')) {
    require $maintenance;
}

require __DIR__.'/../core/vendor/autoload.php';

(require_once __DIR__.'/../core/bootstrap/app.php')
    ->handleRequest(Request::capture());
