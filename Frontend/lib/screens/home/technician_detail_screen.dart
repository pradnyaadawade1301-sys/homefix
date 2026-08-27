import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../services/service_locator.dart';
import '../booking/book_technician_screen.dart';
import '../consultation/searching_technician_screen.dart';

class TechnicianDetailScreen extends StatefulWidget {
  final Technician technician;
  final String? problemDescription;
  const TechnicianDetailScreen({Key? key, required this.technician, this.problemDescription}) : super(key: key);

  @override
  State<TechnicianDetailScreen> createState() => _TechnicianDetailScreenState();
}

class _TechnicianDetailScreenState extends State<TechnicianDetailScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  List<Review> _reviews = [];
  bool _loadingReviews = true;

  static const Color _accent = Color(0xFF0F766E);
  static const Color _accentDark = Color(0xFF115E59);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await context.read<ReviewService>().listForTechnician(widget.technician.id);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _loadingReviews = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingReviews = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.technician;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: _accent,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accent, _accentDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 14, offset: const Offset(0, 6))],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: CircleAvatar(
                              backgroundColor: _accent.withValues(alpha: 0.12),
                              child: Text(
                                t.name.isNotEmpty ? t.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _accent),
                              ),
                            ),
                          ),
                          if (t.isAvailable)
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              t.name.isNotEmpty ? t.name : 'Technician',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (t.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${t.categoryName} Technician', style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Container(
                  transform: Matrix4.translationValues(0, -24, 0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _StatChip(
                            icon: Icons.star_rounded,
                            iconColor: const Color(0xFFF5A623),
                            label: t.ratingCount > 0
                                ? '${t.ratingAvg.toStringAsFixed(1)} (${t.ratingCount} reviews)'
                                : 'No reviews yet',
                          ),
                          _StatChip(icon: Icons.work_history_outlined, iconColor: _accent, label: '${t.experienceYears} yrs experience'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (t.isAvailable ? AppTheme.successColor : Colors.grey).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: t.isAvailable ? AppTheme.successColor : Colors.grey,
                              child: Icon(
                                t.isAvailable ? Icons.check_rounded : Icons.close_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.isAvailable ? 'Available now' : 'Currently unavailable',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: t.isAvailable ? AppTheme.successColor : Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    t.isAvailable ? 'Ready to take new bookings' : 'Not accepting bookings right now',
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('About Me', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                            const SizedBox(height: 8),
                            Text(
                              'I am a professional ${t.categoryName} technician with ${t.experienceYears}+ years '
                              'of experience. Quality service and customer satisfaction is my priority.',
                              style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reviews (${t.ratingCount})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                            const SizedBox(height: 12),
                            if (_loadingReviews)
                              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                            else if (_reviews.isEmpty)
                              Text('No reviews yet', style: TextStyle(fontSize: 13, color: Colors.grey[500]))
                            else
                              ..._reviews.take(5).map((r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              i < r.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                              size: 16,
                                              color: const Color(0xFFF5A623),
                                            ),
                                          ),
                                        ),
                                        if (r.comment.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(r.comment, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                        ],
                                      ],
                                    ),
                                  )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: const [
                            _TrustBadge(icon: Icons.verified_user_outlined, title: 'Background', subtitle: 'Verified'),
                            _TrustBadge(icon: Icons.support_agent_rounded, title: '24/7', subtitle: 'Support'),
                            _TrustBadge(icon: Icons.lock_outline_rounded, title: 'Secure', subtitle: 'Booking'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: t.isAvailable
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BookTechnicianScreen(
                                        categoryId: t.categoryId,
                                        categoryName: t.categoryName,
                                        problemDescription: widget.problemDescription,
                                        preferredTechnician: t,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: t.isAvailable
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SearchingTechnicianScreen(
                                        categoryId: t.categoryId,
                                        categoryName: t.categoryName,
                                        note: widget.problemDescription,
                                        preferredTechnicianId: t.id,
                                        preferredTechnicianName: t.name,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          style: OutlinedButton.styleFrom(foregroundColor: _accent, side: const BorderSide(color: _accent, width: 1.4)),
                          icon: const Icon(Icons.videocam_rounded),
                          label: const Text('Video Call', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  const _StatChip({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _TrustBadge({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0F766E), size: 22),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1F36))),
        Text(subtitle, style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
      ],
    );
  }
}