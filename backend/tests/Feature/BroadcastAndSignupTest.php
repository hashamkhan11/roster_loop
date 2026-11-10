<?php

namespace Tests\Feature;

use App\Models\Team;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BroadcastAndSignupTest extends TestCase
{
    use RefreshDatabase;

    public function test_broadcast_reaches_parents_and_tracks_who_read_it(): void
    {
        ['team' => $team, 'coach' => $coach, 'parent' => $parent] = $this->makeTeam();
        $quietParent = User::factory()->create();
        $team->members()->attach($quietParent->id, ['role' => Team::ROLE_PARENT]);

        $id = $this->actingAs($coach)->postJson("/api/teams/{$team->id}/broadcasts", [
            'title' => 'Bring water', 'body' => 'It will be hot on Saturday.', 'is_urgent' => true,
        ])->assertCreated()->json('broadcast.id');

        $this->assertStringStartsWith('URGENT:', $parent->appNotifications()->first()->title);

        // Opening it twice still counts as one read.
        $this->actingAs($parent)->postJson("/api/broadcasts/{$id}/read")->assertOk();
        $this->actingAs($parent)->postJson("/api/broadcasts/{$id}/read")->assertOk();

        $this->actingAs($coach)->getJson("/api/teams/{$team->id}/broadcasts")
            ->assertJsonPath('data.0.reads_count', 1)
            ->assertJsonPath('data.0.audience_count', 2);

        $this->actingAs($coach)->getJson("/api/broadcasts/{$id}/readers")
            ->assertJsonPath('seen.0.id', $parent->id)
            ->assertJsonPath('not_seen.0.id', $quietParent->id);
    }

    public function test_parents_cannot_broadcast_or_see_readers(): void
    {
        ['team' => $team, 'coach' => $coach, 'parent' => $parent] = $this->makeTeam();

        $this->actingAs($parent)->postJson("/api/teams/{$team->id}/broadcasts", ['title' => 'Hi', 'body' => 'x'])
            ->assertForbidden();

        $broadcast = $team->broadcasts()->create(['user_id' => $coach->id, 'title' => 'T', 'body' => 'B']);
        $this->actingAs($parent)->getJson("/api/broadcasts/{$broadcast->id}/readers")->assertForbidden();
    }

    public function test_carpool_seats_cannot_be_overbooked(): void
    {
        ['team' => $team, 'parent' => $driver, 'child' => $child] = $this->makeTeam();

        $signupId = $this->actingAs($driver)->postJson("/api/teams/{$team->id}/signups", [
            'type' => 'carpool', 'title' => 'Away game at Riverside',
        ])->assertCreated()->json('signup.id');

        $slotId = $this->actingAs($driver)->postJson("/api/signups/{$signupId}/slots", [
            'label' => 'Blue minivan', 'capacity' => 1,
        ])->assertCreated()->json('slot.id');

        $this->actingAs($driver)->postJson("/api/slots/{$slotId}/claim", ['player_id' => $child->id])->assertCreated();

        $otherParent = User::factory()->create();
        $team->members()->attach($otherParent->id, ['role' => Team::ROLE_PARENT]);
        $this->actingAs($otherParent)->postJson("/api/slots/{$slotId}/claim")
            ->assertUnprocessable()->assertJsonValidationErrors('slot');
    }

    public function test_only_coaches_create_volunteer_sheets(): void
    {
        ['team' => $team, 'coach' => $coach, 'parent' => $parent] = $this->makeTeam();
        $sheet = ['type' => 'volunteer', 'title' => 'Saturday helpers', 'slots' => [
            ['label' => 'Snacks', 'capacity' => 2],
            ['label' => 'Scorekeeper'],
        ]];

        $this->actingAs($parent)->postJson("/api/teams/{$team->id}/signups", $sheet)->assertForbidden();
        $this->actingAs($coach)->postJson("/api/teams/{$team->id}/signups", $sheet)
            ->assertCreated()->assertJsonCount(2, 'signup.slots');
    }

    public function test_notifications_inbox_and_mark_all_read(): void
    {
        ['team' => $team, 'coach' => $coach, 'parent' => $parent] = $this->makeTeam();
        $this->actingAs($coach)->postJson("/api/teams/{$team->id}/broadcasts", ['title' => 'A', 'body' => 'B']);

        $this->actingAs($parent)->getJson('/api/notifications')->assertJsonPath('unread_count', 1);
        $this->actingAs($parent)->postJson('/api/notifications/read-all')->assertOk();
        $this->actingAs($parent)->getJson('/api/notifications')->assertJsonPath('unread_count', 0);
    }
}
