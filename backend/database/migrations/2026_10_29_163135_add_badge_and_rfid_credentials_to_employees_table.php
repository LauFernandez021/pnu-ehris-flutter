<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('employees', function (Blueprint $table) {
            $table->string('badge_number')->nullable()->unique();
            $table->string('rfid_card_number')->nullable()->unique();
        });

        DB::table('employees')
            ->whereNull('badge_number')
            ->orderBy('id')
            ->chunkById(500, function ($employees): void {
                foreach ($employees as $employee) {
                    DB::table('employees')
                        ->where('id', $employee->id)
                        ->update([
                            'badge_number' => 'HRMS-'.str_pad((string) $employee->id, 6, '0', STR_PAD_LEFT),
                        ]);
                }
            });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('employees', function (Blueprint $table) {
            $table->dropUnique(['badge_number']);
            $table->dropUnique(['rfid_card_number']);
            $table->dropColumn(['badge_number', 'rfid_card_number']);
        });
    }
};
