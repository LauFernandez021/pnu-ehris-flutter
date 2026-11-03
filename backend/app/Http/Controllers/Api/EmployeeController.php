<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Employee;
use App\Models\User;
use App\Support\AuditLogger;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class EmployeeController extends Controller
{
    private const WITH = ['user:id,email', 'user.roles', 'department:id,name'];

    private function assignableRoles(Request $request): array
    {
        return $request->user()->hasRole('admin')
            ? ['admin', 'hr', 'manager', 'employee']
            : ['manager', 'employee'];
    }

    // HR users may not touch admin or HR accounts.
    private function guardTarget(Request $request, Employee $employee): void
    {
        if (
            ! $request->user()->hasRole('admin')
            && $employee->user->hasAnyRole(['admin', 'hr'])
        ) {
            abort(403, 'Only an admin can modify this account.');
        }
    }

    public function index(Request $request)
    {
        $query = $request->query('trashed') === 'only'
            ? Employee::onlyTrashed()
            : Employee::query();

        return $query->with(self::WITH)
            ->when($request->query('status'), fn ($q, $s) => $q->where('status', $s))
            ->when($request->boolean('self_registered'), fn ($q) => $q->where('self_registered', true))
            ->orderBy('last_name')
            ->paginate(min((int) $request->query('per_page', 20), 200));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email|unique:users,email',
            'password' => ['required', Password::min(10)->mixedCase()->numbers()],
            'role' => ['required', Rule::in($this->assignableRoles($request))],
            'employee_no' => 'required|unique:employees,employee_no',
            'rfid_card_number' => ['nullable', 'string', 'max:100', 'unique:employees,rfid_card_number'],
            'first_name' => 'required|string|max:100',
            'last_name' => 'required|string|max:100',
            'department_id' => [
                'nullable',
                Rule::exists('departments', 'id')->where(
                    fn ($query) => $query->whereNull('deleted_at')
                ),
            ],
            'position' => 'nullable|string|max:100',
            'date_hired' => 'nullable|date',
            'device_user_id' => 'nullable|unique:employees,device_user_id',
        ]);

        $employee = DB::transaction(function () use ($data, $request) {
            $user = User::create([
                'name' => $data['first_name'].' '.$data['last_name'],
                'email' => $data['email'],
                'password' => Hash::make($data['password']),
                'must_change_password' => true,
            ]);
            $user->assignRole($data['role']);

            $employee = Employee::create(Arr::only($data, [
                'employee_no',
                'rfid_card_number',
                'first_name',
                'last_name',
                'department_id',
                'position',
                'date_hired',
                'device_user_id',
            ]) + ['user_id' => $user->id]);
            app(AuditLogger::class)->log($request, 'employee.created', $employee);

            return $employee;
        });

        return response()->json($employee->refresh()->load(self::WITH), 201);
    }

    public function show(Employee $employee)
    {
        return $employee->load(self::WITH);
    }

    public function update(Request $request, Employee $employee)
    {
        $this->guardTarget($request, $employee);

        $actor = $request->user();
        $target = $employee->user;

        $data = $request->validate([
            'employee_no' => [
                'sometimes',
                'string',
                'max:50',
                Rule::unique('employees', 'employee_no')->ignore($employee->id),
            ],
            'email' => [
                'sometimes',
                'email',
                Rule::unique('users', 'email')->ignore($target->id),
            ],
            'role' => ['sometimes', Rule::in($this->assignableRoles($request))],
            'new_password' => ['sometimes', 'nullable', Password::min(10)->mixedCase()->numbers()],
            'first_name' => 'sometimes|string|max:100',
            'last_name' => 'sometimes|string|max:100',
            'department_id' => [
                'nullable',
                Rule::exists('departments', 'id')->where(
                    fn ($query) => $query->whereNull('deleted_at')
                ),
            ],
            'position' => 'nullable|string|max:100',
            'date_hired' => 'nullable|date',
            'status' => 'sometimes|in:active,inactive',
            'device_user_id' => [
                'nullable',
                Rule::unique('employees', 'device_user_id')->ignore($employee->id),
            ],
            'rfid_card_number' => [
                'nullable',
                'string',
                'max:100',
                Rule::unique('employees', 'rfid_card_number')->ignore($employee->id),
            ],
        ]);

        // Nobody can lock themselves out or demote themselves by accident.
        if ($target->id === $actor->id) {
            if (isset($data['role']) && ! $target->hasRole($data['role'])) {
                throw ValidationException::withMessages(
                    ['role' => 'You cannot change your own role.']
                );
            }
            if (($data['status'] ?? 'active') === 'inactive') {
                throw ValidationException::withMessages(
                    ['status' => 'You cannot deactivate your own account.']
                );
            }
        }

        $auditMeta = [
            'changed_fields' => array_values(array_diff(
                array_keys($data),
                ['new_password'],
            )),
            'password_reset' => ! empty($data['new_password']) && $target->id !== $actor->id,
        ];

        DB::transaction(function () use ($data, $employee, $target, $actor, $request, $auditMeta) {
            $employee->update(Arr::only($data, [
                'employee_no',
                'first_name',
                'last_name',
                'department_id',
                'position',
                'date_hired',
                'status',
                'device_user_id',
                'rfid_card_number',
            ]));

            $userChanges = ['name' => $employee->first_name.' '.$employee->last_name];
            if (isset($data['email'])) {
                $userChanges['email'] = $data['email'];
            }
            if (! empty($data['new_password'])) {
                $userChanges['password'] = Hash::make($data['new_password']);
                if ($target->id !== $actor->id) {
                    $userChanges['must_change_password'] = true;
                }
            }
            $target->update($userChanges);

            if (isset($data['role'])) {
                $target->syncRoles([$data['role']]);
            }
            app(AuditLogger::class)->log($request, 'employee.updated', $employee, $auditMeta);
        });

        // Sign the person out everywhere if their access changed.
        $accessChanged = ! empty($data['new_password'])
            || ($data['status'] ?? null) === 'inactive'
            || (isset($data['role']) && $data['role'] !== $target->getRoleNames()->first());
        if ($target->id !== $actor->id && $accessChanged) {
            $target->tokens()->delete();
        }

        return $employee->fresh()->load(self::WITH);
    }

    public function destroy(Request $request, Employee $employee)
    {
        $this->guardTarget($request, $employee);

        if ($employee->user_id === $request->user()->id) {
            abort(422, 'You cannot delete your own account.');
        }

        DB::transaction(function () use ($request, $employee) {
            app(AuditLogger::class)->log($request, 'employee.deleted', $employee);
            $employee->delete();
            $employee->user->tokens()->delete();
        });

        return response()->noContent();
    }

    public function restore(Request $request, int $employeeId)
    {
        $employee = Employee::withTrashed()->findOrFail($employeeId);
        $this->guardTarget($request, $employee);

        if (! $employee->trashed()) {
            abort(422, 'This employee is not archived.');
        }

        $employee->restore();

        return $employee->fresh()->load(self::WITH);
    }

    public function approve(Request $request, Employee $employee)
    {
        $this->guardTarget($request, $employee);

        $data = $request->validate([
            'department_id' => [
                'nullable',
                Rule::exists('departments', 'id')->where(
                    fn ($query) => $query->whereNull('deleted_at')
                ),
            ],
            'position' => 'nullable|string|max:100',
            'device_user_id' => [
                'nullable',
                Rule::unique('employees', 'device_user_id')->ignore($employee->id),
            ],
        ]);

        DB::transaction(function () use ($request, $employee, $data) {
            $updated = Employee::whereKey($employee->id)
                ->whereIn('status', ['pending', 'rejected'])
                ->update([
                    'status' => 'active',
                    'reviewed_by' => $request->user()->id,
                    'reviewed_at' => now(),
                    'review_note' => null,
                ] + Arr::only($data, ['department_id', 'position', 'device_user_id']));

            if (! $updated) {
                abort(422, 'This account is not waiting for approval.');
            }

            app(AuditLogger::class)->log($request, 'employee.approved', $employee, [
                'department_id' => $data['department_id'] ?? null,
            ]);
        });

        return $employee->fresh()->load(self::WITH);
    }

    public function reject(Request $request, Employee $employee)
    {
        $this->guardTarget($request, $employee);
        $data = $request->validate(['note' => 'required|string|max:500']);

        DB::transaction(function () use ($request, $employee, $data) {
            $updated = Employee::whereKey($employee->id)
                ->where('status', 'pending')
                ->update([
                    'status' => 'rejected',
                    'reviewed_by' => $request->user()->id,
                    'reviewed_at' => now(),
                    'review_note' => $data['note'],
                ]);

            if (! $updated) {
                abort(422, 'This account is not waiting for approval.');
            }

            $employee->user->tokens()->delete();
            app(AuditLogger::class)->log($request, 'employee.rejected', $employee);
        });

        return $employee->fresh()->load(self::WITH);
    }

    // Streams a verification photo. Only admin/HR can reach this route.
    public function document(Request $request, Employee $employee, string $kind)
    {
        abort_unless(in_array($kind, ['id', 'selfie'], true), 404);

        $path = $kind === 'id' ? $employee->id_photo_path : $employee->selfie_path;
        abort_unless($path && Storage::exists($path), 404);

        app(AuditLogger::class)->log($request, "employee.{$kind}_photo_viewed", $employee);

        return Storage::response($path);
    }
}
