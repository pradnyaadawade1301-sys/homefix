import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../models/consultation_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../services/booking_service.dart';
import '../../widgets/guided_tour.dart';
import '../consultation/incoming_consultation_screen.dart';
import '../consultation/upcoming_consultations_screen.dart';
import '../profile/profile_screen.dart';
import 'technician_settlement_screen.dart';
import 'technician_history_screen.dart';
import 'repeat_customers_screen.dart';
import '../chat/booking_chat_screen.dart';
import 'technician_estimate_screen.dart';
import 'technician_job_detail_screen.dart';
import '../../providers/category_provider.dart';

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

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to see your jobs.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: AppTheme.errorColor)),
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

  String _navTitle() {
    switch (_navIndex) {
      case 0:
        return 'My Jobs';
      case 1:
        return 'Consultations';
      case 2:
        return 'Settlement';
      default:
        return 'History';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_navTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            key: _customersNavKey,
            tooltip: 'My Customers',
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
            tooltip: 'Log out',
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
          const BottomNavigationBarItem(icon: Icon(Icons.work_outline_rounded), label: 'Jobs'),
          const BottomNavigationBarItem(icon: Icon(Icons.event_available_outlined), label: 'Upcoming'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined, key: _settlementNavKey), label: 'Settlement'),
          const BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader() {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        final activeCount = provider.bookings
            .where((b) => b.status == 'accepted' || b.status == 'on_the_way' || b.status == 'arrived' || b.status == 'inspecting' || b.status == 'in_progress' || b.status == 'awaiting_estimate_approval')
            .length;
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
              const Text('Welcome back 👋', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Here\'s your work overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _statPill('Active', activeCount.toString(), Icons.pending_actions_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _statPill('Completed', completedCount.toString(), Icons.check_circle_outline_rounded)),
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
    return Column(
      children: [
        _buildGreetingHeader(),
        const SizedBox(height: 4),
        if (_pendingRequests.isNotEmpty) _buildConsultationBanner(),
        if (_upcomingConsultations.isNotEmpty) _buildUpcomingBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              key: _filterKey,
              children: [
                _FilterChip(label: 'Active', selected: _tabIndex == 0, onTap: () => setState(() => _tabIndex = 0)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Book Now', selected: _tabIndex == 1, onTap: () => setState(() => _tabIndex = 1)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Video Call', selected: _tabIndex == 2, onTap: () => setState(() => _tabIndex = 2)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Schedule for later', selected: _tabIndex == 3, onTap: () => setState(() => _tabIndex = 3)),
                const SizedBox(width: 8),
                _FilterChip(label: 'All', selected: _tabIndex == 4, onTap: () => setState(() => _tabIndex = 4)),
              ],
            ),
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
                          "Couldn't load your jobs: ${provider.error}",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ),
                    ],
                  );
                }

                // Book Now = an immediate request (no future schedule, no
                // video consultation beforehand). Video Call = a booking
                // that had a video consultation first (jobBrief.hasVideo).
                // Schedule for later = customer picked a future date/time.
                final jobs = switch (_tabIndex) {
                  0 => provider.bookings
                      .where((b) => b.status == 'accepted' || b.status == 'on_the_way' || b.status == 'arrived' || b.status == 'inspecting' || b.status == 'in_progress' || b.status == 'awaiting_estimate_approval')
                      .toList(),
                  1 => provider.bookings.where((b) => b.jobBrief?.hasVideo != true && b.scheduledAt == null).toList(),
                  2 => provider.bookings.where((b) => b.jobBrief?.hasVideo == true).toList(),
                  3 => provider.bookings.where((b) => b.scheduledAt != null).toList(),
                  _ => provider.bookings,
                };

                if (jobs.isEmpty) {
                  final emptyTitle = switch (_tabIndex) {
                    0 => 'No active jobs right now',
                    1 => 'No Book Now requests',
                    2 => 'No Video Call jobs',
                    3 => 'No jobs scheduled for later',
                    _ => 'No jobs yet',
                  };
                  return ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                      Icon(Icons.work_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          emptyTitle,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'New customer requests will show up here',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: jobs.length,
                  itemBuilder: (context, i) => _JobCard(booking: jobs[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsultationBanner() {
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
                          ? '1 live consultation request'
                          : '${_pendingRequests.length} live consultation requests',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    const Text('Tap to accept or reject', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                          ? '1 scheduled consultation'
                          : '${_upcomingConsultations.length} scheduled consultations',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    const Text('Tap to confirm or decline slots', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
  const _JobCard({required this.booking});

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
    final customer = booking.customer;
    return Container(
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
                  booking.categoryName.isNotEmpty ? booking.categoryName : 'Service request',
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
                                Text(customer.name.isNotEmpty ? customer.name : 'Customer',
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
                    tooltip: 'Chat with customer',
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BookingChatScreen(
                          bookingId: booking.id,
                          peerName: customer.name.isNotEmpty ? customer.name : 'Customer',
                        ),
                      ));
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          JobActionRow(booking: booking),
        ],
      ),
    );
  }
}

class JobActionRow extends StatelessWidget {
  final Booking booking;
  const JobActionRow({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BookingProvider>();
    final kycProfile = context.watch<TechnicianKycProvider>().profile;

    switch (booking.status) {
      case 'requested':
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
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: kycProfile == null
                    ? null
                    : () => _runAction(context, () => provider.acceptBooking(booking.id, kycProfile.id)),
                child: const Text('Accept job'),
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
            label: const Text("I'm on my way"),
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
            label: const Text("I've arrived"),
          ),
        );
      case 'arrived':
        return _OtpVerifyRow(booking: booking, technicianId: kycProfile?.id);
      case 'inspecting':
      case 'in_progress':
        return _EstimateAwareAction(booking: booking, technicianId: kycProfile?.id);
      case 'awaiting_estimate_approval':
        return _WaitingOnEstimateRow(booking: booking);
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

  /// Confirms before declining — this is a one-way action (the booking goes
  /// back into the pool for another technician), so it's worth one extra tap
  /// to avoid accidental taps costing the technician a job.
  Future<void> _confirmDecline(
    BuildContext context,
    BookingProvider provider,
    String bookingId,
    String technicianId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline this job?'),
        content: const Text("We'll find another technician for this booking. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Decline', style: TextStyle(color: AppTheme.errorColor)),
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
  String get label {
    switch (this) {
      case _WarrantyUnit.days:
        return 'Days';
      case _WarrantyUnit.months:
        return 'Months';
      case _WarrantyUnit.years:
        return 'Years';
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
    return AlertDialog(
      title: const Text('Generate invoice'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the final amount the customer should pay. This is sent to them immediately as the amount due.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                labelText: 'Final amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offer a warranty', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Customer can raise a free revisit within this window', style: TextStyle(fontSize: 11.5)),
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
                      decoration: const InputDecoration(
                        labelText: 'Duration',
                        hintText: 'e.g. 6',
                        border: OutlineInputBorder(),
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
                          .map((u) => DropdownMenuItem(value: u, child: Text(u.label, style: const TextStyle(fontSize: 13))))
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final price = double.tryParse(_controller.text.trim());
            if (price == null || price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid amount')),
              );
              return;
            }
            if (_warrantyEnabled && _warrantyDaysValue == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid warranty duration')),
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
          child: const Text('Send invoice'),
        ),
      ],
    );
  }
}

class _EstimateAwareAction extends StatefulWidget {
  final Booking booking;
  final String? technicianId;
  const _EstimateAwareAction({required this.booking, required this.technicianId});

  @override
  State<_EstimateAwareAction> createState() => _EstimateAwareActionState();
}

class _EstimateAwareActionState extends State<_EstimateAwareAction> {
  late Future<BookingEstimate?> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<BookingService>().getLatestEstimate(widget.booking.id);
  }

  void _refresh() {
    setState(() {
      _future = context.read<BookingService>().getLatestEstimate(widget.booking.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BookingProvider>();

    return FutureBuilder<BookingEstimate?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final estimate = snapshot.data;
        if (estimate == null || estimate.isDeclined) {
          return Column(
            children: [
              if (estimate != null && estimate.isDeclined && (estimate.customerNote ?? '').isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Customer declined: ${estimate.customerNote}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.errorColor),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  onPressed: widget.technicianId == null
                      ? null
                      : () async {
                          final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
                            builder: (_) => TechnicianEstimateScreen(
                              bookingId: widget.booking.id,
                              technicianId: widget.technicianId!,
                              customerName: widget.booking.customer?.name ?? 'the customer',
                            ),
                          ));
                          if (sent == true) _refresh();
                        },
                  label: Text(estimate != null && estimate.isDeclined ? 'Revise & resend estimate' : 'Submit estimate'),
                ),
              ),
            ],
          );
        }

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _showInvoiceDialog(context, provider, widget.booking),
            child: const Text('Generate invoice & complete'),
          ),
        );
      },
    );
  }
}

class _WaitingOnEstimateRow extends StatelessWidget {
  final Booking booking;
  const _WaitingOnEstimateRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BookingEstimate?>(
      future: context.read<BookingService>().getLatestEstimate(booking.id),
      builder: (context, snapshot) {
        final estimate = snapshot.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.warningColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  estimate != null
                      ? 'Waiting for customer to approve \u20b9${estimate.totalAmount.toStringAsFixed(0)} estimate'
                      : 'Waiting for customer to review your estimate',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OtpVerifyRow extends StatefulWidget {
  final Booking booking;
  final String? technicianId;
  const _OtpVerifyRow({required this.booking, required this.technicianId});

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
    final otp = _controller.text.trim();
    if (widget.technicianId == null) return;
    if (otp.length != 4) {
      setState(() => _errorText = 'Enter the 4-digit OTP');
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
      if (!ok) _errorText = provider.error ?? 'Incorrect OTP, try again';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ask the customer for their OTP to start the service',
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
                  : const Text('Verify'),
            ),
          ],
        ),
      ],
    );
  }
}