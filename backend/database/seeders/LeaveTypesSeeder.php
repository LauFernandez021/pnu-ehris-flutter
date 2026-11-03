<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class LeaveTypesSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        foreach (
            [
                'Vacation Leave' => 10,
                'Sick Leave' => 10,
                'Emergency Leave' => 3,
            ] as $name => $days
        ) {
            \App\Models\LeaveType::firstOrCreate(['name' => $name], ['days_per_year' => $days]);
            \App\Models\LeaveType::where('name', 'Sick Leave')->update(['attachment_required_from_days' => 2]);
        }
    }
}
