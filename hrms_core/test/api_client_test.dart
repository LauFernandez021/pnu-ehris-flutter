import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrms_core/hrms_core.dart';

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? requestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('sends a bearer token when one is available', () async {
    final adapter = _CapturingAdapter();
    final client = ApiClient(
      baseUrl: 'https://hrms.test/api',
      tokenProvider: () async => 'session-token',
    )..dio.httpClientAdapter = adapter;

    await client.get('/me/attendance');

    expect(
      adapter.requestOptions?.headers['Authorization'],
      'Bearer session-token',
    );
    client.dio.close();
  });

  test('omits authorization when no token is available', () async {
    final adapter = _CapturingAdapter();
    final client = ApiClient(
      baseUrl: 'https://hrms.test/api',
      tokenProvider: () async => null,
    )..dio.httpClientAdapter = adapter;

    await client.get('/me/attendance');

    expect(
      adapter.requestOptions?.headers.containsKey('Authorization'),
      isFalse,
    );
    client.dio.close();
  });

  test('uses the supplied bearer token for an explicit logout', () async {
    final adapter = _CapturingAdapter();
    final client = ApiClient(
      baseUrl: 'https://hrms.test/api',
      tokenProvider: () async => 'current-session-token',
    )..dio.httpClientAdapter = adapter;

    await AuthService(client).logout(token: 'one-off-token');

    expect(
      adapter.requestOptions?.headers['Authorization'],
      'Bearer one-off-token',
    );
    client.dio.close();
  });
}
