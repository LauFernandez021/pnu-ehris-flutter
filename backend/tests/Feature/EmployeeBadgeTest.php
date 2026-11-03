<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

class EmployeeBadgeTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_hrms_generates_a_stable_printable_badge_number(): void
    {
        $admin = $this->userWithRole('admin');
        Role::findOrCreate('employee', 'web');
        $employee = Employee::factory()->create(['employee_no' => 'EMP-TEST-1']);

        $this->assertSame(
            'HRMS-'.str_pad((string) $employee->id, 6, '0', STR_PAD_LEFT),
            $employee->badge_number
        );

        $response = $this->actingAs($admin)->postJson('/api/employees', [
            'email' => 'badge.employee@example.test',
            'password' => 'Password123!',
            'role' => 'employee',
            'employee_no' => 'EMP-TEST-2',
            'first_name' => 'Badge',
            'last_name' => 'Holder',
        ]);

        $response->assertCreated()
            ->assertJsonPath(
                'badge_number',
                'HRMS-'.str_pad((string) $response->json('id'), 6, '0', STR_PAD_LEFT)
            );
    }

    public function test_rfid_card_credential_can_be_linked_and_must_be_unique(): void
    {
        $admin = $this->userWithRole('admin');
        $first = Employee::factory()->create(['rfid_card_number' => '04A1B2C3']);
        $second = Employee::factory()->create();

        $this->actingAs($admin)
            ->putJson("/api/employees/{$second->id}", [
                'rfid_card_number' => '04A1B2C3',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['rfid_card_number']);

        $this->putJson("/api/employees/{$second->id}", [
            'rfid_card_number' => '04D4E5F6',
        ])->assertOk()
            ->assertJsonPath('rfid_card_number', '04D4E5F6');

        $this->assertDatabaseHas('employees', [
            'id' => $first->id,
            'rfid_card_number' => '04A1B2C3',
        ]);
    }

    private function userWithRole(string $roleName): User
    {
        $role = Role::findOrCreate($roleName, 'web');
        $user = User::factory()->create();
        $user->assignRole($role);

        return $user;
    }
}
