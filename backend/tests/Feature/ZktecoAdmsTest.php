<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\User;
use App\Models\ZktecoAttendanceEvent;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

class ZktecoAdmsTest extends TestCase
{
    use LazilyRefreshDatabase;

    private const SERIAL = 'UA760-TEST-01';

    private const DEVICE_IP = '203.0.113.24';

    protected function setUp(): void
    {
        parent::setUp();

        config()->set('hrms.zkteco_adms', [
            'enabled' => true,
            'device_serials' => [self::SERIAL],
            'allowed_ips' => [self::DEVICE_IP],
            'max_payload_bytes' => 65536,
            'max_records_per_request' => 500,
        ]);
    }

    public function test_receiver_is_disabled_by_default(): void
    {
        config()->set('hrms.zkteco_adms.enabled', false);

        $this->get('/iclock/cdata?SN='.self::SERIAL)->assertNotFound();
    }

    public function test_receiver_rejects_untrusted_ip_and_unregistered_serial(): void
    {
        $this->getFromDevice('/iclock/cdata?SN='.self::SERIAL, '203.0.113.25')
            ->assertForbidden();

        $this->getFromDevice('/iclock/cdata?SN=UNKNOWN')
            ->assertForbidden();
    }

    public function test_handshake_returns_a_stamp_from_persisted_events(): void
    {
        ZktecoAttendanceEvent::create([
            'device_serial' => self::SERIAL,
            'device_user_id' => '57',
            'employee_id' => null,
            'punch_at' => '2026-10-28 08:02:00',
            'verify_type' => '1',
            'punch_state' => '0',
            'work_code' => null,
            'raw_line' => "57\t2026-10-28 08:02:00\t1\t0",
            'event_hash' => hash('sha256', 'existing-event'),
            'received_at' => now(),
        ]);

        $response = $this->getFromDevice('/iclock/cdata?SN='.self::SERIAL);

        $response->assertOk()
            ->assertSee('GET OPTION FROM: '.self::SERIAL)
            ->assertSee('ATTLOGStamp=')
            ->assertSee('TransFlag=TransData AttLog');
    }

    public function test_attendance_events_are_saved_idempotently_without_mutating_attendance(): void
    {
        $employee = Employee::factory()->create(['device_user_id' => '00057']);
        $body = implode("\r\n", [
            "00057\t2026-10-29 08:02:00\t1\t0\t0",
            "unknown-58\t2026-10-29 08:05:00\t0\t0\t0",
        ]);

        $this->postFromDevice('/iclock/cdata?SN='.self::SERIAL.'&table=ATTLOG', $body)
            ->assertOk()
            ->assertSeeText('OK');
        $this->postFromDevice('/iclock/cdata?SN='.self::SERIAL.'&table=ATTLOG', $body)
            ->assertOk();

        $this->assertDatabaseCount('zkteco_attendance_events', 2);
        $this->assertDatabaseHas('zkteco_attendance_events', [
            'device_serial' => self::SERIAL,
            'device_user_id' => '00057',
            'employee_id' => $employee->id,
            'verify_type' => '1',
            'punch_state' => '0',
        ]);
        $this->assertDatabaseHas('zkteco_attendance_events', [
            'device_serial' => self::SERIAL,
            'device_user_id' => 'unknown-58',
            'employee_id' => null,
        ]);
        $this->assertDatabaseCount('attendances', 0);
    }

    public function test_invalid_batch_is_rejected_without_partially_storing_events(): void
    {
        $body = implode("\n", [
            "57\t2026-10-29 08:02:00\t1\t0",
            "58\tnot-a-date\t1\t0",
        ]);

        $this->postFromDevice('/iclock/cdata?SN='.self::SERIAL.'&table=ATTLOG', $body)
            ->assertUnprocessable();

        $this->assertDatabaseCount('zkteco_attendance_events', 0);
        $this->assertSame(0, Attendance::count());
    }

    public function test_options_and_operation_logs_are_retained_before_acknowledgement(): void
    {
        foreach (['options' => "ATTLOG\t1", 'OPERLOG' => 'operator event'] as $table => $body) {
            $this->postFromDevice(
                '/iclock/cdata?SN='.self::SERIAL.'&table='.$table,
                $body
            )->assertOk();
        }

        $this->assertDatabaseCount('zkteco_device_messages', 2);
    }

    public function test_hr_can_list_events_but_employees_cannot(): void
    {
        ZktecoAttendanceEvent::create([
            'device_serial' => self::SERIAL,
            'device_user_id' => '57',
            'employee_id' => null,
            'punch_at' => '2026-10-29 08:02:00',
            'verify_type' => '1',
            'punch_state' => '0',
            'work_code' => null,
            'raw_line' => "57\t2026-10-29 08:02:00\t1\t0",
            'event_hash' => hash('sha256', 'employee-list-event'),
            'received_at' => now(),
        ]);

        $employee = User::factory()->create();
        Role::findOrCreate('employee', 'web');
        $employee->assignRole('employee');
        $this->actingAs($employee)->getJson('/api/biometric/events')->assertForbidden();

        $hr = User::factory()->create();
        Role::findOrCreate('hr', 'web');
        $hr->assignRole('hr');
        $this->actingAs($hr)
            ->getJson('/api/biometric/events?mapping=unmapped')
            ->assertOk()
            ->assertJsonPath('data.0.device_user_id', '57')
            ->assertJsonMissingPath('data.0.raw_line');
    }

    private function getFromDevice(string $uri, string $ip = self::DEVICE_IP)
    {
        return $this->call('GET', $uri, server: ['REMOTE_ADDR' => $ip]);
    }

    private function postFromDevice(string $uri, string $body, string $ip = self::DEVICE_IP)
    {
        return $this->call(
            'POST',
            $uri,
            server: [
                'REMOTE_ADDR' => $ip,
                'CONTENT_TYPE' => 'text/plain',
            ],
            content: $body
        );
    }
}
