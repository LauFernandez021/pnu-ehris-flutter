<?php

namespace Database\Factories;

use App\Models\DtrBatchEmployee;
use App\Models\DtrEntry;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<DtrEntry>
 */
class DtrEntryFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'dtr_batch_employee_id' => DtrBatchEmployee::factory(),
            'entry_date' => now()->toDateString(),
            'status' => 'present',
            'check_in_at' => now()->setTime(8, 0),
            'check_out_at' => now()->setTime(17, 0),
            'worked_minutes' => 540,
        ];
    }
}
