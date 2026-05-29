import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/room/models/room_detail_models.dart';

class RoomDetailRepositoryException implements Exception {
  const RoomDetailRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class RoomDetailRepository {
  RoomDetailRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<FeedbackPaginatedResponse> getRoomFeedbacks(
    int roomId, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final request = GetFeedbackRequest(
        targetId: roomId,
        page: page,
        limit: limit,
      );

      final response = await _apiClient.get(
        '/feedback',
        queryParameters: request.toJson(),
      );

      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const RoomDetailRepositoryException(
          'Unexpected feedback response format.',
        );
      }

      if (payload['isSuccess'] == false) {
        final errorPayload = payload['error'];
        final message = errorPayload is Map<String, dynamic>
            ? errorPayload['message']?.toString()
            : errorPayload?.toString();

        throw RoomDetailRepositoryException(
          message ?? 'Failed to load room feedbacks.',
          statusCode: payload['statusCode'] as int?,
        );
      }

      final data = payload['data'];
      return FeedbackPaginatedResponse.fromApiData(data);
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = _extractErrorMessage(responseData) ?? 'Failed to load room feedbacks.';

      throw RoomDetailRepositoryException(
        message,
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<ComboPaginatedResponse> getCombos({
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.get(
        '/combo',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const RoomDetailRepositoryException(
          'Unexpected combo response format.',
        );
      }

      if (payload['isSuccess'] == false) {
        final errorPayload = payload['error'];
        final message = errorPayload is Map<String, dynamic>
            ? errorPayload['message']?.toString()
            : errorPayload?.toString();

        throw RoomDetailRepositoryException(
          message ?? 'Failed to load combos.',
          statusCode: payload['statusCode'] as int?,
        );
      }

      final data = payload['data'];
      return ComboPaginatedResponse.fromApiData(data);
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = _extractErrorMessage(responseData) ?? 'Failed to load combos.';

      throw RoomDetailRepositoryException(
        message,
        statusCode: error.response?.statusCode,
      );
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
