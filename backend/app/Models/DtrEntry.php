<?php

namespace App\Models;

use Database\Factories\DtrEntryFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DtrEntry extends Model
{
    /** @use HasFactory<DtrEntryFactory> */
    use HasFactory;

    protected $fillable = [
        'dtr_batch_employee_id',
        'entry_date',
        'status',
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
            'entry_date' => 'date',
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

    public function batchEmployee(): BelongsTo
    {
        return $this->belongsTo(DtrBatchEmployee::class, 'dtr_batch_employee_id');
    }
}
