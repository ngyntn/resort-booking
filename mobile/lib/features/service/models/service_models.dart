class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    required this.status,
  });

  final int id;
  final String name;
  final double price;
  final String? description;
  final String status;

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      price: _parseDouble(json['price']),
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'active',
    );
  }
}

class BookingServiceRequest {
  const BookingServiceRequest({
    required this.bookingId,
    required this.serviceId,
    required this.quantity,
    required this.startDate,
    this.endDate,
  });

  final int bookingId;
  final int serviceId;
  final int quantity;
  final String startDate;
  final String? endDate;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'bookingId': bookingId,
      'serviceId': serviceId,
      'quantity': quantity,
      'startDate': startDate,
    };
    if (endDate != null) m['endDate'] = endDate;
    return m;
  }
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
