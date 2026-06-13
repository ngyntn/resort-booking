import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/booking/models/booking_models.dart';
import 'package:mobile/features/booking/repository/booking_repository.dart';
import 'package:mobile/features/profile/repository/profile_repository.dart';
import 'package:mobile/features/room/models/room_model.dart';
import 'package:mobile/features/room/repository/room_repository.dart';
import 'package:mobile/features/room/view/room_detail_screen.dart';
import 'package:mobile/features/booking/view/booking_confirmation_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _roomRepo = RoomRepository();
  final _bookingRepo = BookingRepository();
  final _profileRepo = ProfileRepository();

  List<RoomModel> _featuredRooms = [];
  int _activeBookings = 0;
  String? _userName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Fetch in parallel, swallow individual errors gracefully
      RoomPaginatedResponse roomsRes = const RoomPaginatedResponse(items: [], total: 0);
      List<BookingModel> bookingList = [];
      ProfileModel? profile;

      await Future.wait([
        _roomRepo.getRooms(const GetRoomsRequest(page: 1, limit: 3))
            .then((r) { roomsRes = r; }).catchError((Object _) {}),
        _bookingRepo.getBookings(limit: 100)
            .then((r) { bookingList = r; }).catchError((Object _) {}),
        _profileRepo.getProfile()
            .then((r) { profile = r; }).catchError((Object _) {}),
      ]);
      if (!mounted) return;
      final active = bookingList.where((b) {
        return b.status == 'pending' || b.status == 'confirmed';
      }).length;
      setState(() {
        _featuredRooms = roomsRes.items;
        _activeBookings = active;
        _userName = profile?.name;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Paradise Resort', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF64748B)), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D584D), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    _userName != null ? 'Xin chào, ${_userName!.split(' ').last}!' : 'Chào mừng trở lại!',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_activeBookings > 0)
                    GestureDetector(
                      onTap: () => context.go('/bookings'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(30)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.event_note, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text('$_activeBookings booking đang hoạt động', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                        ]),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 20),

              // Quick actions
              Row(children: [
                _QuickAction(
                  icon: Icons.king_bed_outlined,
                  label: 'Tìm phòng',
                  color: const Color(0xFF0D584D),
                  onTap: () => context.go('/rooms'),
                ),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.event_note_outlined,
                  label: 'Booking',
                  color: const Color(0xFF6366F1),
                  onTap: () => context.go('/bookings'),
                ),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.room_service_outlined,
                  label: 'Dịch vụ',
                  color: const Color(0xFFEA580C),
                  onTap: () => context.go('/profile'),
                ),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.local_offer_outlined,
                  label: 'Voucher',
                  color: const Color(0xFFBE185D),
                  onTap: () => context.go('/profile'),
                ),
              ]),
              const SizedBox(height: 24),

              // Featured rooms
              Row(children: [
                const Text('Phòng nổi bật', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go('/rooms'),
                  child: const Text('Xem tất cả', style: TextStyle(fontSize: 13, color: Color(0xFF0D584D), fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 12),

              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else if (_featuredRooms.isEmpty)
                _EmptyRooms(onTap: () => context.go('/rooms'))
              else
                ..._featuredRooms.map((room) => _FeaturedRoomCard(
                  room: room,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room))),
                  onBook: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingConfirmationScreen(room: room))),
                )),

              const SizedBox(height: 24),

              // Info card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0D584D), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text('Về Paradise Resort', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ]),
                  const SizedBox(height: 10),
                  const Text(
                    'Một khu nghỉ dưỡng đẳng cấp với tầm nhìn hướng biển, nơi mỗi kỳ lưu trú đều được chăm chút tỉ mỉ với dịch vụ tận tâm và tiện nghi sang trọng.',
                    style: TextStyle(color: Color(0xFF5B6B78), height: 1.5, fontSize: 14),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Amenities grid
              const Text('Tiện ích nổi bật', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
                children: const [
                  _AmenityCard(icon: Icons.pool, title: 'Hồ bơi vô cực', subtitle: 'Ngắm bình minh trên mặt nước', color: Color(0xFF0891B2)),
                  _AmenityCard(icon: Icons.restaurant_menu, title: 'Nhà hàng riêng', subtitle: 'Ẩm thực tinh tế được chọn lọc', color: Color(0xFF7C3AED)),
                  _AmenityCard(icon: Icons.spa, title: 'Spa & Wellness', subtitle: 'Thư giãn toàn diện', color: Color(0xFFBE185D)),
                  _AmenityCard(icon: Icons.directions_car, title: 'Đưa đón sân bay', subtitle: 'Đến nơi không lo phương tiện', color: Color(0xFF1D4ED8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Chào buổi sáng ☀️';
    if (h < 18) return 'Chào buổi chiều 🌤️';
    return 'Chào buổi tối 🌙';
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _FeaturedRoomCard extends StatelessWidget {
  const _FeaturedRoomCard({required this.room, required this.onTap, required this.onBook});
  final RoomModel room;
  final VoidCallback onTap;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final imageUrl = room.media.isNotEmpty && room.media.first.path.isNotEmpty
        ? room.media.first.path
        : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=900&q=80';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: Image.network(imageUrl, width: 100, height: 90, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 100, height: 90, color: const Color(0xFFE2E8F0),
                    child: const Icon(Icons.hotel, size: 36, color: Color(0xFF94A3B8)))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Phòng ${room.roomNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
              if (room.type != null)
                Text(room.type!.name, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.attach_money, size: 14, color: Color(0xFF0D584D)),
                Text('${_fmtPrice(room.price)}đ/đêm', style: const TextStyle(fontSize: 12, color: Color(0xFF0D584D), fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Icon(Icons.people_outline, size: 14, color: Color(0xFF64748B)),
                Text(' ${room.maxPeople}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ]),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: room.status.toLowerCase() == 'available' ? onBook : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D584D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Đặt'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))]),
        child: const Center(child: Column(children: [
          Icon(Icons.king_bed_outlined, size: 40, color: Color(0xFF94A3B8)),
          SizedBox(height: 8),
          Text('Chưa có phòng. Nhấn để xem tất cả.', style: TextStyle(color: Color(0xFF64748B))),
        ])),
      ),
    );
  }
}

class _AmenityCard extends StatelessWidget {
  const _AmenityCard({required this.icon, required this.title, required this.subtitle, required this.color});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B78), height: 1.3)),
      ]),
    );
  }
}

String _fmtPrice(double v) => v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
