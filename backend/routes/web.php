<?php

use App\Http\Controllers\Api\ZktecoAdmsController;
use Illuminate\Support\Facades\Route;

Route::match(['get', 'post'], '/iclock/{endpoint?}', [ZktecoAdmsController::class, 'handle'])
    ->where('endpoint', 'cdata|getrequest|devicecmd')
    ->middleware('throttle:120,1');

Route::get('/', function () {
    return view('welcome');
});
