import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/booking/models/booking_models.dart';
import 'package:mobile/features/booking/repository/booking_repository.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final _repo = BookingRepository();
  List<BookingModel> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await _repo.getBookings(limit: 100);
      // Show checkout status OR bookings whose end date is in the past
      final now = DateTime.now();
      final history = all.where((b) {
        if (b.status == 'checkout') return true;
        try {
          final end = DateTime.parse(b.endDate);
          return end.isBefore(now);
        } catch (_) { return false; }
      }).toList();
      if (mounted) setState(() { _items = history; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Lịch sử đặt phòng'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
                ]))
              : _items.isEmpty
                  ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.history, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('Chưa có lịch sử đặt phòng.', style: TextStyle(color: Color(0xFF64748B))),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _HistoryCard(booking: _items[i]),
                      ),
                    ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(b.roomNumber != null ? 'Phòng ${b.roomNumber}' : 'Booking #${b.id}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)))),
          Text('${_fmtPrice(b.totalPrice)}đ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D584D))),
        ]),
        if (b.roomTypeName != null)
          Text(b.roomTypeName!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        const SizedBox(height: 6),
        Text('${_fmt(b.startDate)} → ${_fmt(b.endDate)}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 10),
        Row(children: [
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _writeReview(context),
            icon: const Icon(Icons.star_outline, size: 16),
            label: const Text('Đánh giá'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0D584D),
              side: const BorderSide(color: Color(0xFF0D584D)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ]),
      ]),
    );
  }

  void _writeReview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(booking: booking),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.booking});
  final BookingModel booking;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  final _api = ApiClient();

  Future<void> _submit() async {
    if (_commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập nhận xét.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.post('/feedback', data: {
        'bookingId': widget.booking.id,
        'rating': _rating,
        'comment': _commentCtrl.text.trim(),
        'targetType': 'room',
        'targetId': widget.booking.roomId,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cảm ơn đánh giá của bạn!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gửi thất bại: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Viết đánh giá', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _rating = i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(i < _rating ? Icons.star : Icons.star_border, color: const Color(0xFFF59E0B), size: 32),
              ),
            )),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Nhận xét về phòng...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D584D), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gửi đánh giá'),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

String _fmt(String dateStr) {
  try {
    final d = DateTime.parse(dateStr);
    return DateFormat('dd/MM/yyyy').format(d);
  } catch (_) {
    return dateStr;
  }
}

String _fmtPrice(double v) {
  return v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
