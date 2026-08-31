import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/consultation_model.dart';
import '../../providers/consultation_provider.dart';

/// Customer-facing consultation history / status screen. Every consultation
/// the customer has ever requested — instant or scheduled — with a plain-
/// language status message. This is where a "Schedule for later" request
/// that got declined by the technician becomes visible in the UI itself,
/// not just as a push notification: the customer sees clearly why nothing
/// happened and what to do next, instead of a call that silently never occurs.
class MyConsultationsScreen extends StatefulWidget {
  const MyConsultationsScreen({Key? key}) : super(key: key);

  @override
  State<MyConsultationsScreen> createState() => _MyConsultationsScreenState();
}

class _MyConsultationsScreenState extends State<MyConsultationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<ConsultationProvider>().loadHistory();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Consultations')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Consumer<ConsultationProvider>(
          builder: (context, provider, _) {
            if (provider.isLoadingHistory && provider.history.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = provider.history;
            if (items.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                  Icon(Icons.videocam_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No consultations yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              itemBuilder: (context, i) => _ConsultationCard(consultation: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;
  final String message;
  const _StatusInfo({required this.label, required this.color, required this.icon, required this.message});
}

class _ConsultationCard extends StatelessWidget {
  final Consultation consultation;
  const _ConsultationCard({required this.consultation});

  static String _formatSlot(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final month = months[local.month - 1];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return '$day $month, $hour12:$minute $ampm';
  }

  _StatusInfo _statusInfo() {
    final isScheduled = consultation.scheduledAt != null;
    switch (consultation.status) {
      case ConsultationStatus.scheduled:
        return _StatusInfo(
          label: 'Awaiting confirmation',
          color: AppTheme.warningColor,
          icon: Icons.hourglass_top_rounded,
          message: 'Waiting for the technician to confirm your requested slot.',
        );
      case ConsultationStatus.confirmed:
        return _StatusInfo(
          label: 'Confirmed',
          color: AppTheme.successColor,
          icon: Icons.event_available_rounded,
          message: 'Your technician confirmed. The call will start automatically at your scheduled time.',
        );
      case ConsultationStatus.searching:
        return _StatusInfo(
          label: 'Searching',
          color: AppTheme.primaryColor,
          icon: Icons.search_rounded,
          message: 'Looking for an available technician...',
        );
      case ConsultationStatus.ringing:
        return _StatusInfo(
          label: 'Ringing',
          color: AppTheme.primaryColor,
          icon: Icons.phone_in_talk_rounded,
          message: 'Ringing the technician now...',
        );
      case ConsultationStatus.accepted:
        return _StatusInfo(
          label: 'Accepted',
          color: AppTheme.successColor,
          icon: Icons.check_circle_rounded,
          message: 'Technician accepted — connecting your call.',
        );
      case ConsultationStatus.rejected:
        return isScheduled
            ? _StatusInfo(
                label: 'Technician unavailable',
                color: AppTheme.errorColor,
                icon: Icons.event_busy_rounded,
                message: 'The technician was busy and couldn\'t make this slot. Please request a new time.',
              )
            : _StatusInfo(
                label: 'Not answered',
                color: AppTheme.errorColor,
                icon: Icons.call_end_rounded,
                message: 'The technician couldn\'t take your call. You can try again.',
              );
      case ConsultationStatus.noTechnician:
        return _StatusInfo(
          label: 'No technician available',
          color: AppTheme.errorColor,
          icon: Icons.person_off_rounded,
          message: 'No technician was available for this request. Please try again later.',
        );
      case ConsultationStatus.inCall:
        return _StatusInfo(
          label: 'In call',
          color: AppTheme.successColor,
          icon: Icons.videocam_rounded,
          message: 'Call in progress.',
        );
      case ConsultationStatus.ended:
        return _StatusInfo(
          label: 'Completed',
          color: Colors.grey[700]!,
          icon: Icons.check_circle_outline_rounded,
          message: 'This consultation has ended.',
        );
      case ConsultationStatus.cancelled:
        return _StatusInfo(
          label: 'Cancelled',
          color: Colors.grey[600]!,
          icon: Icons.cancel_outlined,
          message: 'You cancelled this request.',
        );
      default:
        return _StatusInfo(
          label: consultation.status,
          color: Colors.grey[600]!,
          icon: Icons.info_outline_rounded,
          message: '',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo();
    final slotText = _formatSlot(consultation.scheduledAt);

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
                  color: info.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(info.icon, size: 12, color: info.color),
                    const SizedBox(width: 4),
                    Text(info.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: info.color)),
                  ],
                ),
              ),
            ],
          ),
          if (slotText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(slotText, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          if (consultation.technicianName != null && consultation.technicianName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('with ${consultation.technicianName}', style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
          ],
          if (info.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: info.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(info.message, style: TextStyle(fontSize: 12.5, color: info.color, height: 1.35)),
            ),
          ],
          if (consultation.status == ConsultationStatus.rejected || consultation.status == ConsultationStatus.noTechnician) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Request again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}