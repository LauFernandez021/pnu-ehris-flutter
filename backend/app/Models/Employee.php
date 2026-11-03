<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Employee extends Model
{
    use HasFactory;
    use SoftDeletes;

    protected $fillable = [
        'user_id',
        'department_id',
        'employee_no',
        'rfid_card_number',
        'first_name',
        'last_name',
        'position',
        'date_hired',
        'status',
        'device_user_id',
        'self_registered',
        'id_photo_path',
        'selfie_path',
        'reviewed_by',
        'reviewed_at',
        'review_note',
    ];

    protected $hidden = ['id_photo_path', 'selfie_path'];

    protected $appends = ['role', 'has_documents'];

    protected $casts = ['self_registered' => 'boolean', 'reviewed_at' => 'datetime'];

    protected static function booted(): void
    {
        static::created(function (Employee $employee): void {
            $employee->forceFill([
                'badge_number' => 'HRMS-'.str_pad((string) $employee->id, 6, '0', STR_PAD_LEFT),
            ])->saveQuietly();
        });
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function department()
    {
        return $this->belongsTo(Department::class)->withTrashed();
    }

    public function attendances()
    {
        return $this->hasMany(Attendance::class);
    }

    public function getRoleAttribute(): ?string
    {
        return $this->user?->getRoleNames()->first();
    }

    public function getHasDocumentsAttribute(): bool
    {
        return (bool) ($this->id_photo_path && $this->selfie_path);
    }
}
