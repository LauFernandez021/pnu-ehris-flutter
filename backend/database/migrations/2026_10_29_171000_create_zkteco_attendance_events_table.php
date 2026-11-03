<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('zkteco_attendance_events', function (Blueprint $table): void {
            $table->id();
            $table->string('device_serial', 64);
            $table->string('device_user_id', 100);
            $table->foreignId('employee_id')->nullable()->constrained()->nullOnDelete();
            $table->dateTime('punch_at');
            $table->string('verify_type', 30)->nullable();
            $table->string('punch_state', 30)->nullable();
            $table->string('work_code', 100)->nullable();
            $table->text('raw_line');
            $table->char('event_hash', 64);
            $table->timestamp('received_at');
            $table->timestamps();

            $table->unique(['device_serial', 'event_hash']);
            $table->index(['employee_id', 'punch_at']);
            $table->index(['device_serial', 'punch_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('zkteco_attendance_events');
    }
};
