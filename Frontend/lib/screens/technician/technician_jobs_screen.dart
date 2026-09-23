import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';
import '../../core/booking_call_launcher.dart';
import '../../core/theme.dart';
import '../../core/technician_theme.dart';
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
import '../home/home_screen.dart';
import 'technician_settlement_screen.dart';
import 'technician_history_screen.dart';
import 'repeat_customers_screen.dart';
import '../chat/booking_chat_screen.dart';
import 'technician_job_detail_screen.dart';
import '../../providers/category_provider.dart';
import '../../providers/payment_provider.dart';
import 'job_brief_card.dart';
import 'job_photos_sheet.dart';
import '../notifications/notifications_screen.dart';
import 'manage_categories_screen.dart';

class TechnicianJobsScreen extends StatefulWidget {
  const TechnicianJobsScreen({Key? key}) : super(key: key);

  static final GlobalKey<TechnicianJobsScreenState> globalKey = GlobalKey<TechnicianJobsScreenState>();

  @override
  State<TechnicianJobsScreen> createState() => TechnicianJobsScreenState();
}

class TechnicianJobsScreenState extends State<TechnicianJobsScreen> {
  // Purple/indigo dashboard palette — scoped to the technician app only
  // (customer-facing screens keep AppTheme's teal/green palette). Sourced
  // from TechTheme so every technician screen shares one definition.
  static const _purple = TechTheme.primary;
  static const _purpleDark = TechTheme.primaryDark;
  static const _purpleSoft = TechTheme.primarySoft;
  static const _canvas = TechTheme.canvas;
  static const _green = TechTheme.green;
  static const _greenSoft = TechTheme.greenSoft;
  static const _blue = TechTheme.blue;
  static const _blueSoft = TechTheme.blueSoft;
  static const _amber = TechTheme.amber;
  static const _amberSoft = TechTheme.amberSoft;

  int _navIndex = 0; // 0 = Home, 1 = Jobs, 2 = Earnings, 3 = Messages, 4 = Profile (pushed)
  int _tabIndex = 0;
  int _homeWorkTab = 0; // 0 = Active, 1 = Upcoming, 2 = Completed — "Your Work" card on the Home dashboard
  // For the "press back again to exit" behaviour on the Jobs tab.
  DateTime? _lastBackPress;

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
        title: 'Welcome to OneFix!',
        description: 'Here\'s a quick overview of your active and completed jobs at a glance.',
        tabIndex: 0,
      ),
      GuidedTourStep(
        targetKey: _filterKey,
        icon: Icons.filter_list_rounded,
        title: 'Active & All Jobs',
        description: 'Switch between jobs that need your attention right now and your full job history.',
        tabIndex: 1,
      ),
      GuidedTourStep(
        targetKey: _jobsListKey,
        icon: Icons.work_outline_rounded,
        title: 'Your Jobs',
        description: 'Every job assigned to you shows up here — tap a card to see the full Job Brief, chat with the customer, and update the job status.',
        tabIndex: 1,
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
      onTabChange: (i) {
        if (mounted) setState(() => _navIndex = i);
      },
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
    if (mounted) {
      // Powers the Home dashboard's Total Earned / This Month / Earnings
      // Overview widgets — non-fatal if it fails, those just show ₹0.
      await context.read<PaymentProvider>().loadHistory();
    }
    if (mounted && context.read<CategoryProvider>().categories.isEmpty) {
      await context.read<CategoryProvider>().fetchCategories();
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
    final l10n = AppLocalizations.of(context);
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

  /// Back-button handling for the technician shell:
  /// - on any non-Jobs tab, back returns to the Jobs tab instead of leaving;
  /// - on the Jobs tab, back must be pressed twice within 2s to exit —
  ///   matches the customer HomeScreen's behaviour so the app never just
  ///   closes/exits on a single back press.
  void _handleBack(bool didPop) {
    if (didPop) return;
    if (_navIndex != 0) {
      setState(() => _navIndex = 0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).homePressBackExit), duration: const Duration(seconds: 2)),
      );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: Scaffold(
      appBar: _buildHeader(l10n),
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildHomeDashboard(),
          _buildJobsBody(),
          const TechnicianSettlementScreen(),
          const TechnicianHistoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _purple,
        currentIndex: _navIndex,
        onTap: (i) {
          // "Profile" isn't a tab in the IndexedStack (ProfileScreen owns its
          // own Scaffold/AppBar, like the pushed-route version this replaced)
          // — so tapping it pushes a route instead of switching _navIndex.
          if (i == 4) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            return;
          }
          setState(() => _navIndex = i);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: const Icon(Icons.work_outline_rounded), label: l10n.techJobsBottomNavJobs),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined, key: _settlementNavKey), label: l10n.techJobsBottomNavSettlement),
          BottomNavigationBarItem(icon: const Icon(Icons.chat_bubble_outline_rounded), label: l10n.techJobsBottomNavHistory),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline, key: _profileNavKey), label: l10n.profileTitle),
        ],
      ),
      ),
    );
  }

  /// Custom header replacing the default AppBar — brand mark + name on the
  /// left, all the same functional icons on the right (language, my
  /// customers, book-for-yourself, notifications) plus a bell-style
  /// notification icon and a tappable profile avatar, styled to match the
  /// app's dashboard mockup instead of a plain Material AppBar.
  /// Header for the technician shell — profile photo, greeting + name,
  /// role/category + online status on the left; bell and a settings menu
  /// (bundling language/customers/book-for-yourself, which the previous
  /// icon-row style exposed directly) on the right.
  PreferredSizeWidget _buildHeader(AppLocalizations l10n) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(76),
      child: Container(
        color: _canvas,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 76,
            child: Consumer2<AuthProvider, TechnicianKycProvider>(
              builder: (context, auth, kyc, _) {
                final user = auth.currentUser;
                final photo = user?.photoUrl;
                final initial = (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?';
                final firstName = (user?.name.trim().isNotEmpty == true) ? user!.name.trim().split(' ').first : '';
                final hour = DateTime.now().hour;
                final greeting = hour < 12 ? 'Good Morning' : (hour < 17 ? 'Good Afternoon' : 'Good Evening');
                final isOnline = kyc.profile?.isAvailable ?? false;
                return Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: _purpleSoft,
                        backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                        child: (photo == null || photo.isEmpty)
                            ? Text(initial, style: const TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 18))
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$greeting 👋', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          Text(
                            firstName.isNotEmpty ? firstName : 'Technician',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF1A1F36)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(color: isOnline ? _green : Colors.grey[400], shape: BoxShape.circle),
                              ),
                              Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isOnline ? _green : Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none_rounded, size: 23),
                          tooltip: l10n.profileNotifications,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          ),
                        ),
                        if (_pendingRequests.isNotEmpty)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                              child: Text(
                                '${_pendingRequests.length}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                    PopupMenuButton<int>(
                      key: _customersNavKey,
                      icon: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                        child: const Icon(Icons.settings_outlined, size: 19, color: Color(0xFF1A1F36)),
                      ),
                      onSelected: (v) {
                        switch (v) {
                          case 0:
                            showLanguagePicker(context);
                            break;
                          case 1:
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RepeatCustomersScreen()));
                            break;
                          case 2:
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeScreen(guestMode: true)));
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 0, child: Row(children: [const Icon(Icons.language_rounded, size: 18), const SizedBox(width: 10), Text(l10n.profileLanguage)])),
                        PopupMenuItem(value: 1, child: Row(children: [const Icon(Icons.people_alt_outlined, size: 18), const SizedBox(width: 10), Text(l10n.techJobsMyCustomersTooltip)])),
                        const PopupMenuItem(value: 2, child: Row(children: [Icon(Icons.swap_horiz_rounded, size: 18), SizedBox(width: 10), Text('Book a service for yourself')])),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The purple hero card + stat grid + "Your Work" tabs/list that make up
  /// the new Home tab — the technician dashboard landing screen.
  Widget _buildHomeDashboard() {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: _canvas,
      child: RefreshIndicator(
        onRefresh: () async {
          await _load();
          await _pollPendingRequests();
          await _pollUpcoming();
        },
        child: Consumer2<BookingProvider, TechnicianKycProvider>(
          builder: (context, provider, kyc, _) {
            final activeCount = provider.bookings
                .where((b) =>
                    b.status == 'requested' ||
                    b.status == 'pending_technician' ||
                    b.status == 'accepted' ||
                    b.status == 'on_the_way' ||
                    b.status == 'arrived' ||
                    b.status == 'inspecting' ||
                    b.status == 'in_progress' ||
                    b.status == 'awaiting_estimate_approval')
                .toList();
            final completedBookings = provider.bookings.where((b) => b.status == 'completed').toList();
            final now = DateTime.now();
            final thisMonthPaid = context.watch<PaymentProvider>().history.where((p) =>
                p.status == 'paid' && p.createdAt.year == now.year && p.createdAt.month == now.month);
            final thisMonthEarned = thisMonthPaid.fold<double>(0, (sum, p) => sum + (p.technicianEarning ?? p.amount));
            final ratingAvg = kyc.profile?.ratingAvg ?? 0;
            final ratingCount = kyc.profile?.ratingCount ?? 0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              children: [
                _heroCard(activeCount.length, completedBookings.length),
                if (_upcomingConsultations.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildUpcomingBanner(inList: true),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _statCard('Active Jobs', activeCount.length.toString(), Icons.work_outline_rounded, _purple, _purpleSoft, onTap: () => _goToJobsTab(0))),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Completed', completedBookings.length.toString(), Icons.check_circle_rounded, _green, _greenSoft, onTap: () => _goToJobsTab(1))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'Rating',
                        ratingCount > 0 ? ratingAvg.toStringAsFixed(1) : '—',
                        Icons.star_rounded,
                        _amber,
                        _amberSoft,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('This Month', '₹${thisMonthEarned.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, _blue, _blueSoft)),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your Work', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF1A1F36))),
                    GestureDetector(
                      onTap: () => setState(() => _navIndex = 1),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View All', style: TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 12.5)),
                          Icon(Icons.chevron_right_rounded, color: _purple, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _yourWorkCard(activeCount, completedBookings, l10n, kyc),
                const SizedBox(height: 16),
                _servicesOfferedCard(kyc),
              ],
            );
          },
        ),
      ),
    );
  }

  void _goToJobsTab(int tabIndex) {
    setState(() {
      _navIndex = 1;
      _tabIndex = tabIndex;
    });
  }

  Widget _heroCard(int activeCount, int completedCount) {
    return Container(
      key: _overviewKey,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_purple, _purpleDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          // Large illustration, top-right — allowed to bleed behind the
          // pills row a little (pills are painted on top, in their own
          // opaque white cards, so the overlap never reads as broken).
          Positioned(
            top: -6,
            right: 0,
            child: Image.asset(
              'assets/images/technician_illustration.png',
              width: 150,
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your work at a glance', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 6),
                const Text(
                  'Keep making\na difference ✨',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, height: 1.15),
                ),
                const SizedBox(height: 46),
                Row(
                  children: [
                    Expanded(child: _heroPill(Icons.work_outline_rounded, activeCount.toString(), 'Active Jobs', _purple)),
                    const SizedBox(width: 10),
                    Expanded(child: _heroPill(Icons.check_rounded, completedCount.toString(), 'Completed', _green)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String value, String label, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1F36)), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(fontSize: 9.5, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bg, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[700])),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A1F36))),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _yourWorkCard(List<Booking> active, List<Booking> completed, AppLocalizations l10n, TechnicianKycProvider kyc) {
    final shown = switch (_homeWorkTab) {
      1 => _upcomingConsultations.isEmpty ? <Booking>[] : active.where((b) => b.scheduledAt != null).toList(),
      2 => completed,
      _ => active,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _workTabChip('Active (${active.length})', 0),
                const SizedBox(width: 8),
                _workTabChip('Upcoming (${_upcomingConsultations.length})', 1),
                const SizedBox(width: 8),
                _workTabChip('Completed (${completed.length})', 2),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Column(
              children: [
                Icon(Icons.calendar_month_outlined, size: 56, color: _purple.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(
                  _homeWorkTab == 2 ? 'No completed jobs yet' : (_homeWorkTab == 1 ? 'No upcoming jobs' : 'No active jobs right now'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFF1A1F36)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _homeWorkTab == 0 ? 'Your next service request will appear here. Stay online and ready!' : ' ',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                if (_homeWorkTab == 0) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(vertical: 13)),
                      onPressed: () async {
                        final next = !(kyc.profile?.isAvailable ?? false);
                        await kyc.setAvailability(next);
                      },
                      icon: const Icon(Icons.event_available_outlined, size: 18),
                      label: Text((kyc.profile?.isAvailable ?? false) ? 'Go Offline' : 'Update Availability'),
                    ),
                  ),
                ],
              ],
            )
          else
            ...shown.take(3).map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _JobCard(key: ValueKey(b.id), booking: b),
                )),
        ],
      ),
    );
  }

  Widget _workTabChip(String label, int index) {
    final selected = _homeWorkTab == index;
    return GestureDetector(
      onTap: () => setState(() => _homeWorkTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _purple : _purpleSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : _purple)),
      ),
    );
  }

  Widget _servicesOfferedCard(TechnicianKycProvider kyc) {
    final categoryIds = kyc.profile?.categoryIds ?? const [];
    final allCategories = context.watch<CategoryProvider>().categories;
    final names = <String>[];
    for (final id in categoryIds) {
      for (final c in allCategories) {
        if (c.id == id) {
          names.add(c.name);
          break;
        }
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _purpleSoft, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.build_outlined, color: _purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Services You Offer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(
                  names.isNotEmpty ? names.join(' • ') : 'Manage your services and categories',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageCategoriesScreen())),
            style: TextButton.styleFrom(backgroundColor: _purpleSoft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: const Text('View / Edit', style: TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsBody() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const SizedBox(height: 8),
        if (_pendingRequests.isNotEmpty) _buildConsultationBanner(),
        if (_upcomingConsultations.isNotEmpty) _buildUpcomingBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 0, 6),
          child: SingleChildScrollView(
            key: _filterKey,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                _FilterChip(icon: Icons.work_outline_rounded, label: l10n.techJobsActive, selected: _tabIndex == 0, onTap: () => setState(() => _tabIndex = 0)),
                const SizedBox(width: 8),
                _FilterChip(icon: Icons.grid_view_rounded, label: l10n.techJobsFilterAll, selected: _tabIndex == 1, onTap: () => setState(() => _tabIndex = 1)),
                const SizedBox(width: 8),
                _FilterChip(icon: Icons.calendar_month_rounded, label: 'Book Now', selected: _tabIndex == 2, onTap: () => setState(() => _tabIndex = 2)),
                const SizedBox(width: 8),
                _FilterChip(icon: Icons.videocam_rounded, label: 'Video Call', selected: _tabIndex == 3, onTap: () => setState(() => _tabIndex = 3)),
                const SizedBox(width: 8),
                _FilterChip(icon: Icons.access_time_rounded, label: 'Schedule for later', selected: _tabIndex == 4, onTap: () => setState(() => _tabIndex = 4)),
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

                final jobs = switch (_tabIndex) {
                  0 => provider.bookings
                      .where((b) =>
                          b.status == 'requested' ||
                          b.status == 'pending_technician' ||
                          b.status == 'accepted' ||
                          b.status == 'on_the_way' ||
                          b.status == 'arrived' ||
                          b.status == 'inspecting' ||
                          b.status == 'in_progress' ||
                          b.status == 'awaiting_estimate_approval')
                      .toList(),
                  // "Book Now" = a direct booking, not one that came out of a
                  // video consultation and not a slot scheduled for later.
                  2 => provider.bookings.where((b) => b.jobBrief?.hasVideo != true && b.scheduledAt == null).toList(),
                  // "Video Call" = booking that originated from a video
                  // consultation with the technician.
                  3 => provider.bookings.where((b) => b.jobBrief?.hasVideo == true).toList(),
                  // "Schedule for later" = the customer picked a future slot
                  // rather than booking for right now.
                  4 => provider.bookings.where((b) => b.scheduledAt != null).toList(),
                  _ => provider.bookings,
                };

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
    final l10n = AppLocalizations.of(context);
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
              colors: [_purple, _purpleDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
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

  Widget _buildUpcomingBanner({bool inList = false}) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: inList ? EdgeInsets.zero : const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UpcomingConsultationsScreen()),
        ).then((_) => _pollUpcoming()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _purple.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: _purpleSoft,
                child: Icon(Icons.event_rounded, color: _purple),
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
              const Icon(Icons.chevron_right_rounded, color: _purple),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? TechTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: selected ? null : Border.all(color: Colors.grey[300]!),
          boxShadow: selected
              ? [BoxShadow(color: TechTheme.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey[700]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
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
    final l10n = AppLocalizations.of(context);
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
                color: TechTheme.primary.withValues(alpha: 0.05),
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
                            backgroundColor: TechTheme.primary.withValues(alpha: 0.15),
                            child: Text(
                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: TechTheme.primary, fontWeight: FontWeight.w700),
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
                    icon: const Icon(Icons.call_outlined, color: TechTheme.primary, size: 20),
                    tooltip: 'Call',
                    onPressed: () => startBookingAudioCall(
                      context,
                      bookingId: booking.id,
                      peerDisplayName: customer.name.isNotEmpty ? customer.name : l10n.techJobsCustomerFallback,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forum_outlined, color: TechTheme.primary, size: 20),
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
    final l10n = AppLocalizations.of(context);
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
                style: ElevatedButton.styleFrom(backgroundColor: TechTheme.primary, foregroundColor: Colors.white),
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
            style: OutlinedButton.styleFrom(foregroundColor: TechTheme.primary, side: const BorderSide(color: TechTheme.primary)),
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
            style: ElevatedButton.styleFrom(backgroundColor: TechTheme.primary, foregroundColor: Colors.white),
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
            style: ElevatedButton.styleFrom(backgroundColor: TechTheme.primary, foregroundColor: Colors.white),
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
    final l10n = AppLocalizations.of(context);
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

Future<void> _showInvoiceDialog(BuildContext context, BookingProvider provider, Booking booking) async {
  final completed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _InvoiceDialog(provider: provider, booking: booking),
  );
  // Once the job is actually marked complete, prompt for the "after" proof
  // photo right away — separate step from the invoice dialog itself (that
  // combination was crashing on some devices), and not required to finish
  // the job, but the natural moment to ask for it.
  if (completed == true && context.mounted) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => JobPhotosSheet(bookingId: booking.id),
    );
  }
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
  late final TextEditingController _warrantyDescriptionController;
  bool _warrantyEnabled = false;
  _WarrantyUnit _warrantyUnit = _WarrantyUnit.months;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.booking.estimatedPrice ?? 0) > 0 ? (widget.booking.estimatedPrice ?? 0).toStringAsFixed(0) : '',
    );
    _warrantyAmountController = TextEditingController();
    _warrantyDescriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _warrantyAmountController.dispose();
    _warrantyDescriptionController.dispose();
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
    final l10n = AppLocalizations.of(context);
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
                      initialValue: _warrantyUnit,
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
              const SizedBox(height: 12),
              TextField(
                controller: _warrantyDescriptionController,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: l10n.techJobsWarrantyCoverageLabel,
                  hintText: l10n.techJobsWarrantyCoverageHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
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
        _submitting
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: TechTheme.primary, foregroundColor: Colors.white),
                onPressed: () async {
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
                  // Capture the dialog's own messenger BEFORE closing it —
                  // once we pop, `context` here still resolves fine, but we
                  // want to keep showing progress in this dialog until the
                  // request actually finishes instead of closing it early
                  // and silently losing any failure (that was the original
                  // bug: the dialog closed immediately and the completeBooking
                  // call ran fire-and-forget, so if it failed the technician
                  // never found out and the customer never got an invoice).
                  setState(() => _submitting = true);

                  await widget.provider.completeBooking(
                    widget.booking.id,
                    price,
                    warrantyEnabled: _warrantyEnabled,
                    warrantyDays: _warrantyEnabled ? _warrantyDaysValue : null,
                    warrantyDescription: _warrantyEnabled ? _warrantyDescriptionController.text.trim() : null,
                  );

                  if (!mounted) return;

                  if (widget.provider.error != null) {
                    // Keep the dialog open so the technician can fix the
                    // input (e.g. invalid warranty duration) and retry,
                    // instead of losing their entered amount.
                    setState(() => _submitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(widget.provider.error!)),
                    );
                    return;
                  }

                  Navigator.of(context).pop(true);
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
    final l10n = AppLocalizations.of(context);
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
    final l10n = AppLocalizations.of(context);
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
              style: ElevatedButton.styleFrom(backgroundColor: TechTheme.primary, foregroundColor: Colors.white),
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
