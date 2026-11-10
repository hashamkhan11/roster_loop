<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>RosterLoop · Team communication for youth sports</title>
    <meta name="description" content="Rosters, schedules, broadcasts, RSVPs and carpools for youth sports coaches and parents, in one app.">
    @vite(['resources/css/app.css'])
</head>
<body class="bg-white text-slate-800 antialiased">
<header class="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
    <x-logo class="text-xl"/>
    <a href="{{ route('login') }}" class="text-sm font-medium text-slate-600 hover:text-slate-900">League admin login</a>
</header>

<main>
    <section class="mx-auto max-w-6xl px-6 pb-16 pt-12 text-center sm:pt-20">
        <p class="inline-block rounded-full bg-teal-50 px-3 py-1 text-xs font-medium text-teal-700">For coaches, parents and leagues</p>
        <h1 class="mx-auto mt-5 max-w-3xl text-4xl font-bold tracking-tight sm:text-5xl">
            Keep every parent <span class="text-teal-600">in the loop</span>.
        </h1>
        <p class="mx-auto mt-5 max-w-2xl text-lg text-slate-600">
            No more practice changes lost in a 40-message group chat. RosterLoop gives your team one place for
            the schedule, coach announcements, RSVPs, attendance and carpools.
        </p>
    </section>

    <section class="bg-slate-50 py-16">
        <div class="mx-auto grid max-w-6xl gap-6 px-6 sm:grid-cols-2 lg:grid-cols-4">
            @foreach ([
                ['Broadcasts with read receipts', 'Coaches see "Seen by 14/18" and exactly who missed the message.'],
                ['Schedule that updates itself', 'Weekly practices in one tap. Changes and cancellations push to every phone.'],
                ['RSVP and attendance', 'Parents answer "Is Ali coming?". Coaches mark who showed up and track %.'],
                ['Volunteers and carpools', 'Snack duty, scorekeepers and car seats, with no overbooking.'],
            ] as [$title, $text])
                <div class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
                    <h2 class="font-semibold">{{ $title }}</h2>
                    <p class="mt-2 text-sm text-slate-600">{{ $text }}</p>
                </div>
            @endforeach
        </div>
    </section>

    <section class="mx-auto max-w-3xl px-6 py-16 text-center">
        <h2 class="text-2xl font-semibold">How it works</h2>
        <ol class="mt-8 grid gap-6 text-left sm:grid-cols-3">
            <li><span class="font-mono text-teal-600">01</span><p class="mt-1 font-medium">League creates teams</p><p class="text-sm text-slate-600">and adds coaches from the admin panel.</p></li>
            <li><span class="font-mono text-teal-600">02</span><p class="mt-1 font-medium">Coach shares a 6-letter code</p><p class="text-sm text-slate-600">Parents join and link their child.</p></li>
            <li><span class="font-mono text-teal-600">03</span><p class="mt-1 font-medium">Everyone stays updated</p><p class="text-sm text-slate-600">Push reminders the night before and 2 hours before.</p></li>
        </ol>
    </section>
</main>

<footer class="border-t border-slate-200 py-8 text-center text-sm text-slate-500">
    &copy; {{ date('Y') }} RosterLoop
</footer>
</body>
</html>
