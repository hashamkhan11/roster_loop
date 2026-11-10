@extends('layouts.admin')
@section('title', 'People')

@section('content')
    <h1 class="text-2xl font-semibold">People</h1>

    <form class="mt-6">
        <input name="q" value="{{ request('q') }}" placeholder="Search by name or email..." class="w-full max-w-sm rounded-lg border border-slate-300 px-3 py-2 text-sm">
    </form>

    <div class="mt-4 overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table class="w-full text-sm">
            <thead class="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
                <tr><th class="px-4 py-3">Name</th><th class="px-4 py-3">Email</th><th class="px-4 py-3">Phone</th><th class="px-4 py-3">Teams</th></tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
                @foreach ($users as $user)
                    <tr>
                        <td class="px-4 py-3 font-medium">
                            {{ $user->name }}
                            @if ($user->is_admin)<span class="ml-1 rounded bg-slate-800 px-1.5 py-0.5 text-xs text-white">Admin</span>@endif
                        </td>
                        <td class="px-4 py-3 text-slate-600">{{ $user->email }}</td>
                        <td class="px-4 py-3 text-slate-600">{{ $user->phone ?? '–' }}</td>
                        <td class="px-4 py-3">
                            @foreach ($user->teams as $team)
                                <a href="{{ route('admin.teams.show', $team) }}"
                                   class="mr-1 inline-block rounded-full px-2 py-0.5 text-xs {{ $team->pivot->role === 'coach' ? 'bg-teal-100 text-teal-800' : 'bg-slate-100 text-slate-700' }}">
                                    {{ $team->name }} · {{ $team->pivot->role }}
                                </a>
                            @endforeach
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>

    <div class="mt-6">{{ $users->links() }}</div>
@endsection
