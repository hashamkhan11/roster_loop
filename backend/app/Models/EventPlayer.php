<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A player's RSVP and attendance for one event. */
class EventPlayer extends Model
{
    public const RSVPS = ['going', 'not_going', 'maybe'];

    protected $table = 'event_player';

    protected $fillable = ['event_id', 'player_id', 'rsvp', 'rsvp_by', 'present'];

    protected function casts(): array
    {
        return ['present' => 'boolean'];
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function player(): BelongsTo
    {
        return $this->belongsTo(Player::class);
    }
}
