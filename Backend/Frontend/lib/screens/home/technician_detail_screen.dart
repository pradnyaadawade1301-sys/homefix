import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../services/service_locator.dart';
import '../../utils/working_hours.dart';
import '../../widgets/video_call_precheck_sheet.dart';
import '../../l10n/app_localizations.dart';
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
      SnackBar(content: Text(AppLocalizations.of(context)!.techDetailPickTimeAtLeast10Min)),
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
    final l10n = AppLocalizations.of(context)!;
    final t = widget.technician;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
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
                        // Top-aligned (not centered) so the bottom of the teal
                        // header stays empty — that's the zone the first card
                        // overlaps into (see the sheet's upward transform).
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
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
                                  t.name.isNotEmpty ? t.name : l10n.techDetailTechnicianFallback,
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
                          Text(l10n.techDetailRoleSuffix(t.categoryName), style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                t.ratingCount > 0 ? l10n.techDetailRatingReviews(t.ratingAvg.toStringAsFixed(1), '${t.ratingCount}') : l10n.techDetailNoReviewsYet,
                                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Container(width: 1, height: 11, color: Colors.white.withValues(alpha: 0.35)),
                              ),
                              Icon(Icons.work_history_outlined, color: Colors.white.withValues(alpha: 0.9), size: 15),
                              const SizedBox(width: 4),
                              Text(
                                l10n.techDetailYearsExperience('${t.experienceYears}'),
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
                                    t.isAvailable ? l10n.techDetailAvailableNow : l10n.techDetailCurrentlyUnavailable,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    t.isAvailable ? l10n.techDetailReadyForBookings : l10n.techDetailNotAcceptingBookings,
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
                  // Pull the whole sheet up so its rounded top and the first
                  // card ride onto the empty bottom strip of the header banner
                  // (reference design). A transform, not a margin, so it never
                  // asserts — and the header content is top-aligned so nothing
                  // important sits where the card lands.
                  transform: Matrix4.translationValues(0, -56, 0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 8))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Text(l10n.techDetailAboutMe, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.techDetailAboutMeBody(t.categoryName, '${t.experienceYears}'),
                              style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _WorkingHoursCard(hours: t.workingHours),
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
                            Row(
                              children: [
                                const Icon(Icons.star_outline_rounded, size: 18, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Text(l10n.techDetailReviewsCount('${t.ratingCount}'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_loadingReviews)
                              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                            else if (_reviews.isEmpty)
                              Text(l10n.techDetailNoReviewsYet, style: TextStyle(fontSize: 13, color: Colors.grey[500]))
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
                          children: [
                            _TrustBadge(icon: Icons.verified_user_outlined, title: l10n.techDetailVerified, subtitle: l10n.techDetailBackground),
                            _TrustBadge(icon: Icons.support_agent_rounded, title: l10n.techDetailSupport247, subtitle: l10n.techDetailSupport),
                            _TrustBadge(icon: Icons.thumb_up_outlined, title: l10n.techDetailReliability100, subtitle: l10n.techDetailReliability),
                            _TrustBadge(icon: Icons.lock_outline_rounded, title: l10n.techDetailSecure, subtitle: l10n.techDetailBookings),
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
                          child: _ActionButtonLabel(
                            icon: Icons.calendar_month_rounded,
                            title: l10n.techDetailBookNow,
                            subtitle: l10n.techDetailConfirmGetService,
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
                          child: _ActionButtonLabel(
                            icon: Icons.videocam_rounded,
                            title: l10n.techDetailVideoCall,
                            subtitle: l10n.techDetailTalkToMeNow,
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
                            title: l10n.techDetailScheduleForLater,
                            subtitle: l10n.techDetailPickConvenientTime,
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

/// Collapsible weekly-schedule card. Collapsed, it shows just today's hours and
/// a live "Open now / Opens…" pill; tapping expands the full week with today
/// highlighted. Display-only — the customer can still book outside these hours.
class _WorkingHoursCard extends StatefulWidget {
  final Map<String, DayHours?> hours;
  const _WorkingHoursCard({required this.hours});

  @override
  State<_WorkingHoursCard> createState() => _WorkingHoursCardState();
}

class _WorkingHoursCardState extends State<_WorkingHoursCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hours = widget.hours;
    if (!hasAnyWorkingDay(hours)) return const SizedBox.shrink();

    final now = DateTime.now();
    final todayKey = weekdayKeyFor(now);
    final today = hours[todayKey];
    final open = isOpenNow(hours, now);
    final statusText = open ? l10n.techDetailOpenNow : (nextOpenLabel(hours, now) ?? l10n.techDetailClosed);
    final todaySummary = today == null ? l10n.techDetailClosedToday : l10n.techDetailTodaySummary(today.openLabel, today.closeLabel);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule_rounded, size: 20, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.techDetailWorkingHours, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(todaySummary, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusPill(open, statusText),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Column(
                      children: [
                        Divider(height: 1, color: Colors.grey[200]),
                        const SizedBox(height: 4),
                        ...kWeekdayKeys.map((k) => _dayRow(k, k == todayKey)),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(bool open, String text) {
    final c = open ? AppTheme.successColor : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }

  Widget _dayRow(String k, bool isToday) {
    final v = widget.hours[k];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isToday ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              kWeekdayLabels[k]!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? AppTheme.primaryColor : Colors.grey[800],
              ),
            ),
          ),
          Text(
            v == null ? AppLocalizations.of(context)!.techDetailClosed : '${v.openLabel} – ${v.closeLabel}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: v == null ? Colors.grey[500] : (isToday ? AppTheme.primaryColor : Colors.grey[800]),
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