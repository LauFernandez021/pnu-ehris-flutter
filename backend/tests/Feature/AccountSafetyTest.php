<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Employee;
use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

class AccountSafetyTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_login_and_me_include_the_forced_password_change_flag(): void
    {
        $user = User::factory()->create([
            'password' => 'StartingPassword1',
            'must_change_password' => true,
        ]);

        $login = $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'StartingPassword1',
        ])->assertOk()
            ->assertJsonPath('user.must_change_password', true);

        $this->withToken($login->json('token'))
            ->getJson('/api/me')
            ->assertOk()
            ->assertJsonPath('user.must_change_password', true);
    }

    public function test_forced_password_change_is_enforced_by_the_api_until_password_is_updated(): void
    {
        $user = User::factory()->create([
            'password' => 'StartingPassword1',
            'must_change_password' => true,
        ]);
        $token = $user->createToken('forced-change')->plainTextToken;

        $this->withToken($token)
            ->getJson('/api/me')
            ->assertOk()
            ->assertJsonPath('user.must_change_password', true);

        $this->getJson('/api/me/attendance')
            ->assertStatus(423)
            ->assertJsonPath('must_change_password', true);
        $this->getJson('/api/departments')
            ->assertStatus(423)
            ->assertJsonPath('message', 'You must change your password before continuing.');

        $this->postJson('/api/me/password', [
            'current_password' => 'StartingPassword1',
            'new_password' => 'NewPassword123',
            'new_password_confirmation' => 'NewPassword123',
        ])->assertOk();

        $this->assertFalse($user->fresh()->must_change_password);
        $this->getJson('/api/departments')->assertOk();
        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $user->id,
            'action' => 'user.password_changed',
        ]);
    }

    public function test_forced_password_change_user_can_sign_out(): void
    {
        $user = User::factory()->create(['must_change_password' => true]);
        $token = $user->createToken('forced-change')->plainTextToken;
        $tokenId = $user->tokens()->firstOrFail()->id;

        $this->withToken($token)
            ->postJson('/api/logout')
            ->assertOk();

        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $tokenId]);
    }

    public function test_failed_login_is_recorded_and_employee_creation_requires_password_change(): void
    {
        $admin = $this->userWithRole('admin');
        Role::findOrCreate('employee', 'web');

        $this->postJson('/api/login', [
            'email' => 'unknown@example.test',
            'password' => 'incorrect',
        ])->assertUnauthorized();

        $this->assertDatabaseHas('audit_logs', [
            'action' => 'auth.login_failed',
            'subject_id' => null,
        ]);

        $this->actingAs($admin)->postJson('/api/employees', [
            'email' => 'new.employee@example.test',
            'password' => 'TemporaryPassword1',
            'role' => 'employee',
            'employee_no' => 'EMP-SAFETY-1',
            'first_name' => 'New',
            'last_name' => 'Employee',
        ])->assertCreated();

        $this->assertDatabaseHas('users', [
            'email' => 'new.employee@example.test',
            'must_change_password' => true,
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $admin->id,
            'action' => 'employee.created',
        ]);
    }

    public function test_admin_can_filter_audit_logs_but_hr_cannot_read_them(): void
    {
        $admin = $this->userWithRole('admin');
        $hr = $this->userWithRole('hr');
        AuditLog::create([
            'user_id' => $admin->id,
            'action' => 'employee.updated',
            'subject_type' => Employee::class,
            'subject_id' => 42,
            'meta' => ['changed_fields' => ['position']],
            'ip' => '127.0.0.1',
            'created_at' => now(),
        ]);

        $this->actingAs($admin)
            ->getJson('/api/audit-logs?action=employee.updated&subject_id=42')
            ->assertOk()
            ->assertJsonPath('data.0.action', 'employee.updated')
            ->assertJsonPath('data.0.subject_id', 42)
            ->assertJsonPath('data.0.actor.name', $admin->name);

        $this->actingAs($hr)->getJson('/api/audit-logs')->assertForbidden();
    }

    public function test_hr_password_reset_forces_a_change_and_audits_the_update(): void
    {
        $admin = $this->userWithRole('admin');
        $employeeUser = $this->userWithRole('employee');
        $employee = Employee::factory()->create(['user_id' => $employeeUser->id]);

        $this->actingAs($admin)->putJson("/api/employees/{$employee->id}", [
            'new_password' => 'TemporaryPassword2',
        ])->assertOk();

        $this->assertTrue($employeeUser->fresh()->must_change_password);
        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $admin->id,
            'action' => 'employee.updated',
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
