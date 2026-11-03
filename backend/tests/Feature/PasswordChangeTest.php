<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class PasswordChangeTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_user_can_change_password_and_keep_current_token(): void
    {
        $user = User::factory()->create([
            'password' => 'StartingPassword1',
            'must_change_password' => true,
        ]);
        $currentToken = $user->createToken('current-session')->plainTextToken;
        $user->createToken('other-session');

        $this->withToken($currentToken)
            ->postJson('/api/me/password', [
                'current_password' => 'StartingPassword1',
                'new_password' => 'NewPassword123',
                'new_password_confirmation' => 'NewPassword123',
            ])
            ->assertOk()
            ->assertExactJson(['message' => 'Password changed successfully.']);

        $this->assertTrue(Hash::check('NewPassword123', $user->fresh()->password));
        $this->assertFalse($user->fresh()->must_change_password);
        $this->assertDatabaseCount('personal_access_tokens', 1);
        $this->withToken($currentToken)->getJson('/api/me')->assertOk();

        $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'StartingPassword1',
        ])->assertUnauthorized();

        $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'NewPassword123',
        ])->assertOk();
    }

    public function test_password_change_rejects_wrong_current_password_and_weak_new_password(): void
    {
        $user = User::factory()->create([
            'password' => 'StartingPassword1',
        ]);
        $token = $user->createToken('current-session')->plainTextToken;

        $this->withToken($token)
            ->postJson('/api/me/password', [
                'current_password' => 'incorrect',
                'new_password' => 'NewPassword123',
                'new_password_confirmation' => 'NewPassword123',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['current_password']);

        foreach (['shortA1', 'password1234', 'PASSWORD1234', 'PasswordABC'] as $password) {
            $this->postJson('/api/me/password', [
                'current_password' => 'StartingPassword1',
                'new_password' => $password,
                'new_password_confirmation' => $password,
            ])->assertUnprocessable()
                ->assertJsonValidationErrors(['new_password']);
        }

        $this->assertTrue(Hash::check('StartingPassword1', $user->fresh()->password));
        $this->assertDatabaseCount('personal_access_tokens', 1);
    }
}
