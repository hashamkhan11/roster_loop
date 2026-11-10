<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('leagues', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('sport');
            $table->string('season')->nullable();
            $table->timestamps();
        });

        Schema::create('teams', function (Blueprint $table) {
            $table->id();
            $table->foreignId('league_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('age_group')->nullable();
            $table->string('color', 7)->default('#2563EB');
            // Used to write times in notifications ("Sat 9:00 AM") in the
            // team's local time. The apps show times in the phone's timezone.
            $table->string('timezone')->default('America/New_York');
            // Short code parents type into the app to join the team.
            $table->string('join_code', 6)->unique();
            $table->timestamps();
        });

        // Who belongs to a team and in what role. A user can be a coach on
        // one team and a parent on another, so the role lives here.
        Schema::create('team_user', function (Blueprint $table) {
            $table->id();
            $table->foreignId('team_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('role'); // coach | parent
            $table->timestamps();
            $table->unique(['team_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('team_user');
        Schema::dropIfExists('teams');
        Schema::dropIfExists('leagues');
    }
};
