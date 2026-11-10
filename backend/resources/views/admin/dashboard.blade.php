@extends('layouts.admin')
@section('title', 'Dashboard')

@section('content')
    <h1 class="text-2xl font-semibold">League overview</h1>
    <p class="mt-1 text-sm text-slate-500">Everything happening across your teams.</p>

    <div class="mt-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        @foreach ([
            ['Teams', $stats['teams'], null],
            ['Players', $stats['players'], null],
            ['Coaches / Parents', $stats['coaches'].' / '.$stats['parents'], null],
            ['Events next 7 days', $stats['events_this_week'], null],
        ] as [$label, $value])
            <div class="rounded-xl border border-slate-200 bg-white p-5">
                <p class="text-sm text-slate-500">{{ $label }}</p>
                <p class="mt-2 text-2xl font-semibold">{{ $value }}</p>
            </div>
        @endforeach
    </div>

    <div class="mt-4 grid gap-4 sm:grid-cols-2">
        @foreach ([
            ['Broadcast read rate (30 days)', $stats['read_rate'], 'Share of parents who opened coach messages.'],
            ['Attendance rate', $stats['attendance_rate'], 'Players present at events where attendance was taken.'],
        ] as [$label, $value, $hint])
            <div class="rounded-xl border border-slate-200 bg-white p-5">
                <div class="flex items-baseline justify-between">
                    <p class="text-sm text-slate-500">{{ $label }}</p>
                    <p class="text-2xl font-semibold">{{ $value !== null ? $value.'%' : 'n/a' }}</p>
                </div>
                <div class="mt-3 h-2 rounded-full bg-slate-100">
                    <div class="h-2 rounded-full bg-teal-500" style="width: {{ $value ?? 0 }}%"></div>
                </div>
                <p class="mt-2 text-xs text-slate-500">{{ $hint }}</p>
            </div>
        @endforeach
    </div>

    <div class="mt-8 grid gap-6 lg:grid-cols-3">
        <section class="lg:col-span-2">
            <div class="flex items-center justify-between">
                <h2 class="font-semibold">Teams</h2>
                <a href="{{ route('admin.teams.create') }}" class="text-sm font-medium text-teal-700 hover:underline">+ New team</a>
            </div>
            <div class="mt-3 overflow-x-auto rounded-xl border border-slate-200 bg-white">
                <table class="w-full text-sm">
                    <thead class="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
                        <tr><th class="px-4 py-3">Team</th><th class="px-4 py-3">Players</th><th class="px-4 py-3">Coaches</th><th class="px-4 py-3">Last message</th></tr>
                    </thead>
                    <tbody class="divide-y divide-slate-100">
                        @foreach ($teams as $team)
                            <tr class="hover:bg-slate-50">
                                <td class="px-4 py-3">
                                    <a href="{{ route('admin.teams.show', $team) }}" class="flex items-center gap-2 font-medium">
                                        <span class="h-3 w-3 rounded-full" style="background: {{ $team->color }}"></span>{{ $team->name }}
                                    </a>
                                </td>
                                <td class="px-4 py-3">{{ $team->players_count }}</td>
                                <td class="px-4 py-3">
                                    @if ($team->coaches_count)
                                        {{ $team->coaches_count }}
                                    @else
                                        <span class="rounded bg-amber-100 px-2 py-0.5 text-xs text-amber-800">Needs coach</span>
                                    @endif
                                </td>
                                <td class="px-4 py-3 text-slate-500">
                                    {{ $team->broadcasts_max_created_at ? \Illuminate\Support\Carbon::parse($team->broadcasts_max_created_at)->diffForHumans() : 'Never' }}
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </section>

        <section>
            <h2 class="font-semibold">Coming up this week</h2>
            <ul class="mt-3 space-y-2">
                @forelse ($upcoming as $event)
                    <li class="rounded-xl border border-slate-200 bg-white p-4">
                        <div class="flex items-center justify-between">
                            <span class="text-xs font-medium uppercase {{ $event->type === 'game' ? 'text-amber-700' : 'text-teal-700' }}">{{ $event->type }}</span>
                            <span class="text-xs text-slate-500">{{ $event->team->name }}</span>
                        </div>
                        <p class="mt-1 font-medium">{{ $event->title }}</p>
                        <p class="text-sm text-slate-500">{{ $event->starts_at->copy()->setTimezone($event->team->timezone)->format('D M j, g:i A') }}</p>
                    </li>
                @empty
                    <li class="text-sm text-slate-500">Nothing scheduled.</li>
                @endforelse
            </ul>
        </section>
    </div>
@endsection
