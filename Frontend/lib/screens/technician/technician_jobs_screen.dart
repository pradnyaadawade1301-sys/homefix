import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/contact_actions.dart';
import '../../models/booking_model.dart';
import '../../models/consultation_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../consultation/incoming_consultation_screen.dart';
import '../profile/profile_screen.dart';
import 'technician_settlement_screen.dart';

/// Technician-facing home screen — the mirror image of the customer's
/// [BookingsScreen]. A logged-in technician lands here and sees:
///  - a live "incoming consultation requests" banner (used to be buried in
///    Profile — now front-and-center since that's where jobs actually get
///    created from), and
///  - the jobs assigned to them, each carrying the CUSTOMER's name/phone/
///    address (booking.customer, booking.address).
/// A bottom nav switches between this Jobs view and the Settlement view.
class TechnicianJobsScreen extends StatefulWidget {
  const TechnicianJobsScreen({Key? key}) : super(key: key);

  @override
  State<TechnicianJobsScreen> createState() => _TechnicianJobsScreenState();
}

class _TechnicianJobsScreenState extends State<TechnicianJobsScreen> {
  int _navIndex = 0; // 0 = Jobs, 1 = Settlement
  int _tabIndex = 0; // Active / All filter within the Jobs tab

  List<ConsultationRequest> _pendingRequests = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _pollPendingRequests();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _pollPendingRequests());
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
        title: Text(_navIndex == 0 ? 'My Jobs' : 'Settlement'),
        actions: [
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
          const TechnicianSettlementScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work_outline_rounded), label: 'Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Settlement'),
        ],
      ),
    );
  }
Widget _buildGreetingHeader() {
  return Consumer<BookingProvider>(
    builder: (context, provider, _) {
      final activeCount = provider.bookings
          .where((b) => b.status == 'accepted' || b.status == 'in_progress')
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
                        .where((b) => b.status == 'accepted' || b.status == 'in_progress')
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
/// action button (Accept / Start / Complete).
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
                  if (customer.phone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.call, color: AppTheme.primaryColor, size: 20),
                      tooltip: 'Call customer',
                      onPressed: () => callContact(context, customer.phone),
                    ),
                  if (customer.phone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                      tooltip: 'WhatsApp customer',
                      onPressed: () => openWhatsApp(context, customer.phone),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          _ActionRow(booking: booking),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final Booking booking;
  const _ActionRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BookingProvider>();
    final kycProfile = context.read<TechnicianKycProvider>().profile;

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
          child: OutlinedButton(
            onPressed: () => provider.updateBookingStatus(booking.id, 'in_progress', note: 'Technician started the job'),
            child: const Text('Start job'),
          ),
        );
      case 'in_progress':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final price = booking.estimatedPrice ?? 0;
              provider.completeBooking(booking.id, price);
            },
            child: const Text('Mark as completed'),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}