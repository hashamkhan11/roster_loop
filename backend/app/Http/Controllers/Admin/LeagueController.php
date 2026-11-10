<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\League;
use Illuminate\Http\Request;

class LeagueController extends Controller
{
    public function index()
    {
        $leagues = League::withCount('teams')->orderBy('name')->get();

        return view('admin.leagues.index', compact('leagues'));
    }

    public function store(Request $request)
    {
        League::create($this->validated($request));

        return back()->with('status', 'League created.');
    }

    public function update(Request $request, League $league)
    {
        $league->update($this->validated($request));

        return back()->with('status', 'League updated.');
    }

    public function destroy(League $league)
    {
        if ($league->teams()->exists()) {
            return back()->withErrors(['league' => 'Move or delete this league\'s teams first.']);
        }

        $league->delete();

        return back()->with('status', 'League deleted.');
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'sport' => ['required', 'string', 'max:50'],
            'season' => ['nullable', 'string', 'max:50'],
        ]);
    }
}
