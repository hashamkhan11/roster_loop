<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Models\EventPlayer;
use App\Models\Team;
use App\Models\User;
use App\Services\TeamNotifier;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class EventController extends Controller
{
    public function __construct(private TeamNotifier $notifier) {}

    public function index(Request $request, Team $team)
    {
        Gate::authorize('view-team', $team);

        $past = $request->query('when') === 'past';

        $events = $team->events()
            ->when($past,
                fn ($q) => $q->where('starts_at', '<', now())->orderByDesc('starts_at'),
                fn ($q) => $q->upcoming())
            ->limit(100)
            ->get();

        return response()->json(['events' => $this->withRsvpInfo($events, $request->user())]);
    }

    /** Upcoming events across all of the user's teams, for the home screen. */
    public function upcoming(Request $request)
    {
        $teamIds = $request->user()->teams()->pluck('teams.id');

        $events = Event::whereIn('team_id', $teamIds)->upcoming()
            ->with('team:id,name,color')
            ->limit(20)
            ->get();

        return response()->json(['events' => $this->withRsvpInfo($events, $request->user())]);
    }

    public function show(Request $request, Event $event)
    {
        Gate::authorize('view-team', $event->team);

        $records = $event->playerRecords()->get()->keyBy('player_id');

        $players = $event->team->players()->orderBy('first_name')->get()->map(fn ($p) => [
            'id' => $p->id,
            'full_name' => $p->full_name,
            'jersey_number' => $p->jersey_number,
            'rsvp' => $records[$p->id]->rsvp ?? null,
            'present' => $records[$p->id]->present ?? null,
        ]);

        return response()->json([
            'event' => $this->withRsvpInfo(collect([$event->load('team:id,name,color')]), $request->user())->first(),
            'players' => $players,
        ]);
    }

    /**
     * Creates one event, or a weekly series when repeat_until is given
     * (e.g. "Practice every Tuesday until March 1st").
     */
    public function store(Request $request, Team $team)
    {
        Gate::authorize('manage-team', $team);

        $data = $this->validated($request);
        $data['repeat_until'] = $request->validate([
            'repeat_until' => ['nullable', 'date', 'after:starts_at', 'before:'.now()->addYear()->toDateString()],
        ])['repeat_until'] ?? null;

        $events = DB::transaction(function () use ($team, $data, $request) {
            $start = Carbon::parse($data['starts_at']);
            $duration = isset($data['ends_at']) ? $start->diffInMinutes(Carbon::parse($data['ends_at'])) : null;
            $until = $data['repeat_until'] ? Carbon::parse($data['repeat_until'])->endOfDay() : $start;
            $seriesId = $data['repeat_until'] ? (string) Str::uuid() : null;

            $created = collect();
            for ($at = $start->copy(); $at->lte($until); $at->addWeek()) {
                $created->push($team->events()->create([
                    ...collect($data)->except('repeat_until')->all(),
                    'starts_at' => $at->copy(),
                    'ends_at' => $duration !== null ? $at->copy()->addMinutes($duration) : null,
                    'series_id' => $seriesId,
                    'created_by' => $request->user()->id,
                ]));
            }

            return $created;
        });

        $first = $events->first();
        $body = $events->count() > 1
            ? "{$events->count()} weekly events added, starting {$this->when($first)}."
            : "{$this->when($first)}".($first->location ? " at {$first->location}" : '');

        $this->notifyTeam($team, $request->user(), 'event_created', 'New '.$first->type.': '.$first->title, $body, $first);

        return response()->json(['events' => $events], 201);
    }

    public function update(Request $request, Event $event)
    {
        Gate::authorize('manage-team', $event->team);

        $event->fill($this->validated($request, partial: true));

        // Only bother parents when something they act on changed.
        $important = $event->isDirty(['starts_at', 'ends_at', 'location']);
        $event->save();

        if ($important) {
            $this->notifyTeam($event->team, $request->user(), 'event_updated', 'Schedule change: '.$event->title,
                'Now '.$this->when($event).($event->location ? " at {$event->location}" : '').'.', $event);
        }

        return response()->json(['event' => $event]);
    }

    /** Cancels one event, or every future event in its series with ?series=1. */
    public function cancel(Request $request, Event $event)
    {
        Gate::authorize('manage-team', $event->team);

        $query = $request->boolean('series') && $event->series_id
            ? Event::where('series_id', $event->series_id)->where('starts_at', '>=', $event->starts_at)
            : Event::whereKey($event->id);

        $count = $query->update(['status' => 'cancelled']);

        $title = 'Cancelled: '.$event->title;
        $body = $count > 1
            ? "{$count} events from {$this->when($event)} onward are cancelled."
            : "{$this->when($event)} is cancelled.".($request->filled('reason') ? ' '.$request->input('reason') : '');

        $this->notifyTeam($event->team, $request->user(), 'event_cancelled', $title, $body, $event);

        return response()->json(['message' => $title, 'cancelled' => $count]);
    }

    public function destroy(Event $event)
    {
        Gate::authorize('manage-team', $event->team);

        $event->delete();

        return response()->json(['message' => 'Event deleted.']);
    }

    /** A parent answers "Is my child coming?" (coaches can answer for anyone). */
    public function rsvp(Request $request, Event $event)
    {
        Gate::authorize('view-team', $event->team);

        $data = $request->validate([
            'player_id' => ['required', 'integer'],
            'rsvp' => ['required', Rule::in(EventPlayer::RSVPS)],
        ]);

        $player = $event->team->players()->findOrFail($data['player_id']);
        $isGuardian = $player->guardians()->where('users.id', $request->user()->id)->exists();
        abort_unless($isGuardian || Gate::allows('manage-team', $event->team), 403, 'You can only RSVP for your own child.');

        EventPlayer::updateOrCreate(
            ['event_id' => $event->id, 'player_id' => $player->id],
            ['rsvp' => $data['rsvp'], 'rsvp_by' => $request->user()->id],
        );

        return response()->json(['message' => 'RSVP saved.']);
    }

    /** Coach marks who actually showed up. Body: {"attendance": {"12": true, "13": false}} */
    public function attendance(Request $request, Event $event)
    {
        Gate::authorize('manage-team', $event->team);

        $data = $request->validate([
            'attendance' => ['required', 'array'],
            'attendance.*' => ['boolean'],
        ]);

        $validIds = $event->team->players()->pluck('id')->all();

        foreach ($data['attendance'] as $playerId => $present) {
            if (in_array((int) $playerId, $validIds, true)) {
                EventPlayer::updateOrCreate(
                    ['event_id' => $event->id, 'player_id' => (int) $playerId],
                    ['present' => $present],
                );
            }
        }

        return response()->json(['message' => 'Attendance saved.']);
    }

    /** Attendance % per player over all past events where attendance was taken. */
    public function attendanceReport(Team $team)
    {
        Gate::authorize('manage-team', $team);

        $stats = EventPlayer::query()
            ->join('events', 'events.id', '=', 'event_player.event_id')
            ->where('events.team_id', $team->id)
            ->whereNotNull('event_player.present')
            ->groupBy('event_player.player_id')
            ->selectRaw('event_player.player_id, COUNT(*) as total, SUM(CASE WHEN event_player.present THEN 1 ELSE 0 END) as attended')
            ->get()
            ->keyBy('player_id');

        $report = $team->players()->orderBy('first_name')->get()->map(function ($p) use ($stats) {
            $total = (int) ($stats[$p->id]->total ?? 0);
            $attended = (int) ($stats[$p->id]->attended ?? 0);

            return [
                'player_id' => $p->id,
                'full_name' => $p->full_name,
                'jersey_number' => $p->jersey_number,
                'attended' => $attended,
                'total' => $total,
                'rate' => $total ? round($attended / $total * 100) : null,
            ];
        });

        return response()->json(['report' => $report]);
    }

    /**
     * Adds RSVP counts to each event, plus the current user's children's
     * answers, using 2 queries total instead of 2 per event.
     */
    private function withRsvpInfo($events, User $user)
    {
        $eventIds = $events->pluck('id');
        $records = EventPlayer::whereIn('event_id', $eventIds)->get()->groupBy('event_id');
        $children = $user->children()->get(['players.id', 'players.first_name', 'players.team_id']);

        return $events->map(function (Event $event) use ($records, $children) {
            $rows = $records[$event->id] ?? collect();

            return [
                ...$event->toArray(),
                'rsvp_counts' => [
                    'going' => $rows->where('rsvp', 'going')->count(),
                    'maybe' => $rows->where('rsvp', 'maybe')->count(),
                    'not_going' => $rows->where('rsvp', 'not_going')->count(),
                ],
                'my_children' => $children->where('team_id', $event->team_id)->values()->map(fn ($c) => [
                    'player_id' => $c->id,
                    'first_name' => $c->first_name,
                    'rsvp' => $rows->firstWhere('player_id', $c->id)?->rsvp,
                ]),
            ];
        });
    }

    private function notifyTeam(Team $team, User $actor, string $type, string $title, string $body, Event $event): void
    {
        $recipients = $team->members()->where('users.id', '!=', $actor->id)->get();

        $this->notifier->notify($recipients, $team, $type, $title, $body, ['event_id' => $event->id]);
    }

    private function when(Event $event): string
    {
        return $event->starts_at->copy()->setTimezone($event->team->timezone)->format('D, M j \a\t g:i A');
    }

    private function validated(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'type' => [$required, Rule::in(Event::TYPES)],
            'title' => [$required, 'string', 'max:120'],
            'starts_at' => [$required, 'date'],
            'ends_at' => ['nullable', 'date', ...($request->has('starts_at') ? ['after:starts_at'] : [])],
            'location' => ['nullable', 'string', 'max:200'],
            'opponent' => ['nullable', 'string', 'max:100'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);
    }
}
