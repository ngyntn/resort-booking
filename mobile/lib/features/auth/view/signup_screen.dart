import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/features/auth/models/auth_model.dart';
import 'package:mobile/features/auth/repository/auth_repository.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _repo = AuthRepository();
  int _step = 0;
  bool _isLoading = false;
  String? _error;

  // Step 1 - Form
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cccdCtrl = TextEditingController();
  final _issuedPlaceCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  DateTime? _dob;
  DateTime? _issuedAt;
  String _gender = 'male';
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Step 2 - OTP
  final _otpCtrl = TextEditingController();

  static const _brandGreen = Color(0xFF0D584D);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPwCtrl.dispose();
    _phoneCtrl.dispose();
    _cccdCtrl.dispose();
    _issuedPlaceCtrl.dispose();
    _addressCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      setState(() => _error = 'Please select date of birth.');
      return;
    }
    if (_issuedAt == null) {
      setState(() => _error = 'Please select identity issued date.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _repo.signUp(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        phone: _phoneCtrl.text,
        cccd: _cccdCtrl.text,
        dob: DateFormat('yyyy-MM-dd').format(_dob!),
        gender: _gender,
        identityIssuedAt: DateFormat('yyyy-MM-dd').format(_issuedAt!),
        identityIssuedPlace: _issuedPlaceCtrl.text,
        permanentAddress: _addressCtrl.text,
      );
      setState(() => _step = 1);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Sign up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the 6-digit OTP.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _repo.verifyAccount(email: _emailCtrl.text, otp: otp);
      setState(() => _step = 2);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _repo.sendOtp(_emailCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent successfully.')),
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate({required bool isDob}) async {
    final now = DateTime.now();
    final initial = isDob ? DateTime(now.year - 20, 1, 1) : DateTime(now.year - 5, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: isDob ? (_dob ?? initial) : (_issuedAt ?? initial),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isDob) {
          _dob = picked;
        } else {
          _issuedAt = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Stepper(
          currentStep: _step,
          type: StepperType.horizontal,
          controlsBuilder: (context, details) => const SizedBox.shrink(),
          steps: [
            Step(
              title: const Text('Info'),
              isActive: _step >= 0,
              state: _step > 0 ? StepState.complete : StepState.indexed,
              content: _buildFormStep(),
            ),
            Step(
              title: const Text('Verify'),
              isActive: _step >= 1,
              state: _step > 1 ? StepState.complete : StepState.indexed,
              content: _buildOtpStep(),
            ),
            Step(
              title: const Text('Done'),
              isActive: _step >= 2,
              state: _step == 2 ? StepState.complete : StepState.indexed,
              content: _buildSuccessStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (_error != null) _errorBanner(_error!),
          _field(_nameCtrl, 'Full Name', Icons.person_outline, validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            return null;
          }),
          const SizedBox(height: 12),
          _field(_emailCtrl, 'Email', Icons.email_outlined,
              keyboardType: TextInputType.emailAddress, validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (!RegExp(r'^.+@.+\..+$').hasMatch(v.trim())) return 'Invalid email';
            return null;
          }),
          const SizedBox(height: 12),
          _field(_passwordCtrl, 'Password', Icons.lock_outline,
              obscure: _obscurePass,
              suffixIcon: IconButton(
                icon: Icon(_obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ), validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (v.length < 6) return 'Min 6 characters';
            return null;
          }),
          const SizedBox(height: 12),
          _field(_confirmPwCtrl, 'Confirm Password', Icons.lock_outline,
              obscure: _obscureConfirm,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ), validator: (v) {
            if (v != _passwordCtrl.text) return 'Passwords do not match';
            return null;
          }),
          const SizedBox(height: 12),
          _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
              keyboardType: TextInputType.phone, validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            return null;
          }),
          const SizedBox(height: 12),
          _field(_cccdCtrl, 'CCCD / National ID', Icons.badge_outlined,
              keyboardType: TextInputType.number, validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (v.trim().length != 12) return 'Must be 12 digits';
            return null;
          }),
          const SizedBox(height: 12),
          // Date of Birth
          GestureDetector(
            onTap: () => _pickDate(isDob: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, color: Color(0xFF64748B)),
                  const SizedBox(width: 12),
                  Text(
                    _dob == null
                        ? 'Date of Birth'
                        : DateFormat('dd/MM/yyyy').format(_dob!),
                    style: TextStyle(
                      color: _dob == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Gender
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: InputDecoration(
              labelText: 'Gender',
              prefixIcon: const Icon(Icons.wc_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? 'male'),
          ),
          const SizedBox(height: 12),
          // Identity Issued At
          GestureDetector(
            onTap: () => _pickDate(isDob: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: Color(0xFF64748B)),
                  const SizedBox(width: 12),
                  Text(
                    _issuedAt == null
                        ? 'Identity Issued Date'
                        : DateFormat('dd/MM/yyyy').format(_issuedAt!),
                    style: TextStyle(
                      color: _issuedAt == null
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _field(_issuedPlaceCtrl, 'Identity Issued Place', Icons.location_city_outlined,
              validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            return null;
          }),
          const SizedBox(height: 12),
          _field(_addressCtrl, 'Permanent Address', Icons.home_outlined,
              maxLines: 2, validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            return null;
          }),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit OTP sent to ${_emailCtrl.text}',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (_error != null) _errorBanner(_error!),
        TextFormField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '------',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _brandGreen, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _resendOtp,
            child: const Text('Resend OTP', style: TextStyle(color: _brandGreen)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF0D584D).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, size: 40, color: _brandGreen),
        ),
        const SizedBox(height: 16),
        const Text(
          'Account Created!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your account has been verified successfully.\nYou can now sign in.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Go to Login', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brandGreen, width: 2),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
    );
  }
}
