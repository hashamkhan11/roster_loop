<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Player extends Model
{
    use HasFactory;

    protected $fillable = [
        'team_id', 'first_name', 'last_name', 'jersey_number', 'position', 'date_of_birth',
        'emergency_contact_name', 'emergency_contact_phone', 'medical_notes',
    ];

    protected $appends = ['full_name'];

    protected function casts(): array
    {
        return ['date_of_birth' => 'date:Y-m-d'];
    }

    public function getFullNameAttribute(): string
    {
        return "{$this->first_name} {$this->last_name}";
    }

    public function team(): BelongsTo
    {
        return $this->belongsTo(Team::class);
    }

    public function guardians(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'player_guardian')->withPivot('relationship')->withTimestamps();
    }

    public function eventRecords(): HasMany
    {
        return $this->hasMany(EventPlayer::class);
    }
}
