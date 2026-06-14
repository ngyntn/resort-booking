import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/booking/view/booking_confirmation_screen.dart';
import 'package:mobile/features/room/models/room_model.dart';
import 'package:mobile/features/room/repository/room_repository.dart';
import 'package:mobile/features/room/view/room_detail_screen.dart';
import 'package:mobile/features/room/view/widgets/room_card.dart';
import 'package:mobile/features/room/view/widgets/room_filter_card.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final RoomRepository _repository = RoomRepository();

  static const int _pageSize = 6;

  // Will be fetched from API; fallback to empty list
  List<RoomTypeModel> _roomTypes = const [];
  late GetRoomsRequest _filters;
  RoomPaginatedResponse? _response;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showFilter = false;
  // roomId → favoriteId (for initial heart state on each card)
  Map<int, int> _favoritesMap = {};

  @override
  void initState() {
    super.initState();
    _filters = const GetRoomsRequest(page: 1, limit: _pageSize);
    _loadRooms();
    _loadRoomTypes();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final res = await ApiClient().get('/user/favorite-room', queryParameters: {'page': 1, 'limit': 100});
      final payload = res.data;
      if (payload is! Map<String, dynamic>) return;
      final data = payload['data'];
      List raw = [];
      if (data is List) {
        raw = data.isNotEmpty && data[0] is List ? data[0] as List : data;
      } else if (data is Map<String, dynamic>) {
        raw = data['items'] is List ? data['items'] as List : [];
      }
      final map = <int, int>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final favId = _parseIntVal(item['id']);
        final room = item['room'];
        if (room is Map) {
          final roomId = _parseIntVal(room['id']);
          if (roomId > 0 && favId > 0) map[roomId] = favId;
        }
      }
      if (mounted) setState(() => _favoritesMap = map);
    } catch (_) {}
  }

  Future<void> _loadRoomTypes() async {
    try {
      final types = await _repository.getRoomTypes();
      if (mounted) setState(() => _roomTypes = types);
    } catch (_) {}
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _repository.getRooms(_filters);
      if (!mounted) return;
      setState(() {
        _response = response;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _updateFilters(GetRoomsRequest nextFilters) {
    setState(() {
      _filters = nextFilters;
      _showFilter = false;
    });
    _loadRooms();
  }

  void _clearFilters() {
    setState(() {
      _filters = const GetRoomsRequest(page: 1, limit: _pageSize);
      _showFilter = false;
    });
    _loadRooms();
  }

  void _goToPage(int nextPage) {
    setState(() {
      _filters = GetRoomsRequest(
        page: nextPage,
        limit: _filters.limit,
        keyword: _filters.keyword,
        typeId: _filters.typeId,
        maxPeople: _filters.maxPeople,
        priceRange: _filters.priceRange,
        dateRange: _filters.dateRange,
      );
    });
    _loadRooms();
  }

  bool get _hasActiveFilters =>
      _filters.keyword != null ||
      _filters.typeId != null ||
      _filters.maxPeople != null ||
      _filters.priceRange != null ||
      _filters.dateRange != null;

  @override
  Widget build(BuildContext context) {
    final rooms = _response?.items ?? const <RoomModel>[];
    final total = _response?.total ?? 0;
    final currentPage = _filters.page;
    final totalPages = total == 0 ? 1 : ((total - 1) ~/ _filters.limit) + 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Phòng'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: Icon(_showFilter ? Icons.filter_list_off : Icons.filter_list,
                    color: _showFilter ? const Color(0xFF0D584D) : null),
                tooltip: 'Bộ lọc',
                onPressed: () => setState(() => _showFilter = !_showFilter),
              ),
              if (_hasActiveFilters)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Collapsible filter
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _showFilter
                ? RoomFilterCard(
                    key: const ValueKey('filter'),
                    initialFilters: _filters,
                    roomTypes: _roomTypes,
                    onApply: _updateFilters,
                    onClear: _clearFilters,
                  )
                : const SizedBox.shrink(key: ValueKey('no-filter')),
          ),

          // Active filter chips (when filter hidden but filters active)
          if (!_showFilter && _hasActiveFilters)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(children: [
                const Icon(Icons.filter_alt, size: 14, color: Color(0xFF0D584D)),
                const SizedBox(width: 4),
                const Text('Đang lọc', style: TextStyle(fontSize: 12, color: Color(0xFF0D584D), fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: _clearFilters,
                  child: const Text('Xoá bộ lọc', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
                ),
              ]),
            ),

          // Room list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _ErrorState(message: _errorMessage!, onRetry: _loadRooms)
                    : rooms.isEmpty
                        ? const _EmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadRooms,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              itemCount: rooms.length,
                              itemBuilder: (context, index) {
                                final room = rooms[index];
                                return RoomCard(
                                  room: room,
                                  initialIsFavorite: _favoritesMap.containsKey(room.id),
                                  initialFavoriteId: _favoritesMap[room.id],
                                  onViewDetails: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room))),
                                  onBookRoom: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => BookingConfirmationScreen(room: room))),
                                );
                              },
                            ),
                          ),
          ),

          // Pagination
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: currentPage > 1 ? () => _goToPage(currentPage - 1) : null,
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Trước'),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$currentPage / $totalPages', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: currentPage < totalPages ? () => _goToPage(currentPage + 1) : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D584D), foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Tiếp'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

int _parseIntVal(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text('Không tải được phòng', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 16)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.king_bed_outlined, size: 48, color: Color(0xFF64748B)),
          SizedBox(height: 12),
          Text('Không có phòng phù hợp.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          SizedBox(height: 6),
          Text('Thử thay đổi bộ lọc tìm kiếm.', style: TextStyle(color: Color(0xFF64748B))),
        ]),
      ),
    );
  }
}
