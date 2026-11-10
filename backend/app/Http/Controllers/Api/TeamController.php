<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Player;
use App\Models\Team;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class TeamController extends Controller
{
    /** Every team the user belongs to, with their role on it. */
    public function index(Request $request)
    {
        $teams = $request->user()->teams()
            ->with('league:id,name,sport')
            ->withCount('players')
            ->orderBy('name')
            ->get()
            ->map(fn (Team $team) => $this->summary($team, $team->pivot->role));

        return response()->json(['teams' => $teams]);
    }

    public function join(Request $request)
    {
        $data = $request->validate(['join_code' => ['required', 'string', 'size:6']]);

        $team = Team::where('join_code', strtoupper($data['join_code']))->first();
        if (! $team) {
            throw ValidationException::withMessages(['join_code' => ['No team found with that code.']]);
        }

        // Skip if already a member, so a coach who types their own team's
        // code is not turned into a parent.
        if (! $request->user()->isMemberOf($team)) {
            $team->members()->attach($request->user()->id, ['role' => Team::ROLE_PARENT]);
        }

        $team->load('league:id,name,sport')->loadCount('players');

        return response()->json(['team' => $this->summary($team, $request->user()->roleOn($team))]);
    }

    public function leave(Request $request, Team $team)
    {
        Gate::authorize('view-team', $team);

        $team->members()->detach($request->user()->id);

        return response()->json(['message' => 'You left the team.']);
    }

    /**
     * Team details and roster. Coaches see everything; parents see names and
     * numbers for everyone but private details only for their own children.
     */
    public function show(Request $request, Team $team)
    {
        Gate::authorize('view-team', $team);

        $user = $request->user();
        $isCoach = Gate::allows('manage-team', $team);
        $myChildIds = $user->children()->where('team_id', $team->id)->pluck('players.id');

        $players = $team->players()->with('guardians:id,name,phone')
            ->orderBy('jersey_number')->orderBy('first_name')->get()
            ->map(function (Player $player) use ($isCoach, $myChildIds) {
                $canSeePrivate = $isCoach || $myChildIds->contains($player->id);

                return [
                    'id' => $player->id,
                    'first_name' => $player->first_name,
                    'last_name' => $player->last_name,
                    'full_name' => $player->full_name,
                    'jersey_number' => $player->jersey_number,
                    'position' => $player->position,
                    'is_my_child' => $myChildIds->contains($player->id),
                    'guardians' => $player->guardians->map(fn ($g) => [
                        'id' => $g->id,
                        'name' => $g->name,
                        'phone' => $g->phone,
                    ]),
                    'date_of_birth' => $canSeePrivate ? $player->date_of_birth?->format('Y-m-d') : null,
                    'emergency_contact_name' => $canSeePrivate ? $player->emergency_contact_name : null,
                    'emergency_contact_phone' => $canSeePrivate ? $player->emergency_contact_phone : null,
                    'medical_notes' => $canSeePrivate ? $player->medical_notes : null,
                ];
            });

        $team->load('league:id,name,sport')->loadCount('players');

        return response()->json([
            'team' => $this->summary($team, $user->roleOn($team) ?? ($user->is_admin ? Team::ROLE_COACH : null)),
            'players' => $players,
            'coaches' => $team->coaches()->get(['users.id', 'users.name', 'users.email', 'users.phone']),
            'parent_count' => $team->parents()->count(),
        ]);
    }

    private function summary(Team $team, ?string $role): array
    {
        return [
            'id' => $team->id,
            'name' => $team->name,
            'age_group' => $team->age_group,
            'color' => $team->color,
            'league' => $team->league,
            'players_count' => $team->players_count,
            'role' => $role,
            // Only coaches hand out the join code.
            'join_code' => $role === Team::ROLE_COACH ? $team->join_code : null,
        ];
    }
}
