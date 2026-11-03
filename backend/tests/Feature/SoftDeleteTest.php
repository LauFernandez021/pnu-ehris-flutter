<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\DtrBatch;
use App\Models\Employee;
use App\Models\LeaveBalance;
use App\Models\LeaveRequest;
use App\Models\LeaveType;
use App\Models\PassSlip;
use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

class SoftDeleteTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_archiving_an_employee_revokes_access_and_restore_reenables_login(): void
    {
        $hr = $this->userWithRole('hr');
        $employee = Employee::factory()->create();

        $this->actingAs($hr)
            ->deleteJson("/api/employees/{$employee->id}")
            ->assertNoContent();

        $this->assertSoftDeleted('employees', ['id' => $employee->id]);
        $this->postJson('/api/login', [
            'email' => $employee->user->email,
            'password' => 'password',
        ])->assertForbidden();

        $this->actingAs($hr)
            ->postJson("/api/employees/{$employee->id}/restore")
            ->assertOk();

        $this->assertDatabaseHas('employees', [
            'id' => $employee->id,
            'deleted_at' => null,
        ]);
        $this->postJson('/api/login', [
            'email' => $employee->user->email,
            'password' => 'password',
        ])->assertOk();
    }

    public function test_department_cannot_be_archived_while_any_employee_record_references_it(): void
    {
        $hr = $this->userWithRole('hr');
        $department = Department::create(['name' => 'Operations']);
        Employee::factory()->create(['department_id' => $department->id]);

        $this->actingAs($hr)
            ->deleteJson("/api/departments/{$department->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['department']);

        $this->assertDatabaseHas('departments', [
            'id' => $department->id,
            'deleted_at' => null,
        ]);
    }

    public function test_leave_type_with_balance_cannot_be_archived(): void
    {
        $hr = $this->userWithRole('hr');
        $employee = Employee::factory()->create();
        $leaveType = LeaveType::create([
            'name' => 'Annual',
            'days_per_year' => 12,
            'attachment_required_from_days' => null,
        ]);
        LeaveBalance::create([
            'employee_id' => $employee->id,
            'leave_type_id' => $leaveType->id,
            'year' => now()->year,
            'allocated' => 12,
            'used' => 0,
        ]);

        $this->actingAs($hr)
            ->deleteJson("/api/settings/leave-types/{$leaveType->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['leave_type']);

        $this->assertDatabaseHas('leave_types', [
            'id' => $leaveType->id,
            'deleted_at' => null,
        ]);
    }

    public function test_leave_type_management_supports_create_archive_and_restore(): void
    {
        $hr = $this->userWithRole('hr');

        $response = $this->actingAs($hr)
            ->postJson('/api/settings/leave-types', [
                'name' => 'Personal leave',
                'days_per_year' => 5,
                'attachment_required_from_days' => 2,
            ]);
        $response->assertCreated()
            ->assertJsonPath('name', 'Personal leave')
            ->assertJsonPath('days_per_year', 5)
            ->assertJsonPath('attachment_required_from_days', 2);
        $leaveTypeId = $response->json('id');

        $this->actingAs($hr)
            ->deleteJson("/api/settings/leave-types/{$leaveTypeId}")
            ->assertNoContent();

        $this->actingAs($hr)
            ->getJson('/api/leave-types')
            ->assertOk()
            ->assertJsonMissing(['id' => $leaveTypeId]);

        $this->actingAs($hr)
            ->getJson('/api/settings/leave-types?trashed=only')
            ->assertOk()
            ->assertJsonPath('0.id', $leaveTypeId);

        $this->actingAs($hr)
            ->postJson("/api/settings/leave-types/{$leaveTypeId}/restore")
            ->assertOk()
            ->assertJsonPath('name', 'Personal leave');
    }

    public function test_only_terminal_leave_requests_and_pass_slips_can_be_archived(): void
    {
        $hr = $this->userWithRole('hr');
        $employee = Employee::factory()->create();
        $leaveType = LeaveType::create([
            'name' => 'Annual',
            'days_per_year' => 12,
            'attachment_required_from_days' => null,
        ]);
        $pendingLeave = LeaveRequest::create([
            'employee_id' => $employee->id,
            'leave_type_id' => $leaveType->id,
            'start_date' => '2026-11-02',
            'end_date' => '2026-11-02',
            'days' => 1,
            'status' => 'pending',
        ]);
        $approvedSlip = PassSlip::create([
            'employee_id' => $employee->id,
            'slip_type' => 'official',
            'slip_date' => '2026-11-02',
            'time_out' => '10:00',
            'time_in' => '11:00',
            'destination' => 'Office',
            'status' => 'approved',
        ]);

        $this->actingAs($hr)
            ->deleteJson("/api/leave-requests/{$pendingLeave->id}")
            ->assertUnprocessable();
        $this->actingAs($hr)
            ->deleteJson("/api/pass-slips/{$approvedSlip->id}")
            ->assertUnprocessable();

        $this->assertDatabaseHas('leave_requests', [
            'id' => $pendingLeave->id,
            'deleted_at' => null,
        ]);
        $this->assertDatabaseHas('pass_slips', [
            'id' => $approvedSlip->id,
            'deleted_at' => null,
        ]);
    }

    public function test_dtr_batch_can_be_archived_and_restored_without_loss(): void
    {
        $hr = $this->userWithRole('hr');
        $batch = DtrBatch::factory()->create();

        $this->actingAs($hr)
            ->deleteJson("/api/dtr-batches/{$batch->id}")
            ->assertNoContent();
        $this->assertSoftDeleted('dtr_batches', ['id' => $batch->id]);

        $this->actingAs($hr)
            ->getJson('/api/dtr-batches?trashed=only')
            ->assertOk()
            ->assertJsonPath('data.0.dtr_code', $batch->dtr_code);

        $this->actingAs($hr)
            ->postJson("/api/dtr-batches/{$batch->id}/restore")
            ->assertOk()
            ->assertJsonPath('dtr_code', $batch->dtr_code);

        $this->assertDatabaseHas('dtr_batches', [
            'id' => $batch->id,
            'deleted_at' => null,
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
