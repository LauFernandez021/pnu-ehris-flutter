<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class PassSlip extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'employee_id',
        'slip_type',
        'slip_date',
        'time_out',
        'time_in',
        'destination',
        'reason',
        'status',
        'reviewed_by',
        'reviewed_at',
        'review_note',
    ];

    protected $casts = ['reviewed_at' => 'datetime'];

    public function employee()
    {
        return $this->belongsTo(Employee::class)->withTrashed();
    }
}
