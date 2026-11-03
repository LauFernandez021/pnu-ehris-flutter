<?php

namespace Database\Factories;

use App\Models\DtrBatch;
use App\Models\DtrBatchEmployee;
use App\Models\Employee;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<DtrBatchEmployee>
 */
class DtrBatchEmployeeFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'dtr_batch_id' => DtrBatch::factory(),
            'employee_id' => Employee::factory(),
            'employee_no' => fake()->unique()->numerify('EMP-#####'),
            'employee_name' => fake()->name(),
            'designation' => fake()->jobTitle(),
        ];
    }
}
