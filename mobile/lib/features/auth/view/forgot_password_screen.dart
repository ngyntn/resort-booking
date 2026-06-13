import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/models/auth_model.dart';
import 'package:mobile/features/auth/repository/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _repo = AuthRepository();
  int _step = 0;
  bool _isLoading = false;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  String? _resetCode;

  static const _brandGreen = Color(0xFF0D584D);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !RegExp(r'^.+@.+\..+$').hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _repo.sendOtp(email);
      setState(() => _step = 1);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to send OTP. Please try again.');
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
      _resetCode = await _repo.verifyForgotPassword(
        email: _emailCtrl.text.trim(),
        otp: otp,
      );
      setState(() => _step = 2);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final password = _passwordCtrl.text;
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != _confirmPwCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _repo.resetPassword(
        email: _emailCtrl.text.trim(),
        code: _resetCode!,
        password: password,
      );
      setState(() => _step = 3);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Password reset failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Forgot Password'),
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
              title: const Text('Email'),
              isActive: _step >= 0,
              state: _step > 0 ? StepState.complete : StepState.indexed,
              content: _buildEmailStep(),
            ),
            Step(
              title: const Text('OTP'),
              isActive: _step >= 1,
              state: _step > 1 ? StepState.complete : StepState.indexed,
              content: _buildOtpStep(),
            ),
            Step(
              title: const Text('Password'),
              isActive: _step >= 2,
              state: _step > 2 ? StepState.complete : StepState.indexed,
              content: _buildNewPasswordStep(),
            ),
            Step(
              title: const Text('Done'),
              isActive: _step >= 3,
              state: _step == 3 ? StepState.complete : StepState.indexed,
              content: _buildSuccessStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Enter your registered email address to receive an OTP.',
          style: TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (_error != null) _errorBanner(_error!),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('Email Address', Icons.email_outlined),
        ),
        const SizedBox(height: 16),
        _primaryButton('Send OTP', _isLoading ? null : _sendOtp),
        const SizedBox(height: 16),
      ],
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
        _primaryButton('Verify OTP', _isLoading ? null : _verifyOtp),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _sendOtp,
            child: const Text('Resend OTP', style: TextStyle(color: _brandGreen)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Enter your new password.',
          style: TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (_error != null) _errorBanner(_error!),
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePass,
          decoration: _inputDecoration(
            'New Password',
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(_obscurePass
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmPwCtrl,
          obscureText: _obscureConfirm,
          decoration: _inputDecoration(
            'Confirm New Password',
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _primaryButton('Reset Password', _isLoading ? null : _resetPassword),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF0D584D).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_open_outlined, size: 40, color: _brandGreen),
        ),
        const SizedBox(height: 16),
        const Text(
          'Password Reset!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your password has been reset successfully.\nYou can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 24),
        _primaryButton('Back to Login', () => context.go('/login')),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading && onPressed == null
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
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
