<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\League;
use App\Models\Team;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class TeamController extends Controller
{
    public function index(Request $request)
    {
        $teams = Team::with('league')
            ->withCount(['players', 'parents', 'coaches'])
            ->when($request->query('league'), fn ($q, $id) => $q->where('league_id', $id))
            ->when($request->query('q'), fn ($q, $term) => $q->where('name', 'like', "%{$term}%"))
            ->orderBy('name')
            ->paginate(20)
            ->withQueryString();

        return view('admin.teams.index', ['teams' => $teams, 'leagues' => League::orderBy('name')->get()]);
    }

    public function create()
    {
        return view('admin.teams.form', ['team' => new Team, 'leagues' => League::orderBy('name')->get()]);
    }

    public function store(Request $request)
    {
        $team = Team::create($this->validated($request));

        return redirect()->route('admin.teams.show', $team)->with('status', 'Team created. Share the join code with parents.');
    }

    public function show(Team $team)
    {
        $team->load(['league', 'players.guardians', 'coaches', 'parents']);

        $attendance = $team->players()
            ->withCount(['eventRecords as attended' => fn ($q) => $q->where('present', true)])
            ->withCount(['eventRecords as marked' => fn ($q) => $q->whereNotNull('present')])
            ->get()
            ->keyBy('id');

        $upcoming = $team->events()->upcoming()->limit(5)->get();
        $broadcasts = $team->broadcasts()->withCount('reads')->latest()->limit(5)->get();

        return view('admin.teams.show', compact('team', 'attendance', 'upcoming', 'broadcasts'));
    }

    public function edit(Team $team)
    {
        return view('admin.teams.form', ['team' => $team, 'leagues' => League::orderBy('name')->get()]);
    }

    public function update(Request $request, Team $team)
    {
        $team->update($this->validated($request));

        return redirect()->route('admin.teams.show', $team)->with('status', 'Team updated.');
    }

    public function destroy(Team $team)
    {
        $team->delete();

        return redirect()->route('admin.teams.index')->with('status', "{$team->name} deleted.");
    }

    /** Used when a code has been shared too widely. Old code stops working. */
    public function regenerateCode(Team $team)
    {
        $team->update(['join_code' => Team::generateJoinCode()]);

        return back()->with('status', "New join code: {$team->join_code}");
    }

    /**
     * Adds a coach by email. If they don't have an account yet, one is created
     * with a temporary password that is shown once for the admin to pass on.
     */
    public function addCoach(Request $request, Team $team)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:255'],
        ]);

        $user = User::where('email', $data['email'])->first();
        $tempPassword = null;

        if (! $user) {
            $tempPassword = Str::password(10, symbols: false);
            $user = User::create([...$data, 'password' => $tempPassword]);
        }

        $team->members()->syncWithoutDetaching([$user->id => ['role' => Team::ROLE_COACH]]);
        // syncWithoutDetaching won't update an existing pivot row, so promote
        // a parent who is already on the team.
        $team->members()->updateExistingPivot($user->id, ['role' => Team::ROLE_COACH]);

        $message = "{$user->name} is now a coach of {$team->name}.";
        if ($tempPassword) {
            $message .= " Temporary password: {$tempPassword} (shown only once).";
        }

        return back()->with('status', $message);
    }

    public function removeMember(Team $team, User $user)
    {
        $team->members()->detach($user->id);

        return back()->with('status', "{$user->name} removed from {$team->name}.");
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'league_id' => ['required', 'exists:leagues,id'],
            'name' => ['required', 'string', 'max:100'],
            'age_group' => ['nullable', 'string', 'max:50'],
            'color' => ['required', 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'timezone' => ['required', Rule::in(timezone_identifiers_list())],
        ]);
    }
}
