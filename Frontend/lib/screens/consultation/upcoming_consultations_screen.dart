import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/consultation_model.dart';
import '../../providers/consultation_provider.dart';

/// Technician-side "Upcoming Consultations" screen — lists scheduled slot
/// requests (status 'scheduled', awaiting the technician's confirmation) and
/// already-confirmed slots (status 'confirmed', waiting for their time to
/// arrive). Distinct from [IncomingConsultationScreen], which is the urgent
/// "ringing right now" queue for instant "Consult Now" calls — a scheduled
/// consultation only shows up there once its slot time is actually reached
/// (see backend ConsultationService.PromoteDueScheduled).
///
/// [embedded]: when true, renders without its own Scaffold/AppBar so it can
/// be dropped straight into another screen's IndexedStack (see
/// TechnicianJobsScreen's bottom nav "Upcoming" tab).
class UpcomingConsultationsScreen extends StatefulWidget {
  final bool embedded;
  const UpcomingConsultationsScreen({Key? key, this.embedded = false}) : super(key: key);

  @override
  State<UpcomingConsultationsScreen> createState() => _UpcomingConsultationsScreenState();
}

class _UpcomingConsultationsScreenState extends State<UpcomingConsultationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<ConsultationProvider>().loadUpcoming();

  Future<void> _confirm(Consultation c) async {
    try {
      await context.read<ConsultationProvider>().confirmScheduled(c.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot confirmed'), backgroundColor: AppTheme.successColor),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not confirm: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  /// Shows a dialog asking the technician WHY they're declining, then sends
  /// it along with the decline so the customer isn't left with a bare
  /// "declined" status (see MyConsultationsScreen, which surfaces this text).
  /// The reason is optional — a technician who's in a hurry can still just
  /// tap Decline — but giving one is encouraged via the hint text.
  Future<void> _decline(Consultation c) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline this slot?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The customer will be notified that you can\'t make ${_formatSlot(c.scheduledAt)} and asked to pick another time.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLength: 150,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Not available at that time',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final reason = reasonController.text.trim();
    try {
      await context.read<ConsultationProvider>().declineScheduled(c.id, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot declined')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not decline: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  static String _formatSlot(DateTime? dt) {
    if (dt == null) return 'this slot';
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = _monthNames[local.month - 1];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return '$day $month, $hour12:$minute $ampm';
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _load,
      child: Consumer<ConsultationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingUpcoming && provider.upcoming.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = provider.upcoming;
          if (items.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                Icon(Icons.event_available_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'No upcoming consultations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Scheduled requests from customers will show up here',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (context, i) => _UpcomingCard(
              consultation: items[i],
              formatSlot: _formatSlot,
              onConfirm: () => _confirm(items[i]),
              onDecline: () => _decline(items[i]),
            ),
          );
        },
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Consultations')),
      body: body,
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final Consultation consultation;
  final String Function(DateTime?) formatSlot;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;

  const _UpcomingCard({
    required this.consultation,
    required this.formatSlot,
    required this.onConfirm,
    required this.onDecline,
  });

  bool get _isAwaitingConfirmation => consultation.status == ConsultationStatus.scheduled;

  @override
  Widget build(BuildContext context) {
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
                  consultation.categoryName.isNotEmpty ? consultation.categoryName : 'Consultation',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_isAwaitingConfirmation ? AppTheme.warningColor : AppTheme.successColor).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isAwaitingConfirmation ? 'Needs confirmation' : 'Confirmed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isAwaitingConfirmation ? AppTheme.warningColor : AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                    (consultation.customerName ?? '?').isNotEmpty ? consultation.customerName![0].toUpperCase() : '?',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(consultation.customerName ?? 'Customer',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            formatSlot(consultation.scheduledAt),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isAwaitingConfirmation)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.successColor),
                const SizedBox(width: 6),
                Text(
                  'Waiting for slot time — you\'ll be notified when it starts',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
              ],
            ),
        ],
      ),
    );
  }
}