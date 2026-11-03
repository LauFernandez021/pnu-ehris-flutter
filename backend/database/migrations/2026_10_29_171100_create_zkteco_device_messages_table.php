<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('zkteco_device_messages')) {
            Schema::create('zkteco_device_messages', function (Blueprint $table): void {
                $table->id();
                $table->string('device_serial', 64);
                $table->string('message_type', 30);
                $table->longText('body');
                $table->char('payload_hash', 64);
                $table->timestamp('received_at');
                $table->timestamps();
            });
        }

        Schema::table('zkteco_device_messages', function (Blueprint $table): void {
            $table->unique(
                ['device_serial', 'message_type', 'payload_hash'],
                'zkt_device_msg_dedup_unique'
            );
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('zkteco_device_messages');
    }
};
