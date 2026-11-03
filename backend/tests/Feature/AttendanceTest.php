<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\LeaveRequest;
use App\Models\LeaveType;
use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

class AttendanceTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_employee_checking_in_after_the_grace_period_is_marked_late(): void
    {
        $this->travelTo('2026-10-29 08:11:00');
        $employee = Employee::factory()->create();

        $response = $this->actingAs($employee->user)
            ->postJson('/api/me/attendance/check-in');

        $response->assertCreated()
            ->assertJsonPath('status', 'late')
            ->assertJsonPath('check_in_at', '2026-10-29T08:11:00+08:00');
        $this->assertDatabaseHas('attendances', [
            'employee_id' => $employee->id,
            'attendance_date' => '2026-10-29 00:00:00',
        ]);

        $this->postJson('/api/me/attendance/check-in')->assertUnprocessable();
        $this->assertSame(1, Attendance::where('employee_id', $employee->id)->count());
    }

    public function test_checking_in_at_the_grace_boundary_is_on_time(): void
    {
        $this->travelTo('2026-10-29 08:10:00');
        $employee = Employee::factory()->create();

        $response = $this->actingAs($employee->user)
            ->postJson('/api/me/attendance/check-in');

        $response->assertCreated()->assertJsonPath('status', 'present');
    }

    public function test_employee_can_check_out_once_and_receives_worked_minutes(): void
    {
        $this->travelTo('2026-10-29 08:00:00');
        $employee = Employee::factory()->create();
        $this->actingAs($employee->user)->postJson('/api/me/attendance/check-in')->assertCreated();

        $this->travelTo('2026-10-29 12:00:00');
        $this->postJson('/api/me/attendance/check-out')
            ->assertOk()
            ->assertJsonPath('worked_minutes', 240);
        $this->assertDatabaseHas('attendances', [
            'employee_id' => $employee->id,
            'worked_minutes' => 240,
        ]);

        $this->postJson('/api/me/attendance/check-out')->assertUnprocessable();
        $this->assertSame(1, Attendance::where('employee_id', $employee->id)->count());
    }

    public function test_employee_records_am_pm_and_optional_overtime_punches_in_order(): void
    {
        $this->travelTo('2026-10-29 08:00:00');
        $employee = Employee::factory()->create();
        $this->actingAs($employee->user);

        $this->postJson('/api/me/attendance/punch', ['punch' => 'am_out'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['punch']);
        $this->postJson('/api/me/attendance/punch', ['punch' => 'am_in'])
            ->assertOk()
            ->assertJsonPath('am_in_at', '2026-10-29T08:00:00+08:00');

        $this->travelTo('2026-10-29 12:00:00');
        $this->postJson('/api/me/attendance/punch', ['punch' => 'am_out'])
            ->assertOk()
            ->assertJsonPath('worked_minutes', 240);
        $this->travelTo('2026-10-29 13:00:00');
        $this->postJson('/api/me/attendance/punch', ['punch' => 'pm_in'])
            ->assertOk();
        $this->travelTo('2026-10-29 17:00:00');
        $this->postJson('/api/me/attendance/punch', ['punch' => 'pm_out'])
            ->assertOk()
            ->assertJsonPath('worked_minutes', 480);

        $this->travelTo('2026-10-29 18:00:00');
        $this->postJson('/api/me/attendance/punch', ['punch' => 'ot_in'])
            ->assertOk();
        $this->travelTo('2026-10-29 19:00:00');
        $this->postJson('/api/me/attendance/punch', ['punch' => 'ot_out'])
            ->assertOk()
            ->assertJsonPath('ot_out_at', '2026-10-29T19:00:00+08:00')
            ->assertJsonPath('worked_minutes', 540);

        $this->assertDatabaseHas('attendances', [
            'employee_id' => $employee->id,
            'am_in_at' => '2026-10-29 08:00:00',
            'am_out_at' => '2026-10-29 12:00:00',
            'pm_in_at' => '2026-10-29 13:00:00',
            'pm_out_at' => '2026-10-29 17:00:00',
            'ot_in_at' => '2026-10-29 18:00:00',
            'ot_out_at' => '2026-10-29 19:00:00',
            'check_in_at' => '2026-10-29 08:00:00',
            'check_out_at' => '2026-10-29 17:00:00',
            'worked_minutes' => 540,
        ]);
    }

    public function test_hr_daily_view_distinguishes_absent_and_on_leave_employees(): void
    {
        $this->travelTo('2026-10-29 10:00:00');
        $admin = User::factory()->create();
        Role::findOrCreate('admin', 'web');
        $admin->assignRole('admin');
        $absentEmployee = Employee::factory()->create(['last_name' => 'Absent']);
        $leaveEmployee = Employee::factory()->create(['last_name' => 'Leave']);
        $leaveType = LeaveType::create(['name' => 'Annual', 'days_per_year' => 10]);
        LeaveRequest::create([
            'employee_id' => $leaveEmployee->id,
            'leave_type_id' => $leaveType->id,
            'start_date' => '2026-10-29',
            'end_date' => '2026-10-29',
            'days' => 1,
            'status' => 'approved',
        ]);

        $response = $this->actingAs($admin)
            ->getJson('/api/attendance?date=2026-10-29');

        $response->assertOk()
            ->assertJsonPath('counts.absent', 1)
            ->assertJsonPath('counts.on_leave', 1)
            ->assertJsonFragment([
                'employee_no' => $absentEmployee->employee_no,
                'status' => 'absent',
            ])
            ->assertJsonFragment([
                'employee_no' => $leaveEmployee->employee_no,
                'status' => 'on_leave',
            ]);
    }

    public function test_employee_cannot_open_the_admin_attendance_view(): void
    {
        $employee = Employee::factory()->create();

        $this->actingAs($employee->user)
            ->getJson('/api/attendance')
            ->assertForbidden();
    }

    public function test_employee_attendance_history_contains_fourteen_days(): void
    {
        $this->travelTo('2026-10-29 12:00:00');
        $employee = Employee::factory()->create();

        $response = $this->actingAs($employee->user)->getJson('/api/me/attendance');

        $response->assertOk()
            ->assertJsonCount(14, 'days')
            ->assertJsonPath('days.0.date', '2026-10-29')
            ->assertJsonPath('days.13.date', '2026-10-16');
    }

    public function test_attendance_requires_authentication(): void
    {
        $this->getJson('/api/me/attendance')->assertUnauthorized();
    }
}
