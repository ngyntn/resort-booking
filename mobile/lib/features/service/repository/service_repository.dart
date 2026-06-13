import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/service/models/service_models.dart';

class ServiceException implements Exception {
  const ServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ServiceRepository {
  ServiceRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;

  Future<List<ServiceModel>> getServices({int page = 1, int limit = 20}) async {
    try {
      final res = await _api.get('/service', queryParameters: {'page': page, 'limit': limit});
      final payload = _check(res.data);
      final data = payload['data'];
      List raw = [];
      if (data is List) {
        raw = data.isNotEmpty && data[0] is List ? data[0] as List : data;
      } else if (data is Map<String, dynamic>) {
        raw = data['items'] is List ? data['items'] as List : [];
      }
      return raw.whereType<Map>()
          .map((e) => ServiceModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw ServiceException(_extractMsg(e.response?.data) ?? 'Không tải được dịch vụ.');
    }
  }

  Future<void> bookService(BookingServiceRequest req) async {
    try {
      final res = await _api.post('/booking/service', data: req.toJson());
      _check(res.data);
    } on DioException catch (e) {
      throw ServiceException(_extractMsg(e.response?.data) ?? 'Đặt dịch vụ thất bại.');
    }
  }

  Future<void> cancelBookingService(int bookingServiceId) async {
    try {
      final res = await _api.put('/booking/service/$bookingServiceId/cancel');
      _check(res.data);
    } on DioException catch (e) {
      throw ServiceException(_extractMsg(e.response?.data) ?? 'Huỷ dịch vụ thất bại.');
    }
  }

  Map<String, dynamic> _check(dynamic payload) {
    if (payload is! Map<String, dynamic>) throw const ServiceException('Phản hồi không hợp lệ.');
    if (payload['isSuccess'] == false) {
      final err = payload['error'];
      final msg = err is Map ? err['message']?.toString() : err?.toString();
      throw ServiceException(msg ?? 'Yêu cầu thất bại.');
    }
    return payload;
  }

  String? _extractMsg(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final err = data['error'];
    if (err is Map<String, dynamic>) return err['message']?.toString();
    if (err is String) return err;
    return data['message']?.toString();
  }
}
