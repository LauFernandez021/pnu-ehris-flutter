<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Employee;
use App\Models\PassSlip;
use App\Support\AuditLogger;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PassSlipController extends Controller
{
    private const WITH = ['employee:id,user_id,employee_no,first_name,last_name,department_id'];

    private function me(Request $request): Employee
    {
        $employee = $request->user()->employee;
        if (! $employee) {
            abort(422, 'Your account has no employee record.');
        }

        return $employee;
    }

    // Admin/HR review anyone; managers review their own department; never your own slip.
    private function authorizeReview(Request $request, PassSlip $slip): void
    {
        $user = $request->user();
        $slip->loadMissing('employee');

        $allowed = false;
        if ($slip->employee->user_id !== $user->id) {
            if ($user->hasAnyRole(['admin', 'hr'])) {
                $allowed = true;
            } elseif ($user->hasRole('manager')) {
                $mine = $user->employee;
                $allowed = $mine && $mine->department_id
                    && $mine->department_id === $slip->employee->department_id;
            }
        }

        abort_unless($allowed, 403, 'You cannot review this pass slip.');
    }

    public function mine(Request $request)
    {
        return PassSlip::where('employee_id', $this->me($request)->id)
            ->orderByDesc('slip_date')->orderByDesc('time_out')->paginate(50);
    }

    public function store(Request $request)
    {
        $employee = $this->me($request);

        $data = $request->validate([
            'slip_type' => 'required|in:personal,official',
            'slip_date' => 'required|date|after_or_equal:today',
            'time_out' => 'required|date_format:H:i',
            'time_in' => 'required|date_format:H:i|after:time_out',
            'destination' => 'required|string|max:150',
            'reason' => 'nullable|string|max:500',
        ]);

        if (Carbon::parse($data['slip_date'])->isToday()
            && $data['time_in'] <= now()->format('H:i')) {
            throw ValidationException::withMessages(
                ['time_in' => 'That return time has already passed.']);
        }

        $overlap = PassSlip::where('employee_id', $employee->id)
            ->whereIn('status', ['pending', 'approved'])
            ->where('slip_date', $data['slip_date'])
            ->where('time_out', '<', $data['time_in'])
            ->where('time_in', '>', $data['time_out'])
            ->exists();
        if ($overlap) {
            throw ValidationException::withMessages(
                ['time_out' => 'You already have a pass slip at that time.']);
        }

        $slip = PassSlip::create($data + ['employee_id' => $employee->id, 'status' => 'pending']);

        return response()->json($slip->load(self::WITH), 201);
    }

    public function cancel(Request $request, PassSlip $passSlip)
    {
        abort_unless($passSlip->employee_id === $this->me($request)->id, 403);

        $updated = PassSlip::whereKey($passSlip->id)
            ->where('status', 'pending')->update(['status' => 'cancelled']);
        if (! $updated) {
            abort(422, 'Only pending pass slips can be cancelled.');
        }

        return $passSlip->fresh()->load(self::WITH);
    }

    public function index(Request $request)
    {
        $user = $request->user();
        $query = ($request->query('trashed') === 'only'
            ? PassSlip::onlyTrashed()
            : PassSlip::query())
            ->with(self::WITH)
            ->orderByDesc('slip_date')->orderByDesc('time_out');

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

    public function destroy(Request $request, PassSlip $passSlip)
    {
        abort_unless($request->user()->hasAnyRole(['admin', 'hr']), 403);
        if (in_array($passSlip->status, ['pending', 'approved'], true)) {
            throw ValidationException::withMessages([
                'pass_slip' => 'Pending or approved pass slips cannot be archived.',
            ]);
        }
        $passSlip->delete();

        return response()->noContent();
    }

    public function restore(Request $request, int $passSlipId)
    {
        abort_unless($request->user()->hasAnyRole(['admin', 'hr']), 403);
        $passSlip = PassSlip::withTrashed()->findOrFail($passSlipId);
        if (! $passSlip->trashed()) {
            abort(422, 'This pass slip is not archived.');
        }
        $passSlip->restore();

        return $passSlip->fresh()->load(self::WITH);
    }

    public function approve(Request $request, PassSlip $passSlip)
    {
        $this->authorizeReview($request, $passSlip);

        DB::transaction(function () use ($request, $passSlip) {
            $updated = PassSlip::whereKey($passSlip->id)
                ->where('status', 'pending')
                ->update([
                    'status' => 'approved',
                    'reviewed_by' => $request->user()->id,
                    'reviewed_at' => now(),
                    'review_note' => $request->input('note'),
                ]);
            if (! $updated) {
                abort(422, 'This pass slip was already processed.');
            }

            app(AuditLogger::class)->log($request, 'pass_slip.approved', $passSlip);
        });

        return $passSlip->fresh()->load(self::WITH);
    }

    public function reject(Request $request, PassSlip $passSlip)
    {
        $data = $request->validate(['note' => 'required|string|max:500']);
        $this->authorizeReview($request, $passSlip);

        DB::transaction(function () use ($request, $passSlip, $data) {
            $updated = PassSlip::whereKey($passSlip->id)
                ->where('status', 'pending')
                ->update([
                    'status' => 'rejected',
                    'reviewed_by' => $request->user()->id,
                    'reviewed_at' => now(),
                    'review_note' => $data['note'],
                ]);
            if (! $updated) {
                abort(422, 'This pass slip was already processed.');
            }

            app(AuditLogger::class)->log($request, 'pass_slip.rejected', $passSlip);
        });

        return $passSlip->fresh()->load(self::WITH);
    }
}
