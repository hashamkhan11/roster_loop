@extends('layouts.admin')
@section('title', $team->name)

@section('content')
    <a href="{{ route('admin.teams.index') }}" class="text-sm text-slate-500 hover:text-slate-700">&larr; Teams</a>

    <div class="mt-2 flex flex-wrap items-start justify-between gap-4">
        <div class="flex items-center gap-3">
            <span class="h-10 w-10 rounded-lg" style="background: {{ $team->color }}"></span>
            <div>
                <h1 class="text-2xl font-semibold">{{ $team->name }}</h1>
                <p class="text-sm text-slate-500">{{ $team->league->name }} · {{ $team->age_group ?? 'All ages' }} · {{ $team->timezone }}</p>
            </div>
        </div>
        <a href="{{ route('admin.teams.edit', $team) }}" class="rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium hover:bg-slate-50">Edit team</a>
    </div>

    <div class="mt-6 grid gap-6 lg:grid-cols-3">
        <div class="space-y-6">
            {{-- Join code --}}
            <section class="rounded-xl border border-slate-200 bg-white p-5">
                <h2 class="text-sm font-medium text-slate-500">Parent join code</h2>
                <p class="mt-2 font-mono text-3xl font-bold tracking-[0.3em]">{{ $team->join_code }}</p>
                <p class="mt-2 text-xs text-slate-500">Parents enter this in the app to join the team.</p>
                <form method="POST" action="{{ route('admin.teams.regenerate-code', $team) }}" class="mt-3"
                      onsubmit="return confirm('The old code will stop working. Continue?')">
                    @csrf
                    <button class="text-sm font-medium text-teal-700 hover:underline">Generate new code</button>
                </form>
            </section>

            {{-- Coaches --}}
            <section class="rounded-xl border border-slate-200 bg-white p-5">
                <h2 class="font-semibold">Coaches</h2>
                <ul class="mt-3 space-y-2">
                    @forelse ($team->coaches as $coach)
                        <li class="flex items-center justify-between text-sm">
                            <span><span class="font-medium">{{ $coach->name }}</span><br><span class="text-slate-500">{{ $coach->email }}</span></span>
                            <form method="POST" action="{{ route('admin.teams.members.destroy', [$team, $coach]) }}" onsubmit="return confirm('Remove {{ $coach->name }} from this team?')">
                                @csrf @method('DELETE')
                                <button class="text-xs text-red-600 hover:underline">Remove</button>
                            </form>
                        </li>
                    @empty
                        <li class="text-sm text-amber-700">No coach yet. Add one below.</li>
                    @endforelse
                </ul>
                <form method="POST" action="{{ route('admin.teams.coaches.store', $team) }}" class="mt-4 space-y-2 border-t border-slate-100 pt-4">
                    @csrf
                    <input name="name" placeholder="Coach name" required class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm">
                    <input name="email" type="email" placeholder="coach@email.com" required class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm">
                    <button class="w-full rounded-lg bg-teal-600 px-3 py-2 text-sm font-medium text-white hover:bg-teal-700">Add coach</button>
                </form>
            </section>

            {{-- Upcoming --}}
            <section class="rounded-xl border border-slate-200 bg-white p-5">
                <h2 class="font-semibold">Upcoming</h2>
                <ul class="mt-3 space-y-3 text-sm">
                    @forelse ($upcoming as $event)
                        <li class="{{ $event->isCancelled() ? 'opacity-50 line-through' : '' }}">
                            <p class="font-medium">{{ $event->title }}</p>
                            <p class="text-slate-500">{{ $event->starts_at->copy()->setTimezone($team->timezone)->format('D M j, g:i A') }}</p>
                        </li>
                    @empty
                        <li class="text-slate-500">Nothing scheduled.</li>
                    @endforelse
                </ul>
            </section>
        </div>

        <div class="space-y-6 lg:col-span-2">
            {{-- Roster --}}
            <section class="overflow-hidden rounded-xl border border-slate-200 bg-white">
                <div class="flex items-center justify-between px-5 py-4">
                    <h2 class="font-semibold">Roster <span class="font-normal text-slate-500">({{ $team->players->count() }})</span></h2>
                    <span class="text-xs text-slate-500">{{ $team->parents->count() }} parents joined</span>
                </div>
                <div class="overflow-x-auto">
                    <table class="w-full text-sm">
                        <thead class="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
                            <tr><th class="px-5 py-2">#</th><th class="px-5 py-2">Player</th><th class="px-5 py-2">Parents</th><th class="px-5 py-2">Attendance</th></tr>
                        </thead>
                        <tbody class="divide-y divide-slate-100">
                            @foreach ($team->players->sortBy('jersey_number') as $player)
                                @php
                                    $stat = $attendance[$player->id];
                                    $rate = $stat->marked ? round($stat->attended / $stat->marked * 100) : null;
                                @endphp
                                <tr>
                                    <td class="px-5 py-3 font-mono text-slate-500">{{ $player->jersey_number ?? '–' }}</td>
                                    <td class="px-5 py-3">
                                        <p class="font-medium">{{ $player->full_name }}</p>
                                        <p class="text-xs text-slate-500">{{ $player->position }}</p>
                                    </td>
                                    <td class="px-5 py-3 text-slate-600">
                                        {{ $player->guardians->pluck('name')->join(', ') ?: '' }}
                                        @if ($player->guardians->isEmpty())<span class="text-xs text-amber-700">No parent linked</span>@endif
                                    </td>
                                    <td class="px-5 py-3">
                                        @if ($rate !== null)
                                            <span class="rounded-full px-2 py-0.5 text-xs font-medium {{ $rate >= 80 ? 'bg-teal-100 text-teal-800' : ($rate >= 60 ? 'bg-amber-100 text-amber-800' : 'bg-red-100 text-red-700') }}">{{ $rate }}%</span>
                                            <span class="text-xs text-slate-500">{{ $stat->attended }}/{{ $stat->marked }}</span>
                                        @else
                                            <span class="text-xs text-slate-400">n/a</span>
                                        @endif
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            </section>

            {{-- Broadcasts --}}
            <section class="rounded-xl border border-slate-200 bg-white p-5">
                <h2 class="font-semibold">Recent broadcasts</h2>
                @php $audience = max($team->coaches->count() + $team->parents->count() - 1, 1); @endphp
                <ul class="mt-3 divide-y divide-slate-100">
                    @forelse ($broadcasts as $b)
                        <li class="py-3">
                            <div class="flex items-center justify-between gap-4">
                                <p class="font-medium">
                                    @if ($b->is_urgent)<span class="mr-1 rounded bg-red-100 px-1.5 py-0.5 text-xs text-red-700">Urgent</span>@endif
                                    {{ $b->title }}
                                </p>
                                <span class="shrink-0 text-xs text-slate-500">{{ $b->created_at->diffForHumans() }}</span>
                            </div>
                            <p class="mt-1 line-clamp-2 text-sm text-slate-600">{{ $b->body }}</p>
                            <p class="mt-1 text-xs text-slate-500">Seen by {{ $b->reads_count }}/{{ $audience }}</p>
                        </li>
                    @empty
                        <li class="py-3 text-sm text-slate-500">No messages sent yet.</li>
                    @endforelse
                </ul>
            </section>
        </div>
    </div>
@endsection
