import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Which push-notification categories the technician wants to receive.
/// UI-only for now, same pattern as bank_details_screen.dart /
/// payment_methods_screen.dart — wire `_save` to a real
/// PATCH /technicians/me/notification-prefs (or similar) once that endpoint
/// exists on the backend; until then, changes only live for this session.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // TODO: Load these from the technician's real saved preferences once the
  // backend endpoint exists; defaulting everything to "on" is the safest
  // default so nobody misses a job request while this is still local-only.
  bool _newJobRequests = true;
  bool _bookingUpdates = true;
  bool _chatMessages = true;
  bool _paymentUpdates = true;
  bool _promotions = false;

  void _save(String label, bool value) {
    setState(() {}); // rebuild already happens via the Switch's onChanged below
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label ${value ? 'enabled' : 'disabled'}. This will sync once the backend is connected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PrefTile(
            icon: Icons.work_outline_rounded,
            title: 'New job requests',
            subtitle: 'Get notified the moment a new job matches your category',
            value: _newJobRequests,
            onChanged: (v) {
              setState(() => _newJobRequests = v);
              _save('New job requests', v);
            },
          ),
          _PrefTile(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Booking updates',
            subtitle: 'Status changes, cancellations, and schedule reminders',
            value: _bookingUpdates,
            onChanged: (v) {
              setState(() => _bookingUpdates = v);
              _save('Booking updates', v);
            },
          ),
          _PrefTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Chat messages',
            subtitle: 'New messages from customers',
            value: _chatMessages,
            onChanged: (v) {
              setState(() => _chatMessages = v);
              _save('Chat messages', v);
            },
          ),
          _PrefTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Payment & settlement updates',
            subtitle: 'Payouts, invoices, and wallet balance changes',
            value: _paymentUpdates,
            onChanged: (v) {
              setState(() => _paymentUpdates = v);
              _save('Payment & settlement updates', v);
            },
          ),
          _PrefTile(
            icon: Icons.campaign_outlined,
            title: 'Promotions & offers',
            subtitle: 'Occasional updates about HomeFix offers for technicians',
            value: _promotions,
            onChanged: (v) {
              setState(() => _promotions = v);
              _save('Promotions & offers', v);
            },
          ),
        ],
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightOutline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}