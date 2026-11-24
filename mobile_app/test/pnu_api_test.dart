import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrms_core/hrms_core.dart';
import 'package:mobile_app/pnu_api.dart';

void main() {
  test('parses the PNU bearer login envelope', () async {
    final api = ApiClient(baseUrl: 'https://example.test/api');
    final token = List.filled(64, 'a').join();
    String? requestedPath;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestedPath = options.uri.path;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'response': {
                  'ok': true,
                  'data': {
                    'token': token,
                    'user': {'id': 42, 'name': 'Employee', 'email': ''},
                    'roles': ['employee'],
                  },
                },
              },
            ),
          );
        },
      ),
    );

    final result = await PnuAuthService(api)
        .login('employee', 'password', deviceName: 'test');

    expect(result.token, token);
    expect(result.roles, ['employee']);
    expect(result.user.id, 42);
    expect(requestedPath, '/api/mobile_auth/login');
  });

  test('maps PNU DTR times and worked hours to the mobile model', () async {
    final api = ApiClient(baseUrl: 'https://example.test/api');
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            data: {
              'response': {
                'ok': true,
                'data': [
                  {
                    'id': 7,
                    'code': 'DTR-7',
                    'period': 'first',
                    'transaction_date': '2026-01-16',
                    'start_date': '2026-01-01',
                    'end_date': '2026-01-15',
                    'employee': {
                      'id': 8,
                      'employee_number': 'EMP-8',
                      'name': 'Employee',
                    },
                    'entries': [
                      {
                        'date': '2026-01-05',
                        'attendanceRecord': 'present',
                        'hours_worked': '8',
                        'am_in': '08:00AM',
                        'am_out': '12:00PM',
                        'pm_in': '01:00PM',
                        'pm_out': '05:00PM',
                      },
                    ],
                  },
                ],
              },
            },
          ),
        ),
      ),
    );

    final records = await PnuAuthService(api).dtr();
    final entry = records.single.employees.single.entries.single;

    expect(records.single.payPeriod, 'first_cutoff');
    expect(entry.amInAt, DateTime(2026, 1, 5, 8));
    expect(entry.pmOutAt, DateTime(2026, 1, 5, 17));
    expect(entry.workedMinutes, 480);
  });

  test('loads and submits owner-scoped vehicle and locator requests', () async {
    final api = ApiClient(baseUrl: 'https://example.test/api');
    final requestedPaths = <String>[];
    dynamic submittedData;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestedPaths.add(options.uri.path);
          if (options.method == 'POST') {
            submittedData = options.data;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'response': {'ok': true, 'msg': 'Request submitted'},
                },
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'response': {
                  'ok': true,
                  'data': [
                    {
                      'id': 12,
                      'request_type': 'vehicle',
                      'control_no': 'VR-00012',
                      'purpose': 'Official travel',
                      'destination': 'Manila',
                      'date_needed': '2026-04-04',
                      'time_needed': '08:30AM',
                      'status': 'pending',
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final service = PnuAuthService(api);
    final requests = await service.serviceRequests();
    await service.submitServiceRequest({
      'request_type': 'locator',
      'date_needed': '2026-04-04',
      'time_needed': '08:30',
      'purpose': 'Official travel',
      'destination': 'Manila',
    });

    expect(requests.single.typeLabel, 'Vehicle request');
    expect(requests.single.dateNeeded, DateTime(2026, 4, 4));
    expect(requests.single.timeNeeded, '08:30AM');
    expect(requestedPaths, [
      '/api/mobile_service_requests',
      '/api/mobile_service_requests',
    ]);
    expect(submittedData['request_type'], 'locator');
  });

  test('loads and submits compensatory time-off requests', () async {
    final api = ApiClient(baseUrl: 'https://example.test/api');
    final requestedPaths = <String>[];
    dynamic submittedData;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestedPaths.add(options.uri.path);
          if (options.method == 'POST') {
            submittedData = options.data;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'response': {'ok': true, 'msg': 'Request submitted'},
                },
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'response': {
                  'ok': true,
                  'coc_balance': 12.5,
                  'data': [
                    {
                      'id': 3,
                      'control_no': 'CTO-00003',
                      'period_from': '2026-04-04',
                      'period_to': '2026-04-05',
                      'no_of_hours': 4,
                      'coc_balance': 12.5,
                      'balance_after': 8.5,
                      'status': 'pending',
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );

    final service = PnuAuthService(api);
    final summary = await service.compensatoryTimeOffs();
    await service.submitCompensatoryTimeOff({
      'period_from': '2026-04-04',
      'period_to': '2026-04-05',
      'no_of_hours': 4,
    });

    expect(summary.availableBalance, 12.5);
    expect(summary.requests.single.controlNumber, 'CTO-00003');
    expect(summary.requests.single.periodFrom, DateTime(2026, 4, 4));
    expect(summary.requests.single.balanceAfter, 8.5);
    expect(requestedPaths, [
      '/api/mobile_compensatory_time_offs',
      '/api/mobile_compensatory_time_offs',
    ]);
    expect(submittedData['no_of_hours'], 4);
  });

  test('preserves server validation messages for compensatory time-off', () {
    final api = ApiClient(baseUrl: 'https://example.test/api');
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 409,
              data: {
                'response': {
                  'ok': false,
                  'msg': 'Your available compensatory overtime credit is not enough for this request.',
                },
              },
            ),
          ),
        ),
      ),
    );

    expectLater(
      PnuAuthService(api).submitCompensatoryTimeOff({
        'period_from': '2026-04-04',
        'period_to': '2026-04-05',
        'no_of_hours': 4,
      }),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Your available compensatory overtime credit is not enough for this request.',
        ),
      ),
    );
  });
}
