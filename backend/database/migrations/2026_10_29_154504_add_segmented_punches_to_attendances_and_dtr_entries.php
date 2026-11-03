<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        foreach (['attendances', 'dtr_entries'] as $tableName) {
            Schema::table($tableName, function (Blueprint $table) {
                $table->timestamp('am_in_at')->nullable();
                $table->timestamp('am_out_at')->nullable();
                $table->timestamp('pm_in_at')->nullable();
                $table->timestamp('pm_out_at')->nullable();
                $table->timestamp('ot_in_at')->nullable();
                $table->timestamp('ot_out_at')->nullable();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        foreach (['attendances', 'dtr_entries'] as $tableName) {
            Schema::table($tableName, function (Blueprint $table) {
                $table->dropColumn([
                    'am_in_at',
                    'am_out_at',
                    'pm_in_at',
                    'pm_out_at',
                    'ot_in_at',
                    'ot_out_at',
                ]);
            });
        }
    }
};
