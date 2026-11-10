<?php

namespace App\Providers;

use App\Models\Team;
use App\Models\User;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        // League admins can do everything a coach can.
        Gate::before(fn (User $user) => $user->is_admin ? true : null);

        // Anyone on the team (coach or parent) can see its schedule, roster, etc.
        Gate::define('view-team', fn (User $user, Team $team) => $user->isMemberOf($team));

        // Only coaches can change the team: schedule, roster, broadcasts.
        Gate::define('manage-team', fn (User $user, Team $team) => $user->isCoachOf($team));

        Gate::define('access-admin', fn (User $user) => $user->is_admin);
    }
}
