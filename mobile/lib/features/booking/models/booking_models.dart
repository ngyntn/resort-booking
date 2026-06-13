import 'package:flutter/material.dart';

class VoucherModel {
  const VoucherModel({
    required this.id,
    required this.voucherId,
    required this.name,
    required this.discountType,
    required this.discountValue,
    required this.maxDiscountAmount,
    required this.minBookingAmount,
    this.expiredAt,
    this.isUsed = false,
  });

  final int id;
  final int voucherId;
  final String name;
  final String discountType;
  final double discountValue;
  final double maxDiscountAmount;
  final double minBookingAmount;
  final String? expiredAt;
  final bool isUsed;

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    final v = json['voucher'] is Map<String, dynamic>
        ? json['voucher'] as Map<String, dynamic>
        : json;
    return VoucherModel(
      id: _parseInt(json['id']),
      voucherId: _parseInt(v['id'] ?? json['voucherId'] ?? 0),
      name: v['name']?.toString() ?? '',
      discountType: v['discountType']?.toString() ?? 'percentage',
      discountValue: _parseDouble(v['discountValue']),
      maxDiscountAmount: _parseDouble(v['maxDiscountAmount']),
      minBookingAmount: _parseDouble(v['minBookingAmount']),
      expiredAt: json['expiredAt']?.toString(),
      isUsed: json['isUsed'] == true || json['isUsed'] == 1,
    );
  }

  String get displayDiscount => discountType == 'percentage'
      ? '${discountValue.toStringAsFixed(0)}% off'
      : '-${_fmt(discountValue)}đ';
}

class BookingServiceModel {
  const BookingServiceModel({
    required this.id,
    this.serviceName,
    this.servicePrice,
    required this.quantity,
    this.startDate,
    this.endDate,
    required this.status,
  });

  final int id;
  final String? serviceName;
  final double? servicePrice;
  final int quantity;
  final String? startDate;
  final String? endDate;
  final String status;

  factory BookingServiceModel.fromJson(Map<String, dynamic> json) {
    final svc = json['service'] is Map<String, dynamic>
        ? json['service'] as Map<String, dynamic>
        : <String, dynamic>{};
    return BookingServiceModel(
      id: _parseInt(json['id']),
      serviceName: svc['name']?.toString() ?? json['serviceName']?.toString(),
      servicePrice: _parseDouble(svc['price'] ?? json['servicePrice']),
      quantity: _parseInt(json['quantity'] ?? 1),
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class BookingModel {
  const BookingModel({
    required this.id,
    required this.roomId,
    this.roomNumber,
    this.roomTypeName,
    this.roomImage,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalPrice,
    required this.capacity,
    this.contractPath,
    this.isPaid = false,
    this.comboId,
    this.userVoucherId,
    required this.createdAt,
    this.bookingServices = const [],
  });

  final int id;
  final int roomId;
  final String? roomNumber;
  final String? roomTypeName;
  final String? roomImage;
  final String startDate;
  final String endDate;
  final String status;
  final double totalPrice;
  final int capacity;
  final String? contractPath;
  final bool isPaid;
  final int? comboId;
  final int? userVoucherId;
  final String createdAt;
  final List<BookingServiceModel> bookingServices;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final room = json['room'] is Map<String, dynamic>
        ? json['room'] as Map<String, dynamic>
        : <String, dynamic>{};
    final roomType = room['type'] is Map<String, dynamic>
        ? room['type'] as Map<String, dynamic>
        : <String, dynamic>{};
    final media = room['media'] is List ? room['media'] as List : [];
    final String? firstImage = media.isNotEmpty && media.first is Map
        ? (media.first as Map)['path']?.toString()
        : null;

    final svcsRaw = json['bookingServices'];
    final svcs = svcsRaw is List
        ? svcsRaw
            .whereType<Map>()
            .map((e) => BookingServiceModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <BookingServiceModel>[];

    return BookingModel(
      id: _parseInt(json['id']),
      roomId: _parseInt(json['roomId'] ?? room['id'] ?? 0),
      roomNumber: room['roomNumber']?.toString() ?? json['roomNumber']?.toString(),
      roomTypeName: roomType['name']?.toString(),
      roomImage: firstImage,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      totalPrice: _parseDouble(json['totalPrice']),
      capacity: _parseInt(json['capacity'] ?? 1),
      contractPath: json['contractPath']?.toString(),
      isPaid: json['isPaid'] == true || json['isPaid'] == 1,
      comboId: json['comboId'] is int ? json['comboId'] as int : null,
      userVoucherId: json['userVoucherId'] is int ? json['userVoucherId'] as int : null,
      createdAt: json['createdAt']?.toString() ?? '',
      bookingServices: svcs,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Chờ xác nhận';
      case 'confirmed': return 'Đã xác nhận';
      case 'rejected': return 'Từ chối';
      case 'cancelled': return 'Đã huỷ';
      case 'checkout': return 'Đã trả phòng';
      default: return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'confirmed': return const Color(0xFF10B981);
      case 'rejected': return const Color(0xFFEF4444);
      case 'cancelled': return const Color(0xFF94A3B8);
      case 'checkout': return const Color(0xFF6366F1);
      default: return const Color(0xFF94A3B8);
    }
  }
}

class CreateBookingRequest {
  const CreateBookingRequest({
    required this.roomId,
    required this.startDate,
    required this.endDate,
    required this.capacity,
    this.userVoucherId,
    this.comboId,
  });

  final int roomId;
  final String startDate;
  final String endDate;
  final int capacity;
  final int? userVoucherId;
  final int? comboId;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'roomId': roomId,
      'startDate': startDate,
      'endDate': endDate,
      'capacity': capacity,
    };
    if (userVoucherId != null) m['userVoucherId'] = userVoucherId;
    if (comboId != null) m['comboId'] = comboId;
    return m;
  }
}

class ReceiptModel {
  const ReceiptModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.paymentStatus,
    this.paymentUrl,
    required this.createdAt,
  });

  final int id;
  final double amount;
  final String type;
  final String paymentStatus;
  final String? paymentUrl;
  final String createdAt;

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    return ReceiptModel(
      id: _parseInt(json['id']),
      amount: _parseDouble(json['amount']),
      type: json['type']?.toString() ?? '',
      paymentStatus: json['paymentStatus']?.toString() ?? '',
      paymentUrl: json['paymentUrl']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

String _fmt(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

int _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _parseDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}
