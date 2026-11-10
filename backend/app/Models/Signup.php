<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Signup extends Model
{
    use HasFactory;

    public const TYPES = ['volunteer', 'carpool'];

    protected $fillable = ['team_id', 'event_id', 'created_by', 'type', 'title', 'description'];

    public function team(): BelongsTo
    {
        return $this->belongsTo(Team::class);
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function slots(): HasMany
    {
        return $this->hasMany(SignupSlot::class);
    }
}
