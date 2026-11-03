<?php

namespace Database\Factories;

use App\Models\DtrBatch;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<DtrBatch>
 */
class DtrBatchFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'dtr_code' => fake()->unique()->numerify('DTR-#####'),
            'period_type' => 'monthly',
            'pay_period' => null,
            'year' => now()->year,
            'month' => now()->month,
            'start_date' => now()->startOfMonth()->toDateString(),
            'end_date' => now()->endOfMonth()->toDateString(),
            'transaction_date' => now()->toDateString(),
            'remarks' => null,
            'created_by' => User::factory(),
        ];
    }
}
