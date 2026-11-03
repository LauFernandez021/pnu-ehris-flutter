<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Attendance;
use App\Models\Employee;
use App\Models\LeaveRequest;
use App\Services\DtrAttendanceSynchronizer;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class AttendanceController extends Controller
{
    public function mine(Request $request): array
    {
        $employee = $this->employee($request);
        $today = now()->startOfDay();
        $start = $today->copy()->subDays(13);

        $attendances = Attendance::where('employee_id', $employee->id)
            ->whereBetween('attendance_date', [$start->toDateString(), $today->toDateString()])
            ->get()
            ->keyBy(fn (Attendance $attendance): string => $attendance->attendance_date->toDateString());

        $leaves = LeaveRequest::where('employee_id', $employee->id)
            ->where('status', 'approved')
            ->whereDate('start_date', '<=', $today->toDateString())
            ->whereDate('end_date', '>=', $start->toDateString())
            ->get(['start_date', 'end_date']);

        $days = [];
        for ($offset = 0; $offset < 14; $offset++) {
            $date = $today->copy()->subDays($offset);
            $dateString = $date->toDateString();
            $attendance = $attendances->get($dateString);
            $isOnLeave = $leaves->contains(
                fn (LeaveRequest $leave): bool => $leave->start_date <= $dateString
                    && $leave->end_date >= $dateString
            );
            $days[] = $this->dayPayload($date, $attendance, $isOnLeave);
        }

        return [
            'settings' => $this->settings(),
            'days' => $days,
        ];
    }

    public function checkIn(Request $request): JsonResponse
    {
        $employee = $this->employee($request);
        $now = now();

        if (! $now->isWeekday()) {
            throw ValidationException::withMessages([
                'attendance' => 'Attendance can only be recorded on weekdays.',
            ]);
        }

        $existing = Attendance::where('employee_id', $employee->id)
            ->whereDate('attendance_date', $now->toDateString())
            ->exists();

        if ($existing) {
            throw ValidationException::withMessages([
                'attendance' => 'You have already checked in today.',
            ]);
        }

        $attendance = Attendance::create([
            'employee_id' => $employee->id,
            'attendance_date' => $now->toDateString(),
            'check_in_at' => $now,
        ]);
        app(DtrAttendanceSynchronizer::class)->sync($attendance);
        $isOnLeave = $this->isOnLeave($employee, $now);

        return response()->json($this->dayPayload($now->copy()->startOfDay(), $attendance, $isOnLeave), 201);
    }

    public function punch(Request $request): JsonResponse
    {
        $data = $request->validate([
            'punch' => ['required', 'in:am_in,am_out,pm_in,pm_out,ot_in,ot_out'],
        ]);
        $employee = $this->employee($request);
        $now = now();

        if (! $now->isWeekday()) {
            throw ValidationException::withMessages([
                'attendance' => 'Attendance can only be recorded on weekdays.',
            ]);
        }

        $attendance = Attendance::query()
            ->where('employee_id', $employee->id)
            ->whereDate('attendance_date', $now->toDateString())
            ->first();
        $amInAt = $attendance?->am_in_at ?? $attendance?->check_in_at;
        $pmOutAt = $attendance?->pm_out_at ?? $attendance?->check_out_at;

        $nextPunch = match (true) {
            ! $amInAt => 'am_in',
            ! $attendance?->am_out_at => 'am_out',
            ! $attendance?->pm_in_at => 'pm_in',
            ! $pmOutAt => 'pm_out',
            ! $attendance?->ot_in_at => 'ot_in',
            ! $attendance?->ot_out_at => 'ot_out',
            default => null,
        };

        if ($data['punch'] !== $nextPunch) {
            throw ValidationException::withMessages([
                'punch' => $nextPunch === 'ot_in'
                    ? 'Complete the AM and PM punches before starting overtime.'
                    : ($nextPunch === null
                        ? 'All attendance punches for today are complete.'
                        : 'The next required punch is '.strtoupper(str_replace('_', ' ', $nextPunch)).'.'),
            ]);
        }

        $attendance ??= Attendance::create([
            'employee_id' => $employee->id,
            'attendance_date' => $now->toDateString(),
            'worked_minutes' => 0,
        ]);
        $field = $data['punch'].'_at';
        $attendance->{$field} = $now;

        if ($data['punch'] === 'am_in') {
            $attendance->check_in_at = $now;
        } elseif ($data['punch'] === 'pm_out') {
            $attendance->check_out_at = $now;
        }

        $attendance->worked_minutes = $this->segmentedWorkedMinutes($attendance, $now);
        $attendance->save();
        app(DtrAttendanceSynchronizer::class)->sync($attendance);
        $isOnLeave = $this->isOnLeave($employee, $now);

        return response()->json(
            $this->dayPayload($now->copy()->startOfDay(), $attendance, $isOnLeave)
        );
    }

    public function checkOut(Request $request): JsonResponse
    {
        $employee = $this->employee($request);
        $now = now();
        $attendance = Attendance::where('employee_id', $employee->id)
            ->whereDate('attendance_date', $now->toDateString())
            ->first();

        if (! $attendance || ! $attendance->check_in_at) {
            throw ValidationException::withMessages([
                'attendance' => 'Check in before checking out.',
            ]);
        }

        if ($attendance->check_out_at) {
            throw ValidationException::withMessages([
                'attendance' => 'You have already checked out today.',
            ]);
        }

        if ($now->lessThanOrEqualTo($attendance->check_in_at)) {
            throw ValidationException::withMessages([
                'attendance' => 'Check-out time must be after check-in time.',
            ]);
        }

        $attendance->update([
            'check_out_at' => $now,
            'worked_minutes' => intdiv($now->getTimestamp() - $attendance->check_in_at->getTimestamp(), 60),
        ]);
        app(DtrAttendanceSynchronizer::class)->sync($attendance);

        return response()->json(
            $this->dayPayload($now->copy()->startOfDay(), $attendance, $this->isOnLeave($employee, $now))
        );
    }

    public function index(Request $request): array
    {
        $data = $request->validate([
            'date' => ['sometimes', 'date_format:Y-m-d', 'before_or_equal:today'],
        ]);
        $date = Carbon::parse($data['date'] ?? now()->toDateString())->startOfDay();
        $dateString = $date->toDateString();

        $employees = Employee::with('department:id,name')
            ->where('status', 'active')
            ->where(function ($query) use ($dateString): void {
                $query->whereNull('date_hired')->orWhereDate('date_hired', '<=', $dateString);
            })
            ->orderBy('last_name')
            ->orderBy('first_name')
            ->get(['id', 'employee_no', 'first_name', 'last_name', 'department_id']);

        $employeeIds = $employees->pluck('id');
        $attendances = Attendance::whereIn('employee_id', $employeeIds)
            ->whereDate('attendance_date', $dateString)
            ->get()
            ->keyBy('employee_id');
        $leaveEmployeeIds = LeaveRequest::whereIn('employee_id', $employeeIds)
            ->where('status', 'approved')
            ->whereDate('start_date', '<=', $dateString)
            ->whereDate('end_date', '>=', $dateString)
            ->pluck('employee_id')
            ->all();

        $days = $employees->map(function (Employee $employee) use (
            $date,
            $attendances,
            $leaveEmployeeIds
        ): array {
            $day = $this->dayPayload(
                $date,
                $attendances->get($employee->id),
                in_array($employee->id, $leaveEmployeeIds, true)
            );
            $day['employee_id'] = $employee->id;
            $day['employee_no'] = $employee->employee_no;
            $day['employee_name'] = trim($employee->first_name.' '.$employee->last_name);
            $day['department'] = $employee->department?->name;

            return $day;
        });

        $counts = [
            'present' => 0,
            'late' => 0,
            'absent' => 0,
            'on_leave' => 0,
            'not_started' => 0,
            'day_off' => 0,
        ];

        foreach ($days as $day) {
            $counts[$day['status']]++;
        }

        return [
            'date' => $dateString,
            'settings' => $this->settings(),
            'counts' => $counts,
            'data' => $days->values(),
        ];
    }

    private function employee(Request $request): Employee
    {
        $employee = $request->user()->employee;

        if (! $employee || $employee->status !== 'active') {
            abort(422, 'Your account has no active employee record.');
        }

        return $employee;
    }

    private function isOnLeave(Employee $employee, Carbon $date): bool
    {
        return LeaveRequest::where('employee_id', $employee->id)
            ->where('status', 'approved')
            ->whereDate('start_date', '<=', $date->toDateString())
            ->whereDate('end_date', '>=', $date->toDateString())
            ->exists();
    }

    private function dayPayload(Carbon $date, ?Attendance $attendance, bool $isOnLeave): array
    {
        $status = $this->status($date, $attendance, $isOnLeave);
        $workedMinutes = $this->workedMinutes($attendance, $date);

        return [
            'date' => $date->toDateString(),
            'status' => $status,
            'check_in_at' => $attendance?->check_in_at?->format(DATE_ATOM),
            'check_out_at' => $attendance?->check_out_at?->format(DATE_ATOM),
            'am_in_at' => ($attendance?->am_in_at ?? $attendance?->check_in_at)?->format(DATE_ATOM),
            'am_out_at' => $attendance?->am_out_at?->format(DATE_ATOM),
            'pm_in_at' => $attendance?->pm_in_at?->format(DATE_ATOM),
            'pm_out_at' => ($attendance?->pm_out_at ?? $attendance?->check_out_at)?->format(DATE_ATOM),
            'ot_in_at' => $attendance?->ot_in_at?->format(DATE_ATOM),
            'ot_out_at' => $attendance?->ot_out_at?->format(DATE_ATOM),
            'worked_minutes' => $workedMinutes,
            'worked_hours' => round($workedMinutes / 60, 2),
        ];
    }

    private function status(Carbon $date, ?Attendance $attendance, bool $isOnLeave): string
    {
        if ($attendance?->check_in_at) {
            $scheduledStart = Carbon::parse($date->toDateString().' '.config('attendance.start_time'));
            $lateAfter = $scheduledStart->addMinutes((int) config('attendance.grace_minutes'));

            return $attendance->check_in_at->greaterThan($lateAfter) ? 'late' : 'present';
        }

        if (! $date->isWeekday()) {
            return 'day_off';
        }

        if ($isOnLeave) {
            return 'on_leave';
        }

        $now = now();
        $today = $now->copy()->startOfDay();

        if ($date->greaterThan($today)) {
            return 'not_started';
        }

        $cutoff = Carbon::parse($date->toDateString().' '.config('attendance.start_time'))
            ->addMinutes((int) config('attendance.grace_minutes'));

        if ($date->isSameDay($today) && ! $now->greaterThan($cutoff)) {
            return 'not_started';
        }

        return 'absent';
    }

    private function workedMinutes(?Attendance $attendance, Carbon $date): int
    {
        if ($attendance && ($attendance->am_in_at || $attendance->am_out_at || $attendance->pm_in_at || $attendance->pm_out_at)) {
            return $this->segmentedWorkedMinutes($attendance, now());
        }

        if (! $attendance?->check_in_at) {
            return 0;
        }

        $end = $attendance->check_out_at ?? now();

        if (! $attendance->check_out_at) {
            $scheduledEnd = Carbon::parse($date->toDateString().' '.config('attendance.end_time'));
            if ($end->greaterThan($scheduledEnd)) {
                $end = $scheduledEnd;
            }
        }

        return max(0, intdiv($end->getTimestamp() - $attendance->check_in_at->getTimestamp(), 60));
    }

    private function segmentedWorkedMinutes(Attendance $attendance, Carbon $now): int
    {
        $minutes = 0;

        foreach (
            [['am_in_at', 'am_out_at'], ['pm_in_at', 'pm_out_at'], ['ot_in_at', 'ot_out_at']] as [$startField, $endField]
        ) {
            $start = $attendance->{$startField};
            if (! $start) {
                continue;
            }

            $end = $attendance->{$endField} ?? $now;
            if ($end->greaterThan($start)) {
                $minutes += intdiv($end->getTimestamp() - $start->getTimestamp(), 60);
            }
        }

        return $minutes;
    }

    private function settings(): array
    {
        return [
            'start_time' => config('attendance.start_time'),
            'end_time' => config('attendance.end_time'),
            'grace_minutes' => (int) config('attendance.grace_minutes'),
        ];
    }
}
