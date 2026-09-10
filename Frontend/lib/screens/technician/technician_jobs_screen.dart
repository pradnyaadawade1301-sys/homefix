import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/booking_model.dart';
import '../../models/consultation_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../widgets/guided_tour.dart';
import '../consultation/incoming_consultation_screen.dart';
import '../consultation/upcoming_consultations_screen.dart';
import '../profile/profile_screen.dart';
import 'technician_settlement_screen.dart';
import 'technician_history_screen.dart';
import 'repeat_customers_screen.dart';
import '../chat/booking_chat_screen.dart';
import 'technician_job_detail_screen.dart';
import '../../providers/category_provider.dart';
import 'job_brief_card.dart';

class TechnicianJobsScreen extends StatefulWidget {
  const TechnicianJobsScreen({Key? key}) : super(key: key);

  static final GlobalKey<TechnicianJobsScreenState> globalKey = GlobalKey<TechnicianJobsScreenState>();

  @override
  State<TechnicianJobsScreen> createState() => TechnicianJobsScreenState();
}

class TechnicianJobsScreenState extends State<TechnicianJobsScreen> {
  int _navIndex = 0; // 0 = Jobs, 1 = Consultations, 2 = Settlement, 3 = History
  int _tabIndex = 0;

  List<ConsultationRequest> _pendingRequests = [];
  List<Consultation> _upcomingConsultations = [];
  Timer? _pollTimer;

  final _overviewKey = GlobalKey();
  final _filterKey = GlobalKey();
  final _jobsListKey = GlobalKey();
  final _customersNavKey = GlobalKey();
  final _profileNavKey = GlobalKey();
  final _settlementNavKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    WidgetsBinding.instance.addPostFrameCallback((_) => _startGuidedTourIfNeeded());
    _pollPendingRequests();
    _pollUpcoming();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _pollPendingRequests();
      _pollUpcoming();
      _pollBookings();
    });
  }

  Future<void> _startGuidedTourIfNeeded({bool force = false}) async {
    final steps = <GuidedTourStep>[
      GuidedTourStep(
        targetKey: _overviewKey,
        icon: Icons.pending_actions_rounded,
        title: 'Welcome to HomeFix!',
        description: 'Here\'s a quick overview of your active and completed jobs at a glance.',
      ),
      GuidedTourStep(
        targetKey: _filterKey,
        icon: Icons.filter_list_rounded,
        title: 'Active & All Jobs',
        description: 'Switch between jobs that need your attention right now and your full job history.',
      ),
      GuidedTourStep(
        targetKey: _jobsListKey,
        icon: Icons.work_outline_rounded,
        title: 'Your Jobs',
        description: 'Every job assigned to you shows up here — tap a card to see the full Job Brief, chat with the customer, and update the job status.',
      ),
      GuidedTourStep(
        targetKey: _customersNavKey,
        icon: Icons.people_alt_outlined,
        title: 'My Customers',
        description: 'See customers you\'ve worked with before, so repeat bookings are quick to spot.',
      ),
      GuidedTourStep(
        targetKey: _profileNavKey,
        icon: Icons.person_outline,
        title: 'Your Profile',
        description: 'Manage your KYC, bank details, service categories and settings here.',
      ),
      GuidedTourStep(
        targetKey: _settlementNavKey,
        icon: Icons.receipt_long_outlined,
        title: 'Settlement',
        description: 'Track your earnings, commission and payout status for every completed job here.',
      ),
    ];

    await GuidedTour.maybeShow(
      context,
      force: force,
      steps: steps,
      onTourEnd: () {
        if (mounted) setState(() => _navIndex = 0);
      },
    );
  }

  Future<void> replayGuidedTour() async {
    await GuidedTour.reset();
    if (!mounted) return;
    setState(() => _navIndex = 0);
    await _startGuidedTourIfNeeded(force: true);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollPendingRequests() async {
    try {
      final requests = await context.read<ConsultationProvider>().fetchPendingRequests();
      if (!mounted) return;
      setState(() => _pendingRequests = requests);
    } catch (_) {}
  }

  Future<void> _pollUpcoming() async {
    try {
      final upcoming = await context.read<ConsultationProvider>().fetchUpcomingList();
      if (!mounted) return;
      setState(() => _upcomingConsultations = upcoming);
    } catch (_) {}
  }

  Future<void> _load() async {
    final kyc = context.read<TechnicianKycProvider>();
    if (kyc.profile == null) {
      await kyc.loadMyProfile();
    }
    final technicianId = kyc.profile?.id;
    if (technicianId != null && mounted) {
      await context.read<BookingProvider>().fetchTechnicianBookings(technicianId);
    }
  }

  // Silent poll used by the periodic timer: same fetch as _load, but skips
  // the KYC profile lookup since that never changes after login. Runs every
  // 6s so new job assignments and status changes (e.g. "inspecting" ->
  // "on_the_way") show up without a manual pull-to-refresh.
  Future<void> _pollBookings() async {
    final technicianId = context.read<TechnicianKycProvider>().profile?.id;
    if (technicianId == null || !mounted) return;
    try {
      await context.read<BookingProvider>().fetchTechnicianBookings(technicianId);
    } catch (_) {}
  }

  Future<void> _confirmLogout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.techJobsLogoutTitle),
        content: Text(l10n.techJobsLogoutContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.techJobsCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.techJobsLogout, style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  String _navTitle(AppLocalizations l10n) {
    switch (_navIndex) {
      case 0:
        return l10n.techJobsNavTitleJobs;
      case 1:
        return l10n.techJobsNavTitleConsultations;
      case 2:
        return l10n.techJobsNavTitleSettlement;
      default:
        return l10n.techJobsNavTitleHistory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_navTitle(l10n)),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            key: _customersNavKey,
            tooltip: l10n.techJobsMyCustomersTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RepeatCustomersScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            key: _profileNavKey,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
            tooltip: l10n.techJobsLogoutTooltip,
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildJobsBody(),
          const UpcomingConsultationsScreen(embedded: true),
          const TechnicianSettlementScreen(),
          const TechnicianHistoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.work_outline_rounded), label: l10n.techJobsBottomNavJobs),
          BottomNavigationBarItem(icon: const Icon(Icons.event_available_outlined), label: l10n.techJobsBottomNavUpcoming),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined, key: _settlementNavKey), label: l10n.techJobsBottomNavSettlement),
          BottomNavigationBarItem(icon: const Icon(Icons.history_rounded), label: l10n.techJobsBottomNavHistory),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        final activeCount = provider.bookings
.where((b) => b.status == 'requested' || b.status == 'pending_technician' || b.status == 'accepted' || b.status == 'on_the_way' || b.status == 'arrived' || b.status == 'inspecting' || b.status == 'in_progress' || b.status == 'awaiting_estimate_approval')            .length;
        final completedCount = provider.bookings.where((b) => b.status == 'completed').length;
        return Container(
          key: _overviewKey,
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.techJobsWelcomeBack, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(l10n.techJobsWorkOverview, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _statPill(l10n.techJobsActive, activeCount.toString(), Icons.pending_actions_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _statPill(l10n.techJobsCompleted, completedCount.toString(), Icons.check_circle_outline_rounded)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statPill(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobsBody() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildGreetingHeader(),
        const SizedBox(height: 4),
        if (_pendingRequests.isNotEmpty) _buildConsultationBanner(),
        if (_upcomingConsultations.isNotEmpty) _buildUpcomingBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Row(
            key: _filterKey,
            children: [
              _FilterChip(label: l10n.techJobsActive, selected: _tabIndex == 0, onTap: () => setState(() => _tabIndex = 0)),
              const SizedBox(width: 8),
              _FilterChip(label: l10n.techJobsFilterAll, selected: _tabIndex == 1, onTap: () => setState(() => _tabIndex = 1)),
            ],
          ),
        ),
        Expanded(
          key: _jobsListKey,
          child: RefreshIndicator(
            onRefresh: () async {
              await _load();
              await _pollPendingRequests();
              await _pollUpcoming();
            },
            child: Consumer<BookingProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.bookings.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.bookings.isEmpty) {
                  return ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                      Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.errorColor.withValues(alpha: 0.6)),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          l10n.techJobsCouldNotLoad(provider.error ?? ''),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: OutlinedButton(onPressed: _load, child: Text(l10n.techJobsRetry)),
                      ),
                    ],
                  );
                }

                final jobs = _tabIndex == 0
                    ? provider.bookings
.where((b) => b.status == 'requested' || b.status == 'pending_technician' || b.status == 'accepted' || b.status == 'on_the_way' || b.status == 'arrived' || b.status == 'inspecting' || b.status == 'in_progress' || b.status == 'awaiting_estimate_approval')                        .toList()
                    : provider.bookings;

                if (jobs.isEmpty) {
                  return ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                      Icon(Icons.work_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _tabIndex == 0 ? l10n.techJobsNoActiveJobs : l10n.techJobsNoJobsYet,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          l10n.techJobsNewRequestsHint,
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: jobs.length,
                  itemBuilder: (context, i) => _JobCard(key: ValueKey(jobs[i].id), booking: jobs[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsultationBanner() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const IncomingConsultationScreen()),
        ).then((_) => _pollPendingRequests()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.videocam_rounded, color: Colors.white),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '${_pendingRequests.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pendingRequests.length == 1
                          ? l10n.techJobsLiveConsultationRequest
                          : l10n.techJobsLiveConsultationRequests(_pendingRequests.length.toString()),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(l10n.techJobsTapAcceptReject, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingBanner() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UpcomingConsultationsScreen()),
        ).then((_) => _pollUpcoming()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: const Icon(Icons.event_rounded, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _upcomingConsultations.length == 1
                          ? l10n.techJobsScheduledConsultation
                          : l10n.techJobsScheduledConsultations(_upcomingConsultations.length.toString()),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(l10n.techJobsTapConfirmDecline, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Booking booking;
  const _JobCard({super.key, required this.booking});

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      case 'in_progress':
      case 'accepted':
      case 'on_the_way':
      case 'arrived':
      case 'inspecting':
      case 'awaiting_estimate_approval':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final customer = booking.customer;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TechnicianJobDetailScreen(booking: booking),
      )),
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking.categoryName.isNotEmpty ? booking.categoryName : l10n.techJobsServiceRequestFallback,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(booking.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  booking.status,
                  style: TextStyle(fontSize: 11, color: _statusColor(booking.status), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (booking.problemDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(booking.problemDescription,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ],
          const SizedBox(height: 12),
          if (customer != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TechnicianJobDetailScreen(booking: booking),
                      )),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                            child: Text(
                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customer.name.isNotEmpty ? customer.name : l10n.techJobsCustomerFallback,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                if (booking.address != null)
                                  Text(
                                    booking.address!.formatted,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forum_outlined, color: AppTheme.primaryColor, size: 20),
                    tooltip: l10n.techJobsChatTooltip,
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BookingChatScreen(
                          bookingId: booking.id,
                          peerName: customer.name.isNotEmpty ? customer.name : l10n.techJobsCustomerFallback,
                        ),
                      ));
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          // Full Job Brief (guided answers, AI notes, attachments, and a
          // "what to bring" checklist) only shows once this job is actually
          // assigned to this technician — while it's still 'requested' they
          // only see the short problem_description above, enough to decide
          // Accept/Decline without the full detail cluttering the list.
          if (booking.status != 'requested' && booking.status != 'pending_technician' && (booking.jobBrief != null || booking.images.isNotEmpty)) ...[
            JobBriefCard(booking: booking),
            const SizedBox(height: 10),
          ],
          JobActionRow(booking: booking),
        ],
      ),
      ),
    );
  }
}

class JobActionRow extends StatelessWidget {
  final Booking booking;
  const JobActionRow({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<BookingProvider>();
    final kycProfile = context.watch<TechnicianKycProvider>().profile;

    switch (booking.status) {
      case 'requested':
      case 'pending_technician':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.4)),
                ),
                onPressed: kycProfile == null
                    ? null
                    : () => _confirmDecline(context, provider, booking.id, kycProfile.id),
                child: Text(l10n.techJobsDecline),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: kycProfile == null
                    ? null
                    : () => _acceptBooking(context, provider, booking, kycProfile.id),
                child: Text(l10n.techJobsAcceptJob),
              ),
            ),
          ],
        );
      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.directions_run_rounded, size: 18),
            onPressed: () => _runAction(
                context, () => provider.updateBookingStatus(booking.id, 'on_the_way', note: 'Technician is on the way')),
            label: Text(l10n.techJobsOnMyWay),
          ),
        );
      case 'on_the_way':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.home_rounded, size: 18),
            onPressed: kycProfile == null
                ? null
                : () => _runAction(context, () => provider.markArrived(booking.id, kycProfile.id)),
            label: Text(l10n.techJobsArrived),
          ),
        );
      case 'arrived':
        return _OtpVerifyRow(key: ValueKey('otp_${booking.id}'), booking: booking, technicianId: kycProfile?.id);
      case 'inspecting':
      case 'in_progress':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            onPressed: () => _showInvoiceDialog(context, provider, booking),
            label: Text(l10n.techJobsGenerateInvoiceComplete),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _runAction(BuildContext context, Future<void> Function() action) async {
    final provider = context.read<BookingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await action();
    if (provider.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(provider.error!)));
    }
  }

  /// Accepts the job — no separate estimate/price-negotiation step. The
  /// booking already carries a fixed price (the category's base price, set
  /// at booking creation — see BookingService.Create), so as soon as the
  /// technician accepts, the job card itself flips to the "accepted" state
  /// and shows the "I'm on my way" action next.
  Future<void> _acceptBooking(
    BuildContext context,
    BookingProvider provider,
    Booking booking,
    String technicianId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await provider.acceptBooking(booking.id, technicianId);
    if (provider.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(provider.error!)));
    }
  }

  /// Confirms before declining — this is a one-way action (the booking goes
  /// back into the pool for another technician), so it's worth one extra tap
  /// to avoid accidental taps costing the technician a job.
  Future<void> _confirmDecline(
    BuildContext context,
    BookingProvider provider,
    String bookingId,
    String technicianId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.techJobsDeclineTitle),
        content: Text(l10n.techJobsDeclineContent),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.techJobsCancel)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.techJobsDecline, style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(context, () => provider.declineBooking(bookingId, technicianId));
    }
  }
}

void _showInvoiceDialog(BuildContext context, BookingProvider provider, Booking booking) {
  showDialog(
    context: context,
    builder: (dialogContext) => _InvoiceDialog(provider: provider, booking: booking),
  );
}

/// "Generate invoice" dialog — final amount, plus an optional "Offer a
/// warranty" toggle with a free-form duration (a number + a Days/Months/Years
/// unit). There's no admin-configured whitelist: the technician judges each
/// job on its own merits (e.g. a compressor swap might earn 1 year, a gas
/// top-up 15 days), and the backend only sanity-bounds the total to a
/// positive number under 10 years — see BookingService.Complete.
class _InvoiceDialog extends StatefulWidget {
  final BookingProvider provider;
  final Booking booking;
  const _InvoiceDialog({required this.provider, required this.booking});

  @override
  State<_InvoiceDialog> createState() => _InvoiceDialogState();
}

enum _WarrantyUnit { days, months, years }

extension on _WarrantyUnit {
  String label(AppLocalizations l10n) {
    switch (this) {
      case _WarrantyUnit.days:
        return l10n.techJobsDays;
      case _WarrantyUnit.months:
        return l10n.techJobsMonths;
      case _WarrantyUnit.years:
        return l10n.techJobsYears;
    }
  }

  int get inDays {
    switch (this) {
      case _WarrantyUnit.days:
        return 1;
      case _WarrantyUnit.months:
        return 30;
      case _WarrantyUnit.years:
        return 365;
    }
  }
}

class _InvoiceDialogState extends State<_InvoiceDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _warrantyAmountController;
  bool _warrantyEnabled = false;
  _WarrantyUnit _warrantyUnit = _WarrantyUnit.months;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.booking.estimatedPrice ?? 0) > 0 ? (widget.booking.estimatedPrice ?? 0).toStringAsFixed(0) : '',
    );
    _warrantyAmountController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _warrantyAmountController.dispose();
    super.dispose();
  }

  /// Total warranty length in days, converted from whatever the technician
  /// typed + the unit they picked (e.g. "6" + Months -> 180). Returns null
  /// if the amount isn't a valid positive whole number.
  int? get _warrantyDaysValue {
    final amount = int.tryParse(_warrantyAmountController.text.trim());
    if (amount == null || amount <= 0) return null;
    return amount * _warrantyUnit.inDays;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.techJobsGenerateInvoiceTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.techJobsInvoiceHint,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₹ ',
                labelText: l10n.techJobsFinalAmount,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.techJobsOfferWarranty, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text(l10n.techJobsWarrantySubtitle, style: const TextStyle(fontSize: 11.5)),
              value: _warrantyEnabled,
              onChanged: (v) => setState(() => _warrantyEnabled = v),
            ),
            if (_warrantyEnabled) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _warrantyAmountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.techJobsDuration,
                        hintText: l10n.techJobsDurationHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<_WarrantyUnit>(
                      value: _warrantyUnit,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _WarrantyUnit.values
                          .map((u) => DropdownMenuItem(value: u, child: Text(u.label(l10n), style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (u) => setState(() => _warrantyUnit = u ?? _warrantyUnit),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.techJobsCancel),
        ),
        ElevatedButton(
          onPressed: () {
            final price = double.tryParse(_controller.text.trim());
            if (price == null || price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.techJobsEnterValidAmount)),
              );
              return;
            }
            if (_warrantyEnabled && _warrantyDaysValue == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.techJobsEnterValidWarranty)),
              );
              return;
            }
            Navigator.of(context).pop();
            widget.provider.completeBooking(
              widget.booking.id,
              price,
              warrantyEnabled: _warrantyEnabled,
              warrantyDays: _warrantyEnabled ? _warrantyDaysValue : null,
            );
          },
          child: Text(l10n.techJobsSendInvoice),
        ),
      ],
    );
  }
}

class _OtpVerifyRow extends StatefulWidget {
  final Booking booking;
  final String? technicianId;
  const _OtpVerifyRow({super.key, required this.booking, required this.technicianId});

  @override
  State<_OtpVerifyRow> createState() => _OtpVerifyRowState();
}

class _OtpVerifyRowState extends State<_OtpVerifyRow> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final otp = _controller.text.trim();
    if (widget.technicianId == null) return;
    if (otp.length != 4) {
      setState(() => _errorText = l10n.techJobsEnterOtp);
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final provider = context.read<BookingProvider>();
    final ok = await provider.verifyArrivalOtp(widget.booking.id, widget.technicianId!, otp);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (!ok) _errorText = provider.error ?? l10n.techJobsIncorrectOtp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.techJobsAskOtp,
          style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '----',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.techJobsVerify),
            ),
          ],
        ),
      ],
    );
  }
}