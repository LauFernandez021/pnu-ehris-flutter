<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Employee;
use App\Models\LeaveBalance;
use App\Models\LeaveRequest;
use App\Models\LeaveType;
use App\Support\AuditLogger;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class LeaveController extends Controller
{
    private const WITH = [
        'employee:id,user_id,employee_no,first_name,last_name,department_id',
        'leaveType:id,name',
    ];

    private function me(Request $request): Employee
    {
        $employee = $request->user()->employee;
        if (! $employee) {
            abort(422, 'Your account has no employee record.');
        }

        return $employee;
    }

    private function balanceFor(Employee $employee, LeaveType $type, int $year): LeaveBalance
    {
        return LeaveBalance::firstOrCreate(
            ['employee_id' => $employee->id, 'leave_type_id' => $type->id, 'year' => $year],
            ['allocated' => $type->days_per_year, 'used' => 0]
        );
    }

    private function pendingDays(Employee $employee, int $typeId, int $year): float
    {
        return (float) LeaveRequest::where('employee_id', $employee->id)
            ->where('leave_type_id', $typeId)
            ->where('status', 'pending')
            ->whereYear('start_date', $year)
            ->sum('days');
    }

    // Weekdays only. Holidays are not excluded yet.
    private function workingDays(Carbon $start, Carbon $end): int
    {
        $days = 0;
        for ($d = $start->copy(); $d->lte($end); $d->addDay()) {
            if (! $d->isWeekend()) {
                $days++;
            }
        }

        return $days;
    }

    private function canReview(Request $request, LeaveRequest $leave): bool
    {
        $user = $request->user();

        if ($leave->employee->user_id === $user->id) {
            return false; // nobody approves their own leave
        }
        if ($user->hasAnyRole(['admin', 'hr'])) {
            return true;
        }
        if ($user->hasRole('manager')) {
            $mine = $user->employee;

            return $mine && $mine->department_id
                && $mine->department_id === $leave->employee->department_id;
        }

        return false;
    }

    private function authorizeReview(Request $request, LeaveRequest $leave): void
    {
        $leave->loadMissing('employee');
        if (! $this->canReview($request, $leave)) {
            abort(403, 'You cannot review this request.');
        }
    }

    // The owner and the people allowed to review the request can open the proof.
    public function attachment(Request $request, LeaveRequest $leaveRequest)
    {
        $leaveRequest->loadMissing('employee');
        $isOwner = $leaveRequest->employee->user_id === $request->user()->id;

        abort_unless($isOwner || $this->canReview($request, $leaveRequest), 403);
        abort_unless($leaveRequest->attachment_path && Storage::exists($leaveRequest->attachment_path), 404);

        return Storage::download(
            $leaveRequest->attachment_path,
            $leaveRequest->attachment_name ?: 'attachment'
        );
    }

    public function types()
    {
        return LeaveType::orderBy('name')->get(['id', 'name', 'days_per_year']);
    }

    public function manageTypes(Request $request)
    {
        $query = $request->query('trashed') === 'only'
            ? LeaveType::onlyTrashed()
            : LeaveType::query();

        return $query->orderBy('name')->get([
            'id',
            'name',
            'days_per_year',
            'attachment_required_from_days',
            'deleted_at',
        ]);
    }

    public function storeType(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100', Rule::unique('leave_types', 'name')],
            'days_per_year' => ['required', 'integer', 'min:0', 'max:365'],
            'attachment_required_from_days' => ['nullable', 'integer', 'min:0', 'max:365'],
        ]);

        return response()->json(LeaveType::create($data), 201);
    }

    public function updateType(Request $request, int $leaveTypeId)
    {
        $leaveType = LeaveType::findOrFail($leaveTypeId);
        $data = $request->validate([
            'name' => [
                'required',
                'string',
                'max:100',
                Rule::unique('leave_types', 'name')->ignore($leaveType->id),
            ],
            'days_per_year' => ['required', 'integer', 'min:0', 'max:365'],
            'attachment_required_from_days' => ['nullable', 'integer', 'min:0', 'max:365'],
        ]);
        $leaveType->update($data);

        return $leaveType->fresh();
    }

    public function destroyType(int $leaveTypeId)
    {
        $leaveType = LeaveType::findOrFail($leaveTypeId);

        if (
            LeaveBalance::where('leave_type_id', $leaveType->id)->exists()
            || LeaveRequest::withTrashed()->where('leave_type_id', $leaveType->id)->exists()
        ) {
            throw ValidationException::withMessages([
                'leave_type' => 'This leave type has balances or request history and cannot be archived.',
            ]);
        }

        $leaveType->delete();

        return response()->noContent();
    }

    public function restoreType(int $leaveTypeId)
    {
        $leaveType = LeaveType::withTrashed()->findOrFail($leaveTypeId);
        if (! $leaveType->trashed()) {
            abort(422, 'This leave type is not archived.');
        }
        $leaveType->restore();

        return $leaveType->fresh();
    }

    public function myBalances(Request $request)
    {
        $employee = $this->me($request);
        $year = (int) now()->year;

        return LeaveType::orderBy('name')->get()->map(function ($type) use ($employee, $year) {
            $b = $this->balanceFor($employee, $type, $year);

            return [
                'leave_type_id' => $type->id,
                'leave_type' => $type->name,
                'year' => $year,
                'allocated' => (float) $b->allocated,
                'used' => (float) $b->used,
                'remaining' => (float) $b->allocated - (float) $b->used,
                'pending' => $this->pendingDays($employee, $type->id, $year),
            ];
        })->values();
    }

    public function myRequests(Request $request)
    {
        return LeaveRequest::with('leaveType:id,name')
            ->where('employee_id', $this->me($request)->id)
            ->latest()->paginate(50);
    }

    public function store(Request $request)
    {
        $employee = $this->me($request);

        $data = $request->validate([
            'leave_type_id' => [
                'required',
                Rule::exists('leave_types', 'id')->where(
                    fn ($query) => $query->whereNull('deleted_at')
                ),
            ],
            'start_date' => 'required|date|after_or_equal:today',
            'end_date' => 'required|date|after_or_equal:start_date',
            'reason' => 'nullable|string|max:500',
            'attachment' => 'nullable|file|mimes:jpg,jpeg,png,pdf|max:8192',
        ]);

        $start = Carbon::parse($data['start_date'])->startOfDay();
        $end = Carbon::parse($data['end_date'])->startOfDay();

        if ($start->year !== $end->year) {
            throw ValidationException::withMessages(
                ['end_date' => 'A request cannot span two years. Please file them separately.']
            );
        }

        $days = $this->workingDays($start, $end);
        if ($days < 1) {
            throw ValidationException::withMessages(
                ['start_date' => 'The selected dates have no working days.']
            );
        }

        $overlap = LeaveRequest::where('employee_id', $employee->id)
            ->whereIn('status', ['pending', 'approved'])
            ->where('start_date', '<=', $end->toDateString())
            ->where('end_date', '>=', $start->toDateString())
            ->exists();
        if ($overlap) {
            throw ValidationException::withMessages(
                ['start_date' => 'You already have a leave request on these dates.']
            );
        }

        $type = LeaveType::findOrFail($data['leave_type_id']);
        $balance = $this->balanceFor($employee, $type, $start->year);
        $available = $balance->allocated - $balance->used
            - $this->pendingDays($employee, $type->id, $start->year);

        if ($days > $available) {
            throw ValidationException::withMessages(
                ['leave_type_id' => "Not enough balance. Available: {$available} day(s), requested: {$days}."]
            );
        }

        $file = $request->file('attachment');
        $from = $type->attachment_required_from_days;
        if ($from !== null && $days >= $from && ! $file) {
            throw ValidationException::withMessages([
                'attachment' => "Please attach proof (for example a medical certificate) for {$type->name} of {$from} or more working days.",
            ]);
        }

        $leave = LeaveRequest::create([
            'employee_id' => $employee->id,
            'leave_type_id' => $type->id,
            'start_date' => $data['start_date'],
            'end_date' => $data['end_date'],
            'days' => $days,
            'reason' => $data['reason'] ?? null,
            'status' => 'pending',
            'attachment_path' => $file?->store('leave-attachments'),
            'attachment_name' => $file ? Str::limit($file->getClientOriginalName(), 150, '') : null,
        ]);

        return response()->json($leave->load(self::WITH), 201);
    }

    public function cancel(Request $request, LeaveRequest $leaveRequest)
    {
        abort_unless($leaveRequest->employee_id === $this->me($request)->id, 403);

        $updated = LeaveRequest::whereKey($leaveRequest->id)
            ->where('status', 'pending')->update(['status' => 'cancelled']);
        if (! $updated) {
            abort(422, 'Only pending requests can be cancelled.');
        }

        return $leaveRequest->fresh()->load(self::WITH);
    }

    // For approvers: admin/HR see everything, managers see their own department.
    public function index(Request $request)
    {
        $user = $request->user();
        $query = $request->query('trashed') === 'only'
            ? LeaveRequest::onlyTrashed()->with(self::WITH)->latest()
            : LeaveRequest::with(self::WITH)->latest();

        abort_if(
            $request->query('trashed') === 'only' && ! $user->hasAnyRole(['admin', 'hr']),
            403
        );

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if (! $user->hasAnyRole(['admin', 'hr'])) {
            $dept = $user->employee?->department_id;
            if (! $dept) {
                $query->whereRaw('1 = 0');
            } else {
                $query->whereHas('employee', fn ($q) => $q
                    ->where('department_id', $dept)
                    ->where('user_id', '!=', $user->id));
            }
        }

        return $query->paginate(50);
    }

    public function destroy(Request $request, LeaveRequest $leaveRequest)
    {
        abort_unless($request->user()->hasAnyRole(['admin', 'hr']), 403);
        if ($leaveRequest->status === 'approved' || $leaveRequest->status === 'pending') {
            throw ValidationException::withMessages([
                'leave_request' => 'Pending or approved leave requests cannot be archived.',
            ]);
        }
        $leaveRequest->delete();

        return response()->noContent();
    }

    public function restore(Request $request, int $leaveRequestId)
    {
        abort_unless($request->user()->hasAnyRole(['admin', 'hr']), 403);
        $leaveRequest = LeaveRequest::withTrashed()->findOrFail($leaveRequestId);
        if (! $leaveRequest->trashed()) {
            abort(422, 'This leave request is not archived.');
        }
        $leaveRequest->restore();

        return $leaveRequest->fresh()->load(self::WITH);
    }

    public function approve(Request $request, LeaveRequest $leaveRequest)
    {
        $this->authorizeReview($request, $leaveRequest);

        DB::transaction(function () use ($request, $leaveRequest) {
            $leave = LeaveRequest::with(['employee', 'leaveType'])
                ->whereKey($leaveRequest->id)->lockForUpdate()->firstOrFail();

            if ($leave->status !== 'pending') {
                abort(422, 'This request was already processed.');
            }

            $balance = $this->balanceFor(
                $leave->employee,
                $leave->leaveType,
                Carbon::parse($leave->start_date)->year
            );
            $balance = LeaveBalance::whereKey($balance->id)->lockForUpdate()->first();

            if ($balance->allocated - $balance->used < $leave->days) {
                abort(422, 'The employee does not have enough leave balance.');
            }

            $balance->increment('used', $leave->days);
            $leave->update([
                'status' => 'approved',
                'reviewed_by' => $request->user()->id,
                'reviewed_at' => now(),
                'review_note' => $request->input('note'),
            ]);
            app(AuditLogger::class)->log($request, 'leave_request.approved', $leave);
        });

        return $leaveRequest->fresh()->load(self::WITH);
    }

    public function reject(Request $request, LeaveRequest $leaveRequest)
    {
        $data = $request->validate(['note' => 'required|string|max:500']);
        $this->authorizeReview($request, $leaveRequest);

        DB::transaction(function () use ($request, $leaveRequest, $data) {
            $updated = LeaveRequest::whereKey($leaveRequest->id)
                ->where('status', 'pending')
                ->update([
                    'status' => 'rejected',
                    'reviewed_by' => $request->user()->id,
                    'reviewed_at' => now(),
                    'review_note' => $data['note'],
                ]);
            if (! $updated) {
                abort(422, 'This request was already processed.');
            }

            app(AuditLogger::class)->log($request, 'leave_request.rejected', $leaveRequest);
        });

        return $leaveRequest->fresh()->load(self::WITH);
    }
}
