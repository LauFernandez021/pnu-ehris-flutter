<?php

namespace Database\Factories;

use App\Models\Employee;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Employee>
 */
class EmployeeFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'employee_no' => fake()->unique()->numerify('EMP-#####'),
            'first_name' => fake()->firstName(),
            'last_name' => fake()->lastName(),
            'status' => 'active',
        ];
    }
}
