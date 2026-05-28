import 'package:flutter/material.dart';
import 'package:mobile/features/room/models/room_model.dart';
import 'package:mobile/features/room/repository/room_repository.dart';
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
  static const List<RoomTypeModel> _demoRoomTypes = [
    RoomTypeModel(id: 1, name: 'Ocean View', minPrice: 0, maxPrice: 0),
    RoomTypeModel(id: 2, name: 'Garden Suite', minPrice: 0, maxPrice: 0),
    RoomTypeModel(id: 3, name: 'Villa Retreat', minPrice: 0, maxPrice: 0),
  ];

  late GetRoomsRequest _filters;
  RoomPaginatedResponse? _response;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _filters = const GetRoomsRequest(page: 1, limit: _pageSize);
    _loadRooms();
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
    });
    _loadRooms();
  }

  void _clearFilters() {
    setState(() {
      _filters = const GetRoomsRequest(page: 1, limit: _pageSize);
    });
    _loadRooms();
  }

  void _goToPage(int nextPage) {
    final nextFilters = GetRoomsRequest(
      page: nextPage,
      limit: _filters.limit,
      keyword: _filters.keyword,
      typeId: _filters.typeId,
      maxPeople: _filters.maxPeople,
      priceRange: _filters.priceRange,
      dateRange: _filters.dateRange,
    );

    setState(() {
      _filters = nextFilters;
    });
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _response?.items ?? const <RoomModel>[];
    final total = _response?.total ?? 0;

    final currentPage = _filters.page;
    final totalPages = total == 0 ? 1 : ((total - 1) ~/ _filters.limit) + 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Rooms'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            RoomFilterCard(
              initialFilters: _filters,
              roomTypes: _demoRoomTypes,
              onApply: _updateFilters,
              onClear: _clearFilters,
            ),
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];

                          return RoomCard(
                            room: room,
                            onViewDetails: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Viewing details for room ${room.roomNumber}',
                                  ),
                                ),
                              );
                            },
                            onBookRoom: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Booking room ${room.roomNumber}',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: currentPage > 1
                          ? () => _goToPage(currentPage - 1)
                          : null,
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Page $currentPage / $totalPages'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: currentPage < totalPages
                          ? () => _goToPage(currentPage + 1)
                          : null,
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'Failed to load rooms',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.king_bed_outlined, size: 40, color: Color(0xFF64748B)),
            SizedBox(height: 12),
            Text(
              'No rooms match your filters yet.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Try adjusting the search or clearing filters.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
