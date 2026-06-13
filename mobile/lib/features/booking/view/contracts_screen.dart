import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/features/booking/models/booking_models.dart';
import 'package:mobile/features/booking/repository/booking_repository.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _repo = BookingRepository();

  final _statusTabs = const ['pending', 'confirmed', 'rejected', 'cancelled'];
  final _statusLabels = const ['Chờ xử lý', 'Đã xác nhận', 'Từ chối', 'Đã huỷ'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statusTabs.length, vsync: this);
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
        title: const Text('Đặt phòng của tôi'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: const Color(0xFF0D584D),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF0D584D),
          tabs: _statusLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _statusTabs.map((s) => _BookingList(status: s, repo: _repo)).toList(),
      ),
    );
  }
}

class _BookingList extends StatefulWidget {
  const _BookingList({required this.status, required this.repo});
  final String status;
  final BookingRepository repo;

  @override
  State<_BookingList> createState() => _BookingListState();
}

class _BookingListState extends State<_BookingList> with AutomaticKeepAliveClientMixin {
  List<BookingModel> _items = [];
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await widget.repo.getBookings(status: widget.status);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
      const SizedBox(height: 12),
      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
    ]));
    if (_items.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.event_note_outlined, size: 48, color: Color(0xFF94A3B8)),
      SizedBox(height: 12),
      Text('Chưa có booking nào.', style: TextStyle(color: Color(0xFF64748B))),
    ]));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (ctx, i) => _BookingCard(
          booking: _items[i],
          repo: widget.repo,
          onRefresh: _load,
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.repo, required this.onRefresh});
  final BookingModel booking;
  final BookingRepository repo;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            if (b.roomImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(b.roomImage!, width: 70, height: 70, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 70, height: 70, child: Icon(Icons.hotel, color: Color(0xFF94A3B8)))),
              )
            else
              Container(width: 70, height: 70, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.hotel, color: Color(0xFF94A3B8))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.roomNumber != null ? 'Phòng ${b.roomNumber}' : 'Booking #${b.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                if (b.roomTypeName != null)
                  Text(b.roomTypeName!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(height: 4),
                Text('${_fmt(b.startDate)} → ${_fmt(b.endDate)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: b.statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                    child: Text(b.statusLabel, style: TextStyle(color: b.statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text('${_fmtPrice(b.totalPrice)}đ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D584D), fontSize: 14)),
                ]),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingDetailSheet(booking: booking, repo: repo, onRefresh: onRefresh),
    );
  }
}

class _BookingDetailSheet extends StatefulWidget {
  const _BookingDetailSheet({required this.booking, required this.repo, required this.onRefresh});
  final BookingModel booking;
  final BookingRepository repo;
  final VoidCallback onRefresh;

  @override
  State<_BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends State<_BookingDetailSheet> {
  bool _cancelling = false;
  bool _paying = false;
  List<ReceiptModel> _receipts = [];
  bool _loadingReceipts = false;

  @override
  void initState() {
    super.initState();
    if (widget.booking.isPaid) _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    if (_loadingReceipts) return;
    setState(() => _loadingReceipts = true);
    try {
      final list = await widget.repo.getReceipts(widget.booking.id);
      if (mounted) setState(() { _receipts = list; _loadingReceipts = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingReceipts = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Huỷ đặt phòng'),
        content: const Text('Bạn có chắc muốn huỷ booking này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Huỷ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    setState(() => _cancelling = true);
    try {
      await widget.repo.cancelBooking(widget.booking.id);
      if (!mounted) return;
      // Save messenger reference BEFORE Navigator.pop to avoid unmounted context error
      final messenger = ScaffoldMessenger.of(context);
      final refresh = widget.onRefresh;
      Navigator.pop(context);
      refresh();
      messenger.showSnackBar(const SnackBar(content: Text('Đã huỷ booking thành công.')));
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final url = await widget.repo.payDeposit(widget.booking.id);
      if (!mounted) return;
      if (url != null) {
        await _openUrl(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không lấy được link thanh toán.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _signContract() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SignatureSheet(
        bookingId: widget.booking.id,
        repo: widget.repo,
        onSigned: () {
          Navigator.pop(context);
          widget.onRefresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(controller: ctrl, padding: const EdgeInsets.all(20), children: [
                Row(children: [
                  Expanded(child: Text(b.roomNumber != null ? 'Phòng ${b.roomNumber}' : 'Booking #${b.id}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: b.statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                    child: Text(b.statusLabel, style: TextStyle(color: b.statusColor, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 16),
                _DetailRow(label: 'Check-in', value: _fmt(b.startDate)),
                _DetailRow(label: 'Check-out', value: _fmt(b.endDate)),
                _DetailRow(label: 'Số khách', value: '${b.capacity}'),
                _DetailRow(label: 'Tổng tiền', value: '${_fmtPrice(b.totalPrice)}đ'),
                _DetailRow(label: 'Đã thanh toán', value: b.isPaid ? 'Có' : 'Chưa'),
                if (b.contractPath != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _openUrl(b.contractPath!),
                    child: Row(children: [
                      const Text('Hợp đồng', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                      const Spacer(),
                      const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0D584D)),
                      const SizedBox(width: 4),
                      const Text('Xem hợp đồng', style: TextStyle(color: Color(0xFF0D584D), fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
                if (_receipts.isNotEmpty) ...[
                  const Divider(height: 28),
                  const Text('Biên lai thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ..._receipts.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      const Icon(Icons.receipt_outlined, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Text(_fmt(r.createdAt), style: const TextStyle(fontSize: 13)),
                      const Spacer(),
                      Text('${_fmtPrice(r.amount)}đ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D584D))),
                    ]),
                  )),
                ],
                if (b.isPaid && _loadingReceipts)
                  const Padding(padding: EdgeInsets.only(top: 8), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
                if (b.bookingServices.isNotEmpty) ...[
                  const Divider(height: 32),
                  const Text('Dịch vụ kèm theo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ...b.bookingServices.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.serviceName ?? 'Dịch vụ #${s.id}')),
                      Text('x${s.quantity}', style: const TextStyle(color: Color(0xFF64748B))),
                    ]),
                  )),
                ],
                const SizedBox(height: 24),
                // Actions
                if (b.status == 'pending' || b.status == 'confirmed')
                  OutlinedButton.icon(
                    onPressed: _cancelling ? null : _cancel,
                    icon: _cancelling ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cancel_outlined, color: Colors.red),
                    label: const Text('Huỷ đặt phòng', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                if (b.status == 'pending' && b.contractPath != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _signContract,
                    icon: const Icon(Icons.draw_outlined),
                    label: const Text('Ký hợp đồng'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ],
                if (b.status == 'confirmed' && !b.isPaid) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _paying ? null : _pay,
                    icon: _paying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.payment),
                    label: const Text('Thanh toán VNPay'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D584D), foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignatureSheet extends StatefulWidget {
  const _SignatureSheet({required this.bookingId, required this.repo, required this.onSigned});
  final int bookingId;
  final BookingRepository repo;
  final VoidCallback onSigned;

  @override
  State<_SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<_SignatureSheet> {
  final _sigCtrl = SignatureController(penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white);
  bool _saving = false;

  Future<void> _save() async {
    if (_sigCtrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng vẽ chữ ký.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final Uint8List? bytes = await _sigCtrl.toPngBytes();
      if (bytes == null) throw Exception('Không xuất được chữ ký.');
      final url = await widget.repo.uploadFile(bytes, 'signature_${widget.bookingId}.png');
      await widget.repo.signContract(widget.bookingId, url);
      if (!mounted) return;
      // Save messenger reference BEFORE Navigator.pop to avoid unmounted context error
      final messenger = ScaffoldMessenger.of(context);
      final onSigned = widget.onSigned;
      Navigator.pop(context);
      onSigned();
      messenger.showSnackBar(const SnackBar(content: Text('Ký hợp đồng thành công!')));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    _sigCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Vẽ chữ ký của bạn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(12)),
              child: Signature(controller: _sigCtrl, backgroundColor: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _sigCtrl.clear,
              icon: const Icon(Icons.clear),
              label: const Text('Xoá'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
              label: const Text('Xác nhận ký'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D584D), foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 14)),
      ]),
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
