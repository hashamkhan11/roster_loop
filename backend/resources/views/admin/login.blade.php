<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin login · RosterLoop</title>
    @vite(['resources/css/app.css'])
</head>
<body class="flex min-h-screen items-center justify-center bg-slate-50 px-4 text-slate-800 antialiased">
<div class="w-full max-w-sm">
    <a href="{{ route('home') }}" class="flex justify-center"><x-logo class="text-2xl"/></a>
    <div class="mt-8 rounded-2xl border border-slate-200 bg-white p-8 shadow-sm">
        <h1 class="text-lg font-semibold">League admin login</h1>
        <p class="mt-1 text-sm text-slate-500">Coaches and parents use the mobile app.</p>

        <form method="POST" action="{{ url('/admin/login') }}" class="mt-6 space-y-4">
            @csrf
            <div>
                <label for="email" class="text-sm font-medium">Email</label>
                <input id="email" name="email" type="email" value="{{ old('email') }}" required autofocus
                       class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 focus:border-teal-500 focus:outline-none focus:ring-2 focus:ring-teal-500/20">
            </div>
            <div>
                <label for="password" class="text-sm font-medium">Password</label>
                <input id="password" name="password" type="password" required
                       class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 focus:border-teal-500 focus:outline-none focus:ring-2 focus:ring-teal-500/20">
            </div>
            @error('email')<p class="text-sm text-red-600">{{ $message }}</p>@enderror
            <label class="flex items-center gap-2 text-sm text-slate-600">
                <input type="checkbox" name="remember" class="rounded border-slate-300"> Remember me
            </label>
            <button class="w-full rounded-lg bg-teal-600 px-4 py-2.5 font-medium text-white hover:bg-teal-700">Log in</button>
        </form>
    </div>
    <p class="mt-4 text-center text-xs text-slate-500">Demo: admin@rosterloop.app / password</p>
</div>
</body>
</html>
