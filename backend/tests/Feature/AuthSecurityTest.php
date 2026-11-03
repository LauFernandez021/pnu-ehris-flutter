<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Tests\TestCase;

class AuthSecurityTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_registration_rejects_passwords_that_do_not_meet_policy(): void
    {
        foreach (['Aa1234567', 'password123', 'PASSWORD123', 'PasswordABC'] as $password) {
            $this->postJson('/api/register', [
                'password' => $password,
                'password_confirmation' => $password,
            ])->assertUnprocessable()
                ->assertJsonValidationErrors(['password']);
        }
    }

    public function test_login_attempts_are_limited_per_email_and_ip(): void
    {
        $user = User::factory()->create([
            'email' => 'employee@example.test',
            'password' => 'password',
        ]);

        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->postJson('/api/login', [
                'email' => $user->email,
                'password' => 'incorrect',
            ])->assertUnauthorized()
                ->assertExactJson(['message' => 'Invalid credentials']);
        }

        $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'incorrect',
        ])->assertStatus(429)
            ->assertJsonStructure(['message']);

        $this->postJson('/api/login', [
            'email' => 'another@example.test',
            'password' => 'incorrect',
        ])->assertUnauthorized();

        $this->travel(301)->seconds();

        $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'password',
        ])->assertOk()
            ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email'], 'roles']);
    }
}
