<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SignupSlot extends Model
{
    protected $fillable = ['signup_id', 'owner_id', 'label', 'capacity', 'note'];

    public function signup(): BelongsTo
    {
        return $this->belongsTo(Signup::class);
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function claims(): HasMany
    {
        return $this->hasMany(SlotClaim::class);
    }
}
