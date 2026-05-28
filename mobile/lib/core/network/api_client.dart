import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Global API client for the mobile app.
///
/// Uses a singleton instance so API calls can be shared throughout the app.
/// The base URL targets the Android emulator's host machine through 10.0.2.2.
/// Backend is served under the Nest global prefix `api/v1`, so the mobile client
/// must target the full prefix on the emulator host.
class ApiClient {
  ApiClient._internal()
    : _dio = Dio(
        BaseOptions(
          baseUrl: kIsWeb ? 'http://localhost:8080/api/v1' : 'http://10.0.2.2:8080/api/v1',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          contentType: 'application/json',
          responseType: ResponseType.json,
        ),
      ) {
    _configureInterceptors();
  }

  static final ApiClient _instance = ApiClient._internal();

  /// Global access point for the singleton client.
  factory ApiClient() => _instance;

  final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _tokenKey = 'access_token';

  /// Exposes the configured Dio instance for advanced usage when needed.
  Dio get dio => _dio;

  void _configureInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: _tokenKey);

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          developer.log(
            '[API REQUEST] ${options.method} ${options.uri}',
            name: 'ApiClient',
          );

          handler.next(options);
        },
        onResponse: (response, handler) {
          developer.log(
            '[API RESPONSE] ${response.requestOptions.uri} | status: ${response.statusCode} | body: ${_formatBody(response.data)}',
            name: 'ApiClient',
          );

          handler.next(response);
        },
        onError: (DioException error, handler) {
          final responseBody = error.response?.data;

          developer.log(
            '[API ERROR] ${error.requestOptions.uri} | status: ${error.response?.statusCode} | body: ${_formatBody(responseBody)}',
            name: 'ApiClient',
          );

          handler.next(error);
        },
      ),
    );
  }

  /// Formats response payloads into compact JSON strings for debugging.
  String _formatBody(dynamic body) {
    if (body == null) {
      return 'null';
    }

    if (body is String) {
      return body;
    }

    try {
      return const JsonEncoder().convert(body);
    } catch (_) {
      return body.toString();
    }
  }

  static const String _refreshTokenKey = 'refresh_token';

  /// Saves both auth tokens securely so authenticated requests can continue.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _tokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Optional helper to save the access token securely.
  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  /// Optional helper to remove the stored access token.
  Future<void> clearAccessToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  /// Removes all auth-related stored credentials.
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  /// Standard GET wrapper.
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Standard POST wrapper.
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Standard PUT wrapper.
  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Standard PATCH wrapper.
  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Standard DELETE wrapper.
  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
