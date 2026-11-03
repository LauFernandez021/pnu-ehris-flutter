<p align="center"><a href="https://laravel.com" target="_blank"><img src="https://raw.githubusercontent.com/laravel/art/master/logo-lockup/5%20SVG/2%20CMYK/1%20Full%20Color/laravel-logolockup-cmyk-red.svg" width="400" alt="Laravel Logo"></a></p>

<p align="center">
<a href="https://github.com/laravel/framework/actions"><img src="https://github.com/laravel/framework/workflows/tests/badge.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/dt/laravel/framework" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/v/laravel/framework" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/l/laravel/framework" alt="License"></a>
</p>

## About Laravel

Laravel is a web application framework with expressive, elegant syntax. We believe development must be an enjoyable and creative experience to be truly fulfilling. Laravel takes the pain out of development by easing common tasks used in many web projects, such as:

- [Simple, fast routing engine](https://laravel.com/docs/routing).
- [Powerful dependency injection container](https://laravel.com/docs/container).
- Multiple back-ends for [session](https://laravel.com/docs/session) and [cache](https://laravel.com/docs/cache) storage.
- Expressive, intuitive [database ORM](https://laravel.com/docs/eloquent).
- Database agnostic [schema migrations](https://laravel.com/docs/migrations).
- [Robust background job processing](https://laravel.com/docs/queues).
- [Real-time event broadcasting](https://laravel.com/docs/broadcasting).

Laravel is accessible, powerful, and provides tools required for large, robust applications.

## ZKTeco UA760 ADMS (staged receiver)

The ADMS receiver accepts the text/ATTLOG format observed from the supplied CakePHP integration example. It is disabled by default. Before enabling it in production:

1. Deploy the API behind HTTPS with a valid certificate and configure the terminal to use that public server.
2. Restrict `/iclock` at the firewall or reverse proxy to a static device egress IP. The application independently checks the socket peer (`REMOTE_ADDR`) against `ZKTECO_ADMS_ALLOWED_IPS`; forwarded IP headers are not used. If a reverse proxy is in front, enforce the device source-IP rule at that proxy/firewall too—allowing only the proxy IP in the application is not sufficient by itself.
3. Configure the exact terminal serial in `ZKTECO_ADMS_DEVICE_SERIALS` and allowed source IP(s), then set `ZKTECO_ADMS_ENABLED=true`.
4. Run `php artisan migrate --force`, then clear cached configuration with `php artisan config:cache`.
5. Set the terminal's user PIN to match the employee `device_user_id` exactly. Do not use the printed badge number or RFID card UID for this mapping.
6. Configure the device server address/path according to its firmware documentation. The receiver accepts `/iclock`, `/iclock/cdata`, `/iclock/getrequest`, and `/iclock/devicecmd`; confirm the exact UA760 firmware 8.04 URL and port before connection.

The receiver stores deduplicated raw ATTLOG events and acknowledges a batch only after persistence. It answers the candidate handshake with `ATTLOGStamp=0` so it does not skip unseen out-of-order punches; the terminal may replay its stored history, which is deduplicated by device and record. Unmatched device PINs are retained for review. The admin/HR `Device logs` screen is read-only: incoming events do not change attendance records or DTR snapshots until punch-state semantics and AM/PM/overtime mapping have been verified for this device. Firewall/IP restriction is required because the terminal protocol demonstrated so far has no verified per-device authentication mechanism; a serial number alone is not authentication.

## Learning Laravel

Laravel has the most extensive and thorough [documentation](https://laravel.com/docs) and video tutorial library of all modern web application frameworks, making it a breeze to get started with the framework.

In addition, [Laracasts](https://laracasts.com) contains thousands of video tutorials on a range of topics including Laravel, modern PHP, unit testing, and JavaScript. Boost your skills by digging into our comprehensive video library.

You can also watch bite-sized lessons with real-world projects on [Laravel Learn](https://laravel.com/learn), where you will be guided through building a Laravel application from scratch while learning PHP fundamentals.

## Agentic Development

Laravel's predictable structure and conventions make it ideal for AI coding agents like Claude Code, Cursor, and GitHub Copilot. Install [Laravel Boost](https://laravel.com/docs/ai) to supercharge your AI workflow:

```bash
composer require laravel/boost --dev

php artisan boost:install
```

Boost provides your agent 15+ tools and skills that help agents build Laravel applications while following best practices.

## Contributing

Thank you for considering contributing to the Laravel framework! The contribution guide can be found in the [Laravel documentation](https://laravel.com/docs/contributions).

## Code of Conduct

In order to ensure that the Laravel community is welcoming to all, please review and abide by the [Code of Conduct](https://laravel.com/docs/contributions#code-of-conduct).

## Security Vulnerabilities

If you discover a security vulnerability within Laravel, please send an e-mail to Taylor Otwell via [taylor@laravel.com](mailto:taylor@laravel.com). All security vulnerabilities will be promptly addressed.

## License

The Laravel framework is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
