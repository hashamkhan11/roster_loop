<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SlotClaim extends Model
{
    protected $fillable = ['signup_slot_id', 'user_id', 'player_id'];

    public function slot(): BelongsTo
    {
        return $this->belongsTo(SignupSlot::class, 'signup_slot_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function player(): BelongsTo
    {
        return $this->belongsTo(Player::class);
    }
}
