import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/auth_service.dart';
import '../../../core/network/firebase_service.dart';
import '../../../features/budget/services/budget_service.dart';
import '../../../shared/models/notification_model.dart';

// ─── NOTIFICATION SERVICE ─────────────────────────────────────────────────────

class NotificationService {
  NotificationService(this._firebase);

  final FirebaseService _firebase;

  String get _uid => _firebase.currentUserId ?? '';

  /// Real-time stream of notifications for the current user, newest first.
  /// Includes community broadcasts (userId == 'broadcast') alongside personal ones.
  Stream<List<NotificationModel>> getNotifications() {
    if (_uid.isEmpty) return Stream.value([]);
    return _firebase.notificationsRef
        .where('userId', whereIn: [_uid, 'broadcast'])
        .snapshots()
        .map((snap) {
          final list =
              snap.docs.map((d) => NotificationModel.fromFirestore(d)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .transform(StreamTransformer.fromHandlers(
          handleError: (e, s, sink) => sink.add(<NotificationModel>[]),
        ));
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notifId) async {
    await _firebase.notificationsRef.doc(notifId).update({'isRead': true});
  }

  /// Delete a notification.
  Future<void> deleteNotification(String notifId) async {
    await _firebase.notificationsRef.doc(notifId).delete();
  }

  /// Write a notification. Pass [userId] = `'broadcast'` to notify all nearby users.
  Future<void> createNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? userId,
    String? actionRoute,
    Map<String, dynamic> metadata = const {},
  }) async {
    final targetId = userId ?? _uid;
    if (targetId.isEmpty) return;
    final notif = NotificationModel(
      id: '',
      userId: targetId,
      title: title,
      body: body,
      type: type,
      actionRoute: actionRoute,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
    await _firebase.notificationsRef.add(notif.toFirestore());
  }
}

// ─── SEEN BROADCASTS NOTIFIER ─────────────────────────────────────────────────
// Persists seen broadcast IDs to SharedPreferences so the badge stays cleared
// across app restarts.

class SeenBroadcastsNotifier extends StateNotifier<Set<String>> {
  SeenBroadcastsNotifier() : super({}) {
    _load();
  }

  static const _prefsKey = 'seen_broadcast_ids';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? [];
    state = Set<String>.from(ids);
  }

  Future<void> markSeen(String id) async {
    if (state.contains(id)) return;
    state = {...state, id};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state.toList());
  }

  Future<void> clear() async {
    state = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(firebaseServiceProvider));
});

/// Quick cached position for notification geo-filtering.
/// Uses last-known position (fast, no GPS spin-up) — good enough for 50 km radius.
final _notifLocationProvider = FutureProvider<Position?>((ref) async {
  try {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) { return null; }
    return await Geolocator.getLastKnownPosition();
  } catch (_) {
    return null;
  }
});

/// Notifications for the current user, geo-filtered:
/// - Personal notifications (SOS, medicine, chat…) are always shown.
/// - Broadcast gem notifications are only shown when the gem is within 50 km
///   of the user's last known position. If location is unavailable, all are shown.
final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) async* {
  final pos              = await ref.watch(_notifLocationProvider.future);
  final accountCreatedAt = FirebaseAuth.instance.currentUser?.metadata.creationTime;

  // Only match gems against CURRENTLY ACTIVE trips (user is traveling right now).
  // Upcoming future trips are excluded — no point showing Spain gems while
  // the user is still sitting in Hyderabad.
  final now = DateTime.now();
  final trips = ref.watch(allTripsProvider).valueOrNull ?? [];
  final tripKeywords = trips
      .where((t) => !t.startDate.isAfter(now) && t.endDate.isAfter(now))
      .expand((t) => t.destination.toLowerCase().split(RegExp(r'[,\s]+')))
      .where((w) => w.length > 2)
      .toSet();

  yield* ref.read(notificationServiceProvider).getNotifications().map((list) {
    final cutoff7d = now.subtract(const Duration(days: 7));
    return list.where((n) {
      // Drop broadcasts that predate this user's account
      if (n.userId == 'broadcast' && accountCreatedAt != null) {
        if (n.createdAt.isBefore(accountCreatedAt)) return false;
      }

      // Drop stale gem broadcasts older than 7 days — they're no longer relevant
      if (n.userId == 'broadcast' && n.type == NotificationType.gemAdded) {
        if (n.createdAt.isBefore(cutoff7d)) return false;
      }

      // Only gem broadcasts need location filtering
      if (n.userId != 'broadcast' || n.type != NotificationType.gemAdded) {
        return true;
      }

      // 1️⃣ Show if gem city OR country matches any active trip destination
      final gemCity    = (n.metadata['city']    as String? ?? '').toLowerCase();
      final gemCountry = (n.metadata['country'] as String? ?? '').toLowerCase();
      final gemWords   = {gemCity, gemCountry}.where((s) => s.length > 2);
      if (gemWords.any((word) =>
          tripKeywords.any((kw) => word.contains(kw) || kw.contains(word)))) {
        return true;
      }

      // 2️⃣ Show if gem is within 50 km of current physical location
      if (pos != null) {
        final lat = n.metadata['latitude'] as double?;
        final lng = n.metadata['longitude'] as double?;
        if (lat != null && lng != null) {
          return Geolocator.distanceBetween(
            pos.latitude, pos.longitude, lat, lng,
          ) <= 50 * 1000;
        }
      }

      // 3️⃣ No location permission + no active trip match → hide gem broadcasts
      // (avoids surfacing stale test/dev data and irrelevant gems to new users)
      return false;
    }).toList();
  });
});

/// Persisted set of broadcast notification IDs the user has already seen.
/// Survives app restarts via SharedPreferences.
final seenBroadcastIdsProvider =
    StateNotifierProvider<SeenBroadcastsNotifier, Set<String>>(
  (ref) => SeenBroadcastsNotifier(),
);

/// Derived unread count: Firestore isRead for personal + persisted seen set
/// for broadcasts. Reactive — updates whenever either source changes.
final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? [];
  final seenBroadcasts = ref.watch(seenBroadcastIdsProvider);
  return notifications.where((n) {
    // Gem discoveries don't count toward the bell badge —
    // they're nice-to-know, not action-required
    if (n.type == NotificationType.gemAdded) return false;
    if (n.userId == 'broadcast') return !seenBroadcasts.contains(n.id);
    return !n.isRead;
  }).length;
});
