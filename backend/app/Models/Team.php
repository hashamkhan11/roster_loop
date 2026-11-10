<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Team extends Model
{
    use HasFactory;

    public const ROLE_COACH = 'coach';

    public const ROLE_PARENT = 'parent';

    protected $fillable = ['league_id', 'name', 'age_group', 'color', 'timezone', 'join_code'];

    // Mirrors the column defaults. Without this, a freshly created Team has
    // timezone = null in memory, because Laravel doesn't re-read the row.
    protected $attributes = [
        'color' => '#2563EB',
        'timezone' => 'America/New_York',
    ];

    protected static function booted(): void
    {
        static::creating(function (Team $team) {
            $team->join_code ??= static::generateJoinCode();
        });
    }

    /**
     * Six characters without look-alikes (no 0/O, 1/I/L), so a code read out
     * loud at practice is easy to type correctly.
     */
    public static function generateJoinCode(): string
    {
        $alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

        do {
            $code = '';
            for ($i = 0; $i < 6; $i++) {
                $code .= $alphabet[random_int(0, strlen($alphabet) - 1)];
            }
        } while (static::where('join_code', $code)->exists());

        return $code;
    }

    public function league(): BelongsTo
    {
        return $this->belongsTo(League::class);
    }

    public function members(): BelongsToMany
    {
        return $this->belongsToMany(User::class)->withPivot('role')->withTimestamps();
    }

    public function coaches(): BelongsToMany
    {
        return $this->members()->wherePivot('role', self::ROLE_COACH);
    }

    public function parents(): BelongsToMany
    {
        return $this->members()->wherePivot('role', self::ROLE_PARENT);
    }

    public function players(): HasMany
    {
        return $this->hasMany(Player::class);
    }

    public function events(): HasMany
    {
        return $this->hasMany(Event::class);
    }

    public function broadcasts(): HasMany
    {
        return $this->hasMany(Broadcast::class);
    }

    public function signups(): HasMany
    {
        return $this->hasMany(Signup::class);
    }
}
