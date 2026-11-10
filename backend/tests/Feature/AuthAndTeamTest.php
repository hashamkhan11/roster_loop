<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthAndTeamTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_parent_can_register_and_log_in(): void
    {
        $this->postJson('/api/register', [
            'name' => 'Sara Ahmed',
            'email' => 'sara@example.com',
            'password' => 'secret123',
        ])->assertCreated()->assertJsonStructure(['token', 'user' => ['id', 'name']]);

        $this->postJson('/api/login', ['email' => 'sara@example.com', 'password' => 'secret123'])
            ->assertOk()->assertJsonStructure(['token']);

        $this->postJson('/api/login', ['email' => 'sara@example.com', 'password' => 'wrong-pass'])
            ->assertUnprocessable();
    }

    public function test_sign_up_cannot_make_someone_an_admin(): void
    {
        $this->postJson('/api/register', [
            'name' => 'Sneaky', 'email' => 'sneaky@example.com', 'password' => 'secret123', 'is_admin' => true,
        ])->assertCreated();

        $this->assertFalse(User::where('email', 'sneaky@example.com')->first()->is_admin);
    }

    public function test_a_parent_joins_with_the_code_and_never_sees_it(): void
    {
        ['team' => $team] = $this->makeTeam();
        $newParent = User::factory()->create();

        $this->actingAs($newParent)
            ->postJson('/api/teams/join', ['join_code' => strtolower($team->join_code)])
            ->assertOk()
            ->assertJsonPath('team.role', 'parent')
            ->assertJsonPath('team.join_code', null);

        $this->assertTrue($newParent->isMemberOf($team));
    }

    public function test_a_wrong_join_code_is_rejected(): void
    {
        $this->actingAs(User::factory()->create())
            ->postJson('/api/teams/join', ['join_code' => 'ZZZZZZ'])
            ->assertUnprocessable();
    }

    public function test_coach_sees_join_code_and_strangers_cannot_open_team(): void
    {
        ['team' => $team, 'coach' => $coach] = $this->makeTeam();

        $this->actingAs($coach)->getJson("/api/teams/{$team->id}")
            ->assertOk()->assertJsonPath('team.join_code', $team->join_code);

        $this->actingAs(User::factory()->create())->getJson("/api/teams/{$team->id}")->assertForbidden();
    }

    public function test_parents_only_see_private_details_of_their_own_child(): void
    {
        ['team' => $team, 'parent' => $parent, 'child' => $child] = $this->makeTeam();
        $child->update(['medical_notes' => 'Asthma inhaler in bag']);
        $other = $team->players()->create([
            'first_name' => 'Omar', 'last_name' => 'Raza', 'medical_notes' => 'Peanut allergy',
        ]);

        $players = collect($this->actingAs($parent)->getJson("/api/teams/{$team->id}")->assertOk()->json('players'));

        $this->assertSame('Asthma inhaler in bag', $players->firstWhere('id', $child->id)['medical_notes']);
        $this->assertNull($players->firstWhere('id', $other->id)['medical_notes']);
    }

    public function test_parent_can_add_own_child_but_not_delete_players(): void
    {
        ['team' => $team, 'parent' => $parent, 'child' => $child] = $this->makeTeam();

        $id = $this->actingAs($parent)
            ->postJson("/api/teams/{$team->id}/players", ['first_name' => 'Zara', 'last_name' => 'Khan'])
            ->assertCreated()->json('player.id');

        $this->assertTrue($parent->children()->whereKey($id)->exists());
        $this->actingAs($parent)->deleteJson("/api/players/{$child->id}")->assertForbidden();
    }
}
