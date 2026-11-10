<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\LeagueController;
use App\Http\Controllers\Admin\TeamController;
use App\Http\Controllers\Admin\UserController;
use Illuminate\Support\Facades\Route;

Route::view('/', 'welcome')->name('home');

Route::middleware('guest')->group(function () {
    Route::get('/admin/login', [AuthController::class, 'show'])->name('login');
    Route::post('/admin/login', [AuthController::class, 'login'])->middleware('throttle:5,1');
});

Route::prefix('admin')->name('admin.')->middleware(['auth', 'can:access-admin'])->group(function () {
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');
    Route::get('/', DashboardController::class)->name('dashboard');

    Route::get('/leagues', [LeagueController::class, 'index'])->name('leagues.index');
    Route::post('/leagues', [LeagueController::class, 'store'])->name('leagues.store');
    Route::put('/leagues/{league}', [LeagueController::class, 'update'])->name('leagues.update');
    Route::delete('/leagues/{league}', [LeagueController::class, 'destroy'])->name('leagues.destroy');

    Route::resource('teams', TeamController::class);
    Route::post('/teams/{team}/regenerate-code', [TeamController::class, 'regenerateCode'])->name('teams.regenerate-code');
    Route::post('/teams/{team}/coaches', [TeamController::class, 'addCoach'])->name('teams.coaches.store');
    Route::delete('/teams/{team}/members/{user}', [TeamController::class, 'removeMember'])->name('teams.members.destroy');

    Route::get('/users', [UserController::class, 'index'])->name('users.index');
});
