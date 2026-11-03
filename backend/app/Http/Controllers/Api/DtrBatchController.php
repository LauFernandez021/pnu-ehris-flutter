<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Attendance;
use App\Models\DtrBatch;
use App\Models\DtrBatchEmployee;
use App\Models\Employee;
use App\Models\LeaveRequest;
use App\Services\DtrAttendanceSynchronizer;
use Carbon\Carbon;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class DtrBatchController extends Controller
{
    public function employees(): Collection
    {
        return Employee::query()
            ->where('status', 'active')
            ->with('department:id,name')
            ->orderBy('last_name')
            ->orderBy('first_name')
            ->get(['id', 'employee_no', 'first_name', 'last_name', 'position', 'department_id'])
            ->map(fn (Employee $employee): array => [
                'id' => $employee->id,
                'employee_no' => $employee->employee_no,
                'employee_name' => trim($employee->first_name.' '.$employee->last_name),
                'designation' => $employee->position,
                'department' => $employee->department?->name,
            ]);
    }

    public function index(Request $request): LengthAwarePaginator
    {
        $query = $request->query('trashed') === 'only'
            ? DtrBatch::onlyTrashed()
            : DtrBatch::query();

        return $query
            ->withCount('employees')
            ->latest('id')
            ->paginate(25)
            ->through(fn (DtrBatch $batch): array => $this->batchPayload($batch));
    }

    public function mine(Request $request): Collection
    {
        $employee = $this->currentEmployee($request);

        return DtrBatch::query()
            ->whereHas('employees', fn ($query) => $query->where('employee_id', $employee->id))
            ->withCount('employees')
            ->latest('id')
            ->get()
            ->map(fn (DtrBatch $batch): array => $this->batchPayload($batch));
    }

    public function mineShow(Request $request, DtrBatch $dtrBatch): array
    {
        $employee = $this->currentEmployee($request);
        abort_unless(
            $dtrBatch->employees()->where('employee_id', $employee->id)->exists(),
            404
        );
        $dtrBatch->setRelation(
            'employees',
            $dtrBatch->employees()
                ->where('employee_id', $employee->id)
                ->with('entries')
                ->get()
        );

        return $this->batchPayload($dtrBatch, includeEmployees: true);
    }

    public function show(DtrBatch $dtrBatch): array
    {
        $dtrBatch->load(['employees.entries']);

        return $this->batchPayload($dtrBatch, includeEmployees: true);
    }

    public function destroy(DtrBatch $dtrBatch)
    {
        $dtrBatch->delete();

        return response()->noContent();
    }

    public function restore(int $dtrBatchId): array
    {
        $dtrBatch = DtrBatch::withTrashed()->findOrFail($dtrBatchId);
        if (! $dtrBatch->trashed()) {
            abort(422, 'This DTR batch is not archived.');
        }
        $dtrBatch->restore();

        return $this->show($dtrBatch->fresh());
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'period_type' => ['required', 'in:monthly,semi_monthly'],
            'pay_period' => ['nullable', 'required_if:period_type,semi_monthly', 'in:first_cutoff,second_cutoff'],
            'year' => ['required', 'integer', 'between:2000,2100'],
            'month' => ['required', 'integer', 'between:1,12'],
            'transaction_date' => ['required', 'date_format:Y-m-d'],
            'remarks' => ['nullable', 'string', 'max:2000'],
            'employee_selection' => ['required', 'in:all,selected'],
            'employee_ids' => ['required_if:employee_selection,selected', 'array', 'min:1'],
            'employee_ids.*' => ['integer', 'distinct', 'exists:employees,id'],
        ]);

        $periodStart = Carbon::createFromDate($data['year'], $data['month'], 1)->startOfMonth();
        $periodEnd = $periodStart->copy()->endOfMonth();

        if ($data['period_type'] === 'semi_monthly') {
            if ($data['pay_period'] === 'first_cutoff') {
                $periodEnd->setDay(15);
            } else {
                $periodStart->setDay(16);
            }
        } else {
            $data['pay_period'] = null;
        }

        $employeeQuery = Employee::query()
            ->where('status', 'active')
            ->where(function ($query) use ($periodEnd): void {
                $query->whereNull('date_hired')
                    ->orWhereDate('date_hired', '<=', $periodEnd->toDateString());
            })
            ->with('department:id,name')
            ->orderBy('last_name')
            ->orderBy('first_name');

        if ($data['employee_selection'] === 'selected') {
            $employeeQuery->whereIn('id', $data['employee_ids']);
        }

        $employees = $employeeQuery->get();

        if ($employees->isEmpty()) {
            throw ValidationException::withMessages([
                'employee_ids' => 'Select at least one active employee for this DTR.',
            ]);
        }

        if (
            $data['employee_selection'] === 'selected'
            && $employees->count() !== count(array_unique($data['employee_ids']))
        ) {
            throw ValidationException::withMessages([
                'employee_ids' => 'One or more selected employees are inactive or not eligible for this period.',
            ]);
        }

        $creatorId = $request->user()->id;
        $batch = DB::transaction(function () use (
            $data,
            $employees,
            $periodStart,
            $periodEnd,
            $creatorId
        ): DtrBatch {
            $batch = DtrBatch::create([
                'period_type' => $data['period_type'],
                'pay_period' => $data['pay_period'],
                'year' => $data['year'],
                'month' => $data['month'],
                'start_date' => $periodStart->toDateString(),
                'end_date' => $periodEnd->toDateString(),
                'transaction_date' => $data['transaction_date'],
                'remarks' => $data['remarks'] ?? null,
                'created_by' => $creatorId,
            ]);

            $batch->update([
                'dtr_code' => 'DTR-'.str_pad((string) $batch->id, 5, '0', STR_PAD_LEFT),
            ]);

            $employeeIds = $employees->modelKeys();
            $attendanceByEmployeeAndDate = Attendance::query()
                ->whereIn('employee_id', $employeeIds)
                ->whereBetween('attendance_date', [
                    $periodStart->toDateString(),
                    $periodEnd->toDateString(),
                ])
                ->get()
                ->keyBy(fn (Attendance $attendance): string => $attendance->employee_id.'-'.$attendance->attendance_date->toDateString());

            $approvedLeaves = LeaveRequest::query()
                ->whereIn('employee_id', $employeeIds)
                ->where('status', 'approved')
                ->whereDate('start_date', '<=', $periodEnd->toDateString())
                ->whereDate('end_date', '>=', $periodStart->toDateString())
                ->get(['employee_id', 'start_date', 'end_date']);

            foreach ($employees as $employee) {
                $batchEmployee = $batch->employees()->create([
                    'employee_id' => $employee->id,
                    'employee_no' => $employee->employee_no,
                    'employee_name' => trim($employee->first_name.' '.$employee->last_name),
                    'designation' => $employee->position,
                ]);

                for ($date = $periodStart->copy(); $date->lte($periodEnd); $date->addDay()) {
                    $dateString = $date->toDateString();
                    $attendance = $attendanceByEmployeeAndDate->get($employee->id.'-'.$dateString);
                    $isOnLeave = $approvedLeaves->contains(
                        fn (LeaveRequest $leave): bool => (int) $leave->employee_id === $employee->id
                            && $leave->start_date <= $dateString
                            && $leave->end_date >= $dateString
                    );
                    [$status, $workedMinutes] = app(DtrAttendanceSynchronizer::class)->statusAndMinutes(
                        $date,
                        $employee,
                        $attendance,
                        $isOnLeave
                    );

                    $batchEmployee->entries()->create([
                        'entry_date' => $dateString,
                        'status' => $status,
                        'check_in_at' => $attendance?->check_in_at,
                        'check_out_at' => $attendance?->check_out_at,
                        'am_in_at' => $attendance?->am_in_at ?? $attendance?->check_in_at,
                        'am_out_at' => $attendance?->am_out_at,
                        'pm_in_at' => $attendance?->pm_in_at,
                        'pm_out_at' => $attendance?->pm_out_at ?? $attendance?->check_out_at,
                        'ot_in_at' => $attendance?->ot_in_at,
                        'ot_out_at' => $attendance?->ot_out_at,
                        'worked_minutes' => $workedMinutes,
                    ]);
                }
            }

            return $batch->load(['employees.entries']);
        });

        return response()->json($this->batchPayload($batch, includeEmployees: true), 201);
    }

    private function batchPayload(DtrBatch $batch, bool $includeEmployees = false): array
    {
        $employeeCount = $batch->employees_count ?? $batch->employees->count();
        $payload = [
            'id' => $batch->id,
            'dtr_code' => $batch->dtr_code,
            'period_type' => $batch->period_type,
            'pay_period' => $batch->pay_period,
            'year' => $batch->year,
            'month' => $batch->month,
            'start_date' => $batch->start_date->toDateString(),
            'end_date' => $batch->end_date->toDateString(),
            'transaction_date' => $batch->transaction_date->toDateString(),
            'remarks' => $batch->remarks,
            'employee_count' => $employeeCount,
        ];

        if ($includeEmployees) {
            $payload['employees'] = $batch->employees->map(
                fn (DtrBatchEmployee $employee): array => [
                    'id' => $employee->employee_id,
                    'employee_no' => $employee->employee_no,
                    'employee_name' => $employee->employee_name,
                    'designation' => $employee->designation,
                    'entries' => $employee->entries->map(
                        fn ($entry): array => [
                            'date' => $entry->entry_date->toDateString(),
                            'status' => $entry->status,
                            'check_in_at' => $entry->check_in_at?->format(DATE_ATOM),
                            'check_out_at' => $entry->check_out_at?->format(DATE_ATOM),
                            'am_in_at' => $entry->am_in_at?->format(DATE_ATOM),
                            'am_out_at' => $entry->am_out_at?->format(DATE_ATOM),
                            'pm_in_at' => $entry->pm_in_at?->format(DATE_ATOM),
                            'pm_out_at' => $entry->pm_out_at?->format(DATE_ATOM),
                            'ot_in_at' => $entry->ot_in_at?->format(DATE_ATOM),
                            'ot_out_at' => $entry->ot_out_at?->format(DATE_ATOM),
                            'worked_minutes' => $entry->worked_minutes,
                        ]
                    )->all(),
                ]
            )->all();
        }

        return $payload;
    }

    private function currentEmployee(Request $request): Employee
    {
        $employee = $request->user()->employee;

        if (! $employee || $employee->status !== 'active') {
            abort(422, 'Your account has no active employee record.');
        }

        return $employee;
    }
}
