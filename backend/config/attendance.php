<?php

return [
    'start_time' => env('ATTENDANCE_START_TIME', '08:00'),
    'end_time' => env('ATTENDANCE_END_TIME', '17:00'),
    'grace_minutes' => (int) env('ATTENDANCE_GRACE_MINUTES', 10),
];
