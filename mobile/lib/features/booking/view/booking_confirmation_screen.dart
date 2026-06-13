import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mobile/features/booking/models/booking_models.dart';
import 'package:mobile/features/booking/repository/booking_repository.dart';
import 'package:mobile/features/room/models/room_model.dart';

class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({super.key, required this.room});
  final RoomModel room;

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final _repo = BookingRepository();
  final _dateFmt = DateFormat('yyyy-MM-dd');
  final _displayFmt = DateFormat('dd/MM/yyyy');

  DateTime? _checkIn;
  DateTime? _checkOut;
  int _guests = 1;
  VoucherModel? _selectedVoucher;
  List<VoucherModel> _vouchers = [];
  bool _loadingVouchers = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    setState(() => _loadingVouchers = true);
    try {
      final v = await _repo.getUserVouchers();
      if (mounted) setState(() => _vouchers = v.where((e) => !e.isUsed).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  int get _nights {
    if (_checkIn == null || _checkOut == null) return 0;
    return _checkOut!.difference(_checkIn!).inDays;
  }

  double get _subtotal => widget.room.price * _nights;

  double get _discount {
    if (_selectedVoucher == null || _nights == 0) return 0;
    if (_subtotal < _selectedVoucher!.minBookingAmount) return 0;
    if (_selectedVoucher!.discountType == 'percentage') {
      final d = _subtotal * _selectedVoucher!.discountValue / 100;
      return d.clamp(0, _selectedVoucher!.maxDiscountAmount);
    }
    return _selectedVoucher!.discountValue.clamp(0, _subtotal);
  }

  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  Future<void> _submit() async {
    if (_checkIn == null || _checkOut == null) {
      _snack('Vui lòng chọn ngày check-in và check-out.');
      return;
    }
    if (_nights < 1) {
      _snack('Check-out phải sau check-in ít nhất 1 ngày.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final req = CreateBookingRequest(
        roomId: widget.room.id,
        startDate: _dateFmt.format(_checkIn!),
        endDate: _dateFmt.format(_checkOut!),
        capacity: _guests,
        userVoucherId: _selectedVoucher?.id,
      );
      await _repo.createBooking(req);
      if (!mounted) return;
      _snack('Đặt phòng thành công!');
      context.go('/bookings');
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final image = room.media.isNotEmpty ? room.media.first.path : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Xác nhận đặt phòng'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Room info
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(image, height: 180, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(height: 180, child: Icon(Icons.hotel, size: 60, color: Color(0xFF94A3B8)))),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Phòng ${room.roomNumber}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    if (room.type != null)
                      Text(room.type!.name, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.people_outline, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text('Tối đa ${room.maxPeople} khách', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      const Spacer(),
                      Text('${_fmtPrice(room.price)}đ/đêm',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D584D))),
                    ]),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Calendar
          _Section(
            title: 'Chọn ngày',
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _checkIn ?? DateTime.now(),
              calendarFormat: CalendarFormat.month,
              rangeStartDay: _checkIn,
              rangeEndDay: _checkOut,
              rangeSelectionMode: RangeSelectionMode.toggledOn,
              onRangeSelected: (start, end, focused) {
                setState(() {
                  _checkIn = start;
                  _checkOut = end;
                });
              },
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              calendarStyle: CalendarStyle(
                rangeHighlightColor: const Color(0xFF0D584D).withValues(alpha: 0.15),
                rangeStartDecoration: const BoxDecoration(color: Color(0xFF0D584D), shape: BoxShape.circle),
                rangeEndDecoration: const BoxDecoration(color: Color(0xFF0D584D), shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: const Color(0xFF0D584D).withValues(alpha: 0.3), shape: BoxShape.circle),
              ),
            ),
          ),
          if (_checkIn != null && _checkOut != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                '${_displayFmt.format(_checkIn!)}  →  ${_displayFmt.format(_checkOut!)}  ($_nights đêm)',
                style: const TextStyle(color: Color(0xFF0D584D), fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 16),

          // Guests
          _Section(
            title: 'Số khách',
            child: Row(
              children: [
                IconButton(
                  onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: const Color(0xFF0D584D),
                ),
                Text('$_guests', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _guests < room.maxPeople ? () => setState(() => _guests++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFF0D584D),
                ),
                const Spacer(),
                Text('Tối đa ${room.maxPeople}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Voucher
          _Section(
            title: 'Voucher',
            child: _loadingVouchers
                ? const Center(child: SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2)))
                : _vouchers.isEmpty
                    ? const Text('Không có voucher khả dụng.', style: TextStyle(color: Color(0xFF94A3B8)))
                    : DropdownButtonFormField<VoucherModel?>(
                        value: _selectedVoucher,
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                        hint: const Text('Chọn voucher (tuỳ chọn)'),
                        items: [
                          const DropdownMenuItem<VoucherModel?>(value: null, child: Text('Không dùng voucher')),
                          ..._vouchers.map((v) => DropdownMenuItem<VoucherModel?>(
                              value: v,
                              child: Text('${v.name} — ${v.displayDiscount}', overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) => setState(() => _selectedVoucher = v),
                      ),
          ),
          const SizedBox(height: 16),

          // Price summary
          _Section(
            title: 'Tổng tiền',
            child: Column(
              children: [
                _PriceLine(label: 'Giá phòng', value: '${_fmtPrice(widget.room.price)}đ × $_nights đêm'),
                _PriceLine(label: 'Tạm tính', value: '${_fmtPrice(_subtotal)}đ'),
                if (_discount > 0)
                  _PriceLine(label: 'Giảm giá', value: '-${_fmtPrice(_discount)}đ', color: const Color(0xFF10B981)),
                const Divider(),
                _PriceLine(
                  label: 'Tổng cộng',
                  value: '${_fmtPrice(_total)}đ',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D584D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Xác nhận đặt phòng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

String _fmtPrice(double v) {
  return v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.value, this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color ?? (bold ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style.copyWith(color: color ?? (bold ? const Color(0xFF0D584D) : null))),
      ]),
    );
  }
}
