import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/models/auth_model.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

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

      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const AuthException('Unexpected authentication response format.');
      }

      if (payload['isSuccess'] == false) {
        final errorPayload = payload['error'];
        final message = errorPayload is Map<String, dynamic>
            ? errorPayload['message']?.toString()
            : errorPayload?.toString();
        throw AuthException(
          message ?? 'Authentication failed.',
          statusCode: payload['statusCode'] as int?,
        );
      }

      final data = payload['data'];
      if (data is! Map<String, dynamic>) {
        throw const AuthException(
          'Authentication response did not include token data.',
        );
      }

      final tokens = AuthTokens.fromJson(data);
      if (tokens.accessToken.isEmpty || tokens.refreshToken.isEmpty) {
        throw const AuthException(
          'Authentication response was missing tokens.',
        );
      }

      await _apiClient.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      return AuthSession(tokens: tokens);
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message =
          _extractErrorMessage(responseData) ??
          'Sign in failed. Please try again.';
      throw AuthException(message, statusCode: error.response?.statusCode);
    }
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is! Map<String, dynamic>) {
      return null;
    }

    final errorData = responseData['error'];
    if (errorData is Map<String, dynamic>) {
      return errorData['message']?.toString();
    }

    if (errorData is String) {
      return errorData;
    }

    return responseData['message']?.toString();
  }
}
