import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/gemini_api_service.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/network/firebase_service.dart';
import '../models/packing_input.dart';
import 'packing_engine.dart';

// ─── PACKING SERVICE ─────────────────────────────────────────────────────────
// Manages packing lists stored under users/{uid}/packingLists.
// Shared lists use a collectionGroup query (requires a Firestore
// collectionGroup index on the 'sharedWith' array field).
// ─────────────────────────────────────────────────────────────────────────────

class PackingService {
  PackingService(this._firebase, this._gemini);

  final FirebaseService _firebase;
  final GeminiApiService _gemini;

  String get _uid => _firebase.currentUserId ?? '';
  String get currentUid => _uid;

  // Shorthand for the current user's packing lists subcollection.
  CollectionReference<Map<String, dynamic>> get _myListsRef =>
      _firebase.packingListsRef(_uid);

  // ── Own lists ──────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getPackingLists() {
    if (_uid.isEmpty) return const Stream.empty();
    return _myListsRef
        .where('isTemplate', isEqualTo: false)
        .snapshots()
        .map((snap) => _sortedDocs(snap))
        .handleError((_) => <Map<String, dynamic>>[]);
  }

  // ── Lists shared with this user by others ──────────────────────────────────
  // Uses a collectionGroup query so we can search across all users' subcollections.

  Stream<List<Map<String, dynamic>>> getSharedLists() {
    if (_uid.isEmpty) return const Stream.empty();
    return _firebase.firestore
        .collectionGroup('packingLists')
        .where('sharedWith', arrayContains: _uid)
        .snapshots()
        .map((snap) => _sortedDocs(snap))
        .handleError((_) => <Map<String, dynamic>>[]);
  }

  // ── Templates ──────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getTemplates() {
    if (_uid.isEmpty) return const Stream.empty();
    return _myListsRef
        .where('isTemplate', isEqualTo: true)
        .snapshots()
        .map((snap) => _sortedDocs(snap))
        .handleError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> saveAsTemplate(String listId, String templateName) async {
    final doc = await _myListsRef.doc(listId).get();
    if (!doc.exists) throw Exception('List not found');
    final data = doc.data()!;
    await _myListsRef.add({
      'userId': _uid,
      'name': templateName,
      'destination': data['destination'] ?? '',
      'items': data['items'] ?? [],
      'isTemplate': true,
      'sharedWith': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTemplate(String templateId) async {
    await _myListsRef.doc(templateId).delete();
  }

  // ── Sharing ────────────────────────────────────────────────────────────────

  /// Finds a PacMate user by email and adds them to the list's sharedWith array.
  Future<String> shareListWith(String listId, String email) async {
    final query = await _firebase.usersRef
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('No PacMate user found with that email.');
    }

    final targetUid  = query.docs.first.id;
    final targetName = query.docs.first.data()['fullName'] as String? ?? email;

    if (targetUid == _uid) {
      throw Exception('You cannot share a list with yourself.');
    }

    await _myListsRef.doc(listId).update({
      'sharedWith': FieldValue.arrayUnion([targetUid]),
    });

    return targetName;
  }

  Future<void> removeSharee(String listId, String uid) async {
    await _myListsRef.doc(listId).update({
      'sharedWith': FieldValue.arrayRemove([uid]),
    });
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  /// Fetch a packing list. Pass [ownerUid] when accessing a list shared by
  /// another user (ownerUid is stored in the list document as 'userId').
  Stream<Map<String, dynamic>?> getPackingList(
    String listId, {
    String? ownerUid,
  }) {
    final ref = _firebase.packingListsRef(ownerUid ?? _uid).doc(listId);
    return ref.snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] = doc.id;
      return data;
    });
  }

  Future<void> updateItems(
    String listId,
    List<Map<String, dynamic>> items, {
    String? ownerUid,
  }) async {
    await _firebase
        .packingListsRef(ownerUid ?? _uid)
        .doc(listId)
        .update({
      'items': items,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePackingList(String listId) async {
    await _myListsRef.doc(listId).delete();
  }

  Future<String> savePackingListWithItems({
    required String name,
    required String destination,
    required List<Map<String, dynamic>> items,
  }) async {
    final docRef = await _myListsRef.add({
      'userId': _uid,
      'name': name,
      'destination': destination,
      'items': items,
      'isTemplate': false,
      'sharedWith': <String>[],
      'generatedByAI': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<String> createPackingListFromRules({
    required String name,
    required PackingInput input,
  }) async {
    final result = PackingEngine.generate(input);
    return savePackingListWithItems(
      name: name,
      destination: input.destination,
      items: result.toFirestoreItems(),
    );
  }

  Future<String> createPackingListFromAI({
    required String name,
    required String destination,
    required int durationDays,
    required String month,
    String travelStyle = 'budget',
    String accommodation = 'hostel',
    bool isSoloFemale = false,
    bool hasKids = false,
    bool isSenior = false,
  }) async {
    final categories = await _gemini.generatePackingList(
      destination: destination,
      durationDays: durationDays,
      month: month,
      travelStyle: travelStyle,
      accommodation: accommodation,
      isSoloFemale: isSoloFemale,
      hasKids: hasKids,
      isSenior: isSenior,
    );

    final items = <Map<String, dynamic>>[];
    int idx = 0;
    for (final entry in categories.entries) {
      for (final itemName in entry.value) {
        items.add({
          'id': 'ai_${idx++}',
          'name': itemName,
          'category': entry.key,
          'packed': false,
          'quantity': 1,
        });
      }
    }

    final docRef = await _myListsRef.add({
      'userId': _uid,
      'name': name,
      'destination': destination,
      'items': items,
      'isTemplate': false,
      'sharedWith': <String>[],
      'generatedByAI': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _sortedDocs(QuerySnapshot snap) {
    final docs = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data() as Map);
      data['id'] = d.id;
      return data;
    }).toList();
    docs.sort((a, b) {
      final aTs = a['createdAt'];
      final bTs = b['createdAt'];
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return (bTs as Timestamp).millisecondsSinceEpoch
          .compareTo((aTs as Timestamp).millisecondsSinceEpoch);
    });
    return docs;
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────────────────────

final packingServiceProvider = Provider<PackingService>(
  (ref) => PackingService(
    ref.read(firebaseServiceProvider),
    ref.read(geminiServiceProvider),
  ),
);

final packingListsProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(packingServiceProvider).getPackingLists(),
);

final sharedListsProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(packingServiceProvider).getSharedLists(),
);

final packingTemplatesProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(packingServiceProvider).getTemplates(),
);

final packingListProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, listId) {
  return ref.read(packingServiceProvider).getPackingList(listId);
});
