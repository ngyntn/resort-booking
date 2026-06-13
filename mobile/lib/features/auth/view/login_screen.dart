import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/providers/auth_provider.dart';
import 'package:mobile/features/auth/models/auth_model.dart';
import 'package:mobile/features/auth/repository/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  final _secureStorage = const FlutterSecureStorage();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  static const Color _brandGreen = Color(0xFF0D584D);
  static const Color _brandGreenSoft = Color(0xFF1F8D79);

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedEmail = prefs.getString('remembered_email');
    final rememberedPassword = await _secureStorage.read(key: 'remembered_password');
    if (!mounted) return;
    setState(() {
      _rememberMe = rememberedEmail != null && rememberedPassword != null;
      if (rememberedEmail != null) _emailController.text = rememberedEmail;
      if (rememberedPassword != null) _passwordController.text = rememberedPassword;
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authRepository.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remembered_email', _emailController.text.trim());
        await _secureStorage.write(key: 'remembered_password', value: _passwordController.text);
      } else {
        await prefs.remove('remembered_email');
        await _secureStorage.delete(key: 'remembered_password');
      }

      if (!mounted) return;
      await ref.read(authProvider.notifier).setLoggedIn(true);
      // GoRouter redirect will handle navigation to /home
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E2B2A), Color(0xFF03120F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 360,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _brandGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.hotel, color: _brandGreen, size: 28),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Welcome to Yasuo Resort',
                            style: TextStyle(
                              color: Color(0xFF07201E),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign in to continue your retreat with us.',
                            style: TextStyle(color: Color(0xFF6A7A82), fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration('Email', Icons.email_outlined),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter your email.';
                              if (!RegExp(r'^.+@.+\..+$').hasMatch(v.trim())) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _inputDecoration(
                              'Password',
                              Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please enter your password.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                activeColor: _brandGreen,
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                              ),
                              const Text(
                                'Remember me',
                                style: TextStyle(fontSize: 13, color: Color(0xFF485A66)),
                              ),
                            ],
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFDA4AF)),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Log In',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => context.push('/forgot-password'),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(color: _brandGreen, fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push('/signup'),
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: _brandGreenSoft,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
}
