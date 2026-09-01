import 'dart:async';
import 'package:flutter/material.dart';
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

  Future<void> _openNotification(Map<String, dynamic> n) async {
    final title = n['title']?.toString() ?? 'Notification';
    final body = n['body']?.toString() ?? n['message']?.toString() ?? '';
    final data = n['data'] is Map ? Map<String, dynamic>.from(n['data'] as Map) : null;
    final id = n['id']?.toString();

    // Mark read on tap, best-effort — don't block navigation on it.
    if (id != null && id.isNotEmpty && n['is_read'] != true) {
      unawaited(context.read<NotificationService>().markAsRead(id));
    }

    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NotificationDetailScreen(title: title, body: body, data: data),
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
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                  ),
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
                              ],
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
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