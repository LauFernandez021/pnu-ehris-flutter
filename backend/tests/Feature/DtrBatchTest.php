<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\DtrBatch;
use App\Models\DtrEntry;
use App\Models\Employee;
use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

class DtrBatchTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_hr_can_create_a_monthly_dtr_for_all_active_employees(): void
    {
        $this->travelTo('2026-03-20 12:00:00');
        $hr = $this->userWithRole('hr');
        $firstEmployee = Employee::factory()->create([
            'employee_no' => 'EMP-10001',
            'last_name' => 'Alpha',
            'date_hired' => '2025-01-01',
        ]);
        $secondEmployee = Employee::factory()->create([
            'employee_no' => 'EMP-10002',
            'last_name' => 'Beta',
            'date_hired' => '2025-01-01',
        ]);
        Attendance::create([
            'employee_id' => $firstEmployee->id,
            'attendance_date' => '2026-03-02',
            'check_in_at' => '2026-03-02 08:00:00',
            'check_out_at' => '2026-03-02 17:00:00',
            'worked_minutes' => 540,
        ]);

        $response = $this->actingAs($hr)->postJson('/api/dtr-batches', [
            'period_type' => 'monthly',
            'year' => 2026,
            'month' => 3,
            'transaction_date' => '2026-03-20',
            'remarks' => 'March monthly DTR',
            'employee_selection' => 'all',
        ]);

        $response->assertCreated()
            ->assertJsonPath('dtr_code', 'DTR-00001')
            ->assertJsonPath('period_type', 'monthly')
            ->assertJsonPath('start_date', '2026-03-01')
            ->assertJsonPath('end_date', '2026-03-31')
            ->assertJsonPath('employee_count', 2)
            ->assertJsonPath('employees.0.entries.1.worked_minutes', 540)
            ->assertJsonPath('employees.0.entries.1.am_in_at', '2026-03-02T08:00:00+08:00')
            ->assertJsonPath('employees.0.entries.1.pm_out_at', '2026-03-02T17:00:00+08:00')
            ->assertJsonPath('employees.0.entries.1.am_out_at', null)
            ->assertJsonPath('employees.0.entries.1.pm_in_at', null);
        $this->assertDatabaseCount('dtr_batches', 1);
        $this->assertDatabaseCount('dtr_batch_employees', 2);
        $this->assertDatabaseCount('dtr_entries', 62);
        $this->assertDatabaseHas('dtr_entries', [
            'status' => 'present',
            'worked_minutes' => 540,
        ]);
        $this->assertModelExists($secondEmployee);

        $this->actingAs($hr)
            ->getJson('/api/dtr-batches/1')
            ->assertOk()
            ->assertJsonPath('dtr_code', 'DTR-00001')
            ->assertJsonPath('employees.0.employee_no', 'EMP-10001');

        $this->actingAs($hr)
            ->getJson('/api/dtr-batches')
            ->assertOk()
            ->assertJsonPath('data.0.employee_count', 2);
    }

    public function test_semi_monthly_first_cutoff_uses_days_one_through_fifteen(): void
    {
        $this->travelTo('2026-03-20 12:00:00');
        $hr = $this->userWithRole('hr');
        $employee = Employee::factory()->create();

        $response = $this->actingAs($hr)->postJson('/api/dtr-batches', [
            'period_type' => 'semi_monthly',
            'pay_period' => 'first_cutoff',
            'year' => 2026,
            'month' => 3,
            'transaction_date' => '2026-03-20',
            'employee_selection' => 'selected',
            'employee_ids' => [$employee->id],
        ]);

        $response->assertCreated()
            ->assertJsonPath('start_date', '2026-03-01')
            ->assertJsonPath('end_date', '2026-03-15')
            ->assertJsonPath('pay_period', 'first_cutoff')
            ->assertJsonCount(15, 'employees.0.entries');
    }

    public function test_semi_monthly_second_cutoff_ends_on_the_months_last_day(): void
    {
        $this->travelTo('2026-03-20 12:00:00');
        $hr = $this->userWithRole('hr');
        $employee = Employee::factory()->create();

        $response = $this->actingAs($hr)->postJson('/api/dtr-batches', [
            'period_type' => 'semi_monthly',
            'pay_period' => 'second_cutoff',
            'year' => 2026,
            'month' => 2,
            'transaction_date' => '2026-03-20',
            'employee_selection' => 'selected',
            'employee_ids' => [$employee->id],
        ]);

        $response->assertCreated()
            ->assertJsonPath('start_date', '2026-02-16')
            ->assertJsonPath('end_date', '2026-02-28')
            ->assertJsonCount(13, 'employees.0.entries');
    }

    public function test_hr_can_create_a_dtr_for_only_selected_employees(): void
    {
        $this->travelTo('2026-03-20 12:00:00');
        $hr = $this->userWithRole('hr');
        $selected = Employee::factory()->create();
        Employee::factory()->create();

        $response = $this->actingAs($hr)->postJson('/api/dtr-batches', [
            'period_type' => 'monthly',
            'year' => 2026,
            'month' => 3,
            'transaction_date' => '2026-03-20',
            'employee_selection' => 'selected',
            'employee_ids' => [$selected->id],
        ]);

        $response->assertCreated()->assertJsonPath('employee_count', 1);
        $this->assertSame(
            [$selected->id],
            DtrBatch::firstOrFail()->employees()->pluck('employee_id')->all()
        );
    }

    public function test_dtr_snapshots_all_segmented_punches_for_each_day(): void
    {
        $this->travelTo('2026-03-20 12:00:00');
        $hr = $this->userWithRole('hr');
        $employee = Employee::factory()->create();
        Attendance::create([
            'employee_id' => $employee->id,
            'attendance_date' => '2026-03-02',
            'am_in_at' => '2026-03-02 08:00:00',
            'am_out_at' => '2026-03-02 12:00:00',
            'pm_in_at' => '2026-03-02 13:00:00',
            'pm_out_at' => '2026-03-02 17:00:00',
            'ot_in_at' => '2026-03-02 18:00:00',
            'ot_out_at' => '2026-03-02 19:00:00',
            'check_in_at' => '2026-03-02 08:00:00',
            'check_out_at' => '2026-03-02 17:00:00',
            'worked_minutes' => 480,
        ]);

        $response = $this->actingAs($hr)->postJson('/api/dtr-batches', [
            'period_type' => 'monthly',
            'year' => 2026,
            'month' => 3,
            'transaction_date' => '2026-03-20',
            'employee_selection' => 'selected',
            'employee_ids' => [$employee->id],
        ]);

        $response->assertCreated()
            ->assertJsonPath('employees.0.entries.1.am_in_at', '2026-03-02T08:00:00+08:00')
            ->assertJsonPath('employees.0.entries.1.am_out_at', '2026-03-02T12:00:00+08:00')
            ->assertJsonPath('employees.0.entries.1.pm_in_at', '2026-03-02T13:00:00+08:00')
            ->assertJsonPath('employees.0.entries.1.pm_out_at', '2026-03-02T17:00:00+08:00')
            ->assertJsonPath('employees.0.entries.1.ot_in_at', '2026-03-02T18:00:00+08:00')
            ->assertJsonPath('employees.0.entries.1.ot_out_at', '2026-03-02T19:00:00+08:00');

        $this->assertDatabaseHas('dtr_entries', [
            'am_in_at' => '2026-03-02 08:00:00',
            'am_out_at' => '2026-03-02 12:00:00',
            'pm_in_at' => '2026-03-02 13:00:00',
            'pm_out_at' => '2026-03-02 17:00:00',
            'ot_in_at' => '2026-03-02 18:00:00',
            'ot_out_at' => '2026-03-02 19:00:00',
        ]);
    }

    public function test_attendance_punches_update_an_existing_monthly_dtr(): void
    {
        $this->travelTo('2026-10-29 07:55:00');
        $hr = $this->userWithRole('hr');
        $employee = Employee::factory()->create();

        $this->actingAs($hr)->postJson('/api/dtr-batches', [
            'period_type' => 'monthly',
            'year' => 2026,
            'month' => 10,
            'transaction_date' => '2026-10-29',
            'employee_selection' => 'selected',
            'employee_ids' => [$employee->id],
        ])->assertCreated();

        $this->travelTo('2026-10-29 08:05:00');
        $this->actingAs($employee->user)
            ->postJson('/api/me/attendance/punch', ['punch' => 'am_in'])
            ->assertOk();

        $this->travelTo('2026-10-29 12:00:00');
        $this->postJson('/api/me/attendance/punch', ['punch' => 'am_out'])
            ->assertOk();

        $this->getJson('/api/me/dtr-batches/1')
            ->assertOk()
            ->assertJsonPath('employees.0.entries.28.date', '2026-10-29')
            ->assertJsonPath('employees.0.entries.28.status', 'present')
            ->assertJsonPath('employees.0.entries.28.am_in_at', '2026-10-29T08:05:00+08:00')
            ->assertJsonPath('employees.0.entries.28.am_out_at', '2026-10-29T12:00:00+08:00')
            ->assertJsonPath('employees.0.entries.28.worked_minutes', 235);

        $this->assertSame(31, DtrEntry::count());
    }

    public function test_attendance_punched_before_dtr_creation_is_included_in_the_batch(): void
    {
        $this->travelTo('2026-10-29 08:05:00');
        $hr = $this->userWithRole('hr');
        $employee = Employee::factory()->create();

        $this->actingAs($employee->user)
            ->postJson('/api/me/attendance/punch', ['punch' => 'am_in'])
            ->assertOk();

        $this->actingAs($hr)->postJson('/api/dtr-batches', [
            'period_type' => 'monthly',
            'year' => 2026,
            'month' => 10,
            'transaction_date' => '2026-10-29',
            'employee_selection' => 'selected',
            'employee_ids' => [$employee->id],
        ])
            ->assertCreated()
            ->assertJsonPath('employees.0.entries.28.date', '2026-10-29')
            ->assertJsonPath('employees.0.entries.28.status', 'present')
            ->assertJsonPath('employees.0.entries.28.am_in_at', '2026-10-29T08:05:00+08:00');

        $this->assertSame(31, DtrEntry::count());
    }

    public function test_employee_can_only_view_their_own_generated_dtr_history(): void
    {
        $this->travelTo('2026-03-20 12:00:00');
        $hr = $this->userWithRole('hr');
        $employee = Employee::factory()->create();
        $otherEmployee = Employee::factory()->create();
        $period = [
            'period_type' => 'monthly',
            'year' => 2026,
            'month' => 3,
            'transaction_date' => '2026-03-20',
            'employee_selection' => 'selected',
        ];

        $this->actingAs($hr)->postJson('/api/dtr-batches', [
            ...$period,
            'employee_ids' => [$employee->id],
        ])->assertCreated();
        $this->postJson('/api/dtr-batches', [
            ...$period,
            'employee_ids' => [$otherEmployee->id],
        ])->assertCreated();

        $this->actingAs($employee->user)
            ->getJson('/api/me/dtr-batches')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.dtr_code', 'DTR-00001');

        $this->getJson('/api/me/dtr-batches/1')
            ->assertOk()
            ->assertJsonCount(1, 'employees')
            ->assertJsonPath('employees.0.id', $employee->id)
            ->assertJsonPath('employees.0.entries.1.date', '2026-03-02');

        $this->getJson('/api/me/dtr-batches/2')->assertNotFound();
    }

    public function test_employee_without_hr_role_cannot_create_a_dtr(): void
    {
        $employee = Employee::factory()->create();

        $this->actingAs($employee->user)
            ->postJson('/api/dtr-batches', [])
            ->assertForbidden();

        $this->assertDatabaseCount('dtr_batches', 0);
    }

    public function test_dtr_period_requires_a_valid_semi_monthly_cutoff(): void
    {
        $hr = $this->userWithRole('hr');

        $this->actingAs($hr)->postJson('/api/dtr-batches', [
            'period_type' => 'semi_monthly',
            'year' => 2026,
            'month' => 3,
            'transaction_date' => '2026-03-20',
            'employee_selection' => 'all',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['pay_period']);

        $this->assertDatabaseCount('dtr_batches', 0);
    }

    public function test_dtr_requires_authentication(): void
    {
        $this->postJson('/api/dtr-batches', [])->assertUnauthorized();
        $this->assertSame(0, DtrEntry::count());
    }

    private function userWithRole(string $roleName): User
    {
        $role = Role::findOrCreate($roleName, 'web');
        $user = User::factory()->create();
        $user->assignRole($role);

        return $user;
    }
}
