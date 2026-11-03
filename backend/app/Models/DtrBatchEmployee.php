<?php

namespace App\Models;

use Database\Factories\DtrBatchEmployeeFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DtrBatchEmployee extends Model
{
    /** @use HasFactory<DtrBatchEmployeeFactory> */
    use HasFactory;

    protected $fillable = [
        'dtr_batch_id',
        'employee_id',
        'employee_no',
        'employee_name',
        'designation',
    ];

    public function batch(): BelongsTo
    {
        return $this->belongsTo(DtrBatch::class, 'dtr_batch_id');
    }

    public function entries(): HasMany
    {
        return $this->hasMany(DtrEntry::class)->orderBy('entry_date');
    }
}
