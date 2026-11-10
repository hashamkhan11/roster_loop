<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Player;
use App\Models\Team;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class PlayerController extends Controller
{
    /**
     * Coaches add any player to the roster. A parent can add their own child,
     * who is then linked to them automatically.
     */
    public function store(Request $request, Team $team)
    {
        Gate::authorize('view-team', $team);

        $player = $team->players()->create($this->validated($request));

        if (! Gate::allows('manage-team', $team)) {
            $player->guardians()->attach($request->user()->id, ['relationship' => $request->input('relationship')]);
        }

        return response()->json(['player' => $player], 201);
    }

    public function update(Request $request, Player $player)
    {
        $this->authorizeEdit($request, $player);

        $player->update($this->validated($request, partial: true));

        return response()->json(['player' => $player]);
    }

    public function destroy(Player $player)
    {
        Gate::authorize('manage-team', $player->team);

        $player->delete();

        return response()->json(['message' => 'Player removed.']);
    }

    /** A parent links themselves to a child the coach already added. */
    public function claim(Request $request, Player $player)
    {
        Gate::authorize('view-team', $player->team);

        $player->guardians()->syncWithoutDetaching([
            $request->user()->id => ['relationship' => $request->input('relationship')],
        ]);

        return response()->json(['message' => 'Linked to '.$player->full_name.'.']);
    }

    private function authorizeEdit(Request $request, Player $player): void
    {
        $isGuardian = $player->guardians()->where('users.id', $request->user()->id)->exists();

        abort_unless($isGuardian || Gate::allows('manage-team', $player->team), 403);
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'first_name' => [$required, 'string', 'max:60'],
            'last_name' => [$required, 'string', 'max:60'],
            'jersey_number' => ['nullable', 'integer', 'between:0,999'],
            'position' => ['nullable', 'string', 'max:40'],
            'date_of_birth' => ['nullable', 'date', 'before:today'],
            'emergency_contact_name' => ['nullable', 'string', 'max:100'],
            'emergency_contact_phone' => ['nullable', 'string', 'max:30'],
            'medical_notes' => ['nullable', 'string', 'max:1000'],
        ]);
    }
}
