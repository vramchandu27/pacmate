import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/notification_model.dart';
import '../services/notification_service.dart';

// ─── NOTIFICATIONS SCREEN ─────────────────────────────────────────────────────
// Tapping a notification marks only that one as read (badge decrements by 1).
// Personal notifications → Firestore isRead = true.
// Broadcast notifications → persisted via seenBroadcastIdsProvider (SharedPreferences).
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ),
      body: notificationsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: const TextStyle(fontFamily: 'Poppins', color: AppColors.danger),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) return _buildEmptyState();
          return _buildList(notifications, ref);
        },
      ),
    );
  }

  Widget _buildList(List<NotificationModel> notifications, WidgetRef ref) {
    final alerts     = notifications.where((n) => n.type != NotificationType.gemAdded).toList();
    final discoveries = notifications.where((n) => n.type == NotificationType.gemAdded).toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(notificationsProvider),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          if (alerts.isNotEmpty) ...[
            _sectionHeader('Alerts'),
            ...alerts.map((n) => _NotificationTile(notification: n)),
          ],
          if (discoveries.isNotEmpty) ...[
            _sectionHeader('Nearby Discoveries'),
            ...discoveries.map((n) => _NotificationTile(notification: n)),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.lightOnSurfaceVar,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 72, color: AppColors.lightOutline),
            SizedBox(height: 24),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "We'll let you know when something\nimportant comes up.",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.lightOnSurfaceVar,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── NOTIFICATION TILE ────────────────────────────────────────────────────────

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final NotificationModel notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seenBroadcasts = ref.watch(seenBroadcastIdsProvider);
    final isBroadcast  = notification.userId == 'broadcast';
    final isGem        = notification.type == NotificationType.gemAdded;

    final isUnread = isBroadcast
        ? !seenBroadcasts.contains(notification.id)
        : !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: isBroadcast ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: isBroadcast
          ? null
          : (_) async {
              await ref
                  .read(notificationServiceProvider)
                  .deleteNotification(notification.id);
            },
      child: GestureDetector(
        onTap: () async {
          if (isUnread) {
            if (isBroadcast) {
              await ref
                  .read(seenBroadcastIdsProvider.notifier)
                  .markSeen(notification.id);
            } else {
              await ref
                  .read(notificationServiceProvider)
                  .markAsRead(notification.id);
            }
          }
          if (notification.actionRoute != null && context.mounted) {
            context.push(notification.actionRoute!);
          }
        },
        child: isGem
            ? _buildGemTile(isUnread)
            : _buildAlertTile(isUnread),
      ),
    );
  }

  // ── Discovery tile — gem notifications (lighter, teal-accented) ─────────────
  Widget _buildGemTile(bool isUnseen) {
    final count = notification.metadata['count'] as int? ?? 1;
    final isMultiple = count > 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnseen
            ? AppColors.teal.withAlpha(12)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnseen
              ? AppColors.teal.withAlpha(50)
              : AppColors.lightOutline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gem icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.teal.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.diamond_rounded,
                color: AppColors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time
                Text(
                  _timeAgo(notification.createdAt),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.lightOutline,
                  ),
                ),
                const SizedBox(height: 4),
                // Title
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                // Body
                Text(
                  notification.body,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.lightOnSurfaceVar,
                  ),
                ),
                const SizedBox(height: 8),
                // Count indicator + CTA
                Row(
                  children: [
                    // Spot count pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isMultiple ? '$count spots' : '1 spot',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.explore_rounded,
                        size: 12, color: AppColors.teal),
                    const SizedBox(width: 3),
                    const Text(
                      'View on map',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Alert tile — all other notifications (bold, action-required feel) ────────
  Widget _buildAlertTile(bool isUnread) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? AppColors.primary.withAlpha(10) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread
              ? AppColors.primary.withAlpha(40)
              : AppColors.lightOutline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _typeIcon(notification.type),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight:
                              isUnread ? FontWeight.w600 : FontWeight.w500,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.lightOnSurfaceVar,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _timeAgo(notification.createdAt),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.lightOutline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _typeIcon(NotificationType type) {
    late IconData icon;
    late Color color;
    switch (type) {
      case NotificationType.medicine:
        icon = Icons.medication_rounded;
        color = AppColors.teal;
      case NotificationType.sos:
        icon = Icons.sos_rounded;
        color = AppColors.danger;
      case NotificationType.familyAlert:
        icon = Icons.family_restroom_rounded;
        color = AppColors.purple;
      case NotificationType.chat:
        icon = Icons.chat_bubble_outline_rounded;
        color = AppColors.primary;
      case NotificationType.tripReminder:
        icon = Icons.flight_takeoff_rounded;
        color = AppColors.warning;
      case NotificationType.gemAdded:
        icon = Icons.diamond_outlined;
        color = AppColors.teal;
      case NotificationType.system:
        icon = Icons.info_outline_rounded;
        color = AppColors.lightOnSurfaceVar;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
