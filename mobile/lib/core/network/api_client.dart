import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/constants/api_constants.dart';

class ApiClient {
  ApiClient._internal()
    : _dio = Dio(
        BaseOptions(
          baseUrl: kApiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          contentType: 'application/json',
          responseType: ResponseType.json,
        ),
      ) {
    _configureInterceptors();
  }

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isRefreshing = false;

  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // Set this callback to be notified when session expires
  static void Function()? onUnauthorized;

  Dio get dio => _dio;

  Future<String?> getAccessToken() => _secureStorage.read(key: _tokenKey);
  Future<String?> getRefreshToken() => _secureStorage.read(key: _refreshTokenKey);

  void _configureInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: _tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          developer.log('[REQ] ${options.method} ${options.uri}', name: 'API');
          handler.next(options);
        },
        onResponse: (response, handler) {
          developer.log(
            '[RES] ${response.statusCode} ${response.requestOptions.uri}',
            name: 'API',
          );
          handler.next(response);
        },
        onError: (DioException error, handler) async {
          developer.log(
            '[ERR] ${error.response?.statusCode} ${error.requestOptions.uri}',
            name: 'API',
          );

          if (error.response?.statusCode == 401 && !_isRefreshing) {
            _isRefreshing = true;
            try {
              final accessToken = await _secureStorage.read(key: _tokenKey);
              final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

              if (refreshToken == null || accessToken == null) {
                throw Exception('No tokens available');
              }

              // Use a fresh Dio to avoid interceptor loop
              final refreshDio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
              final res = await refreshDio.put(
                '/auth/refresh-token',
                data: {'accessToken': accessToken, 'refreshToken': refreshToken},
              );

              final data = res.data['data'] as Map<String, dynamic>;
              final newAccess = data['accessToken'] as String;
              final newRefresh = data['refreshToken'] as String;

              await saveTokens(accessToken: newAccess, refreshToken: newRefresh);

              // Retry original request with new token
              final retryOpts = error.requestOptions;
              retryOpts.headers['Authorization'] = 'Bearer $newAccess';
              final retryRes = await _dio.fetch(retryOpts);
              handler.resolve(retryRes);
              return;
            } catch (_) {
              await clearTokens();
              onUnauthorized?.call();
            } finally {
              _isRefreshing = false;
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _tokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<void> clearAccessToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _dio.get(
    path,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _dio.post(
    path,
    data: data,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _dio.put(
    path,
    data: data,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _dio.patch(
    path,
    data: data,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _dio.delete(
    path,
    data: data,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );
}
