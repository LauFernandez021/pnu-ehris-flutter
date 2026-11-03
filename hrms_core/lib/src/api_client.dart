import 'package:dio/dio.dart';

import 'dart:typed_data';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required String baseUrl, this.tokenProvider})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenProvider?.call();
          if (token != null && !options.headers.containsKey('Authorization')) {
            options.headers['Authorization'] = 'Bearer ' + token;
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final Future<String?> Function()? tokenProvider;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _send(() => dio.get(path, queryParameters: query));
      } on ApiException catch (e) {
        // No status code means the request never got an answer (timeout,
        // dropped connection). Try once more, then give up.
        if (e.statusCode != null || attempt >= 2) rethrow;
      }
    }
  }

  /// Downloads a protected file (photo, attachment) with the login token.
  Future<Uint8List> getBytes(String path) async {
    try {
      final response = await dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? headers,
  }) => _send(
    () => dio.post(
      path,
      data: data,
      options: Options(headers: headers),
    ),
  );
  Future<dynamic> put(String path, {Object? data}) =>
      _send(() => dio.put(path, data: data));
  Future<dynamic> delete(String path) => _send(() => dio.delete(path));
  Future<dynamic> _send(Future<Response> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return ApiException(first.first.toString(), status);
        }
      }
      if (data['message'] != null) {
        return ApiException(data['message'].toString(), status);
      }
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException('Cannot reach the server. Is the API running?');
    }
    return ApiException('Request failed', status);
  }
}
