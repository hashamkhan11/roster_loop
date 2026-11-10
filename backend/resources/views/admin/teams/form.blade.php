@extends('layouts.admin')
@section('title', $team->exists ? 'Edit team' : 'New team')

@section('content')
    <a href="{{ $team->exists ? route('admin.teams.show', $team) : route('admin.teams.index') }}" class="text-sm text-slate-500 hover:text-slate-700">&larr; Back</a>
    <h1 class="mt-2 text-2xl font-semibold">{{ $team->exists ? 'Edit '.$team->name : 'New team' }}</h1>

    @if ($leagues->isEmpty())
        <p class="mt-6 rounded-lg bg-amber-50 p-4 text-sm text-amber-800">Create a <a href="{{ route('admin.leagues.index') }}" class="underline">league</a> first.</p>
    @else
        <form method="POST" action="{{ $team->exists ? route('admin.teams.update', $team) : route('admin.teams.store') }}"
              class="mt-6 max-w-xl space-y-5 rounded-xl border border-slate-200 bg-white p-6">
            @csrf
            @if ($team->exists) @method('PUT') @endif

            <div>
                <label class="text-sm font-medium" for="league_id">League</label>
                <select id="league_id" name="league_id" class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2">
                    @foreach ($leagues as $league)
                        <option value="{{ $league->id }}" @selected(old('league_id', $team->league_id) == $league->id)>{{ $league->name }} ({{ $league->sport }})</option>
                    @endforeach
                </select>
            </div>
            <div>
                <label class="text-sm font-medium" for="name">Team name</label>
                <input id="name" name="name" value="{{ old('name', $team->name) }}" required placeholder="U10 Lions" class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2">
            </div>
            <div class="grid gap-4 sm:grid-cols-2">
                <div>
                    <label class="text-sm font-medium" for="age_group">Age group</label>
                    <input id="age_group" name="age_group" value="{{ old('age_group', $team->age_group) }}" placeholder="Under 10" class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2">
                </div>
                <div>
                    <label class="text-sm font-medium" for="color">Team colour</label>
                    <input id="color" name="color" type="color" value="{{ old('color', $team->color) }}" class="mt-1 h-10 w-full rounded-lg border border-slate-300 px-1">
                </div>
            </div>
            <div>
                <label class="text-sm font-medium" for="timezone">Timezone</label>
                <select id="timezone" name="timezone" class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2">
                    @foreach (timezone_identifiers_list() as $tz)
                        <option @selected(old('timezone', $team->timezone) === $tz)>{{ $tz }}</option>
                    @endforeach
                </select>
                <p class="mt-1 text-xs text-slate-500">Used for times in reminders and notifications.</p>
            </div>

            <button class="rounded-lg bg-teal-600 px-4 py-2 font-medium text-white hover:bg-teal-700">{{ $team->exists ? 'Save changes' : 'Create team' }}</button>
        </form>

        @if ($team->exists)
            <form method="POST" action="{{ route('admin.teams.destroy', $team) }}" class="mt-6 max-w-xl"
                  onsubmit="return confirm('Delete {{ $team->name }}? Its roster, schedule and messages will be removed.')">
                @csrf @method('DELETE')
                <button class="text-sm font-medium text-red-600 hover:underline">Delete this team</button>
            </form>
        @endif
    @endif
@endsection
