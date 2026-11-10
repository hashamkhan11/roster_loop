<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('team_id')->constrained()->cascadeOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('type'); // game | practice
            $table->string('title');
            $table->dateTime('starts_at');
            $table->dateTime('ends_at')->nullable();
            $table->string('location')->nullable();
            $table->string('opponent')->nullable();
            $table->text('notes')->nullable();
            $table->string('status')->default('scheduled'); // scheduled | cancelled
            // Events created together as a weekly repeat share a series id,
            // so a coach can cancel the whole series later.
            $table->uuid('series_id')->nullable()->index();
            $table->timestamp('day_reminder_sent_at')->nullable();
            $table->timestamp('hour_reminder_sent_at')->nullable();
            $table->timestamps();
            $table->index(['team_id', 'starts_at']);
        });

        // One row per player per event: the RSVP before the event and the
        // coach's attendance mark on the day.
        Schema::create('event_player', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->foreignId('player_id')->constrained()->cascadeOnDelete();
            $table->string('rsvp')->nullable(); // going | not_going | maybe
            $table->foreignId('rsvp_by')->nullable()->constrained('users')->nullOnDelete();
            $table->boolean('present')->nullable();
            $table->timestamps();
            $table->unique(['event_id', 'player_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('event_player');
        Schema::dropIfExists('events');
    }
};
