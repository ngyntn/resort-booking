import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/booking/models/booking_models.dart';
import 'package:mobile/features/booking/repository/booking_repository.dart';

class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> with SingleTickerProviderStateMixin {
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
        title: const Text('Voucher'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF0D584D),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF0D584D),
          tabs: const [Tab(text: 'Tất cả'), Tab(text: 'Của tôi')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_AllVouchers(), _MyVouchers()],
      ),
    );
  }
}

class _AllVouchers extends StatefulWidget {
  const _AllVouchers();

  @override
  State<_AllVouchers> createState() => _AllVouchersState();
}

class _AllVouchersState extends State<_AllVouchers> with AutomaticKeepAliveClientMixin {
  final _api = ApiClient();
  List<dynamic> _items = [];
  bool _loading = false;
  final Set<int> _claiming = {};

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
      final res = await _api.get('/voucher', queryParameters: {'page': 1, 'limit': 20});
      final payload = res.data as Map<String, dynamic>;
      final data = payload['data'];
      List raw = [];
      if (data is List) {
        raw = data.isNotEmpty && data[0] is List ? data[0] as List : data;
      } else if (data is Map<String, dynamic>) {
        raw = data['items'] is List ? data['items'] as List : [];
      }
      if (mounted) setState(() { _items = raw; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claim(int voucherId) async {
    setState(() => _claiming.add(voucherId));
    try {
      await _api.post('/voucher/claim', data: {'voucherId': voucherId});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhận voucher thành công!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _claiming.remove(voucherId));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.local_offer_outlined, size: 48, color: Color(0xFF94A3B8)),
      SizedBox(height: 12),
      Text('Không có voucher nào.', style: TextStyle(color: Color(0xFF64748B))),
    ]));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i] is Map<String, dynamic> ? _items[i] as Map<String, dynamic> : <String, dynamic>{};
          final id = _parseInt(item['id']);
          final name = item['name']?.toString() ?? '';
          final type = item['discountType']?.toString() ?? 'percentage';
          final value = _parseDouble(item['discountValue']);
          final maxDisc = _parseDouble(item['maxDiscountAmount']);
          final minBook = _parseDouble(item['minBookingAmount']);
          final expiry = item['expiredAt']?.toString();
          final discount = type == 'percentage' ? '${value.toStringAsFixed(0)}% off' : '-${_fmtPrice(value)}đ';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: const Border(left: BorderSide(color: Color(0xFF0D584D), width: 4)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(discount, style: const TextStyle(color: Color(0xFF0D584D), fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('Đơn tối thiểu ${_fmtPrice(minBook)}đ  •  Giảm tối đa ${_fmtPrice(maxDisc)}đ',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  if (expiry != null)
                    Text('HSD: ${_fmtDate(expiry)}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ])),
                const SizedBox(width: 12),
                SizedBox(
                  width: 76,
                  child: ElevatedButton(
                    onPressed: _claiming.contains(id) ? null : () => _claim(id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D584D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: _claiming.contains(id)
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Nhận'),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _MyVouchers extends StatefulWidget {
  const _MyVouchers();

  @override
  State<_MyVouchers> createState() => _MyVouchersState();
}

class _MyVouchersState extends State<_MyVouchers> with AutomaticKeepAliveClientMixin {
  final _repo = BookingRepository();
  List<VoucherModel> _items = [];
  bool _loading = false;

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
      final items = await _repo.getUserVouchers();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.local_offer_outlined, size: 48, color: Color(0xFF94A3B8)),
      SizedBox(height: 12),
      Text('Chưa có voucher nào.', style: TextStyle(color: Color(0xFF64748B))),
    ]));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final v = _items[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: v.isUsed ? const Color(0xFFF1F5F9) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: v.isUsed ? const Color(0xFF94A3B8) : const Color(0xFF0D584D), width: 4)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: v.isUsed ? const Color(0xFF94A3B8) : const Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(v.displayDiscount, style: TextStyle(color: v.isUsed ? const Color(0xFF94A3B8) : const Color(0xFF0D584D), fontWeight: FontWeight.w600, fontSize: 13)),
                  if (v.expiredAt != null)
                    Text('HSD: ${_fmtDate(v.expiredAt!)}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (v.isUsed ? const Color(0xFF94A3B8) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(v.isUsed ? 'Đã dùng' : 'Còn hạn',
                      style: TextStyle(color: v.isUsed ? const Color(0xFF94A3B8) : const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

String _fmtDate(String dateStr) {
  try {
    final d = DateTime.parse(dateStr);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    return dateStr;
  }
}

String _fmtPrice(double v) {
  return v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
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
