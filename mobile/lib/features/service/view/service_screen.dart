import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/booking/models/booking_models.dart';
import 'package:mobile/features/booking/repository/booking_repository.dart';
import 'package:mobile/features/service/models/service_models.dart';
import 'package:mobile/features/service/repository/service_repository.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  final _svcRepo = ServiceRepository();
  final _bookingRepo = BookingRepository();

  List<BookingModel> _confirmedBookings = [];
  List<ServiceModel> _services = [];
  BookingModel? _selectedBooking;
  final Map<int, int> _cart = {}; // serviceId → quantity
  bool _loadingBookings = true;
  bool _loadingServices = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _loadBookingsAndServices();
  }

  Future<void> _loadBookingsAndServices() async {
    setState(() { _loadingBookings = true; _loadingServices = true; });
    try {
      final bookings = await _bookingRepo.getBookings(limit: 100);
      final confirmed = bookings.where((b) => b.status == 'confirmed').toList();
      if (mounted) setState(() { _confirmedBookings = confirmed; _loadingBookings = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingBookings = false);
    }
    try {
      final svcs = await _svcRepo.getServices();
      if (mounted) setState(() { _services = svcs; _loadingServices = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  int _cartTotal() => _cart.values.fold(0, (a, b) => a + b);

  double _cartPrice() {
    return _cart.entries.fold(0.0, (sum, e) {
      final svc = _services.firstWhere((s) => s.id == e.key, orElse: () => ServiceModel(id: e.key, name: '', price: 0, status: ''));
      return sum + svc.price * e.value;
    });
  }

  void _addToCart(ServiceModel svc) {
    setState(() => _cart[svc.id] = (_cart[svc.id] ?? 0) + 1);
  }

  void _removeFromCart(ServiceModel svc) {
    setState(() {
      if ((_cart[svc.id] ?? 0) <= 1) {
        _cart.remove(svc.id);
      } else {
        _cart[svc.id] = _cart[svc.id]! - 1;
      }
    });
  }

  Future<void> _order() async {
    if (_selectedBooking == null) {
      _snack('Chọn booking trước.');
      return;
    }
    if (_cart.isEmpty) {
      _snack('Chưa chọn dịch vụ nào.');
      return;
    }
    final startDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() => _submitting = true);
    try {
      for (final entry in _cart.entries) {
        final req = BookingServiceRequest(
          bookingId: _selectedBooking!.id,
          serviceId: entry.key,
          quantity: entry.value,
          startDate: startDate,
        );
        await _svcRepo.bookService(req);
      }
      if (mounted) {
        setState(() { _cart.clear(); _submitting = false; });
        _snack('Đặt dịch vụ thành công!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack(e.toString());
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Đặt dịch vụ'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _loadingBookings && _loadingServices
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Select booking
                _Section(
                  title: 'Chọn booking',
                  child: _loadingBookings
                      ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                      : _confirmedBookings.isEmpty
                          ? const Text('Không có booking đang xác nhận.', style: TextStyle(color: Color(0xFF94A3B8)))
                          : DropdownButtonFormField<BookingModel>(
                              value: _selectedBooking,
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              hint: const Text('Chọn booking'),
                              items: _confirmedBookings.map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(b.roomNumber != null ? 'Phòng ${b.roomNumber} — #${b.id}' : 'Booking #${b.id}', overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (b) => setState(() => _selectedBooking = b),
                            ),
                ),
                const SizedBox(height: 16),

                // Services list
                _Section(
                  title: 'Danh sách dịch vụ',
                  child: _loadingServices
                      ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                      : _services.isEmpty
                          ? const Text('Không có dịch vụ.', style: TextStyle(color: Color(0xFF94A3B8)))
                          : Column(
                              children: _services.map((svc) => _ServiceRow(
                                service: svc,
                                qty: _cart[svc.id] ?? 0,
                                onAdd: () => _addToCart(svc),
                                onRemove: () => _removeFromCart(svc),
                              )).toList(),
                            ),
                ),
                const SizedBox(height: 16),

                // Cart summary
                if (_cart.isNotEmpty) ...[
                  _Section(
                    title: 'Giỏ dịch vụ',
                    child: Column(children: [
                      ..._cart.entries.map((e) {
                        final svc = _services.firstWhere((s) => s.id == e.key, orElse: () => ServiceModel(id: e.key, name: '#${e.key}', price: 0, status: ''));
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Expanded(child: Text(svc.name)),
                            Text('×${e.value}  ${_fmtPrice(svc.price * e.value)}đ', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                        );
                      }),
                      const Divider(),
                      Row(children: [
                        const Text('Tổng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        Text('${_fmtPrice(_cartPrice())}đ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D584D))),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _order,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D584D), foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: _submitting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Đặt ${_cartTotal()} dịch vụ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.qty, required this.onAdd, required this.onRemove});
  final ServiceModel service;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(service.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          if (service.description != null)
            Text(service.description!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${_fmtPrice(service.price)}đ', style: const TextStyle(color: Color(0xFF0D584D), fontWeight: FontWeight.bold, fontSize: 13)),
        ])),
        Row(children: [
          if (qty > 0) ...[
            IconButton(onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline), iconSize: 22, padding: EdgeInsets.zero),
            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D584D))),
          ],
          IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0D584D)), iconSize: 22, padding: EdgeInsets.zero),
        ]),
      ]),
    );
  }
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

String _fmtPrice(double v) {
  return v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
