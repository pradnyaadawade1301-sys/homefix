import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../models/consultation_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../services/booking_service.dart';
import '../../services/service_locator.dart' show UploadService;
import '../consultation/incoming_consultation_screen.dart';
import '../consultation/upcoming_consultations_screen.dart';
import '../profile/profile_screen.dart';
import 'technician_settlement_screen.dart';
import 'repeat_customers_screen.dart';
import '../chat/booking_chat_screen.dart';
import 'technician_estimate_screen.dart';
import 'job_photos_sheet.dart';
import 'technician_job_detail_screen.dart';
/// Technician-facing home screen — the mirror image of the customer's
/// [BookingsScreen]. A logged-in technician lands here and sees:
///  - a live "incoming consultation requests" banner (used to be buried in
///    Profile — now front-and-center since that's where jobs actually get
///    created from),
///  - an "upcoming scheduled consultations" banner (Schedule for Later slots
///    awaiting confirmation or already confirmed), and
///  - the jobs assigned to them, each carrying the CUSTOMER's name/phone/
///    address (booking.customer, booking.address).
/// A bottom nav switches between this Jobs view and the Settlement view.
class TechnicianJobsScreen extends StatefulWidget {
  const TechnicianJobsScreen({Key? key}) : super(key: key);

  @override
  State<TechnicianJobsScreen> createState() => _TechnicianJobsScreenState();
}

class _TechnicianJobsScreenState extends State<TechnicianJobsScreen> {
  int _navIndex = 0; // 0 = Jobs, 1 = Consultations, 2 = Settlement
  int _tabIndex = 0; // Active / All filter within the Jobs tab

  List<ConsultationRequest> _pendingRequests = [];
  List<Consultation> _upcomingConsultations = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _pollPendingRequests();
    _pollUpcoming();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _pollPendingRequests();
      _pollUpcoming();
    });
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
  } catch (_) {
    // Silent — this is a background poll; the Jobs list below still shows
    // its own error if the main fetch fails.
  }
}

  Future<void> _pollUpcoming() async {
    try {
      final upcoming = await context.read<ConsultationProvider>().fetchUpcomingList();
      if (!mounted) return;
      setState(() => _upcomingConsultations = upcoming);
    } catch (_) {
      // Silent — same as _pollPendingRequests, background poll only.
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
title: Text(_navIndex == 0 ? 'My Jobs' : _navIndex == 1 ? 'Consultations' : 'Settlement'),        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'My Customers',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RepeatCustomersScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
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
  ],
),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
        BottomNavigationBarItem(icon: Icon(Icons.work_outline_rounded), label: 'Jobs'),
        BottomNavigationBarItem(icon: Icon(Icons.event_available_outlined), label: 'Upcoming'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Settlement'),
      ],
      ),
    );
  }
Widget _buildGreetingHeader() {
  return Consumer<BookingProvider>(
    builder: (context, provider, _) {
      final activeCount = provider.bookings
          .where((b) => b.status == 'accepted' || b.status == 'on_the_way' || b.status == 'arrived' || b.status == 'in_progress' || b.status == 'awaiting_estimate_approval')
          .length;
      final completedCount = provider.bookings.where((b) => b.status == 'completed').length;
      return Container(
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
padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),          child: Row(
            children: [
              _FilterChip(label: 'Active', selected: _tabIndex == 0, onTap: () => setState(() => _tabIndex = 0)),
              const SizedBox(width: 8),
              _FilterChip(label: 'All', selected: _tabIndex == 1, onTap: () => setState(() => _tabIndex = 1)),
            ],
          ),
        ),
        Expanded(
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

                // Surface real fetch errors instead of silently showing an
                // empty state — an empty list and a failed request used to
                // look identical to the technician.
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

                final jobs = _tabIndex == 0
                    ? provider.bookings
                        .where((b) => b.status == 'accepted' || b.status == 'on_the_way' || b.status == 'arrived' || b.status == 'in_progress' || b.status == 'awaiting_estimate_approval')
                        .toList()
                    : provider.bookings;

                if (jobs.isEmpty) {
                  return ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                      Icon(Icons.work_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _tabIndex == 0 ? 'No active jobs right now' : 'No jobs yet',
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

  /// Prominent "you have live video consultation requests" banner — this used
  /// to only be reachable via Profile → "Live Consultation Requests"; now it
  /// sits right on the main dashboard where the technician is already looking.
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

  /// "You have scheduled consultations" banner — Schedule for Later slots
  /// that are either awaiting the technician's confirmation ('scheduled') or
  /// already confirmed and waiting for their time ('confirmed'). Distinct
  /// from [_buildConsultationBanner], which is the urgent ringing-right-now
  /// queue — this one is calmer (no red badge/ring), just a reminder to open
  /// [UpcomingConsultationsScreen] and confirm/decline.
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

/// A single job card for the technician — leads with the CUSTOMER's details
/// (name, phone, address) since that's what the technician needs to act on
/// the job, plus the category/problem description and a status-appropriate
/// action button (Accept / Start / Complete). Tapping the customer block
/// opens the full [TechnicianJobDetailScreen].
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
          // --- Customer details: the whole point of this screen ---
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
                 if (booking.status != 'requested' && booking.status != 'cancelled')
  IconButton(
    icon: const Icon(Icons.add_a_photo_outlined, color: AppTheme.primaryColor, size: 20),
    tooltip: 'Before/after photos',
    onPressed: () => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => JobPhotosSheet(bookingId: booking.id),
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
  const JobActionRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BookingProvider>();
    // `watch` (not `read`) here: the KYC profile loads asynchronously after
    // this screen's first frame, so without watching, a technician whose
    // profile hadn't finished loading yet would get stuck with a permanently
    // disabled action button (e.g. "I've arrived" never becoming tappable)
    // until something unrelated happened to rebuild this row.
    final kycProfile = context.watch<TechnicianKycProvider>().profile;

    switch (booking.status) {
      case 'requested':
        // Only reachable when browsing the general "requested" queue; for now
        // technicians only see jobs already routed to them via ListForTechnician,
        // but keep Accept available in case that changes.
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: kycProfile == null
                ? null
                : () => provider.acceptBooking(booking.id, kycProfile.id),
            child: const Text('Accept job'),
          ),
        );
      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.directions_run_rounded, size: 18),
            onPressed: () => provider.updateBookingStatus(booking.id, 'on_the_way', note: 'Technician is on the way'),
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
                : () => provider.markArrived(booking.id, kycProfile.id),
            label: const Text("I've arrived"),
          ),
        );
      case 'arrived':
        return _OtpVerifyRow(booking: booking, technicianId: kycProfile?.id);
      case 'in_progress':
        return _EstimateAwareAction(booking: booking, technicianId: kycProfile?.id);
      case 'awaiting_estimate_approval':
        return _WaitingOnEstimateRow(booking: booking);
      default:
        return const SizedBox.shrink();
    }
  }

}

/// The technician's "invoice" — a single final-amount entry, since that's
/// what the backend actually stores (Booking.FinalPrice) and what
/// UpiService.CreateOrder validates the customer's payment against. Pre-
/// filled with the original estimate so the common case (no change) is a
/// single tap, but the technician can adjust it up or down for parts used,
/// extra labor, etc. before it goes to the customer.
void _showInvoiceDialog(BuildContext context, BookingProvider provider, Booking booking) {
    final controller = TextEditingController(
      text: (booking.estimatedPrice ?? 0) > 0 ? (booking.estimatedPrice ?? 0).toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generate invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the final amount the customer should pay. This is sent to them immediately as the amount due.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                labelText: 'Final amount',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text.trim());
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount')),
                );
                return;
              }
              Navigator.of(dialogContext).pop();
              provider.completeBooking(booking.id, price);
            },
            child: const Text('Send invoice'),
          ),
        ],
      ),
    );
}

/// Shown for an 'in_progress' job. A technician who hasn't inspected the job
/// yet (or whose last estimate was declined) sees "Submit estimate"; once an
/// estimate has been approved by the customer, this instead shows the usual
/// "Generate invoice & complete" button. Fetches the booking's latest
/// estimate lazily (once per card) rather than through the shared
/// BookingProvider state, since many job cards can be on screen at once.
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
        // No estimate yet, or the last one was declined — technician needs
        // to (re)submit one before they can proceed to invoicing.
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

        // estimate.isApproved (or otherwise already resolved) — proceed to
        // the normal final-invoice flow, pre-filled with the approved total.
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

/// Shown while a booking is 'awaiting_estimate_approval' — the technician
/// has submitted an estimate and is waiting on the customer to approve,
/// decline, or discuss it. Read-only; nothing for the technician to tap
/// except a peek at what they sent.
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


/// Uber-style OTP entry shown to the technician once a booking is "arrived".
/// The customer reads out the code from their tracking screen; the
/// technician types it here to actually start the job.
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
    if (otp.length != 6) {
      setState(() => _errorText = 'Enter the 6-digit OTP');
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
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
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