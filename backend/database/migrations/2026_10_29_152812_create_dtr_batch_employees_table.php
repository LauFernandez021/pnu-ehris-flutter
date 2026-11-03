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
        Schema::create('dtr_batch_employees', function (Blueprint $table) {
            $table->id();
            $table->foreignId('dtr_batch_id')->constrained()->cascadeOnDelete();
            $table->foreignId('employee_id')->constrained()->cascadeOnDelete();
            $table->string('employee_no');
            $table->string('employee_name');
            $table->string('designation')->nullable();
            $table->timestamps();

            $table->unique(['dtr_batch_id', 'employee_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('dtr_batch_employees');
    }
};
