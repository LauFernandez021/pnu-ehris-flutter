<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    public function index(Request $request)
    {
        $filters = $request->validate([
            'action' => 'nullable|string|max:100',
            'subject_type' => 'nullable|string|max:255',
            'actor_id' => 'nullable|integer',
            'subject_id' => 'nullable|integer',
            'from' => 'nullable|date',
            'to' => 'nullable|date|after_or_equal:from',
        ]);

        $logs = AuditLog::query()
            ->with('user:id,name,email')
            ->when($filters['action'] ?? null, fn ($query, $action) => $query
                ->where('action', 'like', "%{$action}%"))
            ->when($filters['subject_type'] ?? null, fn ($query, $type) => $query
                ->where('subject_type', 'like', "%{$type}%"))
            ->when($filters['actor_id'] ?? null, fn ($query, $id) => $query
                ->where('user_id', $id))
            ->when($filters['subject_id'] ?? null, fn ($query, $id) => $query
                ->where('subject_id', $id))
            ->when($filters['from'] ?? null, fn ($query, $date) => $query
                ->whereDate('created_at', '>=', $date))
            ->when($filters['to'] ?? null, fn ($query, $date) => $query
                ->whereDate('created_at', '<=', $date))
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate(min(max((int) $request->query('per_page', 50), 1), 100));

        return $logs->through(fn (AuditLog $log) => [
            'id' => $log->id,
            'actor' => $log->user?->only(['id', 'name', 'email']),
            'action' => $log->action,
            'subject_type' => $log->subject_type,
            'subject_id' => $log->subject_id,
            'meta' => $log->meta,
            'ip' => $log->ip,
            'created_at' => $log->created_at,
        ]);
    }
}
