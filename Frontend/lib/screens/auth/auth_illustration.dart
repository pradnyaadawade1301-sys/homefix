import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// A small decorative "house with floating service badges" illustration,
/// built entirely from Flutter shapes (no image assets needed). Meant to sit
/// in a top corner of an auth screen as a subtle accent — NOT as the main
/// hero graphic (the app logo stays the hero).
class AuthHouseCorner extends StatefulWidget {
  final double size;
  const AuthHouseCorner({Key? key, this.size = 110}) : super(key: key);

  @override
  State<AuthHouseCorner> createState() => _AuthHouseCornerState();
}

class _AuthHouseCornerState extends State<AuthHouseCorner> with TickerProviderStateMixin {
  late final AnimationController _c1;
  late final AnimationController _c2;
  late final Animation<double> _float1;
  late final Animation<double> _float2;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _c2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _float1 = Tween<double>(begin: -4, end: 2).animate(CurvedAnimation(parent: _c1, curve: Curves.easeInOut));
    _float2 = Tween<double>(begin: -3, end: 2).animate(CurvedAnimation(parent: _c2, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s * 0.92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Roof (triangle)
          Positioned(
            top: 0,
            left: s * 0.16,
            child: CustomPaint(
              size: Size(s * 0.68, s * 0.32),
              painter: _RoofPainter(color: AppTheme.primaryColor.withValues(alpha: 0.85)),
            ),
          ),
          // Wall + door + window
          Positioned(
            top: s * 0.30,
            left: s * 0.24,
            child: Container(
              width: s * 0.52,
              height: s * 0.42,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.8), width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: s * 0.16,
                      height: s * 0.24,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: s * 0.06,
                    left: s * 0.06,
                    child: Container(
                      width: s * 0.10,
                      height: s * 0.10,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.7), width: 1.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Floating service badge 1 (top-left, spanner)
          AnimatedBuilder(
            animation: _float1,
            builder: (context, child) => Transform.translate(offset: Offset(0, _float1.value), child: child),
            child: Positioned(
              top: -s * 0.04,
              left: -s * 0.06,
              child: _badge(s * 0.30, AppTheme.primaryColor, Icons.build_rounded),
            ),
          ),
          // Floating service badge 2 (right side, bolt)
          Positioned(
            top: s * 0.20,
            right: -s * 0.08,
            child: AnimatedBuilder(
              animation: _float2,
              builder: (context, child) => Transform.translate(offset: Offset(0, _float2.value), child: child),
              child: _badge(s * 0.24, AppTheme.tertiaryColor, Icons.bolt_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(double d, Color color, IconData icon) {
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: d * 0.5),
    );
  }
}

class _RoofPainter extends CustomPainter {
  final Color color;
  _RoofPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RoofPainter oldDelegate) => oldDelegate.color != color;
}