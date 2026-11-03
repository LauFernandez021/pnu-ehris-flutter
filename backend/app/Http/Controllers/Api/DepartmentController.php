<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Department;
use App\Models\Employee;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class DepartmentController extends Controller
{
    public function index(Request $request)
    {
        abort_if(
            $request->query('trashed') === 'only'
                && ! $request->user()->hasAnyRole(['admin', 'hr']),
            403
        );

        $query = $request->query('trashed') === 'only'
            ? Department::onlyTrashed()
            : Department::query();

        return $query->orderBy('name')->get(['id', 'name']);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:100|unique:departments,name',
        ]);

        return response()->json(Department::create($data), 201);
    }

    public function update(Request $request, Department $department)
    {
        $data = $request->validate([
            'name' => [
                'required',
                'string',
                'max:100',
                Rule::unique('departments', 'name')->ignore($department->id),
            ],
        ]);
        $department->update($data);

        return $department->fresh();
    }

    public function destroy(Department $department)
    {
        if (Employee::withTrashed()->where('department_id', $department->id)->exists()) {
            throw ValidationException::withMessages([
                'department' => 'This department is still assigned to employee records and cannot be archived.',
            ]);
        }

        $department->delete();

        return response()->noContent();
    }

    public function restore(int $departmentId)
    {
        $department = Department::withTrashed()->findOrFail($departmentId);
        if (! $department->trashed()) {
            abort(422, 'This department is not archived.');
        }
        $department->restore();

        return $department->fresh();
    }
}
