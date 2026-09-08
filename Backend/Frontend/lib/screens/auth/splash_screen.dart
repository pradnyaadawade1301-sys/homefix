import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0, curve: Curves.easeIn));
    _controller.forward();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.checkLoginStatus();
    if (!mounted) return;

    if (!authProvider.isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // Restoring a session only confirms a stored token — fetch the profile to know
    // the role (technicians need the approval-status gate before reaching Home).
    final userProvider = context.read<UserProvider>();
    await userProvider.fetchProfile();
    if (!mounted) return;

    // checkLoginStatus() only restores the access token; the in-memory user
    // (needed as myId for things like starting a video call) has to come
    // from this profile fetch.
    if (userProvider.user != null) {
      authProvider.setCurrentUser(userProvider.user!);
    }

    if (userProvider.user?.role != 'technician') {
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 220,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor.withValues(alpha: 0.6)),
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
}