import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/google_auth_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _identifierController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      await _routeAfterLogin();
    } else if (authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error!), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  /// "Continue with Google" — opens the native account picker, then sends
  /// the resulting ID token to our backend for verification. A cancelled
  /// picker (user backs out) is not an error, so it just silently no-ops.
  void _handleGoogleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _isGoogleLoading = true);

    String? idToken;
    try {
      idToken = await GoogleAuthHelper.signIn();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    if (idToken == null) {
      // User cancelled the account picker.
      if (mounted) setState(() => _isGoogleLoading = false);
      return;
    }

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginWithGoogle(idToken);

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (success) {
      await _routeAfterLogin();
    } else if (authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error!), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  /// Shared post-login routing for both password and Google sign-in —
  /// technicians go through their KYC/status gate, customers go straight
  /// home.
  Future<void> _routeAfterLogin() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentUser?.role == 'technician') {
      final kycProvider = context.read<TechnicianKycProvider>();
      await kycProvider.loadMyProfile();
      if (!mounted) return;
      final profile = kycProvider.profile;
      if (profile == null) {
        Navigator.of(context).pushReplacementNamed('/technician-kyc');
      } else if (profile.isApproved) {
        Navigator.of(context).pushReplacementNamed('/technician-home');
      } else {
        Navigator.of(context).pushReplacementNamed('/technician-status');
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                child: Image.asset(
                  'assets/images/login_hero.png',
                  width: double.infinity,
                  height: 240,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: 240,
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    child: const Icon(Icons.home_repair_service_rounded, size: 64, color: AppTheme.primaryColor),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1F36),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to book trusted home services',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _identifierController,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              hintText: 'Email or phone number',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email or phone number required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Forgot password flow coming soon')),
                                );
                              },
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              return SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: authProvider.isLoading ? null : _handleLogin,
                                  child: authProvider.isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('Sign In'),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded, size: 20),
                                          ],
                                        ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey[300])),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('OR', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              Expanded(child: Divider(color: Colors.grey[300])),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[300]!),
                                backgroundColor: Colors.white,
                              ),
                              child: _isGoogleLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.primaryColor),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CustomPaint(painter: _GoogleLogoPainter()),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Continue with Google',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1F36)),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, color: AppTheme.successColor, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Trusted by thousands of users',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                Text(
                                  'Verified professionals • Secure bookings • 24/7 Support',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SignupScreen()),
                              );
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the official 4-colour Google "G" logo with vector paths (no PNG
/// asset needed) — used on the "Continue with Google" button so it always
/// renders correctly instead of falling back to a plain red "G" icon when
/// no asset is bundled.
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 18.0;
    canvas.save();
    canvas.scale(scale);

    final blue = Path()
      ..moveTo(17.6400, 9.2045)
      ..cubicTo(17.6400, 8.5664, 17.5827, 7.9527, 17.4764, 7.3636)
      ..lineTo(9.0000, 7.3636)
      ..lineTo(9.0000, 10.8450)
      ..lineTo(13.8436, 10.8450)
      ..cubicTo(13.6350, 11.9700, 13.0009, 12.9232, 12.0477, 13.5614)
      ..lineTo(12.0477, 15.8195)
      ..lineTo(14.9564, 15.8195)
      ..cubicTo(16.6582, 14.2527, 17.6400, 11.9454, 17.6400, 9.2045)
      ..close();
    canvas.drawPath(blue, Paint()..color = const Color(0xFF4285F4));

    final green = Path()
      ..moveTo(9.0000, 18.0000)
      ..cubicTo(11.4300, 18.0000, 13.4673, 17.1940, 14.9564, 15.8195)
      ..lineTo(12.0477, 13.5614)
      ..cubicTo(11.2413, 14.1014, 10.2109, 14.4204, 9.0000, 14.4204)
      ..cubicTo(6.6560, 14.4204, 4.6718, 12.8373, 3.9640, 10.7100)
      ..lineTo(0.9573, 10.7100)
      ..lineTo(0.9573, 13.0418)
      ..cubicTo(2.4382, 15.9832, 5.4818, 18.0000, 9.0000, 18.0000)
      ..close();
    canvas.drawPath(green, Paint()..color = const Color(0xFF34A853));

    final yellow = Path()
      ..moveTo(3.9640, 10.7100)
      ..cubicTo(3.7840, 10.1700, 3.6818, 9.5932, 3.6818, 9.0000)
      ..cubicTo(3.6818, 8.4068, 3.7841, 7.8300, 3.9641, 7.2900)
      ..lineTo(3.9641, 4.9582)
      ..lineTo(0.9573, 4.9582)
      ..cubicTo(0.3477, 6.1732, 0.0000, 7.5477, 0.0000, 9.0000)
      ..cubicTo(0.0000, 10.4523, 0.3477, 11.8268, 0.9573, 13.0418)
      ..lineTo(3.9640, 10.7100)
      ..close();
    canvas.drawPath(yellow, Paint()..color = const Color(0xFFFBBC05));

    final red = Path()
      ..moveTo(9.0000, 3.5795)
      ..cubicTo(10.3214, 3.5795, 11.5077, 4.0336, 12.4405, 4.9255)
      ..lineTo(15.0218, 2.3441)
      ..cubicTo(13.4632, 0.8918, 11.4260, 0.0000, 9.0000, 0.0000)
      ..cubicTo(5.4818, 0.0000, 2.4382, 2.0168, 0.9573, 4.9582)
      ..lineTo(3.9640, 7.2900)
      ..cubicTo(4.6718, 5.1627, 6.6560, 3.5795, 9.0000, 3.5795)
      ..close();
    canvas.drawPath(red, Paint()..color = const Color(0xFFEA4335));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}