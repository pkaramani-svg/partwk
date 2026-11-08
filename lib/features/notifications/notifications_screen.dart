import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/user_notification_service.dart';
import '../../models/user_notification.dart';
import '../book/book_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final UserNotificationService _service = UserNotificationService();
  late List<UserNotification> _notifications;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _notifications = _service.notifications;
    });
  }

  Future<void> _handleMarkAllRead() async {
    await _service.markAllAsRead();
    _refreshList();
  }

  Future<void> _handleNotificationTap(UserNotification item) async {
    if (!item.isRead) {
      await _service.markAsRead(item.id);
      _refreshList();
    }
    if (item.bookId != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookDetailsScreen(bookId: item.bookId!),
        ),
      );
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'welcome':
        return Icons.celebration_rounded;
      case 'digest':
        return Icons.auto_stories_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'download':
        return Icons.download_done_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _colorForType(String type, ThemeData theme) {
    switch (type) {
      case 'welcome':
        return Colors.amber.shade700;
      case 'digest':
        return theme.colorScheme.secondary;
      case 'streak':
        return Colors.deepOrange;
      case 'download':
        return Colors.teal;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _formatTime(DateTime time, AppLocalizations loc) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return loc.translate('notification_just_now');
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else {
      return '${diff.inDays}d';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('notifications')),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _handleMarkAllRead,
              child: Text(
                loc.translate('mark_all_read'),
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: Colors.grey.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.translate('no_notifications'),
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _notifications[index];
                final iconColor = _colorForType(item.type, theme);

                return InkWell(
                  onTap: () => _handleNotificationTap(item),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: item.isRead
                          ? theme.colorScheme.surface
                          : theme.colorScheme.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.isRead
                            ? Colors.grey.withOpacity(0.12)
                            : theme.colorScheme.secondary.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForType(item.type),
                            color: iconColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatTime(item.timestamp, loc),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.body,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: item.isRead
                                      ? theme.textTheme.bodyMedium?.color?.withOpacity(0.7)
                                      : theme.textTheme.bodyMedium?.color,
                                  height: 1.35,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
