<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ZktecoAttendanceEvent extends Model
{
    protected $fillable = [
        'device_serial',
        'device_user_id',
        'employee_id',
        'punch_at',
        'verify_type',
        'punch_state',
        'work_code',
        'raw_line',
        'event_hash',
        'received_at',
    ];

    protected $hidden = ['raw_line', 'event_hash'];

    protected function casts(): array
    {
        return [
            'punch_at' => 'datetime',
            'received_at' => 'datetime',
            'raw_line' => 'encrypted',
        ];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class)->withTrashed();
    }
}
