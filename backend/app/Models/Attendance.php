<?php

namespace App\Models;

use Database\Factories\AttendanceFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Attendance extends Model
{
    /** @use HasFactory<AttendanceFactory> */
    use HasFactory;

    protected $fillable = [
        'employee_id',
        'attendance_date',
        'check_in_at',
        'check_out_at',
        'am_in_at',
        'am_out_at',
        'pm_in_at',
        'pm_out_at',
        'ot_in_at',
        'ot_out_at',
        'worked_minutes',
    ];

    protected function casts(): array
    {
        return [
            'attendance_date' => 'date',
            'check_in_at' => 'datetime',
            'check_out_at' => 'datetime',
            'am_in_at' => 'datetime',
            'am_out_at' => 'datetime',
            'pm_in_at' => 'datetime',
            'pm_out_at' => 'datetime',
            'ot_in_at' => 'datetime',
            'ot_out_at' => 'datetime',
            'worked_minutes' => 'integer',
        ];
    }

    public function employee()
    {
        return $this->belongsTo(Employee::class)->withTrashed();
    }
}
