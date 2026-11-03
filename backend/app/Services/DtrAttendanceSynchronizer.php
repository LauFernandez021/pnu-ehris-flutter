<?php

namespace App\Services;

use App\Models\Attendance;
use App\Models\DtrEntry;
use App\Models\Employee;
use App\Models\LeaveRequest;
use Carbon\Carbon;

class DtrAttendanceSynchronizer
{
    public function sync(Attendance $attendance): void
    {
        $date = Carbon::parse($attendance->attendance_date->toDateString());
        $employee = $attendance->employee;
        $isOnLeave = LeaveRequest::query()
            ->where('employee_id', $attendance->employee_id)
            ->where('status', 'approved')
            ->whereDate('start_date', '<=', $date->toDateString())
            ->whereDate('end_date', '>=', $date->toDateString())
            ->exists();
        [$status, $workedMinutes] = $this->statusAndMinutes(
            $date,
            $employee,
            $attendance,
            $isOnLeave
        );

        DtrEntry::query()
            ->whereDate('entry_date', $date->toDateString())
            ->whereHas(
                'batchEmployee',
                fn ($query) => $query->where('employee_id', $attendance->employee_id)
            )
            ->update([
                'status' => $status,
                'check_in_at' => $attendance->check_in_at,
                'check_out_at' => $attendance->check_out_at,
                'am_in_at' => $attendance->am_in_at ?? $attendance->check_in_at,
                'am_out_at' => $attendance->am_out_at,
                'pm_in_at' => $attendance->pm_in_at,
                'pm_out_at' => $attendance->pm_out_at ?? $attendance->check_out_at,
                'ot_in_at' => $attendance->ot_in_at,
                'ot_out_at' => $attendance->ot_out_at,
                'worked_minutes' => $workedMinutes,
            ]);
    }

    public function statusAndMinutes(
        Carbon $date,
        Employee $employee,
        ?Attendance $attendance,
        bool $isOnLeave
    ): array {
        $dateString = $date->toDateString();
        if ($employee->date_hired && $employee->date_hired > $dateString) {
            return ['not_employed', 0];
        }

        if (! $date->isWeekday()) {
            return ['day_off', 0];
        }

        if ($attendance?->check_in_at) {
            $start = Carbon::parse($dateString.' '.config('attendance.start_time'))
                ->addMinutes((int) config('attendance.grace_minutes'));
            $status = $attendance->check_in_at->greaterThan($start) ? 'late' : 'present';
            $workedMinutes = (int) $attendance->worked_minutes;

            if (! $attendance->check_out_at) {
                $end = now();
                $scheduledEnd = Carbon::parse($dateString.' '.config('attendance.end_time'));
                if ($end->greaterThan($scheduledEnd)) {
                    $end = $scheduledEnd;
                }
                $workedMinutes = max(
                    0,
                    intdiv($end->getTimestamp() - $attendance->check_in_at->getTimestamp(), 60)
                );
            }

            return [$status, $workedMinutes];
        }

        if ($isOnLeave) {
            return ['on_leave', 0];
        }

        $today = now()->startOfDay();
        if ($date->greaterThan($today)) {
            return ['not_started', 0];
        }

        $cutoff = Carbon::parse($dateString.' '.config('attendance.start_time'))
            ->addMinutes((int) config('attendance.grace_minutes'));
        if ($date->isSameDay($today) && ! now()->greaterThan($cutoff)) {
            return ['not_started', 0];
        }

        return ['absent', 0];
    }
}
