import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/service_locator.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<NotificationService>().getNotifications();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = context.read<NotificationService>().getNotifications();
    });
    await _future;
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'consultation_recommendation':
        return Icons.assignment_turned_in_outlined;
      case 'consultation_accepted':
      case 'consultation_request':
        return Icons.videocam_outlined;
      case 'booking_update':
        return Icons.local_shipping_outlined;
      case 'chat_message':
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  // Date and time are shown in two different places on the card (date top-right
  // next to the title, time bottom-right next to the sender), so they're
  // formatted separately rather than as one combined string.
  DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  String? _formatDate(DateTime? dt) => dt == null ? null : DateFormat('d MMM yyyy').format(dt);
  String? _formatTime(DateTime? dt) => dt == null ? null : DateFormat('h:mm a').format(dt);

  Future<void> _openNotification(Map<String, dynamic> n) async {
    final title = n['title']?.toString() ?? 'Notification';
    final body = n['body']?.toString() ?? n['message']?.toString() ?? '';
    final data = n['data'] is Map ? Map<String, dynamic>.from(n['data'] as Map) : null;
    final id = n['id']?.toString();
    final createdAt = n['created_at']?.toString();

    // Mark read on tap, best-effort — don't block navigation on it.
    if (id != null && id.isNotEmpty && n['is_read'] != true) {
      unawaited(context.read<NotificationService>().markAsRead(id));
    }

    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NotificationDetailScreen(title: title, body: body, data: data, createdAt: createdAt),
    ));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      snapshot.hasError ? 'Could not load notifications' : 'No notifications yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final n = items[i] as Map<String, dynamic>;
                final title = n['title']?.toString() ?? n['message']?.toString() ?? 'Notification';
                final body = n['body']?.toString();
                final data = n['data'] is Map ? Map<String, dynamic>.from(n['data'] as Map) : null;
                final type = data?['type'] as String?;
                final isUnread = n['is_read'] == false;
                final senderName = (data?['sender_name'] as String?)?.trim();
                final dt = _parseTimestamp(n['created_at']);
                final date = _formatDate(dt);
                final time = _formatTime(dt);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: isUnread ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)) : null,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openNotification(n),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_iconFor(type), size: 18, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title on the left, date pinned top-right of the card.
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (date != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        date,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ],
                                ),
                                if (body != null && body.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                                  ),
                                ],
                                if ((senderName != null && senderName.isNotEmpty) || time != null) ...[
                                  const SizedBox(height: 5),
                                  // Sender pinned left, time pinned bottom-right.
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (senderName != null && senderName.isNotEmpty)
                                        Flexible(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey[500]),
                                              const SizedBox(width: 3),
                                              Flexible(
                                                child: Text(
                                                  senderName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500], fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        const SizedBox.shrink(),
                                      if (time != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.schedule_rounded, size: 12, color: Colors.grey[500]),
                                            const SizedBox(width: 3),
                                            Text(
                                              time,
                                              style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8, top: 4),
                              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}  