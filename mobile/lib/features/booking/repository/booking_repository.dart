import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/booking/models/booking_models.dart';

class BookingException implements Exception {
  const BookingException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BookingRepository {
  BookingRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;

  Future<List<BookingModel>> getBookings({String? status, int page = 1, int limit = 100}) async {
    try {
      // Backend validates status as an array; filter client-side to avoid issues
      final params = <String, dynamic>{'page': page, 'limit': limit};
      final res = await _api.get('/booking', queryParameters: params);
      final payload = _check(res.data);
      final data = payload['data'];
      List raw = [];
      if (data is List) {
        raw = data.isNotEmpty && data[0] is List ? data[0] as List : data;
      } else if (data is Map<String, dynamic>) {
        raw = data['items'] is List ? data['items'] as List : [];
      }
      final all = raw.whereType<Map>()
          .map((e) => BookingModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // Client-side filter by status
      if (status != null) return all.where((b) => b.status == status).toList();
      return all;
    } on DioException catch (e) {
      throw BookingException(_extractMsg(e.response?.data) ?? 'Không tải được danh sách booking.');
    }
  }

  Future<BookingModel> createBooking(CreateBookingRequest req) async {
    try {
      final res = await _api.post('/booking', data: req.toJson());
      final payload = _check(res.data);
      final data = payload['data'];
      if (data is Map<String, dynamic>) return BookingModel.fromJson(data);
      throw const BookingException('Phản hồi không hợp lệ.');
    } on DioException catch (e) {
      throw BookingException(_extractMsg(e.response?.data) ?? 'Đặt phòng thất bại.');
    }
  }

  Future<void> cancelBooking(int bookingId) async {
    try {
      final res = await _api.put('/booking/$bookingId/cancel-room-booking');
      _check(res.data);
    } on DioException catch (e) {
      throw BookingException(_extractMsg(e.response?.data) ?? 'Huỷ booking thất bại.');
    }
  }

  Future<void> signContract(int bookingId, String signatureUrl) async {
    try {
      final res = await _api.put('/booking/$bookingId/sign-contract', data: {'signatureUrl': signatureUrl});
      _check(res.data);
    } on DioException catch (e) {
      throw BookingException(_extractMsg(e.response?.data) ?? 'Ký hợp đồng thất bại.');
    }
  }

  Future<List<VoucherModel>> getUserVouchers() async {
    try {
      final res = await _api.get('/voucher/customer', queryParameters: {'page': 1, 'limit': 100});
      final payload = _check(res.data);
      final data = payload['data'];
      List raw = [];
      if (data is List) {
        raw = data.isNotEmpty && data[0] is List ? data[0] as List : data;
      } else if (data is Map<String, dynamic>) {
        raw = data['items'] is List ? data['items'] as List : [];
      }
      return raw.whereType<Map>()
          .map((e) => VoucherModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw BookingException(_extractMsg(e.response?.data) ?? 'Không tải được voucher.');
    }
  }

  Future<String?> payDeposit(int bookingId) async {
    try {
      final res = await _api.post('/payment/pay', data: {'bookingId': bookingId});
      final payload = _check(res.data);
      final data = payload['data'];
      if (data is Map<String, dynamic>) return data['paymentUrl']?.toString();
      return null;
    } on DioException catch (e) {
      throw BookingException(_extractMsg(e.response?.data) ?? 'Thanh toán thất bại.');
    }
  }

  Future<List<ReceiptModel>> getReceipts(int bookingId) async {
    try {
      final res = await _api.get('/payment/receipts', queryParameters: {'bookingId': bookingId});
      final payload = _check(res.data);
      final data = payload['data'];
      List raw = [];
      if (data is List) {
        raw = data.isNotEmpty && data[0] is List ? data[0] as List : data;
      } else if (data is Map<String, dynamic>) {
        raw = data['items'] is List ? data['items'] as List : [];
      }
      return raw.whereType<Map>()
          .map((e) => ReceiptModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw BookingException(_extractMsg(e.response?.data) ?? 'Không tải được receipts.');
    }
  }

  Future<String> uploadFile(Uint8List bytes, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await _api.post('/upload', data: formData,
          options: Options(contentType: 'multipart/form-data'));
      final payload = _check(res.data);
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return data['url']?.toString() ?? data['path']?.toString() ?? '';
      }
      if (data is String) return data;
      throw const BookingException('Upload failed: no URL returned.');
    } on DioException catch (e) {
      throw BookingException(_extractMsg(e.response?.data) ?? 'Upload thất bại.');
    }
  }

  Map<String, dynamic> _check(dynamic payload) {
    if (payload is! Map<String, dynamic>) throw const BookingException('Phản hồi không hợp lệ.');
    if (payload['isSuccess'] == false) {
      final err = payload['error'];
      final msg = err is Map ? err['message']?.toString() : err?.toString();
      throw BookingException(msg ?? 'Yêu cầu thất bại.');
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
