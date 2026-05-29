class FeedbackUserModel {
  const FeedbackUserModel({
    required this.id,
    required this.name,
    this.avatar,
  });

  final int id;
  final String name;
  final String? avatar;

  factory FeedbackUserModel.fromJson(Map<String, dynamic> json) {
    return FeedbackUserModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
  };
}

class FeedbackModel {
  const FeedbackModel({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.user,
  });

  final int id;
  final int rating;
  final String comment;
  final DateTime? createdAt;
  final FeedbackUserModel user;

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: _parseInt(json['id']),
      rating: _parseInt(json['rating']),
      comment: json['comment']?.toString() ?? '',
      createdAt: _parseDateTime(json['createdAt']),
      user: FeedbackUserModel.fromJson(
        Map<String, dynamic>.from(json['user'] ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt?.toIso8601String(),
    'user': user.toJson(),
  };
}

class ComboServiceServiceModel {
  const ComboServiceServiceModel({
    required this.id,
    required this.name,
    required this.status,
    required this.price,
    this.description,
  });

  final int id;
  final String name;
  final String status;
  final double price;
  final String? description;

  factory ComboServiceServiceModel.fromJson(Map<String, dynamic> json) {
    return ComboServiceServiceModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      price: _parseDouble(json['price']),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status,
    'price': price,
    'description': description,
  };
}

class ComboServiceModel {
  const ComboServiceModel({
    required this.comboId,
    required this.serviceId,
    required this.createdAt,
    required this.service,
  });

  final int comboId;
  final int serviceId;
  final DateTime? createdAt;
  final ComboServiceServiceModel service;

  factory ComboServiceModel.fromJson(Map<String, dynamic> json) {
    return ComboServiceModel(
      comboId: _parseInt(json['comboId']),
      serviceId: _parseInt(json['serviceId']),
      createdAt: _parseDateTime(json['createdAt']),
      service: ComboServiceServiceModel.fromJson(
        Map<String, dynamic>.from(json['service'] ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'comboId': comboId,
    'serviceId': serviceId,
    'createdAt': createdAt?.toIso8601String(),
    'service': service.toJson(),
  };
}

class ComboModel {
  const ComboModel({
    required this.id,
    required this.roomTypeId,
    required this.name,
    required this.discountValue,
    required this.maxDiscountAmount,
    required this.minStayNights,
    required this.isActive,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.comboServices,
  });

  final int id;
  final int roomTypeId;
  final String name;
  final double discountValue;
  final double maxDiscountAmount;
  final int minStayNights;
  final int isActive;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ComboServiceModel> comboServices;

  factory ComboModel.fromJson(Map<String, dynamic> json) {
    final comboServicesJson = json['comboServices'];
    final parsedComboServices = comboServicesJson is List
        ? comboServicesJson
            .whereType<Map>()
            .map((item) => ComboServiceModel.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <ComboServiceModel>[];

    return ComboModel(
      id: _parseInt(json['id']),
      roomTypeId: _parseInt(json['roomTypeId']),
      name: json['name']?.toString() ?? '',
      discountValue: _parseDouble(json['discountValue']),
      maxDiscountAmount: _parseDouble(json['maxDiscountAmount']),
      minStayNights: _parseInt(json['minStayNights']),
      isActive: _parseInt(json['isActive']),
      description: json['description']?.toString(),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      comboServices: parsedComboServices,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roomTypeId': roomTypeId,
    'name': name,
    'discountValue': discountValue,
    'maxDiscountAmount': maxDiscountAmount,
    'minStayNights': minStayNights,
    'isActive': isActive,
    'description': description,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'comboServices': comboServices.map((item) => item.toJson()).toList(),
  };
}

class GetFeedbackRequest {
  const GetFeedbackRequest({
    this.targetType = 'room',
    required this.targetId,
    required this.page,
    required this.limit,
  });

  final String targetType;
  final int targetId;
  final int page;
  final int limit;

  Map<String, dynamic> toJson() => {
    'targetType': targetType,
    'targetId': targetId,
    'page': page,
    'limit': limit,
  };
}

class FeedbackPaginatedResponse {
  const FeedbackPaginatedResponse({
    required this.items,
    required this.total,
  });

  final List<FeedbackModel> items;
  final int total;

  factory FeedbackPaginatedResponse.fromApiData(dynamic data) {
    if (data is List) {
      final rawItems = data.isNotEmpty && data[0] is List ? data[0] as List : <dynamic>[];
      final rawTotal = data.length > 1 ? data[1] : rawItems.length;

      return FeedbackPaginatedResponse(
        items: rawItems
            .whereType<Map>()
            .map((item) => FeedbackModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        total: _parseInt(rawTotal),
      );
    }

    if (data is Map<String, dynamic>) {
      final rawItems = data['items'];
      final rawTotal = data['total'];

      return FeedbackPaginatedResponse(
        items: rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((item) => FeedbackModel.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : <FeedbackModel>[],
        total: _parseInt(rawTotal),
      );
    }

    return const FeedbackPaginatedResponse(items: [], total: 0);
  }
}

class ComboPaginatedResponse {
  const ComboPaginatedResponse({
    required this.items,
    required this.total,
  });

  final List<ComboModel> items;
  final int total;

  factory ComboPaginatedResponse.fromApiData(dynamic data) {
    if (data is List) {
      final rawItems = data.isNotEmpty && data[0] is List ? data[0] as List : <dynamic>[];
      final rawTotal = data.length > 1 ? data[1] : rawItems.length;

      return ComboPaginatedResponse(
        items: rawItems
            .whereType<Map>()
            .map((item) => ComboModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        total: _parseInt(rawTotal),
      );
    }

    if (data is Map<String, dynamic>) {
      final rawItems = data['items'];
      final rawTotal = data['total'];

      return ComboPaginatedResponse(
        items: rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((item) => ComboModel.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : <ComboModel>[],
        total: _parseInt(rawTotal),
      );
    }

    return const ComboPaginatedResponse(items: [], total: 0);
  }
}

int _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}

double _parseDouble(dynamic value) {
  if (value is double) {
    return value;
  }

  if (value is int) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }

  return 0.0;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}
