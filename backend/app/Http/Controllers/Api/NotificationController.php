<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $notifications = $request->user()->appNotifications()->latest()->limit(50)->get();

        return response()->json([
            'notifications' => $notifications,
            'unread_count' => $request->user()->appNotifications()->whereNull('read_at')->count(),
        ]);
    }

    public function markAllRead(Request $request)
    {
        $request->user()->appNotifications()->whereNull('read_at')->update(['read_at' => now()]);

        return response()->json(['message' => 'All caught up.']);
    }
}
