<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsurePasswordChanged
{
    public function handle(Request $request, Closure $next): Response
    {
        $allowedRoutes = ['api.me', 'api.me.password', 'api.logout'];

        if (
            $request->user()?->must_change_password
            && ! $request->routeIs(...$allowedRoutes)
        ) {
            return response()->json([
                'message' => 'You must change your password before continuing.',
                'must_change_password' => true,
            ], 423);
        }

        return $next($request);
    }
}
