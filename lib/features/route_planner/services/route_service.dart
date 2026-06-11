import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/gemini_api_service.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/network/firebase_service.dart';
import '../models/route_model.dart';

// ─── ROUTE SERVICE ────────────────────────────────────────────────────────────
// Generates AI itineraries via Gemini and persists them to Firestore.
// ─────────────────────────────────────────────────────────────────────────────

class RouteService {
  RouteService(this._firebase, this._gemini);

  final FirebaseService _firebase;
  final GeminiApiService _gemini;

  String get _uid => _firebase.currentUserId ?? '';

  // ── Generate ───────────────────────────────────────────────────────────────

  Future<List<RouteDayModel>> generateRoute({
    required String startCity,
    required String endCity,
    required int durationDays,
    required int dailyBudgetINR,
    List<String> interests = const [],
    String pace = 'moderate',
    bool isSenior = false,
    int maxWalkingKm = 10,
    bool vegetarianOnly = false,
  }) async {
    final raw = await _gemini.generateRoute(
      startCity:      startCity,
      endCity:        endCity,
      durationDays:   durationDays,
      dailyBudgetINR: dailyBudgetINR,
      interests:      interests,
      pace:           pace,
      isSenior:       isSenior,
      maxWalkingKm:   maxWalkingKm,
      vegetarianOnly: vegetarianOnly,
    );
    return raw.map(RouteDayModel.fromJson).toList();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<String> saveRoute({
    required String startCity,
    required String endCity,
    required int durationDays,
    required int dailyBudgetINR,
    required List<RouteDayModel> days,
  }) async {
    final docRef = await _firebase.tripsRef(_uid).add({
      'userId':         _uid,
      'type':           'ai_route',
      'startCity':      startCity,
      'endCity':        endCity,
      'durationDays':   durationDays,
      'dailyBudgetINR': dailyBudgetINR,
      'days':           days.map((d) => d.toJson()).toList(),
      'createdAt':      FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ── Saved routes list ──────────────────────────────────────────────────────

  Stream<List<SavedRouteModel>> getSavedRoutes() {
    if (_uid.isEmpty) return const Stream.empty();
    return _firebase.tripsRef(_uid)
        .where('type', isEqualTo: 'ai_route')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SavedRouteModel.fromFirestore(
                Map<String, dynamic>.from(d.data()), d.id))
            .toList());
  }

  Future<void> deleteRoute(String routeId) async {
    await _firebase.tripsRef(_uid).doc(routeId).delete();
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────────────────────

final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService(
    ref.read(firebaseServiceProvider),
    ref.read(geminiServiceProvider),
  );
});

final savedRoutesProvider = StreamProvider<List<SavedRouteModel>>((ref) {
  return ref.read(routeServiceProvider).getSavedRoutes();
});
