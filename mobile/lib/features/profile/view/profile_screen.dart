import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/providers/auth_provider.dart';
import 'package:mobile/features/auth/repository/auth_repository.dart';
import 'package:mobile/features/booking/view/booking_history_screen.dart';
import 'package:mobile/features/favorite/view/favorites_screen.dart';
import 'package:mobile/features/profile/repository/profile_repository.dart';
import 'package:mobile/features/service/view/service_screen.dart';
import 'package:mobile/features/voucher/view/voucher_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileRepo = ProfileRepository();
  ProfileModel? _profile;
  bool _loadingProfile = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final p = await _profileRepo.getProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await AuthRepository().signOut();
    } catch (_) {
      // ignore sign out API error, still proceed
    }
    if (!mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) setState(() => _isLoggingOut = false);
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openEdit() {
    if (_profile == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        profile: _profile!,
        repo: _profileRepo,
        onSaved: (updated) {
          if (mounted) setState(() => _profile = updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_profile != null)
            TextButton(
              onPressed: _openEdit,
              child: const Text('Chỉnh sửa', style: TextStyle(color: Color(0xFF0D584D), fontWeight: FontWeight.w600)),
            ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadProfile),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Avatar
              GestureDetector(
                onTap: _profile != null ? _openEdit : null,
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE2E8F0)),
                      child: p?.avatar != null && p!.avatar!.isNotEmpty
                          ? ClipOval(child: Image.network(p.avatar!, fit: BoxFit.cover, width: 96, height: 96,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 52, color: Color(0xFF94A3B8))))
                          : const Icon(Icons.person, size: 52, color: Color(0xFF0D584D)),
                    ),
                    if (_loadingProfile)
                      const Positioned.fill(child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    if (_profile != null)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 28, height: 28,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0D584D)),
                          child: const Icon(Icons.edit, color: Colors.white, size: 15),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p?.name ?? (_loadingProfile ? '...' : '—'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                p?.email ?? '—',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              if (p?.tier != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF0D584D).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                  child: Text(p!.tier!, style: const TextStyle(color: Color(0xFF0D584D), fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
              const SizedBox(height: 20),

              // Info card
              if (p != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Column(children: [
                    if (p.phone != null) _InfoRow(icon: Icons.phone_outlined, label: 'Điện thoại', value: p.phone!),
                    if (p.dob != null) _InfoRow(icon: Icons.cake_outlined, label: 'Ngày sinh', value: _fmt(p.dob!)),
                    if (p.gender != null) _InfoRow(icon: Icons.person_outline, label: 'Giới tính', value: p.genderLabel),
                    if (p.cccd != null) _InfoRow(icon: Icons.credit_card_outlined, label: 'CCCD', value: p.cccd!),
                    if (p.permanentAddress != null) _InfoRow(icon: Icons.location_on_outlined, label: 'Địa chỉ', value: p.permanentAddress!),
                    if (p.phone == null && p.dob == null && p.gender == null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(children: [
                          const Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          const Text('Nhấn "Chỉnh sửa" để cập nhật thông tin.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ]),
                      ),
                  ]),
                ),

              // Menu items
              _MenuItem(icon: Icons.history, title: 'Lịch sử đặt phòng', subtitle: 'Xem các phòng đã ở',
                  onTap: () => _push(const BookingHistoryScreen())),
              const SizedBox(height: 12),
              _MenuItem(icon: Icons.room_service_outlined, title: 'Đặt dịch vụ', subtitle: 'Dịch vụ bổ sung cho booking',
                  onTap: () => _push(const ServiceScreen())),
              const SizedBox(height: 12),
              _MenuItem(icon: Icons.favorite_outline, title: 'Yêu thích', subtitle: 'Phòng và dịch vụ đã lưu',
                  onTap: () => _push(const FavoritesScreen())),
              const SizedBox(height: 12),
              _MenuItem(icon: Icons.local_offer_outlined, title: 'Voucher', subtitle: 'Mã giảm giá của bạn',
                  onTap: () => _push(const VoucherScreen())),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoggingOut ? null : _logout,
                  icon: _isLoggingOut
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDC2626))))
                      : const Icon(Icons.logout, color: Color(0xFFDC2626)),
                  label: Text(_isLoggingOut ? 'Đang đăng xuất...' : 'Đăng xuất',
                      style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit Profile Sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile, required this.repo, required this.onSaved});
  final ProfileModel profile;
  final ProfileRepository repo;
  final ValueChanged<ProfileModel> onSaved;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  Uint8List? _pickedBytes;
  String? _pickedFileName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
    _phoneCtrl = TextEditingController(text: widget.profile.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() { _pickedBytes = bytes; _pickedFileName = picked.name; });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tên không được để trống.')));
      return;
    }
    setState(() => _saving = true);
    try {
      String? avatarUrl;
      if (_pickedBytes != null && _pickedFileName != null) {
        avatarUrl = await widget.repo.uploadAvatar(_pickedBytes!, _pickedFileName!);
      }
      final updated = await widget.repo.updateProfile(
        name: name,
        phone: phone.isEmpty ? null : phone,
        avatar: avatarUrl,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final onSaved = widget.onSaved;
      Navigator.pop(context);
      onSaved(updated);
      messenger.showSnackBar(const SnackBar(content: Text('Cập nhật hồ sơ thành công!')));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Chỉnh sửa hồ sơ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Avatar picker
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage: _pickedBytes != null
                      ? MemoryImage(_pickedBytes!)
                      : (widget.profile.avatar != null && widget.profile.avatar!.isNotEmpty
                          ? NetworkImage(widget.profile.avatar!) as ImageProvider
                          : null),
                  child: (_pickedBytes == null && (widget.profile.avatar == null || widget.profile.avatar!.isEmpty))
                      ? const Icon(Icons.person, size: 42, color: Color(0xFF0D584D))
                      : null,
                ),
                Container(
                  width: 26, height: 26,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0D584D)),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text('Nhấn để đổi ảnh', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 20),

          // Name field
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Họ và tên',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),

          // Phone field
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D584D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Lưu thay đổi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

String _fmt(String dateStr) {
  try {
    final parts = dateStr.split('T')[0].split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
  } catch (_) {}
  return dateStr;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        const Spacer(),
        Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13), textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: const Color(0xFF0D584D).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF0D584D), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        ]),
      ),
    );
  }
}
