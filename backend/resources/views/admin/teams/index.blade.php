@extends('layouts.admin')
@section('title', 'Teams')

@section('content')
    <div class="flex flex-wrap items-center justify-between gap-4">
        <h1 class="text-2xl font-semibold">Teams</h1>
        <a href="{{ route('admin.teams.create') }}" class="rounded-lg bg-teal-600 px-4 py-2 text-sm font-medium text-white hover:bg-teal-700">+ New team</a>
    </div>

    <form class="mt-6 flex flex-wrap gap-2">
        <input name="q" value="{{ request('q') }}" placeholder="Search teams..." class="w-full max-w-xs rounded-lg border border-slate-300 px-3 py-2 text-sm">
        <select name="league" class="rounded-lg border border-slate-300 px-3 py-2 text-sm" onchange="this.form.submit()">
            <option value="">All leagues</option>
            @foreach ($leagues as $league)
                <option value="{{ $league->id }}" @selected(request('league') == $league->id)>{{ $league->name }}</option>
            @endforeach
        </select>
    </form>

    <div class="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        @forelse ($teams as $team)
            <a href="{{ route('admin.teams.show', $team) }}" class="group rounded-xl border border-slate-200 bg-white p-5 transition hover:border-teal-300 hover:shadow-sm">
                <div class="flex items-center gap-3">
                    <span class="flex h-10 w-10 items-center justify-center rounded-lg text-sm font-bold text-white" style="background: {{ $team->color }}">
                        {{ str($team->name)->explode(' ')->map(fn ($w) => $w[0])->take(2)->implode('') }}
                    </span>
                    <div>
                        <p class="font-semibold group-hover:text-teal-700">{{ $team->name }}</p>
                        <p class="text-xs text-slate-500">{{ $team->league->name }}</p>
                    </div>
                </div>
                <dl class="mt-4 grid grid-cols-3 text-center text-sm">
                    <div><dt class="text-xs text-slate-500">Players</dt><dd class="font-semibold">{{ $team->players_count }}</dd></div>
                    <div><dt class="text-xs text-slate-500">Parents</dt><dd class="font-semibold">{{ $team->parents_count }}</dd></div>
                    <div><dt class="text-xs text-slate-500">Coaches</dt><dd class="font-semibold {{ $team->coaches_count ? '' : 'text-amber-600' }}">{{ $team->coaches_count }}</dd></div>
                </dl>
            </a>
        @empty
            <p class="text-sm text-slate-500">No teams yet.</p>
        @endforelse
    </div>

    <div class="mt-6">{{ $teams->links() }}</div>
@endsection
