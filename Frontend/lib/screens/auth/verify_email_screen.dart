import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Shown right after signup when the user provided an email — sends a 6-digit
/// code via POST /auth/request-email-otp and verifies it via
/// POST /auth/verify-email-otp. Skippable: email verification doesn't block
/// using the app, it's a nice-to-have trust signal (see backend's
/// EmailVerified field).
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String destinationRoute;

  const VerifyEmailScreen({
    Key? key,
    required this.email,
    required this.destinationRoute,
  }) : super(key: key);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _otpController = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  String? _error;
  String? _info;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOtp(initial: true);
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendOtp({bool initial = false}) async {
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });
    final authProvider = context.read<AuthProvider>();
    final err = await authProvider.requestEmailOtp(widget.email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (err != null) {
        _error = err;
      } else {
        _info = initial ? 'Code sent to ${widget.email}' : 'Code re-sent to ${widget.email}';
        _startCooldown();
      }
    });
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });
    final authProvider = context.read<AuthProvider>();
    final err = await authProvider.verifyEmailOtp(widget.email, otp);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (err == null) {
      Navigator.of(context).pushNamedAndRemoveUntil(widget.destinationRoute, (route) => false);
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
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
                child: const Icon(Icons.mark_email_read_outlined, color: AppTheme.primaryColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Verify your email',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1F36),
                    ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Enter the 6-digit code sent to ',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  children: [
                    TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1F36))),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '------',
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
              ],
              if (_info != null && _error == null) ...[
                const SizedBox(height: 10),
                Text(_info!, style: TextStyle(color: Colors.green[700], fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Verify'),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: (_sending || _resendCooldown > 0) ? null : () => _sendOtp(),
                  child: Text(
                    _resendCooldown > 0 ? 'Resend code in ${_resendCooldown}s' : "Didn't get it? Resend code",
                    style: TextStyle(color: _resendCooldown > 0 ? Colors.grey : AppTheme.primaryColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}