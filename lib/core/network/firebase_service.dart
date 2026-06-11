import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ─── FIREBASE SERVICE ─────────────────────────────────────────────────────────
// Central hub that exposes all Firebase service instances and collection refs.
// ─────────────────────────────────────────────────────────────────────────────

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  // ── Service Instances ──────────────────────────────────────────────────────
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Enable Firestore offline persistence
    firestore.settings = const Settings(persistenceEnabled: true);

    // Request notification permission
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set analytics collection enabled
    await analytics.setAnalyticsCollectionEnabled(true);
  }

  // ── Auth helpers ───────────────────────────────────────────────────────────

  User? getCurrentUser() => auth.currentUser;

  bool get isLoggedIn => auth.currentUser != null;

  String? get currentUserId => auth.currentUser?.uid;

  Stream<User?> get authStateChanges => auth.authStateChanges();

  // ── Collection References ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get usersRef =>
      firestore.collection('users');

  // User-scoped subcollections — data lives under users/{uid}/...
  CollectionReference<Map<String, dynamic>> tripsRef(String uid) =>
      usersRef.doc(uid).collection('trips');

  CollectionReference<Map<String, dynamic>> expensesRef(String uid) =>
      usersRef.doc(uid).collection('expenses');

  CollectionReference<Map<String, dynamic>> packingListsRef(String uid) =>
      usersRef.doc(uid).collection('packingLists');

  CollectionReference<Map<String, dynamic>> get hiddenGemsRef =>
      firestore.collection('hiddenGems');

  CollectionReference<Map<String, dynamic>> get notificationsRef =>
      firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> get rateLimitsRef =>
      firestore.collection('rateLimits');

  CollectionReference<Map<String, dynamic>> get aiCacheRef =>
      firestore.collection('aiCache');

  CollectionReference<Map<String, dynamic>> get currencyCacheRef =>
      firestore.collection('currencyCache');

  // ── Storage Helpers ────────────────────────────────────────────────────────

  Reference profilePhotosRef(String userId) =>
      storage.ref('profile_photos/$userId');

  Reference gemPhotosRef(String gemId) => storage.ref('gem_photos/$gemId');

  Reference tripPhotosRef(String tripId) => storage.ref('trip_photos/$tripId');


  // ── Analytics Event Helpers ────────────────────────────────────────────────

  Future<void> logLogin(String method) async {
    await analytics.logLogin(loginMethod: method);
  }

  Future<void> logSignUp(String method) async {
    await analytics.logSignUp(signUpMethod: method);
  }

  Future<void> logTripCreated(String destination) async {
    await analytics.logEvent(
      name: 'trip_created',
      parameters: {'destination': destination},
    );
  }

  Future<void> logExpenseAdded(String category, double amount) async {
    await analytics.logEvent(
      name: 'expense_added',
      parameters: {
        'category': category,
        'amount': amount,
      },
    );
  }

  Future<void> logGemAdded(String category) async {
    await analytics.logEvent(
      name: 'gem_added',
      parameters: {'category': category},
    );
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    await analytics.logEvent(name: name, parameters: parameters);
  }

  // ── FCM Token ──────────────────────────────────────────────────────────────

  Future<String?> getFcmToken() async {
    try {
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Save the current FCM token to the user's Firestore doc.
  Future<void> saveFcmToken() async {
    final uid = currentUserId;
    if (uid == null) return;
    final token = await getFcmToken();
    if (token == null) return;
    await usersRef.doc(uid).update({'fcmToken': token});
  }

  // ── Rate Limiting ──────────────────────────────────────────────────────────

  /// Returns true if the action is within the allowed limit.
  Future<bool> checkRateLimit(String action, int maxCount) async {
    final uid = currentUserId;
    if (uid == null) return false;

    final today = _dateKey(DateTime.now());
    final docId = '${uid}_${action}_$today';
    final ref = rateLimitsRef.doc(docId);

    return firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'count': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      final count = snap.data()!['count'] as int? ?? 0;
      if (count >= maxCount) return false;
      tx.update(ref, {
        'count': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
