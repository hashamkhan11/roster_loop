<?php

namespace App\Console\Commands;

use App\Models\Event;
use App\Services\TeamNotifier;
use Illuminate\Console\Command;

class SendEventReminders extends Command
{
    protected $signature = 'events:send-reminders';

    protected $description = 'Remind team members about events starting tomorrow and in the next 2 hours';

    public function handle(TeamNotifier $notifier): int
    {
        $sent = 0;

        // "Tomorrow" reminder: anything in the next 24 hours that is still
        // more than 2 hours away (closer ones get the 2-hour reminder instead).
        $tomorrow = Event::scheduled()->with('team')
            ->whereNull('day_reminder_sent_at')
            ->whereBetween('starts_at', [now()->addHours(2), now()->addDay()])
            ->get();

        foreach ($tomorrow as $event) {
            $this->remind($notifier, $event, 'Tomorrow: '.$event->title);
            $event->forceFill(['day_reminder_sent_at' => now()])->save();
            $sent++;
        }

        $soon = Event::scheduled()->with('team')
            ->whereNull('hour_reminder_sent_at')
            ->whereBetween('starts_at', [now(), now()->addHours(2)])
            ->get();

        foreach ($soon as $event) {
            $this->remind($notifier, $event, 'Starting soon: '.$event->title);
            // If the event was created at the last minute, the day reminder
            // is no longer useful, so mark both as done.
            $event->forceFill(['hour_reminder_sent_at' => now(), 'day_reminder_sent_at' => $event->day_reminder_sent_at ?? now()])->save();
            $sent++;
        }

        $this->info("Sent {$sent} reminder(s).");

        return self::SUCCESS;
    }

    private function remind(TeamNotifier $notifier, Event $event, string $title): void
    {
        $time = $event->starts_at->copy()->setTimezone($event->team->timezone)->format('D g:i A');
        $body = $event->team->name.' · '.$time.($event->location ? ' · '.$event->location : '');

        $notifier->notify($event->team->members()->get(), $event->team, 'event_reminder', $title, $body, ['event_id' => $event->id]);
    }
}
