<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('players', function (Blueprint $table) {
            $table->id();
            $table->foreignId('team_id')->constrained()->cascadeOnDelete();
            $table->string('first_name');
            $table->string('last_name');
            $table->unsignedSmallInteger('jersey_number')->nullable();
            $table->string('position')->nullable();
            $table->date('date_of_birth')->nullable();
            $table->string('emergency_contact_name')->nullable();
            $table->string('emergency_contact_phone')->nullable();
            $table->text('medical_notes')->nullable();
            $table->timestamps();
        });

        // Links parents to their children. Many-to-many: two parents can
        // share one child, and one parent can have two children.
        Schema::create('player_guardian', function (Blueprint $table) {
            $table->id();
            $table->foreignId('player_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('relationship')->nullable();
            $table->timestamps();
            $table->unique(['player_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('player_guardian');
        Schema::dropIfExists('players');
    }
};
