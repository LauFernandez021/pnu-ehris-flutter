<?php

namespace Database\Factories;

use App\Models\Attendance;
use App\Models\Employee;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Attendance>
 */
class AttendanceFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'employee_id' => Employee::factory(),
            'attendance_date' => now()->toDateString(),
            'check_in_at' => now()->setTime(8, 0),
            'check_out_at' => null,
            'worked_minutes' => 0,
        ];
    }
}
