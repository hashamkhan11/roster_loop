<?php

namespace Tests;

use App\Models\League;
use App\Models\Player;
use App\Models\Team;
use App\Models\User;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    /**
     * A team with one coach, one parent and the parent's child.
     *
     * @return array{team: Team, coach: User, parent: User, child: Player}
     */
    protected function makeTeam(): array
    {
        $league = League::create(['name' => 'Valley Youth Soccer', 'sport' => 'Soccer']);
        $team = Team::create(['league_id' => $league->id, 'name' => 'U10 Lions']);

        $coach = User::factory()->create();
        $parent = User::factory()->create();
        $team->members()->attach($coach->id, ['role' => Team::ROLE_COACH]);
        $team->members()->attach($parent->id, ['role' => Team::ROLE_PARENT]);

        $child = $team->players()->create(['first_name' => 'Ali', 'last_name' => 'Khan', 'jersey_number' => 7]);
        $child->guardians()->attach($parent->id);

        return compact('team', 'coach', 'parent', 'child');
    }
}
