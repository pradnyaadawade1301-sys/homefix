import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import 'reset_password_screen.dart';

/// Step 1 of the forgot-password flow — just an email field. On submit, sends
/// a 6-digit code via POST /auth/forgot-password and hands off to
/// ResetPasswordScreen to enter the code + a new password. Mirrors
/// VerifyEmailScreen's OTP pattern, just for password reset instead of
/// signup verification.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    final email = _emailController.text.trim();
    final authProvider = context.read<AuthProvider>();
    final err = await authProvider.forgotPassword(email);
    if (!mounted) return;
    setState(() => _sending = false);

    if (err == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)),
      );
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryColor, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  'Forgot password?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1F36),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the email on your account and we\u2019ll send you a 6-digit code to reset your password.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter your email';
                    if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    child: _sending
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Text('Send Reset Code'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}