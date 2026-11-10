<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    // is_admin is deliberately NOT fillable, so nobody can make themselves an
    // admin by sending "is_admin": true in a sign-up request.
    protected $fillable = [
        'name',
        'email',
        'phone',
        'password',
        'fcm_token',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'fcm_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_admin' => 'boolean',
        ];
    }

    public function teams(): BelongsToMany
    {
        return $this->belongsToMany(Team::class)->withPivot('role')->withTimestamps();
    }

    public function children(): BelongsToMany
    {
        return $this->belongsToMany(Player::class, 'player_guardian')->withPivot('relationship')->withTimestamps();
    }

    public function appNotifications(): HasMany
    {
        return $this->hasMany(AppNotification::class);
    }

    /** The user's role on a team ("coach" / "parent"), or null if not a member. */
    public function roleOn(Team $team): ?string
    {
        return $this->teams()->where('teams.id', $team->id)->first()?->pivot->role;
    }

    public function isCoachOf(Team $team): bool
    {
        return $this->roleOn($team) === Team::ROLE_COACH;
    }

    public function isMemberOf(Team $team): bool
    {
        return $this->roleOn($team) !== null;
    }
}
