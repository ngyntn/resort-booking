import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/booking/view/booking_confirmation_screen.dart';
import 'package:mobile/features/room/models/room_model.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Yêu thích'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF0D584D),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF0D584D),
          tabs: const [Tab(text: 'Phòng'), Tab(text: 'Dịch vụ')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_FavoriteRooms(), _FavoriteServices()],
      ),
    );
  }
}

class _FavoriteRooms extends StatefulWidget {
  const _FavoriteRooms();

  @override
  State<_FavoriteRooms> createState() => _FavoriteRoomsState();
}

class _FavoriteRoomsState extends State<_FavoriteRooms> with AutomaticKeepAliveClientMixin {
  final _api = ApiClient();
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  final Set<int> _removing = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/user/favorite-room', queryParameters: {'page': 1, 'limit': 100});
      final payload = res.data as Map<String, dynamic>;
      final data = payload['data'];
      List raw = [];
      if (data is List) {
        raw = data.isNotEmpty && data[0] is List ? data[0] as List : data;
      } else if (data is Map<String, dynamic>) {
        raw = data['items'] is List ? data['items'] as List : [];
      }
      if (mounted) setState(() {
        _items = raw.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(int favoriteId) async {
    setState(() => _removing.add(favoriteId));
    try {
      await _api.delete('/user/favorite-room/$favoriteId');
      if (mounted) {
        setState(() => _items.removeWhere((e) => e['id'] == favoriteId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xoá khỏi yêu thích.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _removing.remove(favoriteId));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.favorite_border, size: 48, color: Color(0xFF94A3B8)),
      SizedBox(height: 12),
      Text('Chưa có phòng yêu thích.', style: TextStyle(color: Color(0xFF64748B))),
    ]));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          final favId = _parseInt(item['id']);
          final room = item['room'] is Map<String, dynamic>
              ? item['room'] as Map<String, dynamic>
              : item;
          final roomModel = RoomModel.fromJson(room);
          final image = roomModel.media.isNotEmpty ? roomModel.media.first.path : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: image != null
                    ? Image.network(image, width: 100, height: 100, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 100, height: 100, child: Icon(Icons.hotel, color: Color(0xFF94A3B8))))
                    : const SizedBox(width: 100, height: 100, child: Icon(Icons.hotel, color: Color(0xFF94A3B8))),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Phòng ${roomModel.roomNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                    if (roomModel.type != null)
                      Text(roomModel.type!.name, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${_fmtPrice(roomModel.price)}đ/đêm',
                        style: const TextStyle(color: Color(0xFF0D584D), fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingConfirmationScreen(room: roomModel))),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D584D),
                            side: const BorderSide(color: Color(0xFF0D584D)),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: const Text('Đặt phòng'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _removing.contains(favId) ? null : () => _remove(favId),
                        icon: _removing.contains(favId)
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ]),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _FavoriteServices extends StatefulWidget {
  const _FavoriteServices();

  @override
  State<_FavoriteServices> createState() => _FavoriteServicesState();
}

class _FavoriteServicesState extends State<_FavoriteServices> with AutomaticKeepAliveClientMixin {
  final _api = ApiClient();
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  final Set<int> _removing = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/user/favorite-service', queryParameters: {'page': 1, 'limit': 100});
      final payload = res.data as Map<String, dynamic>;
      final data = payload['data'];
      List raw = [];
      if (data is List) {
        raw = data.isNotEmpty && data[0] is List ? data[0] as List : data;
      } else if (data is Map<String, dynamic>) {
        raw = data['items'] is List ? data['items'] as List : [];
      }
      if (mounted) setState(() {
        _items = raw.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(int favoriteId) async {
    setState(() => _removing.add(favoriteId));
    try {
      await _api.delete('/user/favorite-service/$favoriteId');
      if (mounted) {
        setState(() => _items.removeWhere((e) => e['id'] == favoriteId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xoá khỏi yêu thích.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _removing.remove(favoriteId));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.room_service_outlined, size: 48, color: Color(0xFF94A3B8)),
      SizedBox(height: 12),
      Text('Chưa có dịch vụ yêu thích.', style: TextStyle(color: Color(0xFF64748B))),
    ]));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          final favId = _parseInt(item['id']);
          final svc = item['service'] is Map<String, dynamic> ? item['service'] as Map<String, dynamic> : item;
          final name = svc['name']?.toString() ?? '';
          final price = _parseDouble(svc['price']);
          final desc = svc['description']?.toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: const Color(0xFF0D584D).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.room_service_outlined, color: Color(0xFF0D584D)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                if (desc != null) Text(desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${_fmtPrice(price)}đ', style: const TextStyle(color: Color(0xFF0D584D), fontWeight: FontWeight.w600, fontSize: 13)),
              ])),
              IconButton(
                onPressed: _removing.contains(favId) ? null : () => _remove(favId),
                icon: _removing.contains(favId)
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ]),
          );
        },
      ),
    );
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

String _fmtPrice(double v) {
  return v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
