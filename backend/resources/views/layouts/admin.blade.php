<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Dashboard') · RosterLoop Admin</title>
    @vite(['resources/css/app.css'])
</head>
<body class="min-h-screen bg-slate-50 text-slate-800 antialiased">
@php
    $nav = [
        ['admin.dashboard', 'Dashboard', 'M3 12l9-9 9 9M5 10v10h14V10'],
        ['admin.teams.index', 'Teams', 'M17 20h5v-2a4 4 0 00-5-3.9M9 20H2v-2a4 4 0 015-3.9m5-2.1a4 4 0 100-8 4 4 0 000 8z'],
        ['admin.leagues.index', 'Leagues', 'M5 3h14v4a7 7 0 01-14 0V3zm7 11v4m-4 3h8'],
        ['admin.users.index', 'People', 'M16 7a4 4 0 11-8 0 4 4 0 018 0zM4 21v-1a6 6 0 0112 0v1'],
    ];
@endphp
<div class="flex min-h-screen">
    <aside class="hidden w-60 shrink-0 flex-col border-r border-slate-200 bg-white px-4 py-6 md:flex">
        <a href="{{ route('admin.dashboard') }}" class="px-2"><x-logo class="text-lg"/></a>
        <nav class="mt-8 space-y-1">
            @foreach ($nav as [$route, $label, $icon])
                @php $active = request()->routeIs(str_replace('.index', '.*', $route)); @endphp
                <a href="{{ route($route) }}"
                   class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium {{ $active ? 'bg-teal-50 text-teal-700' : 'text-slate-600 hover:bg-slate-100' }}">
                    <svg class="h-5 w-5" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="{{ $icon }}"/></svg>
                    {{ $label }}
                </a>
            @endforeach
        </nav>
        <div class="mt-auto border-t border-slate-200 pt-4 text-sm">
            <p class="px-2 font-medium">{{ auth()->user()->name }}</p>
            <p class="px-2 text-xs text-slate-500">{{ auth()->user()->email }}</p>
            <form method="POST" action="{{ route('admin.logout') }}" class="mt-3">
                @csrf
                <button class="w-full rounded-lg px-3 py-2 text-left text-slate-600 hover:bg-slate-100">Log out</button>
            </form>
        </div>
    </aside>

    <div class="flex-1">
        {{-- Small screens: top bar instead of sidebar --}}
        <header class="flex items-center justify-between border-b border-slate-200 bg-white px-4 py-3 md:hidden">
            <x-logo/>
            <form method="POST" action="{{ route('admin.logout') }}">@csrf<button class="text-sm text-slate-600">Log out</button></form>
        </header>
        <nav class="flex gap-1 overflow-x-auto border-b border-slate-200 bg-white px-2 md:hidden">
            @foreach ($nav as [$route, $label])
                <a href="{{ route($route) }}" class="whitespace-nowrap px-3 py-2 text-sm {{ request()->routeIs(str_replace('.index', '.*', $route)) ? 'border-b-2 border-teal-600 text-teal-700' : 'text-slate-600' }}">{{ $label }}</a>
            @endforeach
        </nav>

        <main class="mx-auto max-w-6xl px-4 py-8 sm:px-8">
            @if (session('status'))
                <div class="mb-6 rounded-lg border border-teal-200 bg-teal-50 px-4 py-3 text-sm text-teal-800">{{ session('status') }}</div>
            @endif
            @if ($errors->any())
                <div class="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                    @foreach ($errors->all() as $error)<p>{{ $error }}</p>@endforeach
                </div>
            @endif

            @yield('content')
        </main>
    </div>
</div>
</body>
</html>
