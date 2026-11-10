@extends('layouts.admin')
@section('title', 'Leagues')

@section('content')
    <h1 class="text-2xl font-semibold">Leagues</h1>

    <div class="mt-6 grid gap-6 lg:grid-cols-3">
        <div class="space-y-3 lg:col-span-2">
            @forelse ($leagues as $league)
                <details class="rounded-xl border border-slate-200 bg-white">
                    <summary class="flex cursor-pointer items-center justify-between p-5">
                        <span>
                            <span class="font-semibold">{{ $league->name }}</span>
                            <span class="ml-2 text-sm text-slate-500">{{ $league->sport }}{{ $league->season ? ' · '.$league->season : '' }}</span>
                        </span>
                        <a href="{{ route('admin.teams.index', ['league' => $league->id]) }}" class="text-sm text-teal-700 hover:underline">{{ $league->teams_count }} teams</a>
                    </summary>
                    <div class="border-t border-slate-100 p-5">
                        <form method="POST" action="{{ route('admin.leagues.update', $league) }}" class="grid gap-2 sm:grid-cols-4">
                            @csrf @method('PUT')
                            <input name="name" value="{{ $league->name }}" class="rounded-lg border border-slate-300 px-3 py-2 text-sm sm:col-span-2">
                            <input name="sport" value="{{ $league->sport }}" class="rounded-lg border border-slate-300 px-3 py-2 text-sm">
                            <input name="season" value="{{ $league->season }}" placeholder="Season" class="rounded-lg border border-slate-300 px-3 py-2 text-sm">
                            <button class="rounded-lg bg-slate-800 px-3 py-2 text-sm font-medium text-white sm:col-span-1">Save</button>
                        </form>
                        <form method="POST" action="{{ route('admin.leagues.destroy', $league) }}" class="mt-3" onsubmit="return confirm('Delete this league?')">
                            @csrf @method('DELETE')
                            <button class="text-sm text-red-600 hover:underline">Delete league</button>
                        </form>
                    </div>
                </details>
            @empty
                <p class="text-sm text-slate-500">No leagues yet. Create your first one.</p>
            @endforelse
        </div>

        <form method="POST" action="{{ route('admin.leagues.store') }}" class="h-fit space-y-3 rounded-xl border border-slate-200 bg-white p-5">
            @csrf
            <h2 class="font-semibold">New league</h2>
            <input name="name" placeholder="League name" required class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm">
            <input name="sport" placeholder="Sport (e.g. Soccer)" required class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm">
            <input name="season" placeholder="Season (e.g. Spring 2027)" class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm">
            <button class="w-full rounded-lg bg-teal-600 px-3 py-2 text-sm font-medium text-white hover:bg-teal-700">Create league</button>
        </form>
    </div>
@endsection
