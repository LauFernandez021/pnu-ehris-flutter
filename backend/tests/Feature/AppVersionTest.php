<?php

namespace Tests\Feature;

use Tests\TestCase;

class AppVersionTest extends TestCase
{
    public function test_app_version_is_public_and_returns_mobile_and_desktop_versions(): void
    {
        config()->set('hrms.app', [
            'latest' => '1.2.3',
            'minimum' => '1.0.0',
            'apk_url' => 'https://example.test/downloads/hrms-1.2.3.apk',
            'notes' => 'Bug fixes',
            'desktop_latest' => '2.3.4',
            'desktop_minimum' => '2.0.0',
            'desktop_url' => 'https://example.test/downloads/admin-2.3.4.exe',
        ]);

        $this->getJson('/api/app-version')
            ->assertOk()
            ->assertExactJson([
                'latest' => '1.2.3',
                'minimum' => '1.0.0',
                'apk_url' => 'https://example.test/downloads/hrms-1.2.3.apk',
                'notes' => 'Bug fixes',
                'desktop_latest' => '2.3.4',
                'desktop_minimum' => '2.0.0',
                'desktop_url' => 'https://example.test/downloads/admin-2.3.4.exe',
            ]);
    }
}
