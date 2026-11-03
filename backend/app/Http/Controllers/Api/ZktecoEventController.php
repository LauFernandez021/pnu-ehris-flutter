<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ZktecoAttendanceEvent;
use Illuminate\Http\Request;

class ZktecoEventController extends Controller
{
    public function index(Request $request)
    {
        $query = ZktecoAttendanceEvent::query()
            ->with('employee:id,employee_no,first_name,last_name')
            ->latest('punch_at');

        if ($request->query('mapping') === 'unmapped') {
            $query->whereNull('employee_id');
        } elseif ($request->query('mapping') === 'mapped') {
            $query->whereNotNull('employee_id');
        }

        return $query->paginate(min((int) $request->query('per_page', 50), 200));
    }
}
