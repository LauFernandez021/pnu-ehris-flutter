<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Employee;
use App\Models\ZktecoAttendanceEvent;
use App\Models\ZktecoDeviceMessage;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class ZktecoAdmsController extends Controller
{
    public function handle(Request $request, ?string $endpoint = null): Response
    {
        $config = config('hrms.zkteco_adms');
        abort_unless($config['enabled'], 404);

        $remoteIp = (string) $request->server('REMOTE_ADDR');
        abort_if(
            config('app.env') === 'production' && ! $request->isSecure(),
            400,
            'The ADMS receiver requires HTTPS.'
        );
        abort_unless(
            $remoteIp !== ''
                && in_array($remoteIp, $config['allowed_ips'], true),
            403
        );

        $serial = (string) $request->query('SN', '');
        abort_unless(
            preg_match('/\A[A-Za-z0-9._-]{1,64}\z/', $serial) === 1
                && in_array($serial, $config['device_serials'], true),
            403
        );

        if ($request->isMethod('GET')) {
            return $this->handleGet($request, $endpoint, $serial);
        }

        abort_unless($request->isMethod('POST'), 405);

        return $this->handlePost($request, $serial, $endpoint);
    }

    private function handleGet(Request $request, ?string $endpoint, string $serial): Response
    {
        if ($endpoint === 'getrequest') {
            return response('OK', 200, ['Content-Type' => 'text/plain']);
        }
        abort_if($endpoint === 'devicecmd', 400);

        $table = strtoupper((string) $request->query('table', ''));
        if ($table !== '') {
            abort_unless(in_array($table, ['ATTLOG', 'OPERLOG', 'OPTIONS'], true), 400);

            return response('OK', 200, ['Content-Type' => 'text/plain']);
        }

        $timezoneHours = (int) (now()->getOffset() / 3600);
        $response = "GET OPTION FROM: {$serial}\n"
            ."ATTLOGStamp=0\n"
            ."OPERLOGStamp=0\n"
            ."ATTPHOTOStamp=0\n"
            ."ErrorDelay=30\n"
            ."Delay=10\n"
            ."TransInterval=1\n"
            ."TransFlag=TransData AttLog\n"
            ."TimeZone={$timezoneHours}\n"
            ."Realtime=1\n"
            ."Encrypt=0\n";

        return response($response, 200, ['Content-Type' => 'text/plain; charset=utf-8']);
    }

    private function handlePost(Request $request, string $serial, ?string $endpoint): Response
    {
        $table = strtoupper((string) $request->query('table', ''));
        if ($endpoint === 'devicecmd') {
            $table = 'DEVICECMD';
        }
        abort_unless(in_array($table, ['ATTLOG', 'OPERLOG', 'OPTIONS'], true)
            || $table === 'DEVICECMD', 400);

        $body = $request->getContent();
        $config = config('hrms.zkteco_adms');
        abort_if(strlen($body) > $config['max_payload_bytes'], 413);

        if ($table !== 'ATTLOG') {
            ZktecoDeviceMessage::query()->firstOrCreate(
                [
                    'device_serial' => $serial,
                    'message_type' => $table,
                    'payload_hash' => hash('sha256', $body),
                ],
                [
                    'body' => $body,
                    'received_at' => now(),
                ]
            );

            return response('OK', 200, ['Content-Type' => 'text/plain']);
        }

        $events = $this->parseAttendancePayload($body, $config['max_records_per_request']);
        if ($events === []) {
            return response('OK', 200, ['Content-Type' => 'text/plain']);
        }

        $deviceUserIds = array_values(array_unique(array_column($events, 'device_user_id')));
        $employees = Employee::withTrashed()
            ->whereIn('device_user_id', $deviceUserIds)
            ->get(['id', 'device_user_id'])
            ->keyBy('device_user_id');
        $receivedAt = now();

        DB::transaction(function () use ($events, $employees, $receivedAt, $serial): void {
            foreach ($events as $event) {
                $employee = $employees->get($event['device_user_id']);
                ZktecoAttendanceEvent::query()->firstOrCreate(
                    [
                        'device_serial' => $serial,
                        'event_hash' => hash('sha256', $event['raw_line']),
                    ],
                    [
                        'device_user_id' => $event['device_user_id'],
                        'employee_id' => $employee?->id,
                        'punch_at' => $event['punch_at'],
                        'verify_type' => $event['verify_type'],
                        'punch_state' => $event['punch_state'],
                        'work_code' => $event['work_code'],
                        'raw_line' => $event['raw_line'],
                        'received_at' => $receivedAt,
                    ]
                );
            }
        });

        return response('OK', 200, ['Content-Type' => 'text/plain']);
    }

    private function parseAttendancePayload(string $body, int $maxRecords): array
    {
        $lines = preg_split('/\r\n|\n|\r/', trim($body));
        if ($lines === false) {
            abort(422, 'Invalid attendance payload.');
        }
        $lines = array_values(array_filter($lines, fn (string $line): bool => trim($line) !== ''));
        abort_if(count($lines) > $maxRecords, 413, 'Too many attendance records in one request.');

        $events = [];
        foreach ($lines as $line) {
            $parts = explode("\t", $line);
            abort_if(count($parts) < 2, 422, 'Attendance record is missing required fields.');

            $deviceUserId = trim($parts[0]);
            $rawPunchAt = trim($parts[1]);
            abort_unless(
                $deviceUserId !== ''
                    && strlen($deviceUserId) <= 100
                    && preg_match('/\A[\pL\pN._-]+\z/u', $deviceUserId) === 1,
                422,
                'Attendance record has an invalid device user ID.'
            );

            try {
                $punchAt = CarbonImmutable::createFromFormat(
                    '!Y-m-d H:i:s',
                    $rawPunchAt,
                    config('app.timezone')
                );
            } catch (Throwable) {
                $punchAt = false;
            }
            abort_unless(
                $punchAt !== false && $punchAt->format('Y-m-d H:i:s') === $rawPunchAt,
                422,
                'Attendance record has an invalid timestamp.'
            );

            $events[] = [
                'device_user_id' => $deviceUserId,
                'punch_at' => $punchAt->format('Y-m-d H:i:s'),
                'verify_type' => $this->nullableField($parts[2] ?? null, 30),
                'punch_state' => $this->nullableField($parts[3] ?? null, 30),
                'work_code' => $this->nullableField($parts[4] ?? null, 100),
                'raw_line' => $line,
            ];
        }

        return $events;
    }

    private function nullableField(?string $value, int $maxLength): ?string
    {
        $value = $value === null ? null : trim($value);
        abort_if($value !== null && strlen($value) > $maxLength, 422, 'Attendance record contains an oversized field.');

        return $value === '' ? null : $value;
    }
}
