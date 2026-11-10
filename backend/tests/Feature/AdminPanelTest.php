<?php

namespace Tests\Feature;

use App\Models\Team;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminPanelTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    private function admin(): User
    {
        $admin = User::factory()->create();
        $admin->forceFill(['is_admin' => true])->save();

        return $admin;
    }

    public function test_coaches_and_parents_cannot_use_the_panel(): void
    {
        ['coach' => $coach] = $this->makeTeam();

        $this->post('/admin/login', ['email' => $coach->email, 'password' => 'password'])
            ->assertSessionHasErrors('email');
        $this->assertGuest();

        $this->actingAs($coach)->get('/admin')->assertForbidden();
    }

    public function test_admin_can_log_in_and_every_page_renders(): void
    {
        ['team' => $team] = $this->makeTeam();
        $admin = $this->admin();

        $this->post('/admin/login', ['email' => $admin->email, 'password' => 'password'])->assertRedirect('/admin');

        foreach (['/admin', '/admin/teams', "/admin/teams/{$team->id}", "/admin/teams/{$team->id}/edit", '/admin/teams/create', '/admin/leagues', '/admin/users'] as $url) {
            $this->get($url)->assertOk();
        }
        $this->get('/')->assertOk()->assertSee('in the loop');
    }

    public function test_adding_a_new_coach_creates_their_account(): void
    {
        ['team' => $team] = $this->makeTeam();

        $this->actingAs($this->admin())
            ->post("/admin/teams/{$team->id}/coaches", ['name' => 'Coach Amir', 'email' => 'amir@example.com'])
            ->assertSessionHas('status', fn ($msg) => str_contains($msg, 'Temporary password'));

        $this->assertTrue(User::where('email', 'amir@example.com')->first()->isCoachOf($team));
    }

    public function test_promoting_an_existing_parent_to_coach(): void
    {
        ['team' => $team, 'parent' => $parent] = $this->makeTeam();

        $this->actingAs($this->admin())
            ->post("/admin/teams/{$team->id}/coaches", ['name' => $parent->name, 'email' => $parent->email]);

        $this->assertSame(Team::ROLE_COACH, $parent->roleOn($team));
    }

    public function test_regenerating_the_join_code_replaces_it(): void
    {
        ['team' => $team] = $this->makeTeam();
        $old = $team->join_code;

        $this->actingAs($this->admin())->post("/admin/teams/{$team->id}/regenerate-code");

        $this->assertNotSame($old, $team->fresh()->join_code);
    }
}
