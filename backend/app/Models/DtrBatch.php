<?php

namespace App\Models;

use Database\Factories\DtrBatchFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class DtrBatch extends Model
{
    /** @use HasFactory<DtrBatchFactory> */
    use HasFactory;

    use SoftDeletes;

    protected $fillable = [
        'dtr_code',
        'period_type',
        'pay_period',
        'year',
        'month',
        'start_date',
        'end_date',
        'transaction_date',
        'remarks',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'year' => 'integer',
            'month' => 'integer',
            'start_date' => 'date',
            'end_date' => 'date',
            'transaction_date' => 'date',
        ];
    }

    public function employees(): HasMany
    {
        return $this->hasMany(DtrBatchEmployee::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
