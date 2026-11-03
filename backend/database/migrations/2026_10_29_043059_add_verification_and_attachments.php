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
        Schema::table('employees', function (Blueprint $table) {
            $table->boolean('self_registered')->default(false);
            $table->string('id_photo_path')->nullable();
            $table->string('selfie_path')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->text('review_note')->nullable();
        });

        // null = this leave type takes no attachment; N = required from N working days
        Schema::table('leave_types', function (Blueprint $table) {
            $table->unsignedSmallInteger('attachment_required_from_days')->nullable();
        });

        Schema::table('leave_requests', function (Blueprint $table) {
            $table->string('attachment_path')->nullable();
            $table->string('attachment_name')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('leave_requests', fn(Blueprint $t) => $t->dropColumn(['attachment_path', 'attachment_name']));
        Schema::table('leave_types', fn(Blueprint $t) => $t->dropColumn('attachment_required_from_days'));
        Schema::table('employees', function (Blueprint $table) {
            $table->dropConstrainedForeignId('reviewed_by');
            $table->dropColumn(['self_registered', 'id_photo_path', 'selfie_path', 'reviewed_at', 'review_note']);
        });
    }
};
