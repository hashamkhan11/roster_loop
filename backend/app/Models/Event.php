<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Event extends Model
{
    use HasFactory;

    public const TYPES = ['game', 'practice'];

    protected $fillable = [
        'team_id', 'created_by', 'type', 'title', 'starts_at', 'ends_at', 'location',
        'opponent', 'notes', 'status', 'series_id',
    ];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'day_reminder_sent_at' => 'datetime',
            'hour_reminder_sent_at' => 'datetime',
        ];
    }

    public function team(): BelongsTo
    {
        return $this->belongsTo(Team::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function playerRecords(): HasMany
    {
        return $this->hasMany(EventPlayer::class);
    }

    /** Events still to come (plus ones that started in the last 3 hours, so today's game stays visible). */
    public function scopeUpcoming(Builder $query): Builder
    {
        return $query->where('starts_at', '>=', now()->subHours(3))->orderBy('starts_at');
    }

    public function scopeScheduled(Builder $query): Builder
    {
        return $query->where('status', 'scheduled');
    }

    public function isCancelled(): bool
    {
        return $this->status === 'cancelled';
    }
}
