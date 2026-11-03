<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Role;
use App\Models\Department;

class RolesAndAdminSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        foreach (['admin', 'hr', 'manager', 'employee'] as $role) {
            \Spatie\Permission\Models\Role::findOrCreate($role, 'web');
        }
        foreach (['Human Resources', 'Finance', 'IT', 'Operations'] as $name) {
            \App\Models\Department::firstOrCreate(['name' => $name]);
        }

        $admin = \App\Models\User::firstOrCreate(
            ['email' => 'admin@example.com'],
            ['name' => 'System Admin', 'password' => \Illuminate\Support\Facades\Hash::make('ChangeMe123!')]
        );
        $admin->assignRole('admin');
    }
}
