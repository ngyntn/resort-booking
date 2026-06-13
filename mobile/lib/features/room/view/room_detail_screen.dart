import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/booking/view/booking_confirmation_screen.dart';
import 'package:mobile/features/room/models/room_detail_models.dart';
import 'package:mobile/features/room/models/room_model.dart';
import 'package:mobile/features/room/repository/room_detail_repository.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({super.key, required this.room});
  final RoomModel room;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _detailRepo = RoomDetailRepository();
  final _api = ApiClient();

  // Feedbacks
  List<FeedbackModel> _feedbacks = [];
  int _feedbackTotal = 0;
  bool _loadingFeedbacks = false;
  int _feedbackPage = 1;

  // Combos
  List<ComboModel> _combos = [];
  bool _loadingCombos = false;

  // Image page
  int _imgIndex = 0;

  // Favorite
  bool _isFavorite = false;
  int? _favoriteId;
  bool _togglingFav = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (_tab.index == 1 && _feedbacks.isEmpty && !_loadingFeedbacks) _loadFeedbacks();
      if (_tab.index == 2 && _combos.isEmpty && !_loadingCombos) _loadCombos();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadFeedbacks({bool reset = false}) async {
    if (_loadingFeedbacks) return;
    if (reset) { setState(() { _feedbacks = []; _feedbackPage = 1; }); }
    setState(() => _loadingFeedbacks = true);
    try {
      final result = await _detailRepo.getRoomFeedbacks(widget.room.id, page: _feedbackPage, limit: 5);
      if (mounted) setState(() {
        _feedbacks = reset ? result.items : [..._feedbacks, ...result.items];
        _feedbackTotal = result.total;
        _loadingFeedbacks = false;
        _feedbackPage++;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFeedbacks = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_togglingFav) return;
    setState(() => _togglingFav = true);
    try {
      if (_isFavorite && _favoriteId != null) {
        await _api.delete('/user/favorite-room/$_favoriteId');
        if (mounted) setState(() { _isFavorite = false; _favoriteId = null; });
      } else {
        final res = await _api.post('/user/favorite-room', data: {'roomId': widget.room.id});
        final data = res.data;
        int? newId;
        if (data is Map && data['data'] is Map) {
          newId = (data['data'] as Map)['id'] as int?;
        }
        if (mounted) setState(() { _isFavorite = true; _favoriteId = newId; });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _togglingFav = false);
    }
  }

  Future<void> _loadCombos() async {
    setState(() => _loadingCombos = true);
    try {
      final result = await _detailRepo.getCombos();
      if (mounted) setState(() {
        _combos = result.items.where((c) => c.roomTypeId == (widget.room.type?.id ?? 0) || c.isActive == 1).toList();
        _loadingCombos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCombos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final images = room.media.map((m) => m.path).where((p) => p.isNotEmpty).toList();
    final displayImage = images.isNotEmpty
        ? images[0]
        : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=900&q=80';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            actions: [
              _togglingFav
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(
                      icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.red : const Color(0xFF64748B)),
                      tooltip: _isFavorite ? 'Bỏ yêu thích' : 'Thêm yêu thích',
                      onPressed: _toggleFavorite,
                    ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: images.length > 1
                  ? Stack(children: [
                      PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _imgIndex = i),
                        itemBuilder: (_, i) => Image.network(images[i], fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE2E8F0), child: const Icon(Icons.hotel, size: 60, color: Color(0xFF94A3B8)))),
                      ),
                      Positioned(bottom: 12, left: 0, right: 0,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(images.length, (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _imgIndex ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: i == _imgIndex ? Colors.white : Colors.white.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(3)),
                              )))),
                    ])
                  : Image.network(displayImage, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE2E8F0), child: const Icon(Icons.hotel, size: 60, color: Color(0xFF94A3B8)))),
            ),
          ),
        ],
        body: Column(
          children: [
            // Room header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Phòng ${room.roomNumber}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFF0D584D), borderRadius: BorderRadius.circular(999)),
                    child: Text(room.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                if (room.type != null)
                  Text(room.type!.name, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.attach_money, size: 18, color: Color(0xFF0D584D)),
                  Text('${_fmtPrice(room.price)}đ/đêm',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D584D))),
                  const SizedBox(width: 16),
                  const Icon(Icons.people_outline, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text('Tối đa ${room.maxPeople} khách', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tab,
                  labelColor: const Color(0xFF0D584D),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  indicatorColor: const Color(0xFF0D584D),
                  tabs: const [Tab(text: 'Chi tiết'), Tab(text: 'Đánh giá'), Tab(text: 'Combo')],
                ),
              ]),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _DetailTab(room: room),
                  _ReviewsTab(
                    feedbacks: _feedbacks,
                    total: _feedbackTotal,
                    loading: _loadingFeedbacks,
                    onLoad: _loadFeedbacks,
                    loaded: _feedbacks.isNotEmpty,
                  ),
                  _CombosTab(combos: _combos, loading: _loadingCombos, onLoad: _loadCombos, loaded: _combos.isNotEmpty),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: room.status.toLowerCase() == 'available'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingConfirmationScreen(room: room))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D584D),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Đặt phòng ngay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          : null,
    );
  }
}

class _DetailTab extends StatelessWidget {
  const _DetailTab({required this.room});
  final RoomModel room;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        Text(room.description ?? 'Không có mô tả.', style: const TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.5)),
        const SizedBox(height: 20),
        const Text('Tiện nghi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: const [
          _Tag('Tầm nhìn đại dương'), _Tag('Bữa sáng miễn phí'), _Tag('Wi-Fi cao tốc'), _Tag('Ban công riêng'), _Tag('Điều hoà'), _Tag('Tivi thông minh'),
        ]),
      ]),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.feedbacks, required this.total, required this.loading, required this.onLoad, required this.loaded});
  final List<FeedbackModel> feedbacks;
  final int total;
  final bool loading;
  final VoidCallback onLoad;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    if (!loaded && !loading) {
      return Center(child: ElevatedButton(onPressed: onLoad, child: const Text('Tải đánh giá')));
    }
    if (loading && feedbacks.isEmpty) return const Center(child: CircularProgressIndicator());
    if (feedbacks.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.rate_review_outlined, size: 48, color: Color(0xFF94A3B8)),
      SizedBox(height: 12),
      Text('Chưa có đánh giá.', style: TextStyle(color: Color(0xFF64748B))),
    ]));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: feedbacks.length + (feedbacks.length < total ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == feedbacks.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton(onPressed: onLoad, child: const Text('Xem thêm')),
          );
        }
        final f = feedbacks[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 3))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0D584D).withValues(alpha: 0.15),
                backgroundImage: f.user.avatar != null ? NetworkImage(f.user.avatar!) : null,
                child: f.user.avatar == null ? Text(f.user.name.isNotEmpty ? f.user.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF0D584D), fontWeight: FontWeight.bold)) : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(f.createdAt != null ? _fmtDate(f.createdAt!) : '', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ])),
              Row(children: List.generate(5, (s) => Icon(s < f.rating ? Icons.star : Icons.star_border, size: 14, color: const Color(0xFFF59E0B)))),
            ]),
            const SizedBox(height: 8),
            Text(f.comment, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4)),
          ]),
        );
      },
    );
  }
}

class _CombosTab extends StatelessWidget {
  const _CombosTab({required this.combos, required this.loading, required this.onLoad, required this.loaded});
  final List<ComboModel> combos;
  final bool loading;
  final VoidCallback onLoad;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    if (!loaded && !loading) {
      return Center(child: ElevatedButton(onPressed: onLoad, child: const Text('Tải combo')));
    }
    if (loading) return const Center(child: CircularProgressIndicator());
    if (combos.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.loyalty_outlined, size: 48, color: Color(0xFF94A3B8)),
      SizedBox(height: 12),
      Text('Không có combo cho phòng này.', style: TextStyle(color: Color(0xFF64748B))),
    ]));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: combos.length,
      itemBuilder: (_, i) {
        final c = combos[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: const Border(left: BorderSide(color: Color(0xFF6366F1), width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text('${c.discountValue.toStringAsFixed(0)}% off', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Ở tối thiểu ${c.minStayNights} đêm  •  Giảm tối đa ${_fmtPrice(c.maxDiscountAmount)}đ',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            if (c.description != null) ...[const SizedBox(height: 4), Text(c.description!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))],
            if (c.comboServices.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Dịch vụ bao gồm:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ...c.comboServices.map((s) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(s.service.name, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                ]),
              )),
            ],
          ]),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D584D).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFF0D584D), fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

String _fmtDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _fmtPrice(double v) {
  return v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
