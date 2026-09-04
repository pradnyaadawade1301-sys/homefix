import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../services/service_locator.dart';
import '../../widgets/video_call_precheck_sheet.dart';
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
  Future<void> _pickScheduleTime(BuildContext context) async {
  final t = widget.technician;
  final now = DateTime.now();

  final preCheck = await showVideoCallPreCheckSheet(context, initialDescription: widget.problemDescription);
  if (preCheck == null || !context.mounted) return;

  final date = await showDatePicker(
    context: context,
    initialDate: now.add(const Duration(hours: 1)),
    firstDate: now,
    lastDate: now.add(const Duration(days: 30)),
  );
  if (date == null || !context.mounted) return;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
  );
  if (time == null || !context.mounted) return;

  final scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

  if (scheduledAt.isBefore(now.add(const Duration(minutes: 10)))) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please pick a time at least 10 minutes from now')),
    );
    return;
  }

  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SearchingTechnicianScreen(
      categoryId: t.categoryId,
      categoryName: t.categoryName,
      note: preCheck.note,
      area: preCheck.area,
      aiDiagnosisSessionId: preCheck.aiDiagnosisSessionId,
      preferredTechnicianId: t.id,
      preferredTechnicianName: t.name,
      scheduledAt: scheduledAt,
    ),
  ));
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
            expandedHeight: 296,
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
                child: Stack(
                  children: [
                    // Decorative touches so the banner reads as designed
                    // rather than a flat block of color, matching the
                    // reference's subtle background shapes.
                    Positioned(
                      top: -40,
                      right: -30,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
                      ),
                    ),
                    Positioned(
                      bottom: -60,
                      left: -40,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
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
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _accent),
                                  ),
                                ),
                              ),
                              if (t.isAvailable)
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  t.name.isNotEmpty ? t.name : 'Technician',
                                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (t.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, color: Colors.white, size: 19),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('${t.categoryName} Technician', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                t.ratingCount > 0 ? '${t.ratingAvg.toStringAsFixed(1)} (${t.ratingCount} reviews)' : 'No reviews yet',
                                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Container(width: 1, height: 11, color: Colors.white.withValues(alpha: 0.35)),
                              ),
                              Icon(Icons.work_history_outlined, color: Colors.white.withValues(alpha: 0.9), size: 15),
                              const SizedBox(width: 4),
                              Text(
                                '${t.experienceYears} yrs Experience',
                                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: t.isAvailable ? AppTheme.successColor : Colors.grey[300],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    t.isAvailable ? 'Available Now' : 'Currently unavailable',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    t.isAvailable ? 'Ready to take new bookings' : 'Not accepting bookings',
                                    style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.75)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  transform: Matrix4.translationValues(0, -36, 0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _TrustBadge(icon: Icons.verified_user_outlined, title: 'Verified', subtitle: 'Background'),
                            _TrustBadge(icon: Icons.support_agent_rounded, title: '24/7', subtitle: 'Support'),
                            _TrustBadge(icon: Icons.thumb_up_outlined, title: '100%', subtitle: 'Reliability'),
                            _TrustBadge(icon: Icons.lock_outline_rounded, title: 'Secure', subtitle: 'Bookings'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const _ActionButtonLabel(
                            icon: Icons.calendar_month_rounded,
                            title: 'Book Now',
                            subtitle: 'Confirm & get your service',
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: t.isAvailable
                              ? () async {
                                  final preCheck = await showVideoCallPreCheckSheet(
                                    context,
                                    initialDescription: widget.problemDescription,
                                  );
                                  if (preCheck == null || !context.mounted) return;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SearchingTechnicianScreen(
                                        categoryId: t.categoryId,
                                        categoryName: t.categoryName,
                                        note: preCheck.note,
                                        area: preCheck.area,
                                        aiDiagnosisSessionId: preCheck.aiDiagnosisSessionId,
                                        preferredTechnicianId: t.id,
                                        preferredTechnicianName: t.name,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            side: const BorderSide(color: _accent, width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const _ActionButtonLabel(
                            icon: Icons.videocam_rounded,
                            title: 'Video Call',
                            subtitle: 'Talk to me now',
                            color: _accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _pickScheduleTime(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[400]!, width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _ActionButtonLabel(
                            icon: Icons.event_available_outlined,
                            title: 'Schedule for Later',
                            subtitle: 'Pick a convenient time',
                            color: Colors.grey[700]!,
                          ),
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

class _ActionButtonLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final Color? color;
  const _ActionButtonLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.filled = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : (color ?? Colors.black87);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: fg),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: fg)),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11.5, color: filled ? Colors.white.withValues(alpha: 0.85) : fg.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ],
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
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF0F766E), size: 20),
        ),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1F36))),
        Text(subtitle, style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
      ],
    );
  }
}