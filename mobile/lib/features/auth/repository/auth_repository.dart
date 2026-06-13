import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/models/auth_model.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/sign-in',
        data: {'email': email.trim(), 'password': password},
      );

      final payload = _requireSuccess(response.data);
      final tokens = AuthTokens.fromJson(payload['data'] as Map<String, dynamic>);

      if (tokens.accessToken.isEmpty || tokens.refreshToken.isEmpty) {
        throw const AuthException('Authentication response was missing tokens.');
      }

      await _apiClient.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      return AuthSession(tokens: tokens);
    } on DioException catch (e) {
      throw AuthException(_extractError(e.response?.data) ?? 'Sign in failed.');
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String cccd,
    required String dob,
    required String gender,
    required String identityIssuedAt,
    required String identityIssuedPlace,
    required String permanentAddress,
  }) async {
    try {
      final response = await _apiClient.post('/auth/sign-up', data: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'phone': phone.trim(),
        'cccd': cccd.trim(),
        'dob': dob,
        'gender': gender,
        'identityIssuedAt': identityIssuedAt,
        'identityIssuedPlace': identityIssuedPlace.trim(),
        'permanentAddress': permanentAddress.trim(),
      });
      _requireSuccess(response.data);
    } on DioException catch (e) {
      throw AuthException(_extractError(e.response?.data) ?? 'Sign up failed.');
    }
  }

  Future<void> sendOtp(String email) async {
    try {
      final response = await _apiClient.post(
        '/auth/send-otp',
        data: {'email': email.trim()},
      );
      _requireSuccess(response.data);
    } on DioException catch (e) {
      throw AuthException(_extractError(e.response?.data) ?? 'Failed to send OTP.');
    }
  }

  Future<void> verifyAccount({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _apiClient.post('/auth/verify-account', data: {
        'email': email.trim(),
        'otp': otp.trim(),
      });
      _requireSuccess(response.data);
    } on DioException catch (e) {
      throw AuthException(_extractError(e.response?.data) ?? 'OTP verification failed.');
    }
  }

  Future<String> verifyForgotPassword({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _apiClient.post('/auth/verify-forgot-password', data: {
        'email': email.trim(),
        'otp': otp.trim(),
      });
      final payload = _requireSuccess(response.data);
      final code = payload['data']?['code'] as String?;
      if (code == null || code.isEmpty) {
        throw const AuthException('Invalid reset code received.');
      }
      return code;
    } on DioException catch (e) {
      throw AuthException(_extractError(e.response?.data) ?? 'OTP verification failed.');
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    try {
      final response = await _apiClient.put('/auth/reset-password', data: {
        'email': email.trim(),
        'code': code,
        'password': password,
      });
      _requireSuccess(response.data);
    } on DioException catch (e) {
      throw AuthException(_extractError(e.response?.data) ?? 'Password reset failed.');
    }
  }

  Future<void> signOut() async {
    try {
      final accessToken = await _apiClient.getAccessToken();
      final refreshToken = await _apiClient.getRefreshToken();
      if (accessToken != null && refreshToken != null) {
        await _apiClient.post('/auth/sign-out', data: {
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        });
      }
    } catch (_) {
      // Always clear local tokens regardless of API result
    } finally {
      await _apiClient.clearTokens();
    }
  }

  Map<String, dynamic> _requireSuccess(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      throw const AuthException('Unexpected response format.');
    }
    if (payload['isSuccess'] == false) {
      final err = payload['error'];
      final msg = err is Map ? err['message']?.toString() : err?.toString();
      throw AuthException(msg ?? 'Request failed.');
    }
    return payload;
  }

  String? _extractError(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final err = data['error'];
    if (err is Map<String, dynamic>) return err['message']?.toString();
    if (err is String) return err;
    return data['message']?.toString();
  }
}
