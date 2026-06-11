import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/auth_service.dart';
import '../../../core/network/firebase_service.dart';
import '../../../shared/models/budget_model.dart';

// ─── BUDGET SERVICE ───────────────────────────────────────────────────────────
// Manages trips and expenses stored under users/{uid}/trips and
// users/{uid}/expenses (subcollections of the user document).
// ─────────────────────────────────────────────────────────────────────────────

class BudgetService {
  BudgetService(this._firebase);

  final FirebaseService _firebase;

  String get _uid => _firebase.currentUserId ?? '';
  String get currentUserId => _uid;

  // ── Trip (Budget) Operations ───────────────────────────────────────────────

  /// Create a new trip and return its Firestore document ID.
  Future<String> createTrip({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required double totalBudget,
    required String currency,
  }) async {
    final now = DateTime.now();
    final trip = BudgetModel(
      id: '',
      userId: _uid,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      totalBudget: totalBudget,
      currency: currency,
      createdAt: now,
      updatedAt: now,
    );

    // Deactivate any existing active trip — all trips are now user-scoped
    // by path so no userId filter needed.
    final existing = await _firebase.tripsRef(_uid).get();
    for (final doc in existing.docs) {
      final t = BudgetModel.fromFirestore(doc);
      if (t.isActive) await doc.reference.update({'isActive': false});
    }

    final docRef = await _firebase.tripsRef(_uid).add(trip.toFirestore());
    await _firebase.logTripCreated(destination);
    return docRef.id;
  }

  /// Stream of the current user's active trip.
  Stream<BudgetModel?> getActiveTrip() {
    if (_uid.isEmpty) return Stream.value(null);
    return _firebase.tripsRef(_uid).snapshots().map((snap) {
      for (final doc in snap.docs) {
        final trip = BudgetModel.fromFirestore(doc);
        if (trip.isActive) return trip;
      }
      return null;
    });
  }

  /// Stream of all trips for the current user, sorted newest-first.
  Stream<List<BudgetModel>> getAllTrips() {
    if (_uid.isEmpty) return Stream.value([]);
    return _firebase.tripsRef(_uid).snapshots().map((snap) {
      final trips =
          snap.docs.map((d) => BudgetModel.fromFirestore(d)).toList();
      trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return trips;
    });
  }

  // ── Expense Operations ─────────────────────────────────────────────────────

  /// Add an expense and update the trip's totalSpent atomically.
  Future<String> addExpense({
    required String tripId,
    required double amount,
    required double convertedAmountINR,
    required String originalCurrency,
    required String category,
    String? note,
    required String paidBy,
    bool splitEqually = false,
    List<String> splitBetween = const [],
  }) async {
    final now = DateTime.now();
    final expense = ExpenseModel(
      id: '',
      tripId: tripId,
      userId: _uid,
      amount: amount,
      convertedAmountINR: convertedAmountINR,
      originalCurrency: originalCurrency,
      category: category,
      note: note,
      paidBy: paidBy,
      splitEqually: splitEqually,
      splitBetween: splitBetween,
      date: now,
      createdAt: now,
    );

    final docRef = await _firebase.expensesRef(_uid).add(expense.toFirestore());

    await _firebase.tripsRef(_uid).doc(tripId).update({
      'totalSpent': FieldValue.increment(convertedAmountINR),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firebase.logExpenseAdded(category, convertedAmountINR);
    return docRef.id;
  }

  /// Real-time stream of all expenses for a trip, newest first.
  Stream<List<ExpenseModel>> getExpenses(String tripId) {
    if (_uid.isEmpty || tripId.isEmpty) return Stream.value([]);
    return _firebase
        .expensesRef(_uid)
        .where('tripId', isEqualTo: tripId)
        .snapshots()
        .map((snap) {
      final expenses =
          snap.docs.map((d) => ExpenseModel.fromFirestore(d)).toList();
      expenses.sort((a, b) => b.date.compareTo(a.date));
      return expenses;
    });
  }

  /// Update an expense's amount, category, and note; adjusts trip totalSpent.
  Future<void> updateExpense({
    required String expenseId,
    required String tripId,
    required double oldConvertedAmountINR,
    required double newAmount,
    required double newConvertedAmountINR,
    required String category,
    String? note,
  }) async {
    await _firebase.expensesRef(_uid).doc(expenseId).update({
      'amount': newAmount,
      'convertedAmountINR': newConvertedAmountINR,
      'category': category,
      'note': note ?? '',
    });
    final diff = newConvertedAmountINR - oldConvertedAmountINR;
    if (diff.abs() > 0.001) {
      await _firebase.tripsRef(_uid).doc(tripId).update({
        'totalSpent': FieldValue.increment(diff),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Delete an expense and subtract its amount from the trip total.
  Future<void> deleteExpense({
    required String expenseId,
    required String tripId,
    required double convertedAmountINR,
  }) async {
    await _firebase.expensesRef(_uid).doc(expenseId).delete();
    await _firebase.tripsRef(_uid).doc(tripId).update({
      'totalSpent': FieldValue.increment(-convertedAmountINR),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Confirm the user has departed — sets tripStarted = true.
  Future<void> startTrip(String tripId) async {
    await _firebase.tripsRef(_uid).doc(tripId).update({
      'tripStarted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark a trip as completed — deactivates it and records completion timestamp.
  Future<void> completeTrip(String tripId) async {
    if (_uid.isEmpty) throw Exception('Not logged in');

    final batch = _firebase.firestore.batch();

    batch.update(_firebase.tripsRef(_uid).doc(tripId), {
      'isActive': false,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(
      _firebase.usersRef.doc(_uid),
      {'totalTrips': FieldValue.increment(1)},
    );

    await batch.commit();
  }

  /// Update editable trip fields — budget, end date, destination.
  Future<void> updateTrip(
    String tripId, {
    double? totalBudget,
    DateTime? endDate,
    String? destination,
  }) async {
    if (_uid.isEmpty) throw Exception('Not logged in');
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (totalBudget != null) data['totalBudget'] = totalBudget;
    if (endDate != null) data['endDate'] = Timestamp.fromDate(endDate);
    if (destination != null) data['destination'] = destination;
    await _firebase.tripsRef(_uid).doc(tripId).update(data);
  }

  /// Returns category → total-spent map for a trip.
  Future<Map<String, double>> getExpensesByCategory(String tripId) async {
    final snap = await _firebase
        .expensesRef(_uid)
        .where('tripId', isEqualTo: tripId)
        .get();

    final map = <String, double>{};
    for (final doc in snap.docs) {
      final expense = ExpenseModel.fromFirestore(doc);
      map[expense.category] =
          (map[expense.category] ?? 0) + expense.convertedAmountINR;
    }
    return map;
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────────────────────

final budgetServiceProvider = Provider<BudgetService>(
  (ref) => BudgetService(ref.read(firebaseServiceProvider)),
);

final activeTripProvider = StreamProvider<BudgetModel?>((ref) {
  return ref.watch(budgetServiceProvider).getActiveTrip();
});

final tripExpensesProvider =
    StreamProvider.family<List<ExpenseModel>, String>((ref, tripId) {
  return ref.read(budgetServiceProvider).getExpenses(tripId);
});

final allTripsProvider = StreamProvider<List<BudgetModel>>((ref) {
  return ref.watch(budgetServiceProvider).getAllTrips();
});
