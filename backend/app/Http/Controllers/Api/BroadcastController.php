<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Broadcast;
use App\Models\BroadcastRead;
use App\Models\Team;
use App\Services\TeamNotifier;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class BroadcastController extends Controller
{
    public function __construct(private TeamNotifier $notifier) {}

    public function index(Request $request, Team $team)
    {
        Gate::authorize('view-team', $team);

        $userId = $request->user()->id;
        $audience = $team->members()->count();

        $broadcasts = $team->broadcasts()
            ->with('sender:id,name')
            ->withCount('reads')
            ->withExists(['reads as read_by_me' => fn ($q) => $q->where('user_id', $userId)])
            ->latest()
            ->paginate(20);

        // "Seen by 14/18": everyone on the team except the sender.
        $broadcasts->getCollection()->transform(fn (Broadcast $b) => [
            ...$b->toArray(),
            'audience_count' => max($audience - 1, 0),
        ]);

        return response()->json($broadcasts);
    }

    public function store(Request $request, Team $team)
    {
        Gate::authorize('manage-team', $team);

        $data = $request->validate([
            'title' => ['required', 'string', 'max:120'],
            'body' => ['required', 'string', 'max:5000'],
            'is_urgent' => ['boolean'],
        ]);

        $broadcast = $team->broadcasts()->create([...$data, 'user_id' => $request->user()->id]);

        $recipients = $team->members()->where('users.id', '!=', $request->user()->id)->get();
        $this->notifier->notify(
            $recipients,
            $team,
            'broadcast',
            ($broadcast->is_urgent ? 'URGENT: ' : '').$team->name.': '.$broadcast->title,
            str($broadcast->body)->limit(150)->toString(),
            ['broadcast_id' => $broadcast->id],
        );

        return response()->json(['broadcast' => $broadcast], 201);
    }

    /** Called when a parent opens the message. Safe to call twice. */
    public function markRead(Request $request, Broadcast $broadcast)
    {
        Gate::authorize('view-team', $broadcast->team);

        BroadcastRead::firstOrCreate(
            ['broadcast_id' => $broadcast->id, 'user_id' => $request->user()->id],
            ['read_at' => now()],
        );

        return response()->json(['message' => 'Marked as read.']);
    }

    /** For the coach: exactly who has and hasn't seen it, so they can follow up. */
    public function readers(Broadcast $broadcast)
    {
        Gate::authorize('manage-team', $broadcast->team);

        $reads = $broadcast->reads()->pluck('read_at', 'user_id');

        $members = $broadcast->team->members()
            ->where('users.id', '!=', $broadcast->user_id)
            ->orderBy('name')
            ->get(['users.id', 'users.name', 'users.phone']);

        return response()->json([
            'seen' => $members->filter(fn ($m) => $reads->has($m->id))->values()
                ->map(fn ($m) => ['id' => $m->id, 'name' => $m->name, 'read_at' => $reads[$m->id]]),
            'not_seen' => $members->reject(fn ($m) => $reads->has($m->id))->values()
                ->map(fn ($m) => ['id' => $m->id, 'name' => $m->name, 'phone' => $m->phone]),
        ]);
    }

    public function destroy(Broadcast $broadcast)
    {
        Gate::authorize('manage-team', $broadcast->team);

        $broadcast->delete();

        return response()->json(['message' => 'Broadcast deleted.']);
    }
}
