<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LeaveBalance extends Model
{
    protected $fillable = ['employee_id', 'leave_type_id', 'year', 'allocated', 'used'];
    protected $casts = ['allocated' => 'float', 'used' => 'float'];
}
