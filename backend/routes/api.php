<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BroadcastController;
use App\Http\Controllers\Api\EventController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\PlayerController;
use App\Http\Controllers\Api\SignupController;
use App\Http\Controllers\Api\TeamController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:5,1');
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:5,1');

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::put('/me', [AuthController::class, 'updateProfile']);
    Route::post('/me/fcm-token', [AuthController::class, 'updateFcmToken']);

    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);

    // Teams and roster
    Route::get('/teams', [TeamController::class, 'index']);
    Route::post('/teams/join', [TeamController::class, 'join'])->middleware('throttle:10,1');
    Route::get('/teams/{team}', [TeamController::class, 'show']);
    Route::delete('/teams/{team}/leave', [TeamController::class, 'leave']);

    Route::post('/teams/{team}/players', [PlayerController::class, 'store']);
    Route::put('/players/{player}', [PlayerController::class, 'update']);
    Route::delete('/players/{player}', [PlayerController::class, 'destroy']);
    Route::post('/players/{player}/claim', [PlayerController::class, 'claim']);

    // Schedule, RSVP and attendance
    Route::get('/events/upcoming', [EventController::class, 'upcoming']);
    Route::get('/teams/{team}/events', [EventController::class, 'index']);
    Route::post('/teams/{team}/events', [EventController::class, 'store']);
    Route::get('/teams/{team}/attendance-report', [EventController::class, 'attendanceReport']);
    Route::get('/events/{event}', [EventController::class, 'show']);
    Route::put('/events/{event}', [EventController::class, 'update']);
    Route::post('/events/{event}/cancel', [EventController::class, 'cancel']);
    Route::delete('/events/{event}', [EventController::class, 'destroy']);
    Route::post('/events/{event}/rsvp', [EventController::class, 'rsvp']);
    Route::post('/events/{event}/attendance', [EventController::class, 'attendance']);

    // Broadcasts
    Route::get('/teams/{team}/broadcasts', [BroadcastController::class, 'index']);
    Route::post('/teams/{team}/broadcasts', [BroadcastController::class, 'store'])->middleware('throttle:20,1');
    Route::post('/broadcasts/{broadcast}/read', [BroadcastController::class, 'markRead']);
    Route::get('/broadcasts/{broadcast}/readers', [BroadcastController::class, 'readers']);
    Route::delete('/broadcasts/{broadcast}', [BroadcastController::class, 'destroy']);

    // Volunteer and carpool sign-ups
    Route::get('/teams/{team}/signups', [SignupController::class, 'index']);
    Route::post('/teams/{team}/signups', [SignupController::class, 'store']);
    Route::delete('/signups/{signup}', [SignupController::class, 'destroy']);
    Route::post('/signups/{signup}/slots', [SignupController::class, 'addSlot']);
    Route::delete('/slots/{slot}', [SignupController::class, 'removeSlot']);
    Route::post('/slots/{slot}/claim', [SignupController::class, 'claim']);
    Route::delete('/claims/{claim}', [SignupController::class, 'unclaim']);
});
