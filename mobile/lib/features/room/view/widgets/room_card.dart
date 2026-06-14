import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/room/models/room_model.dart';

class RoomCard extends StatefulWidget {
  const RoomCard({
    super.key,
    required this.room,
    required this.onViewDetails,
    required this.onBookRoom,
    this.initialIsFavorite = false,
    this.initialFavoriteId,
  });

  final RoomModel room;
  final VoidCallback onViewDetails;
  final VoidCallback onBookRoom;
  final bool initialIsFavorite;
  final int? initialFavoriteId;

  @override
  State<RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<RoomCard> {
  final _api = ApiClient();
  late bool _isFavorite;
  late int? _favoriteId;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initialIsFavorite;
    _favoriteId = widget.initialFavoriteId;
  }

  String get _imageUrl {
    if (widget.room.media.isNotEmpty && widget.room.media.first.path.isNotEmpty) {
      return widget.room.media.first.path;
    }
    return 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=900&q=80';
  }

  Future<void> _toggleFavorite() async {
    if (_toggling) return;
    setState(() => _toggling = true);
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
      // Silently fail — user can retry
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 220,
                width: double.infinity,
                child: Image.network(
                  _imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFE2E8F0),
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.room.status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.room.type?.name ?? 'Room',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // Favorite button
              Positioned(
                right: 12,
                bottom: 12,
                child: GestureDetector(
                  onTap: _toggleFavorite,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: _toggling
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : const Color(0xFF64748B),
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phòng ${widget.room.roomNumber}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.room.description ?? 'Phòng nghỉ sang trọng với tầm nhìn tuyệt đẹp.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _InfoChip(
                      icon: Icons.attach_money,
                      label: '${_fmtPrice(widget.room.price)}đ',
                      subtitle: 'mỗi đêm',
                    ),
                    _InfoChip(
                      icon: Icons.people,
                      label: '${widget.room.maxPeople}',
                      subtitle: 'khách',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onViewDetails,
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Chi tiết'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withValues(alpha: 0.45)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.room.status.toLowerCase() == 'available' ? widget.onBookRoom : null,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('Đặt phòng'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.subtitle});

  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 17),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }
}

String _fmtPrice(double v) => v.toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
