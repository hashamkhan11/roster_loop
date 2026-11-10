<?php

namespace Database\Seeders;

use App\Models\Event;
use App\Models\EventPlayer;
use App\Models\League;
use App\Models\Team;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * Demo data: one league, two teams, a full roster, a season of games and
 * practices with attendance, broadcasts and sign-ups.
 *
 * Demo logins (password: "password"):
 *   admin@rosterloop.app   league admin (web panel)
 *   coach@rosterloop.app   coach of U10 Lions
 *   parent@rosterloop.app  parent of two kids, one on each team
 */
class DatabaseSeeder extends Seeder
{
    private const FIRST_NAMES = ['Ali', 'Ayaan', 'Zara', 'Omar', 'Hania', 'Ibrahim', 'Mia', 'Noah', 'Ella', 'Rayan', 'Sofia', 'Adam', 'Liam', 'Aisha', 'Yusuf', 'Emma', 'Hamza', 'Leah', 'Musa', 'Olivia', 'Zayn', 'Inaya', 'Lucas', 'Maryam'];

    private const LAST_NAMES = ['Khan', 'Ahmed', 'Smith', 'Raza', 'Malik', 'Garcia', 'Hussain', 'Brown', 'Shah', 'Lee', 'Iqbal', 'Wilson'];

    private const PARENT_NAMES = ['Fatima', 'James', 'Ayesha', 'Michael', 'Nadia', 'Carlos', 'Hina', 'David', 'Sana', 'Kevin', 'Rabia', 'Tom', 'Amna', 'Chris'];

    public function run(): void
    {
        $admin = $this->user('League Admin', 'admin@rosterloop.app');
        $admin->forceFill(['is_admin' => true])->save();

        $coach = $this->user('Coach Daniel Reed', 'coach@rosterloop.app', '+1 555 0100');
        $assistant = $this->user('Coach Priya Nair', 'priya@rosterloop.app', '+1 555 0101');
        $demoParent = $this->user('Sara Ahmed', 'parent@rosterloop.app', '+1 555 0142');

        $league = League::create(['name' => 'Valley Youth Soccer League', 'sport' => 'Soccer', 'season' => 'Fall 2026']);

        $lions = Team::create(['league_id' => $league->id, 'name' => 'U10 Lions', 'age_group' => 'Under 10', 'color' => '#F59E0B', 'join_code' => 'LIONS7']);
        $hawks = Team::create(['league_id' => $league->id, 'name' => 'U12 Hawks', 'age_group' => 'Under 12', 'color' => '#2563EB', 'join_code' => 'HAWK12']);
        Team::create(['league_id' => $league->id, 'name' => 'U8 Cubs', 'age_group' => 'Under 8', 'color' => '#10B981']);

        $lions->members()->attach($coach->id, ['role' => Team::ROLE_COACH]);
        $hawks->members()->attach($assistant->id, ['role' => Team::ROLE_COACH]);

        $this->roster($lions, 14, $demoParent, 'Ayaan');
        $this->roster($hawks, 12, $demoParent, 'Zara');

        $this->season($lions, $coach, ['Tigers', 'Sharks', 'Eagles', 'Panthers', 'Wolves', 'Falcons']);
        $this->season($hawks, $assistant, ['Rockets', 'Comets', 'Thunder', 'Storm', 'Blaze', 'Titans']);

        $this->broadcasts($lions, $coach);
        $this->signups($lions, $coach);
    }

    private function user(string $name, string $email, ?string $phone = null): User
    {
        return User::create(['name' => $name, 'email' => $email, 'phone' => $phone, 'password' => 'password']);
    }

    /** Creates players, each with a parent account; the demo parent gets one named child. */
    private function roster(Team $team, int $size, User $demoParent, string $demoChild): void
    {
        $team->members()->attach($demoParent->id, ['role' => Team::ROLE_PARENT]);

        for ($i = 0; $i < $size; $i++) {
            $isDemoChild = $i === 0;
            $last = $isDemoChild ? 'Ahmed' : self::LAST_NAMES[($i + $team->id) % count(self::LAST_NAMES)];
            // Stepping by 5 through 24 names never repeats a name within a team.
            $first = $isDemoChild ? $demoChild : self::FIRST_NAMES[($i * 5 + $team->id) % count(self::FIRST_NAMES)];
            $parentName = $isDemoChild ? 'Bilal Ahmed' : self::PARENT_NAMES[($i + $team->id) % count(self::PARENT_NAMES)]." {$last}";

            $player = $team->players()->create([
                'first_name' => $first,
                'last_name' => $last,
                // The demo child wears #10, so everyone else skips it.
                'jersey_number' => $isDemoChild ? 10 : ($i < 9 ? $i + 1 : $i + 2),
                'position' => ['Forward', 'Midfielder', 'Defender', 'Goalkeeper'][$i % 4],
                'date_of_birth' => now()->subYears($team->name === 'U10 Lions' ? 9 : 11)->subDays($i * 17),
                'emergency_contact_name' => $parentName,
                'emergency_contact_phone' => '+1 555 '.str_pad((string) (200 + $i), 4, '0', STR_PAD_LEFT),
                'medical_notes' => $i % 5 === 1 ? 'Mild asthma, inhaler in bag' : null,
            ]);

            $parent = $isDemoChild
                ? $demoParent
                : $this->user($parentName, Str::slug("{$parentName}-{$team->id}-{$i}").'@example.com', '+1 555 '.(300 + $i));

            $player->guardians()->attach($parent->id, ['relationship' => $isDemoChild ? 'Mother' : 'Parent']);
            if (! $isDemoChild) {
                $team->members()->attach($parent->id, ['role' => Team::ROLE_PARENT]);
            }
        }
    }

    /** 6 weeks back and 6 weeks ahead: Tue/Thu practices and Saturday games. */
    private function season(Team $team, User $coach, array $opponents): void
    {
        $tz = $team->timezone;
        $start = Carbon::now($tz)->startOfWeek()->subWeeks(6);
        $seriesId = (string) Str::uuid();
        $players = $team->players()->get();

        for ($week = 0; $week < 12; $week++) {
            $monday = $start->copy()->addWeeks($week);

            foreach ([1, 3] as $dayOffset) {
                $this->event($team, $coach, $players, [
                    'type' => 'practice',
                    'title' => 'Team practice',
                    'starts_at' => $monday->copy()->addDays($dayOffset)->setTime(17, 30)->utc(),
                    'ends_at' => $monday->copy()->addDays($dayOffset)->setTime(19, 0)->utc(),
                    'location' => 'Riverside Park, Field 3',
                    'series_id' => $seriesId,
                ]);
            }

            $home = $week % 2 === 0;
            $this->event($team, $coach, $players, [
                'type' => 'game',
                'title' => ($home ? 'vs ' : '@ ').$opponents[$week % count($opponents)],
                'opponent' => $opponents[$week % count($opponents)],
                'starts_at' => $monday->copy()->addDays(5)->setTime(9, 0)->utc(),
                'ends_at' => $monday->copy()->addDays(5)->setTime(10, 30)->utc(),
                'location' => $home ? 'Riverside Park, Field 1' : 'Oak Hill Sports Complex',
                'notes' => $home ? 'Home game: wear yellow jerseys. Arrive 30 min early.' : 'Away game: wear blue jerseys.',
                'status' => $week === 7 ? 'cancelled' : 'scheduled',
            ]);
        }
    }

    private function event(Team $team, User $coach, $players, array $attributes): void
    {
        $event = $team->events()->create([...$attributes, 'created_by' => $coach->id]);
        if ($event->isCancelled()) {
            return;
        }

        $isPast = $event->starts_at->isPast();
        $inNextTwoWeeks = $event->starts_at->lt(now()->addWeeks(2));
        if (! $isPast && ! $inNextTwoWeeks) {
            return;
        }

        foreach ($players as $i => $player) {
            // Deterministic "random" so every reseed gives the same numbers.
            $roll = crc32($event->id.'-'.$player->id) % 100;
            if (! $isPast && $i === 0) {
                continue; // Leave the demo child unanswered so the RSVP buttons show.
            }

            EventPlayer::create([
                'event_id' => $event->id,
                'player_id' => $player->id,
                'rsvp' => $roll < 75 ? 'going' : ($roll < 88 ? 'maybe' : 'not_going'),
                'present' => $isPast ? $roll < 85 : null,
            ]);
        }

        if ($isPast) {
            $event->forceFill(['day_reminder_sent_at' => $event->starts_at->copy()->subDay(), 'hour_reminder_sent_at' => $event->starts_at->copy()->subHours(2)])->save();
        }
    }

    private function broadcasts(Team $team, User $coach): void
    {
        $members = $team->members()->where('users.id', '!=', $coach->id)->pluck('users.id');

        $messages = [
            [9, false, 'Welcome to the Fall season!', "Hi families! I'm excited for the season. Practices are Tue/Thu 5:30-7pm at Riverside Park. Please RSVP in the app so I can plan drills. Shin guards are required at every practice."],
            [5, false, 'Picture day next Saturday', 'Team and individual photos before the game at 8:15 AM. Order forms were sent home in the kit bags.'],
            [2, true, 'Field change for Thursday', "Field 3 is being re-seeded. Thursday's practice moves to Field 5 (behind the parking lot). Same time."],
            [0, false, 'Snack and carpool sign-ups are open', "We still need snack volunteers for the next two games and drivers for the away game. Tap 'Sign-ups' to help out. Thank you!"],
        ];

        foreach ($messages as [$daysAgo, $urgent, $title, $body]) {
            $broadcast = $team->broadcasts()->create([
                'user_id' => $coach->id, 'title' => $title, 'body' => $body, 'is_urgent' => $urgent,
            ]);
            $broadcast->forceFill(['created_at' => now()->subDays($daysAgo)->subHours(3)])->save();

            // Older messages have been read by more people.
            $readers = $members->take((int) round($members->count() * min(0.95, 0.45 + $daysAgo * 0.07)));
            foreach ($readers as $userId) {
                $broadcast->reads()->create(['user_id' => $userId, 'read_at' => $broadcast->created_at->copy()->addHours(2)]);
            }
        }
    }

    private function signups(Team $team, User $coach): void
    {
        $nextGames = $team->events()->where('type', 'game')->scheduled()->where('starts_at', '>', now())->orderBy('starts_at')->take(2)->get();
        $parents = $team->parents()->where('users.email', '!=', 'parent@rosterloop.app')->get();

        $snacks = $team->signups()->create([
            'type' => 'volunteer', 'title' => 'Game day volunteers', 'created_by' => $coach->id,
            'event_id' => $nextGames->first()?->id,
            'description' => 'Help make game day run smoothly. Healthy snacks please (orange slices, water).',
        ]);
        $snacks->slots()->create(['label' => 'Half-time snacks', 'capacity' => 2])->claims()->create(['user_id' => $parents[0]->id]);
        $snacks->slots()->create(['label' => 'Scorekeeper', 'capacity' => 1]);
        $snacks->slots()->create(['label' => 'Field setup (nets and flags)', 'capacity' => 2])->claims()->create(['user_id' => $parents[1]->id]);

        $away = $nextGames->first(fn (Event $e) => str_starts_with($e->title, '@')) ?? $nextGames->last();
        $carpool = $team->signups()->create([
            'type' => 'carpool', 'title' => 'Carpool to '.($away?->location ?? 'away game'), 'created_by' => $parents[2]->id,
            'event_id' => $away?->id, 'description' => 'Leaving the school parking lot at 8:00 AM.',
        ]);
        $van = $carpool->slots()->create(['label' => 'Blue minivan', 'capacity' => 4, 'owner_id' => $parents[2]->id, 'note' => 'Have 2 booster seats']);
        foreach ($parents->slice(3, 2) as $p) {
            $van->claims()->create(['user_id' => $p->id, 'player_id' => $p->children()->first()?->id]);
        }
        $carpool->slots()->create(['label' => 'Silver SUV', 'capacity' => 3, 'owner_id' => $parents[5]->id]);
    }
}
