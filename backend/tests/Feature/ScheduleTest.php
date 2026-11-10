<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ScheduleTest extends TestCase
{
    use RefreshDatabase;

    private function practice(array $overrides = []): array
    {
        return [
            'type' => 'practice',
            'title' => 'Team practice',
            'starts_at' => now()->addDay()->setTime(17, 0)->toIso8601String(),
            'ends_at' => now()->addDay()->setTime(18, 30)->toIso8601String(),
            'location' => 'Field 3',
            ...$overrides,
        ];
    }

    public function test_only_coaches_can_add_events(): void
    {
        ['team' => $team, 'parent' => $parent] = $this->makeTeam();

        $this->actingAs($parent)->postJson("/api/teams/{$team->id}/events", $this->practice())->assertForbidden();
    }

    public function test_weekly_practice_creates_a_series_and_notifies_parents(): void
    {
        ['team' => $team, 'coach' => $coach, 'parent' => $parent] = $this->makeTeam();

        $this->actingAs($coach)->postJson("/api/teams/{$team->id}/events", $this->practice([
            'repeat_until' => now()->addDay()->addWeeks(3)->toDateString(),
        ]))->assertCreated()->assertJsonCount(4, 'events');

        $events = $team->events()->orderBy('starts_at')->get();
        $this->assertSame(1, $events->pluck('series_id')->unique()->count());
        $this->assertEquals(90, $events[3]->starts_at->diffInMinutes($events[3]->ends_at));

        // Parent gets one notification for the whole series, the coach none.
        $this->assertSame(1, $parent->appNotifications()->count());
        $this->assertSame(0, $coach->appNotifications()->count());
    }

    public function test_changing_the_time_notifies_but_renaming_does_not(): void
    {
        ['team' => $team, 'coach' => $coach, 'parent' => $parent] = $this->makeTeam();
        $event = $team->events()->create($this->practice());

        $this->actingAs($coach)->putJson("/api/events/{$event->id}", ['title' => 'Skills practice'])->assertOk();
        $this->assertSame(0, $parent->appNotifications()->count());

        $this->actingAs($coach)->putJson("/api/events/{$event->id}", [
            'starts_at' => now()->addDays(2)->setTime(18, 0)->toIso8601String(),
        ])->assertOk();
        $this->assertSame('event_updated', $parent->appNotifications()->first()->type);
    }

    public function test_cancelling_a_series_cancels_only_future_events_in_it(): void
    {
        ['team' => $team, 'coach' => $coach] = $this->makeTeam();
        $this->actingAs($coach)->postJson("/api/teams/{$team->id}/events", $this->practice([
            'repeat_until' => now()->addDay()->addWeeks(3)->toDateString(),
        ]));
        $events = $team->events()->orderBy('starts_at')->get();

        $this->actingAs($coach)->postJson("/api/events/{$events[2]->id}/cancel?series=1")
            ->assertOk()->assertJsonPath('cancelled', 2);

        $this->assertSame(['scheduled', 'scheduled', 'cancelled', 'cancelled'],
            $team->events()->orderBy('starts_at')->pluck('status')->all());
    }

    public function test_parents_rsvp_only_for_their_own_child(): void
    {
        ['team' => $team, 'parent' => $parent, 'child' => $child] = $this->makeTeam();
        $other = $team->players()->create(['first_name' => 'Omar', 'last_name' => 'Raza']);
        $event = $team->events()->create($this->practice());

        $this->actingAs($parent)->postJson("/api/events/{$event->id}/rsvp", ['player_id' => $child->id, 'rsvp' => 'going'])->assertOk();
        $this->actingAs($parent)->postJson("/api/events/{$event->id}/rsvp", ['player_id' => $other->id, 'rsvp' => 'going'])->assertForbidden();

        $this->actingAs($parent)->getJson("/api/teams/{$team->id}/events")
            ->assertJsonPath('events.0.rsvp_counts.going', 1)
            ->assertJsonPath('events.0.my_children.0.rsvp', 'going');
    }

    public function test_attendance_report_shows_percentage(): void
    {
        ['team' => $team, 'coach' => $coach, 'child' => $child] = $this->makeTeam();

        foreach ([true, true, true, false] as $i => $present) {
            $event = $team->events()->create($this->practice(['starts_at' => now()->subWeeks($i + 1)]));
            $this->actingAs($coach)->postJson("/api/events/{$event->id}/attendance", [
                'attendance' => [$child->id => $present],
            ])->assertOk();
        }

        $this->actingAs($coach)->getJson("/api/teams/{$team->id}/attendance-report")
            ->assertJsonPath('report.0.attended', 3)
            ->assertJsonPath('report.0.total', 4)
            ->assertJsonPath('report.0.rate', 75);
    }

    public function test_upcoming_feed_only_includes_my_teams(): void
    {
        ['team' => $team, 'parent' => $parent] = $this->makeTeam();
        ['team' => $otherTeam] = $this->makeTeam();
        $team->events()->create($this->practice());
        $otherTeam->events()->create($this->practice());

        $this->actingAs($parent)->getJson('/api/events/upcoming')->assertJsonCount(1, 'events');
        $this->assertSame(2, Event::count());
        $this->assertFalse(User::find($parent->id)->isMemberOf($otherTeam));
    }
}
