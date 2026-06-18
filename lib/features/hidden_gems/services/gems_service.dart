import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/auth_service.dart';
import '../../../core/network/firebase_service.dart';
import '../../../shared/models/gem_model.dart';

// ─── GEMS SERVICE ─────────────────────────────────────────────────────────────

typedef GemPage = ({
  List<GemModel> gems,
  DocumentSnapshot? cursor,
  bool hasMore,
});

class GemsService {
  GemsService(this._firebase);

  final FirebaseService _firebase;

  String get _uid => _firebase.currentUserId ?? '';

  // ── Discovery ──────────────────────────────────────────────────────────────

  /// Stream gems within [radiusKm] of [latitude, longitude].
  /// Fetches all gems and filters by real-world distance client-side —
  /// avoids composite Firestore index requirements.
  Stream<List<GemModel>> getGemsNearby({
    required double latitude,
    required double longitude,
    String? category,
    double radiusKm = 50,
  }) {
    return _firebase.hiddenGemsRef
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .map((snap) {
          final all = snap.docs.map((d) => GemModel.fromFirestore(d));
          final nearby = all.where((g) {
            final dist = Geolocator.distanceBetween(
              latitude, longitude,
              g.location.latitude, g.location.longitude,
            );
            return dist <= radiusKm * 1000;
          }).toList();
          if (category != null && category != 'All') {
            return nearby.where((g) => g.category == category).toList();
          }
          return nearby;
        });
  }

  /// Stream gems filtered by trip city (case-insensitive contains match).
  Stream<List<GemModel>> getGemsByCity(String city, {String? category}) {
    final cityLower = city.trim().toLowerCase();
    if (cityLower.isEmpty) return getAllGems(category: category);
    return _firebase.hiddenGemsRef
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) {
          var gems = snap.docs.map((d) => GemModel.fromFirestore(d)).where((g) {
            final g2 = g.city.trim().toLowerCase();
            // Gems with no city saved cannot be matched to any destination.
            if (g2.isEmpty) return false;
            return g2.contains(cityLower) || cityLower.contains(g2);
          }).toList();
          if (category != null && category != 'All') {
            gems = gems.where((g) => g.category == category).toList();
          }
          return gems;
        });
  }

  // ── Pagination ─────────────────────────────────────────────────────────────

  static const pageSize = 20;

  Future<GemPage> fetchRecentPage({
    String? category,
    DocumentSnapshot? after,
  }) async {
    var q = _firebase.hiddenGemsRef
        .orderBy('createdAt', descending: true)
        .limit(pageSize + 1);
    if (after != null) q = q.startAfterDocument(after);
    return _toPage(await q.get(), category);
  }

  Future<GemPage> fetchTrendingPage({
    String? category,
    DocumentSnapshot? after,
  }) async {
    var q = _firebase.hiddenGemsRef
        .orderBy('upvotes', descending: true)
        .limit(pageSize + 1);
    if (after != null) q = q.startAfterDocument(after);
    return _toPage(await q.get(), category);
  }

  Future<GemPage> fetchNearbyPage({
    required double latitude,
    required double longitude,
    String? category,
    DocumentSnapshot? after,
    double radiusKm = 50,
  }) async {
    // Geo-filter can't be paginated server-side, so fetch a large batch
    // and filter by real-world distance client-side.
    var q = _firebase.hiddenGemsRef
        .orderBy('createdAt', descending: true)
        .limit(200);
    if (after != null) q = q.startAfterDocument(after);
    final snap = await q.get();
    final nearby = snap.docs
        .map((d) => GemModel.fromFirestore(d))
        .where((g) {
          final m = Geolocator.distanceBetween(
            latitude, longitude,
            g.location.latitude, g.location.longitude,
          );
          return m <= radiusKm * 1000;
        })
        .toList();
    final filtered = category != null
        ? nearby.where((g) => g.category == category).toList()
        : nearby;
    final page = filtered.take(pageSize).toList();
    return (
      gems: page,
      cursor: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length >= 200,
    );
  }

  /// Paginated fetch filtered by city name (client-side, case-insensitive).
  Future<GemPage> fetchCityPage({
    required String city,
    String? category,
    DocumentSnapshot? after,
  }) async {
    var q = _firebase.hiddenGemsRef
        .orderBy('createdAt', descending: true)
        .limit(200);
    if (after != null) q = q.startAfterDocument(after);
    final snap = await q.get();
    final cityLower = city.trim().toLowerCase();
    final filtered = snap.docs
        .map((d) => GemModel.fromFirestore(d))
        .where((g) {
          if (cityLower.isEmpty) return true;
          final g2 = g.city.trim().toLowerCase();
          if (g2.isEmpty) return false;
          return g2.contains(cityLower) || cityLower.contains(g2);
        })
        .where((g) => category == null || g.category == category)
        .toList();
    final page = filtered.take(pageSize).toList();
    return (
      gems: page,
      cursor: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length >= 200,
    );
  }

  GemPage _toPage(QuerySnapshot snap, String? category) {
    final hasMore = snap.docs.length > pageSize;
    final docs = hasMore ? snap.docs.take(pageSize).toList() : snap.docs.toList();
    var gems = docs.map((d) => GemModel.fromFirestore(d)).toList();
    if (category != null) {
      gems = gems.where((g) => g.category == category).toList();
    }
    return (
      gems: gems,
      cursor: docs.isEmpty ? null : docs.last,
      hasMore: hasMore,
    );
  }

  // ── Stream (used by map view only) ────────────────────────────────────────

  /// Stream all gems, newest first (for list/browse view).
  Stream<List<GemModel>> getAllGems({String? category}) {
    final query = _firebase.hiddenGemsRef
        .orderBy('createdAt', descending: true)
        .limit(100);

    return query.snapshots().map((snap) {
      final gems = snap.docs.map((d) => GemModel.fromFirestore(d)).toList();
      if (category != null && category != 'All') {
        return gems.where((g) => g.category == category).toList();
      }
      return gems;
    });
  }

  /// Most-upvoted gems (trending), optionally filtered by category.
  Stream<List<GemModel>> getTrendingGems({String? category}) {
    final query = _firebase.hiddenGemsRef
        .orderBy('upvotes', descending: true)
        .limit(50);

    return query.snapshots().map((snap) {
      final gems = snap.docs.map((d) => GemModel.fromFirestore(d)).toList();
      if (category != null && category != 'All') {
        return gems.where((g) => g.category == category).toList();
      }
      return gems;
    });
  }

  // ── Submission ─────────────────────────────────────────────────────────────

  /// Add a new gem, upload photos to Storage, and return the gem ID.
  Future<String> addGem({
    required String name,
    required String description,
    required String category,
    required double latitude,
    required double longitude,
    required String city,
    required String country,
    List<File> photoFiles = const [],
    void Function(int done)? onPhotoUploaded,
  }) async {
    final now = DateTime.now();

    // Upload photos sequentially so we can report per-photo progress.
    final photoUrls = <String>[];
    for (var i = 0; i < photoFiles.length; i++) {
      final ref = _firebase.gemPhotosRef('temp').child(
          '${_uid}_${now.millisecondsSinceEpoch}_$i.jpg');
      final task = await ref.putFile(
        photoFiles[i],
        SettableMetadata(contentType: 'image/jpeg'),
      );
      photoUrls.add(await task.ref.getDownloadURL());
      onPhotoUploaded?.call(i + 1);
    }

    final gem = GemModel(
      id: '',
      name: name,
      description: description,
      category: category,
      location: GeoPoint(latitude, longitude),
      city: city,
      country: country,
      photos: photoUrls,
      addedBy: _uid,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _firebase.hiddenGemsRef.add(gem.toFirestore());

    // Write or increment today's batch notification for this location.
    // One card per city per day instead of one card per gem.
    await _writeGemBatchNotification(
      gemId: docRef.id,
      city: city,
      country: country,
      latitude: latitude,
      longitude: longitude,
    );

    _firebase.logGemAdded(category);
    return docRef.id;
  }

  /// Finds today's batch notification for [city] and increments its count,
  /// or creates a new one if none exists yet today.
  Future<void> _writeGemBatchNotification({
    required String gemId,
    required String city,
    required String country,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final now      = DateTime.now();
      final dateKey  = '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final location = city.isNotEmpty
          ? city
          : (country.isNotEmpty ? country : 'your area');
      final batchKey = '${location}_$dateKey';

      // Query by top-level batchKey field — no composite index required.
      final snap = await _firebase.notificationsRef
          .where('batchKey', isEqualTo: batchKey)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        // Batch already exists today — increment count and mark unread again.
        final doc  = snap.docs.first;
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final meta = data['metadata'] as Map<String, dynamic>? ?? {};
        final newCount = (meta['count'] as int? ?? 1) + 1;

        final existingIds = List<String>.from(meta['gemIds'] as List? ?? []);
        final updatedIds  = [...existingIds, gemId];
        await doc.reference.update({
          'title'           : '$newCount new spots added in $location today',
          'body'            : 'Travelers are discovering new places in $location — go explore!',
          'isRead'          : false,
          'actionRoute'     : '/gems/new?ids=${updatedIds.join(',')}&city=${Uri.encodeComponent(location)}',
          'metadata.count'  : FieldValue.increment(1),
          'metadata.gemIds' : FieldValue.arrayUnion([gemId]),
        });
      } else {
        // First gem in this location today — create the batch card.
        await _firebase.notificationsRef.add({
          'userId'     : 'broadcast',
          'title'      : 'New spot just added in $location 🗺️',
          'body'       : 'Be the first to visit and share your experience!',
          'type'       : 'gemAdded',
          'isRead'     : false,
          'batchKey'   : batchKey,
          'actionRoute': '/gems/new?ids=$gemId&city=${Uri.encodeComponent(location)}',
          'metadata'   : {
            'batchKey' : batchKey,
            'city'     : location,
            'country'  : country,
            'count'    : 1,
            'gemIds'   : [gemId],
            'date'     : dateKey,
            'latitude' : latitude,
            'longitude': longitude,
          },
          'createdAt'  : FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Notification failure must never block gem creation.
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  /// Client-side search across name, description, city, and category.
  /// Fetches the 300 most recent gems and filters locally.
  Future<List<GemModel>> searchGems(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final snap = await _firebase.hiddenGemsRef
        .orderBy('createdAt', descending: true)
        .limit(300)
        .get();
    return snap.docs
        .map((d) => GemModel.fromFirestore(d))
        .where((g) =>
            g.name.toLowerCase().contains(q) ||
            g.description.toLowerCase().contains(q) ||
            g.city.toLowerCase().contains(q) ||
            g.category.toLowerCase().contains(q))
        .toList();
  }

  // ── Single Gem ─────────────────────────────────────────────────────────────

  Future<GemModel?> getGemById(String gemId) async {
    final doc = await _firebase.hiddenGemsRef.doc(gemId).get();
    if (!doc.exists) return null;
    return GemModel.fromFirestore(doc);
  }

  // ── My Gems ────────────────────────────────────────────────────────────────

  Stream<List<GemModel>> getMyGems() {
    return _firebase.hiddenGemsRef
        .where('addedBy', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => GemModel.fromFirestore(d)).toList());
  }

  // ── Voting ─────────────────────────────────────────────────────────────────

  /// Returns true if the current user has already liked [gemId].
  Future<bool> hasUserLiked(String gemId) async {
    final doc = await _firebase.hiddenGemsRef
        .doc(gemId)
        .collection('likes')
        .doc(_uid)
        .get();
    return doc.exists;
  }

  /// Toggles the like atomically. Returns the new liked state.
  Future<bool> toggleLike(String gemId) async {
    final gemRef = _firebase.hiddenGemsRef.doc(gemId);
    final likeRef = gemRef.collection('likes').doc(_uid);

    bool nowLiked = false;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(gemRef, {'upvotes': FieldValue.increment(-1)});
        nowLiked = false;
      } else {
        tx.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
        tx.update(gemRef, {'upvotes': FieldValue.increment(1)});
        nowLiked = true;
      }
    });
    return nowLiked;
  }

  // ── Ratings ────────────────────────────────────────────────────────────────

  /// Returns the current user's rating for [gemId], or null if not rated.
  Future<int?> getUserRating(String gemId) async {
    final doc = await _firebase.hiddenGemsRef
        .doc(gemId)
        .collection('ratings')
        .doc(_uid)
        .get();
    if (!doc.exists) return null;
    return doc.data()!['rating'] as int?;
  }

  /// Rate a gem 1–5. Updates the gem's averageRating + ratingCount atomically.
  Future<void> rateGem(String gemId, int rating) async {
    final gemRef = _firebase.hiddenGemsRef.doc(gemId);
    final ratingRef = gemRef.collection('ratings').doc(_uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final ratingSnap = await tx.get(ratingRef);
      final gemSnap = await tx.get(gemRef);
      final data = gemSnap.data() as Map<String, dynamic>;

      final currentCount = (data['ratingCount'] as int?) ?? 0;
      final currentAvg = (data['averageRating'] as num?)?.toDouble() ?? 0.0;

      if (ratingSnap.exists) {
        final oldRating = (ratingSnap.data()!['rating'] as int?) ?? 0;
        final newAvg = currentCount > 0
            ? (currentAvg * currentCount - oldRating + rating) / currentCount
            : rating.toDouble();
        tx.update(gemRef, {'averageRating': newAvg});
      } else {
        final newCount = currentCount + 1;
        final newAvg =
            (currentAvg * currentCount + rating) / newCount;
        tx.update(gemRef, {
          'averageRating': newAvg,
          'ratingCount': newCount,
        });
      }
      tx.set(ratingRef, {
        'rating': rating,
        'ratedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Save / Unsave (stored in user subcollection) ───────────────────────────

  Future<void> saveGem(String gemId) async {
    await _firebase.usersRef
        .doc(_uid)
        .collection('savedGems')
        .doc(gemId)
        .set({'savedAt': FieldValue.serverTimestamp()});
  }

  Future<void> unsaveGem(String gemId) async {
    await _firebase.usersRef
        .doc(_uid)
        .collection('savedGems')
        .doc(gemId)
        .delete();
  }

  Stream<List<String>> getSavedGemIds() {
    return _firebase.usersRef
        .doc(_uid)
        .collection('savedGems')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────────────────────

final gemsServiceProvider = Provider<GemsService>(
  (ref) => GemsService(ref.read(firebaseServiceProvider)),
);

final allGemsProvider =
    StreamProvider.family<List<GemModel>, String?>((ref, category) {
  return ref.read(gemsServiceProvider).getAllGems(category: category);
});

final trendingGemsProvider =
    StreamProvider.family<List<GemModel>, String?>((ref, category) {
  return ref.read(gemsServiceProvider).getTrendingGems(category: category);
});

/// Resolves the device's current position once. Returns null only if permission denied.
/// Tries medium accuracy first (20s), then falls back to low accuracy (15s) so slow
/// GPS receivers on budget phones don't silently return null.
final currentPositionProvider = FutureProvider<Position?>((ref) async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      // Medium accuracy timed out — fall back to low accuracy (network-based).
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
    }
  } catch (_) {
    return null;
  }
});

/// Gems within ~50 km of the user's current location.
/// Stays in loading state until the position future resolves.
final nearbyGemsProvider =
    StreamProvider.family<List<GemModel>, String?>((ref, category) async* {
  final pos = await ref.watch(currentPositionProvider.future);
  if (pos == null) {
    yield [];
    return;
  }
  yield* ref.read(gemsServiceProvider).getGemsNearby(
    latitude: pos.latitude,
    longitude: pos.longitude,
    category: category,
  );
});

final myGemsProvider = StreamProvider<List<GemModel>>((ref) {
  return ref.read(gemsServiceProvider).getMyGems();
});

final savedGemIdsProvider = StreamProvider<List<String>>((ref) {
  return ref.read(gemsServiceProvider).getSavedGemIds();
});

/// Stream gems for a specific trip city, with optional category filter.
final cityGemsStreamProvider = StreamProvider.family<List<GemModel>,
    ({String city, String? category})>((ref, args) {
  return ref
      .read(gemsServiceProvider)
      .getGemsByCity(args.city, category: args.category);
});
