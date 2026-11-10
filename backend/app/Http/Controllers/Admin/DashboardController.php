<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Broadcast;
use App\Models\Event;
use App\Models\EventPlayer;
use App\Models\Player;
use App\Models\Team;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function __invoke()
    {
        $stats = [
            'teams' => Team::count(),
            'players' => Player::count(),
            'coaches' => DB::table('team_user')->where('role', Team::ROLE_COACH)->distinct()->count('user_id'),
            'parents' => DB::table('team_user')->where('role', Team::ROLE_PARENT)->distinct()->count('user_id'),
            'events_this_week' => Event::scheduled()->whereBetween('starts_at', [now(), now()->addWeek()])->count(),
        ];

        // How well messages land: reads / (broadcasts x people who could read them).
        $memberCounts = DB::table('team_user')->selectRaw('team_id, COUNT(*) as total')->groupBy('team_id')->pluck('total', 'team_id');
        $recent = Broadcast::withCount('reads')->where('created_at', '>=', now()->subDays(30))->get();
        $possible = $recent->sum(fn ($b) => max(($memberCounts[$b->team_id] ?? 0) - 1, 0));
        $stats['read_rate'] = $possible ? round($recent->sum('reads_count') / $possible * 100) : null;

        $marked = EventPlayer::whereNotNull('present');
        $stats['attendance_rate'] = ($total = (clone $marked)->count())
            ? round((clone $marked)->where('present', true)->count() / $total * 100)
            : null;

        $teams = Team::with('league')
            ->withCount(['players', 'parents', 'coaches'])
            ->withMax('broadcasts', 'created_at')
            ->orderBy('name')
            ->get();

        $upcoming = Event::scheduled()->with('team')
            ->whereBetween('starts_at', [now(), now()->addWeek()])
            ->orderBy('starts_at')
            ->limit(8)
            ->get();

        return view('admin.dashboard', compact('stats', 'teams', 'upcoming'));
    }
}
