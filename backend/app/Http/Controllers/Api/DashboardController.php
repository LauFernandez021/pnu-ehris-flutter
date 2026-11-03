<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Department;
use App\Models\Employee;
use App\Models\LeaveRequest;
use App\Models\PassSlip;

class DashboardController extends Controller
{
    public function summary()
    {
        $today = now()->toDateString();

        return [
            'active_employees' => Employee::where('status', 'active')->count(),
            'pending_accounts' => Employee::where('status', 'pending')->count(),
            'departments' => Department::count(),
            'pending_leave' => LeaveRequest::where('status', 'pending')->count(),
            'on_leave_today' => LeaveRequest::where('status', 'approved')
                ->where('start_date', '<=', $today)
                ->where('end_date', '>=', $today)->count(),
            'pending_pass_slips' => PassSlip::where('status', 'pending')->count(),
            'pass_slips_today' => PassSlip::where('status', 'approved')->where('slip_date', $today)->count(),
        ];
    }
}
