import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../shared/widgets/ui.dart';

/// Unified patient feed: personal system notifications plus published Admin announcements.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final PatientPortalRepository _repository = PatientPortalRepository();
  bool _markingAll = false;

  Future<void> _markAllRead(List<Map<String, dynamic>> items) async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      for (final item in items.where((item) => item['_source'] == 'system' && item['read'] != true)) {
        final id = (item['_docId'] ?? item['id'] ?? '').toString();
        if (id.isNotEmpty) await _repository.markNotificationRead(id);
      }
    } catch (error) {
      if (mounted) _showError('Could not update notifications: $error');
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['_source'] != 'system' || item['read'] == true) return;
    final id = (item['_docId'] ?? item['id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      await _repository.markNotificationRead(id);
    } catch (error) {
      if (mounted) _showError('Could not mark notification as read: $error');
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: AppColors.red),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _repository.watchMyNotifications(),
      builder: (context, notificationSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _repository.watchPublishedAnnouncements(),
          builder: (context, announcementSnapshot) {
            final notifications = [...?notificationSnapshot.data]
                .map((item) => {...item, '_source': 'system'})
                .toList();
            final announcements = [...?announcementSnapshot.data].map((item) => {
              ...item,
              '_source': 'announcement',
              'message': item['content'] ?? item['message'] ?? item['description'] ?? '',
              'createdAt': item['publishedAt'] ?? item['createdAt'] ?? item['date'] ?? '',
              'category': item['category'] ?? 'announcement',
              'read': true,
            }).toList();
            final items = [...notifications, ...announcements]
              ..sort((a, b) => _dateValue(b).compareTo(_dateValue(a)));
            final unread = notifications.where((item) => item['read'] != true).length;
            final loading = !notificationSnapshot.hasData || !announcementSnapshot.hasData;
            final error = notificationSnapshot.error ?? announcementSnapshot.error;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PageHeading(
                'Notifications',
                subtitle: 'Personal updates and announcements published by Alapot Dental Clinic.',
                trailing: TextButton.icon(
                  onPressed: _markingAll || unread == 0 ? null : () => _markAllRead(items),
                  icon: _markingAll
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark all read'),
                ),
              ),
              if (error != null)
                SurfaceCard(child: Text('Some notifications could not be loaded: $error'))
              else if (loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (items.isEmpty)
                Expanded(child: _emptyState())
              else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(spacing: 10, children: [
                    Text('$unread unread', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    Text('${notifications.length} system · ${announcements.length} announcements', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ]),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isAnnouncement = item['_source'] == 'announcement';
                      final isUnread = !isAnnouncement && item['read'] != true;
                      final title = (item['title'] ?? (isAnnouncement ? 'Clinic announcement' : 'Clinic update')).toString();
                      final message = (item['message'] ?? '').toString();
                      final category = (item['category'] ?? item['type'] ?? (isAnnouncement ? 'announcement' : 'system')).toString().toLowerCase();
                      return SurfaceCard(
                        color: isUnread ? AppColors.teal.withValues(alpha: .045) : Theme.of(context).cardColor,
                        onTap: () => _markRead(item),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            height: 42, width: 42,
                            decoration: BoxDecoration(color: isAnnouncement ? const Color(0xFFFFF4DB) : AppColors.sky, borderRadius: BorderRadius.circular(13)),
                            child: Icon(_iconFor(category), color: isAnnouncement ? const Color(0xFF9A6B12) : AppColors.deepTeal, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                              if (isAnnouncement) const Chip(label: Text('Announcement'), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                              if (isUnread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
                            ]),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(message, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: .8))),
                            ],
                            const SizedBox(height: 8),
                            Text(_formatDate(item), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                          ])),
                        ]),
                      );
                    },
                  ),
                ),
              ],
            ]);
          },
        );
      },
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.notifications_none, size: 42, color: AppColors.muted),
      const SizedBox(height: 10),
      Text('You’re all caught up', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text('Personal notifications and clinic announcements will appear here.', style: TextStyle(color: AppColors.muted), textAlign: TextAlign.center),
    ]),
  );

  static IconData _iconFor(String category) {
    if (category.contains('appointment')) return Icons.calendar_month_outlined;
    if (category.contains('payment') || category.contains('receipt')) return Icons.receipt_long_outlined;
    if (category.contains('announcement')) return Icons.campaign_outlined;
    if (category.contains('review')) return Icons.star_outline;
    return Icons.notifications_none;
  }

  static DateTime _dateValue(Map<String, dynamic> item) =>
      DateTime.tryParse((item['createdAt'] ?? item['date'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);

  static String _formatDate(Map<String, dynamic> item) {
    final date = _dateValue(item);
    if (date.millisecondsSinceEpoch == 0) return '';
    return DateFormat('MMM d, yyyy · h:mm a').format(date.toLocal());
  }
}
