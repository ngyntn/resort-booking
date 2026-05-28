class RoomTypeModel {
  const RoomTypeModel({
    required this.id,
    required this.name,
    required this.minPrice,
    required this.maxPrice,
    this.description,
  });

  final int id;
  final String name;
  final double minPrice;
  final double maxPrice;
  final String? description;

  factory RoomTypeModel.fromJson(Map<String, dynamic> json) {
    return RoomTypeModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      minPrice: _parseDouble(json['minPrice']),
      maxPrice: _parseDouble(json['maxPrice']),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'description': description,
  };
}

class MediaModel {
  const MediaModel({
    required this.id,
    required this.path,
    this.roomId,
    this.comboId,
  });

  final int id;
  final String path;
  final int? roomId;
  final int? comboId;

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      id: _parseInt(json['id']),
      path: json['path']?.toString() ?? '',
      roomId: json['roomId'] is int ? json['roomId'] as int : null,
      comboId: json['comboId'] is int ? json['comboId'] as int : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'roomId': roomId,
    'comboId': comboId,
  };
}

class RoomModel {
  const RoomModel({
    required this.id,
    required this.roomNumber,
    required this.maxPeople,
    required this.price,
    required this.status,
    this.description,
    this.type,
    this.media = const [],
  });

  final int id;
  final String roomNumber;
  final int maxPeople;
  final double price;
  final String status;
  final String? description;
  final RoomTypeModel? type;
  final List<MediaModel> media;

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    final mediaJson = json['media'];
    final parsedMedia = mediaJson is List
        ? mediaJson
            .whereType<Map>()
            .map((item) => MediaModel.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <MediaModel>[];

    return RoomModel(
      id: _parseInt(json['id']),
      roomNumber: json['roomNumber']?.toString() ?? '',
      maxPeople: _parseInt(json['maxPeople']),
      price: _parseDouble(json['price']),
      status: json['status']?.toString() ?? '',
      description: json['description']?.toString(),
      type: json['type'] is Map<String, dynamic>
          ? RoomTypeModel.fromJson(Map<String, dynamic>.from(json['type']))
          : null,
      media: parsedMedia,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roomNumber': roomNumber,
    'maxPeople': maxPeople,
    'price': price,
    'status': status,
    'description': description,
    'type': type?.toJson(),
    'media': media.map((item) => item.toJson()).toList(),
  };
}

class PriceRangeQuery {
  const PriceRangeQuery({
    required this.minPrice,
    required this.maxPrice,
  });

  final String minPrice;
  final String maxPrice;

  Map<String, dynamic> toJson() => {
    'minPrice': minPrice,
    'maxPrice': maxPrice,
  };
}

class DateRangeQuery {
  const DateRangeQuery({
    required this.startDate,
    required this.endDate,
  });

  final String startDate;
  final String endDate;

  Map<String, dynamic> toJson() => {
    'startDate': startDate,
    'endDate': endDate,
  };
}

class GetRoomsRequest {
  const GetRoomsRequest({
    required this.page,
    required this.limit,
    this.keyword,
    this.typeId,
    this.maxPeople,
    this.priceRange,
    this.dateRange,
  });

  final int page;
  final int limit;
  final String? keyword;
  final int? typeId;
  final int? maxPeople;
  final PriceRangeQuery? priceRange;
  final DateRangeQuery? dateRange;

  Map<String, dynamic> toJson() {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (keyword != null && keyword!.isNotEmpty) {
      query['keyword'] = keyword;
    }

    if (typeId != null) {
      query['typeId'] = typeId;
    }

    if (maxPeople != null) {
      query['maxPeople'] = maxPeople;
    }

    if (priceRange != null) {
      query['priceRange'] = priceRange!.toJson();
    }

    if (dateRange != null) {
      query['dateRange'] = dateRange!.toJson();
    }

    return query;
  }
}

class RoomPaginatedResponse {
  const RoomPaginatedResponse({
    required this.items,
    required this.total,
  });

  final List<RoomModel> items;
  final int total;

  factory RoomPaginatedResponse.fromApiData(dynamic data) {
    if (data is List) {
      final rawItems = data.isNotEmpty && data[0] is List
          ? data[0] as List
          : <dynamic>[];
      final rawTotal = data.length > 1 ? data[1] : rawItems.length;

      return RoomPaginatedResponse(
        items: rawItems
            .whereType<Map>()
            .map((item) => RoomModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        total: _parseInt(rawTotal),
      );
    }

    if (data is Map<String, dynamic>) {
      final rawItems = data['items'];
      final rawTotal = data['total'];

      return RoomPaginatedResponse(
        items: rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((item) => RoomModel.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : <RoomModel>[],
        total: _parseInt(rawTotal),
      );
    }

    return const RoomPaginatedResponse(items: [], total: 0);
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
