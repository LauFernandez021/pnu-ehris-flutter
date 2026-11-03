# HRMS

## Android release build

The permanent Android application ID is `com.kenneth.hrms`; keep it unchanged
for future updates.

From the `mobile_app` directory, build a release APK with:

```powershell
flutter build apk --release --obfuscate --split-debug-info=build/symbols --dart-define=API_URL=https://kenneth.mycreativepanda.com/hrms-api/api
```

Keep the generated `mobile_app/build/symbols` folder. It is required to decode
crash traces from this obfuscated build.

### Release signing

Generate the upload keystore once from PowerShell:

```powershell
keytool -genkey -v -keystore C:\keys\hrms-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias hrms
```

Create `mobile_app/android/key.properties` locally with the keystore values:

```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=hrms
storeFile=C:/keys/hrms-upload.jks
```

`key.properties` and `*.jks` are ignored by Git. Never commit or share them.
Keep the keystore and its passwords secure and use the same keystore for every
release; Android requires the same signing key to install updates over an
existing app. The release build fails with a configuration message if signing
details are missing.

## Admin password changes

Signed-in administrators and HR users can change their own password from
**Settings → Account security** in the desktop app. The API requires the current
password and a new password with at least 10 characters, uppercase, lowercase,
and a number. The current session remains active; other sessions for that user
are revoked.

Deploy the backend controller and `routes/api.php` changes before using this
feature with the live API. No database migration is needed. Since the API route
changed, clear the files in `backend/bootstrap/cache` except `.gitignore` after
uploading the backend files.

## Phase 4: password-change enforcement and audit logs

New employee accounts created by HR/admin and passwords reset for another
employee require a password change at next sign-in. The mobile and desktop apps
block access until that password is changed, and the API also rejects other
authenticated requests until the change is complete. Existing users are not
forced to change passwords by this update. Signed-in users can change their
password later from the mobile account menu or desktop **Settings → Account security**.

The admin desktop app has an **Audit logs** page. It is available only to
super-admins and shows filtered records for failed logins, employee
create/update/approve/reject/delete and verification-photo views, leave and
pass-slip approvals/rejections, and password changes.

Back up the live database before deployment. Apply the schema using exactly one
of these approaches:

- On a server where Artisan is available, upload the migration and run
  `php artisan migrate --force`.
- With SiteGround/phpMyAdmin, execute
  [`phase4_account_safety_audit.sql`](backend/database/manual_sql/phase4_account_safety_audit.sql)
  once against the HRMS database instead. Do not run both methods, because
  they create the same column and table.

Upload the backend and both updated app builds after applying the schema. Clear
the files in `backend/bootstrap/cache` except `.gitignore` after uploading the
backend routes/configuration. Failed-login audit entries do not contain the
submitted password.

## App update releases

The public API endpoint `GET /api/app-version` reads these values from the
backend `.env`:

```dotenv
APP_LATEST_VERSION=1.0.0
APP_MIN_VERSION=1.0.0
APP_APK_URL=https://kenneth.mycreativepanda.com/hrms-api/downloads/hrms-1.0.0.apk
APP_RELEASE_NOTES=
DESKTOP_LATEST_VERSION=1.0.0
DESKTOP_MIN_VERSION=1.0.0
DESKTOP_INSTALLER_URL=https://kenneth.mycreativepanda.com/hrms-api/downloads/HRMS-Admin-Setup-1.0.0.exe
```

The mobile app checks this endpoint on Android; the desktop app checks it on
Windows. An update prompt appears only when the platform's `latest` version is
newer than the installed version and its direct download URL is set. The
`minimum` version makes the prompt non-dismissible for older versions, so leave
it at the currently released version unless an update must be mandatory.

Upload APKs and Windows installers as plain static files under
`public_html/hrms-api/downloads/`. The version URL must point directly to the
file, not to a web preview page. The updater requires a higher latest version
than the installed version; increase a minimum version only when that platform
must install the update.

### Production update API verification

After uploading backend route/config changes and clearing the files in
`backend/bootstrap/cache` except `.gitignore`, test the public endpoint from
PowerShell:

```powershell
$api = 'https://kenneth.mycreativepanda.com/hrms-api/api'
$versions = Invoke-RestMethod "$api/app-version"
$versions | ConvertTo-Json -Depth 3
```

It should return HTTP 200 JSON with `latest`, `minimum`, `apk_url`, `notes`,
`desktop_latest`, `desktop_minimum`, and `desktop_url`. Before announcing an
update, verify each configured download URL points directly to its file and
returns HTTP 200; an HTML preview or a 404 will not install correctly. Test
with a device/PC that has an older version first, and only raise `minimum`
after the installer has been uploaded and verified.

For each release:

1. Update the version and build number in both `mobile_app/pubspec.yaml` and
   `desktop_admin/pubspec.yaml` (for example, `1.0.1+2`). The updater compares
   only the part before `+`.
2. Update `AppVersion` in `desktop_admin/installer.iss` to the desktop
   `pubspec.yaml` version.
3. Build the Android APK using the release command above and the same release
   keystore. Keep the corresponding `mobile_app/build/symbols` files.
4. Build the Windows app from `desktop_admin` with
   `flutter build windows --release --dart-define=API_URL=https://kenneth.mycreativepanda.com/hrms-api/api`,
   then compile `desktop_admin/installer.iss` with Inno Setup (`ISCC.exe`).
5. Name the files `hrms-<version>.apk` and
   `HRMS-Admin-Setup-<version>.exe`, then upload them to
   `public_html/hrms-api/downloads/`.
6. Set the `.env` values above to the new versions, direct download URLs, and
   release notes. Raise a minimum version only to force an update.
7. Clear files in `backend/bootstrap/cache` except `.gitignore` after changing
   routes or configuration, then open an older app to verify its update prompt.

Android always requires the user to confirm installation in the system
installer and may ask once to allow installs from HRMS. Windows starts the
downloaded installer silently and closes the old app; Inno Setup upgrades it
in place using the fixed `AppId` in `desktop_admin/installer.iss`.
