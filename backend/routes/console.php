<?php

use Illuminate\Support\Facades\Schedule;

Schedule::command('events:send-reminders')->everyFiveMinutes()->withoutOverlapping();
