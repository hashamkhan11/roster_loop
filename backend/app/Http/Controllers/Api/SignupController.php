<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Signup;
use App\Models\SignupSlot;
use App\Models\SlotClaim;
use App\Models\Team;
use App\Services\TeamNotifier;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SignupController extends Controller
{
    public function __construct(private TeamNotifier $notifier) {}

    public function index(Team $team)
    {
        Gate::authorize('view-team', $team);

        $signups = $team->signups()
            ->with([
                'event:id,title,starts_at,status',
                'slots.owner:id,name,phone',
                'slots.claims.user:id,name',
                'slots.claims.player:id,first_name,last_name',
            ])
            ->latest()
            ->get();

        return response()->json(['signups' => $signups]);
    }

    /**
     * Volunteer sheets are created by coaches with their slots. Carpool sheets
     * can be started by anyone; drivers then add their own car as a slot.
     */
    public function store(Request $request, Team $team)
    {
        $data = $request->validate([
            'type' => ['required', Rule::in(Signup::TYPES)],
            'title' => ['required', 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:1000'],
            'event_id' => ['nullable', Rule::exists('events', 'id')->where('team_id', $team->id)],
            'slots' => ['array', 'max:30'],
            'slots.*.label' => ['required', 'string', 'max:80'],
            'slots.*.capacity' => ['integer', 'between:1,50'],
        ]);

        Gate::authorize($data['type'] === 'volunteer' ? 'manage-team' : 'view-team', $team);

        $signup = DB::transaction(function () use ($team, $data, $request) {
            $signup = $team->signups()->create([
                ...collect($data)->except('slots')->all(),
                'created_by' => $request->user()->id,
            ]);

            foreach ($data['slots'] ?? [] as $slot) {
                $signup->slots()->create(['label' => $slot['label'], 'capacity' => $slot['capacity'] ?? 1]);
            }

            return $signup;
        });

        $this->notifier->notify(
            $team->members()->where('users.id', '!=', $request->user()->id)->get(),
            $team,
            'signup',
            ($signup->type === 'carpool' ? 'Carpool: ' : 'Volunteers needed: ').$signup->title,
            $signup->description ?: 'Tap to sign up.',
            ['signup_id' => $signup->id],
        );

        return response()->json(['signup' => $signup->load('slots')], 201);
    }

    /** Coach adds a volunteer slot, or a parent offers their car for a carpool. */
    public function addSlot(Request $request, Signup $signup)
    {
        Gate::authorize($signup->type === 'volunteer' ? 'manage-team' : 'view-team', $signup->team);

        $data = $request->validate([
            'label' => ['required', 'string', 'max:80'],
            'capacity' => ['required', 'integer', 'between:1,50'],
            'note' => ['nullable', 'string', 'max:200'],
        ]);

        $slot = $signup->slots()->create([
            ...$data,
            'owner_id' => $signup->type === 'carpool' ? $request->user()->id : null,
        ]);

        return response()->json(['slot' => $slot], 201);
    }

    public function removeSlot(Request $request, SignupSlot $slot)
    {
        $isOwner = $slot->owner_id === $request->user()->id;
        abort_unless($isOwner || Gate::allows('manage-team', $slot->signup->team), 403);

        $slot->delete();

        return response()->json(['message' => 'Slot removed.']);
    }

    /** Take a spot. For carpools, player_id says which child is riding. */
    public function claim(Request $request, SignupSlot $slot)
    {
        $team = $slot->signup->team;
        Gate::authorize('view-team', $team);

        $data = $request->validate([
            'player_id' => ['nullable', Rule::exists('players', 'id')->where('team_id', $team->id)],
        ]);

        $claim = DB::transaction(function () use ($slot, $data, $request) {
            // Lock the slot row: a second request for the same slot waits here
            // until this one commits, so it sees the updated count.
            $slot = SignupSlot::whereKey($slot->id)->lockForUpdate()->first();

            $alreadyClaimed = $slot->claims()
                ->where('user_id', $request->user()->id)
                ->where('player_id', $data['player_id'] ?? null)
                ->exists();
            if ($alreadyClaimed) {
                throw ValidationException::withMessages(['slot' => ['You already signed up for this spot.']]);
            }

            if ($slot->claims()->count() >= $slot->capacity) {
                throw ValidationException::withMessages(['slot' => ['Sorry, this spot is already full.']]);
            }

            return $slot->claims()->create([
                'user_id' => $request->user()->id,
                'player_id' => $data['player_id'] ?? null,
            ]);
        });

        return response()->json(['claim' => $claim], 201);
    }

    public function unclaim(Request $request, SlotClaim $claim)
    {
        $team = $claim->slot->signup->team;
        abort_unless($claim->user_id === $request->user()->id || Gate::allows('manage-team', $team), 403);

        $claim->delete();

        return response()->json(['message' => 'Removed.']);
    }

    public function destroy(Request $request, Signup $signup)
    {
        abort_unless($signup->created_by === $request->user()->id || Gate::allows('manage-team', $signup->team), 403);

        $signup->delete();

        return response()->json(['message' => 'Sign-up deleted.']);
    }
}
