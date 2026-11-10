<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A sign-up sheet, e.g. "Volunteers for Saturday" or "Carpool to the
        // away game".
        Schema::create('signups', function (Blueprint $table) {
            $table->id();
            $table->foreignId('team_id')->constrained()->cascadeOnDelete();
            $table->foreignId('event_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('type'); // volunteer | carpool
            $table->string('title');
            $table->text('description')->nullable();
            $table->timestamps();
        });

        // Volunteer: "Snacks" with 2 spots. Carpool: a driver's car with
        // 3 seats, offered by that driver (owner_id).
        Schema::create('signup_slots', function (Blueprint $table) {
            $table->id();
            $table->foreignId('signup_id')->constrained()->cascadeOnDelete();
            $table->foreignId('owner_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('label');
            $table->unsignedSmallInteger('capacity')->default(1);
            $table->string('note')->nullable();
            $table->timestamps();
        });

        Schema::create('slot_claims', function (Blueprint $table) {
            $table->id();
            $table->foreignId('signup_slot_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            // For carpools: which child is riding.
            $table->foreignId('player_id')->nullable()->constrained()->cascadeOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('slot_claims');
        Schema::dropIfExists('signup_slots');
        Schema::dropIfExists('signups');
    }
};
