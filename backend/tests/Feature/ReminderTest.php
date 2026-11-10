<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReminderTest extends TestCase
{
    use RefreshDatabase;

    public function test_each_reminder_is_sent_once_and_cancelled_events_are_skipped(): void
    {
        ['team' => $team, 'parent' => $parent] = $this->makeTeam();
        $team->events()->create(['type' => 'game', 'title' => 'vs Tigers', 'starts_at' => now()->addHours(20)]);
        $team->events()->create(['type' => 'practice', 'title' => 'Practice', 'starts_at' => now()->addHour()]);
        $team->events()->create(['type' => 'practice', 'title' => 'Off', 'starts_at' => now()->addHour(), 'status' => 'cancelled']);
        $team->events()->create(['type' => 'practice', 'title' => 'Next week', 'starts_at' => now()->addWeek()]);

        $this->artisan('events:send-reminders')->assertSuccessful();
        $this->artisan('events:send-reminders')->assertSuccessful();

        $titles = $parent->appNotifications()->pluck('title')->sort()->values()->all();
        $this->assertSame(['Starting soon: Practice', 'Tomorrow: vs Tigers'], $titles);
    }
}
