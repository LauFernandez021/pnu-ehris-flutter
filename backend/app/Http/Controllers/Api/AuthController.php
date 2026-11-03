<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Employee;
use App\Models\User;
use App\Support\AuditLogger;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\PersonalAccessToken;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'password' => 'required',
            'device_name' => 'nullable|string',
        ]);

        $key = 'login:'.strtolower($data['email']).'|'.$request->ip();

        if (RateLimiter::tooManyAttempts($key, 5)) {
            $wait = RateLimiter::availableIn($key);

            return response()->json([
                'message' => "Too many attempts. Try again in {$wait} seconds.",
            ], 429);
        }

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            RateLimiter::hit($key, 300);
            app(AuditLogger::class)->log(
                $request,
                'auth.login_failed',
                $user,
                ['email' => $data['email'], 'reason' => 'invalid_credentials'],
            );

            return response()->json(['message' => 'Invalid credentials'], 401);
        }
        $employee = Employee::withTrashed()->where('user_id', $user->id)->first();
        if ($employee && ($employee->trashed() || $employee->status !== 'active')) {
            $note = $employee->review_note;
            $message = $employee->trashed()
                ? 'This account is inactive.'
                : match ($employee->status) {
                    'pending' => 'Your account is waiting for HR approval.',
                    'rejected' => 'Your registration was not approved.'
                        .($note ? ' Reason: '.$note : ' Please contact HR.'),
                    default => 'This account is inactive.',
                };

            return response()->json(['message' => $message], 403);
        }
        RateLimiter::clear($key);
        $token = $user->createToken($data['device_name'] ?? 'app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $user->only(['id', 'name', 'email', 'must_change_password']),
            'roles' => $user->getRoleNames(),
        ]);
    }

    public function register(Request $request)
    {
        $data = $request->validate([
            'registration_code' => 'nullable|string|max:100',
            'employee_no' => 'required|string|max:50|unique:employees,employee_no',
            'first_name' => 'required|string|max:100',
            'last_name' => 'required|string|max:100',
            'email' => 'required|email|unique:users,email',
            'password' => ['required', 'string', Password::min(10)->mixedCase()->numbers(), 'confirmed'],
            'id_photo' => 'required|image|mimes:jpg,jpeg,png|max:8192',
            'selfie' => 'required|image|mimes:jpg,jpeg,png|max:8192',
        ]);

        $code = config('hrms.registration_code');
        if ($code && ! hash_equals((string) $code, (string) $request->input('registration_code', ''))) {
            throw ValidationException::withMessages(
                ['registration_code' => 'The company registration code is not correct.']
            );
        }

        // Stored on the private disk, never in a public folder.
        $idPath = $request->file('id_photo')->store('verification');
        $selfiePath = $request->file('selfie')->store('verification');

        try {
            DB::transaction(function () use ($data, $idPath, $selfiePath) {
                $user = User::create([
                    'name' => $data['first_name'].' '.$data['last_name'],
                    'email' => $data['email'],
                    'password' => Hash::make($data['password']),
                ]);
                $user->assignRole('employee');

                Employee::create([
                    'user_id' => $user->id,
                    'employee_no' => $data['employee_no'],
                    'first_name' => $data['first_name'],
                    'last_name' => $data['last_name'],
                    'status' => 'pending',
                    'self_registered' => true,
                    'id_photo_path' => $idPath,
                    'selfie_path' => $selfiePath,
                ]);
            });
        } catch (\Throwable $e) {
            Storage::delete([$idPath, $selfiePath]);
            throw $e;
        }

        return response()->json(
            ['message' => 'Registration received. HR will review your account.'],
            201
        );
    }

    public function me(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'user' => $user->only(['id', 'name', 'email', 'must_change_password']),
            'roles' => $user->getRoleNames(),
            'employee' => $user->employee,
        ]);
    }

    public function changePassword(Request $request)
    {
        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'new_password' => [
                'required',
                'string',
                Password::min(10)->mixedCase()->numbers(),
                'confirmed',
            ],
        ]);

        $user = $request->user();
        if (! Hash::check($data['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => 'The current password is incorrect.',
            ]);
        }

        DB::transaction(function () use ($request, $user, $data) {
            $user->password = $data['new_password'];
            $user->must_change_password = false;
            $user->save();

            $currentToken = $user->currentAccessToken();
            if ($currentToken instanceof PersonalAccessToken) {
                $user->tokens()->where('id', '!=', $currentToken->getKey())->delete();
            }
            app(AuditLogger::class)->log($request, 'user.password_changed', $user);
        });

        return response()->json(['message' => 'Password changed successfully.']);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out']);
    }
}
