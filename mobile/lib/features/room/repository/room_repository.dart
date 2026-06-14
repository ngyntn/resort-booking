import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/room/models/room_model.dart';

class RoomRepositoryException implements Exception {
  const RoomRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class RoomRepository {
  RoomRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<RoomPaginatedResponse> getRooms(GetRoomsRequest request) async {
    try {
      final response = await _apiClient.get('/room', queryParameters: request.toJson());

      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const RoomRepositoryException(
          'Unexpected room response format.',
        );
      }

      if (payload['isSuccess'] == false) {
        final errorPayload = payload['error'];
        final message = errorPayload is Map<String, dynamic>
            ? errorPayload['message']?.toString()
            : errorPayload?.toString();

        throw RoomRepositoryException(
          message ?? 'Failed to load rooms.',
          statusCode: payload['statusCode'] as int?,
        );
      }

      final data = payload['data'];
      return RoomPaginatedResponse.fromApiData(data);
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = _extractErrorMessage(responseData) ?? 'Failed to load rooms.';

      throw RoomRepositoryException(
        message,
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<List<RoomTypeModel>> getRoomTypes() async {
    try {
      final response = await _apiClient.get('/room-type');
      final payload = response.data;
      if (payload is! Map<String, dynamic>) return [];
      final data = payload['data'];
      List raw = [];
      if (data is List) {
        raw = data.isNotEmpty && data[0] is List ? data[0] as List : data;
      } else if (data is Map<String, dynamic>) {
        raw = data['items'] is List ? data['items'] as List : [];
      }
      return raw.whereType<Map>()
          .map((e) => RoomTypeModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
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
