<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ZktecoDeviceMessage extends Model
{
    protected $fillable = [
        'device_serial',
        'message_type',
        'body',
        'payload_hash',
        'received_at',
    ];

    protected $hidden = ['body', 'payload_hash'];

    protected function casts(): array
    {
        return [
            'received_at' => 'datetime',
            'body' => 'encrypted',
        ];
    }
}
