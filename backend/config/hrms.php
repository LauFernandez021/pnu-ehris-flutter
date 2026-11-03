<?php

return [
    // Leave empty to allow registration without a code.
    'registration_code' => env('REGISTRATION_CODE'),

    'app' => [
        'latest' => env('APP_LATEST_VERSION', '0.1.0'),
        'minimum' => env('APP_MIN_VERSION', '0.1.0'),
        'apk_url' => env('APP_APK_URL'),
        'notes' => env('APP_RELEASE_NOTES', ''),
        'desktop_latest' => env('DESKTOP_LATEST_VERSION', '0.1.0'),
        'desktop_minimum' => env('DESKTOP_MIN_VERSION', '0.1.0'),
        'desktop_url' => env('DESKTOP_INSTALLER_URL'),
    ],

    'zkteco_adms' => [
        'enabled' => env('ZKTECO_ADMS_ENABLED', false),
        'device_serials' => array_values(array_filter(array_map(
            'trim',
            explode(',', (string) env('ZKTECO_ADMS_DEVICE_SERIALS', ''))
        ))),
        'allowed_ips' => array_values(array_filter(array_map(
            'trim',
            explode(',', (string) env('ZKTECO_ADMS_ALLOWED_IPS', ''))
        ))),
        'max_payload_bytes' => (int) env('ZKTECO_ADMS_MAX_PAYLOAD_BYTES', 65536),
        'max_records_per_request' => (int) env('ZKTECO_ADMS_MAX_RECORDS', 500),
    ],
];
