<?php

namespace App\Services;

use App\Models\AppNotification;
use App\Models\Team;
use App\Models\User;
use Illuminate\Support\Collection;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification as FcmNotification;
use Kreait\Laravel\Firebase\Facades\Firebase;

/**
 * Notifies a group of users: always saves the message to each user's in-app
 * inbox, and also sends a push to every phone that has an FCM token.
 * Every feature (broadcasts, schedule changes, reminders) goes through here,
 * so they all behave the same way.
 */
class TeamNotifier
{
    /**
     * @param  Collection<int, User>  $users
     */
    public function notify(Collection $users, ?Team $team, string $type, string $title, string $body, array $data = []): void
    {
        $users = $users->unique('id');
        if ($users->isEmpty()) {
            return;
        }

        $now = now();
        $data = ['type' => $type, 'team_id' => (string) $team?->id] + array_map('strval', $data);

        // One INSERT for the whole team instead of one per parent.
        AppNotification::insert($users->map(fn (User $user) => [
            'user_id' => $user->id,
            'team_id' => $team?->id,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'data' => json_encode($data),
            'created_at' => $now,
            'updated_at' => $now,
        ])->all());

        $this->push($users->pluck('fcm_token')->filter()->values()->all(), $title, $body, $data);
    }

    private function push(array $tokens, string $title, string $body, array $data): void
    {
        if ($tokens === [] || ! config('firebase.projects.app.credentials')) {
            return;
        }

        try {
            $message = CloudMessage::new()
                ->withNotification(FcmNotification::create($title, $body))
                ->withData($data);

            $report = Firebase::messaging()->sendMulticast($message, $tokens);

            // Phones that uninstalled the app leave dead tokens behind; clear
            // them so we stop trying to reach those devices.
            if ($report->hasFailures()) {
                User::whereIn('fcm_token', $report->invalidTokens())->update(['fcm_token' => null]);
            }
        } catch (\Throwable $e) {
            // A push failing must never break the request that triggered it;
            // the message is already saved in the inbox.
            report($e);
        }
    }
}
