<?php

use App\Http\Controllers\Api\AttendanceController;
use App\Http\Controllers\Api\AuditLogController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\DepartmentController;
use App\Http\Controllers\Api\DtrBatchController;
use App\Http\Controllers\Api\EmployeeController;
use App\Http\Controllers\Api\LeaveController;
use App\Http\Controllers\Api\PassSlipController;
use App\Http\Controllers\Api\ZktecoEventController;
use App\Http\Middleware\EnsurePasswordChanged;
use Illuminate\Support\Facades\Route;

// Public
Route::get('/login', fn () => response()->json(['message' => 'Unauthenticated.'], 401))
    ->name('login');

Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:10,1');
Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:5,1');
Route::get('/app-version', fn () => [
    'latest' => config('hrms.app.latest'),
    'minimum' => config('hrms.app.minimum'),
    'apk_url' => config('hrms.app.apk_url'),
    'notes' => config('hrms.app.notes'),
    'desktop_latest' => config('hrms.app.desktop_latest'),
    'desktop_minimum' => config('hrms.app.desktop_minimum'),
    'desktop_url' => config('hrms.app.desktop_url'),
])->middleware('throttle:30,1');

// Everything below needs a valid token
Route::middleware(['auth:sanctum', 'throttle:120,1', EnsurePasswordChanged::class])->group(function () {
    Route::get('/me', [AuthController::class, 'me'])->name('api.me');
    Route::post('/me/password', [AuthController::class, 'changePassword'])->name('api.me.password');
    Route::post('/logout', [AuthController::class, 'logout'])->name('api.logout');

    Route::middleware('role:admin')->get('/audit-logs', [AuditLogController::class, 'index']);

    Route::get('/departments', [DepartmentController::class, 'index']);

    // Any signed-in employee
    Route::get('/me/attendance', [AttendanceController::class, 'mine']);
    Route::post('/me/attendance/punch', [AttendanceController::class, 'punch']);
    Route::post('/me/attendance/check-in', [AttendanceController::class, 'checkIn']);
    Route::post('/me/attendance/check-out', [AttendanceController::class, 'checkOut']);
    Route::get('/me/dtr-batches', [DtrBatchController::class, 'mine']);
    Route::get('/me/dtr-batches/{dtrBatch}', [DtrBatchController::class, 'mineShow']);

    Route::get('/leave-types', [LeaveController::class, 'types']);
    Route::get('/me/leave-balances', [LeaveController::class, 'myBalances']);
    Route::get('/me/leave-requests', [LeaveController::class, 'myRequests']);
    Route::post('/leave-requests', [LeaveController::class, 'store']);
    Route::post('/leave-requests/{leaveRequest}/cancel', [LeaveController::class, 'cancel']);
    Route::get('/leave-requests/{leaveRequest}/attachment', [LeaveController::class, 'attachment']);

    Route::get('/me/pass-slips', [PassSlipController::class, 'mine']);
    Route::post('/pass-slips', [PassSlipController::class, 'store']);
    Route::post('/pass-slips/{passSlip}/cancel', [PassSlipController::class, 'cancel']);

    // Admin, HR and managers
    Route::middleware('role:admin|hr|manager')->group(function () {
        Route::get('/leave-requests', [LeaveController::class, 'index']);
        Route::post('/leave-requests/{leaveRequest}/approve', [LeaveController::class, 'approve']);
        Route::post('/leave-requests/{leaveRequest}/reject', [LeaveController::class, 'reject']);

        Route::get('/pass-slips', [PassSlipController::class, 'index']);
        Route::post('/pass-slips/{passSlip}/approve', [PassSlipController::class, 'approve']);
        Route::post('/pass-slips/{passSlip}/reject', [PassSlipController::class, 'reject']);

        Route::delete('/leave-requests/{leaveRequest}', [LeaveController::class, 'destroy']);
        Route::delete('/pass-slips/{passSlip}', [PassSlipController::class, 'destroy']);
    });

    // Admin and HR only
    Route::middleware('role:admin|hr')->group(function () {
        Route::get('/biometric/events', [ZktecoEventController::class, 'index']);
        Route::get('/dtr-employees', [DtrBatchController::class, 'employees']);
        Route::get('/dtr-batches', [DtrBatchController::class, 'index']);
        Route::post('/dtr-batches', [DtrBatchController::class, 'store']);
        Route::get('/dtr-batches/{dtrBatch}', [DtrBatchController::class, 'show']);
        Route::delete('/dtr-batches/{dtrBatch}', [DtrBatchController::class, 'destroy']);
        Route::post('/dtr-batches/{dtrBatchId}/restore', [DtrBatchController::class, 'restore']);

        Route::apiResource('employees', EmployeeController::class);
        Route::post('/employees/{employeeId}/restore', [EmployeeController::class, 'restore']);
        Route::post('/employees/{employee}/approve', [EmployeeController::class, 'approve']);
        Route::post('/employees/{employee}/reject', [EmployeeController::class, 'reject']);
        Route::get('/employees/{employee}/documents/{kind}', [EmployeeController::class, 'document']);

        Route::post('/departments', [DepartmentController::class, 'store']);
        Route::put('/departments/{department}', [DepartmentController::class, 'update']);
        Route::delete('/departments/{department}', [DepartmentController::class, 'destroy']);
        Route::post('/departments/{departmentId}/restore', [DepartmentController::class, 'restore']);

        Route::get('/settings/leave-types', [LeaveController::class, 'manageTypes']);
        Route::post('/settings/leave-types', [LeaveController::class, 'storeType']);
        Route::put('/settings/leave-types/{leaveTypeId}', [LeaveController::class, 'updateType']);
        Route::delete('/settings/leave-types/{leaveTypeId}', [LeaveController::class, 'destroyType']);
        Route::post('/settings/leave-types/{leaveTypeId}/restore', [LeaveController::class, 'restoreType']);
        Route::post('/leave-requests/{leaveRequestId}/restore', [LeaveController::class, 'restore']);
        Route::post('/pass-slips/{passSlipId}/restore', [PassSlipController::class, 'restore']);
        Route::get('/dashboard/summary', [DashboardController::class, 'summary']);
        Route::get('/attendance', [AttendanceController::class, 'index']);
    });
});
