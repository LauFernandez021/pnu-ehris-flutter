<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class LeaveRequest extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'employee_id',
        'leave_type_id',
        'start_date',
        'end_date',
        'days',
        'reason',
        'status',
        'reviewed_by',
        'reviewed_at',
        'review_note',
        'attachment_path',
        'attachment_name',
    ];

    protected $hidden = ['attachment_path'];

    protected $appends = ['has_attachment'];

    protected $casts = ['days' => 'float', 'reviewed_at' => 'datetime'];

    public function employee()
    {
        return $this->belongsTo(Employee::class)->withTrashed();
    }

    public function leaveType()
    {
        return $this->belongsTo(LeaveType::class)->withTrashed();
    }

    public function getHasAttachmentAttribute(): bool
    {
        return (bool) $this->attachment_path;
    }
}
