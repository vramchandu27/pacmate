import 'package:cloud_firestore/cloud_firestore.dart';

// ─── BUDGET / TRIP MODEL ──────────────────────────────────────────────────────

class BudgetModel {
  final String id;
  final String userId;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final double totalBudget;
  final String currency;
  final double totalSpent;
  final bool isActive;
  final bool tripStarted;
  final DateTime? completedAt;
  final List<String> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.totalBudget,
    required this.currency,
    this.totalSpent = 0.0,
    this.isActive = true,
    this.tripStarted = false,
    this.completedAt,
    this.members = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  double get remaining => totalBudget - totalSpent;
  double get spentPercent =>
      totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      destination: d['destination'] as String? ?? '',
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalBudget: (d['totalBudget'] as num?)?.toDouble() ?? 0.0,
      currency: d['currency'] as String? ?? 'INR',
      totalSpent: (d['totalSpent'] as num?)?.toDouble() ?? 0.0,
      isActive: d['isActive'] as bool? ?? true,
      tripStarted: d['tripStarted'] as bool? ?? false,
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      members: List<String>.from(d['members'] as List? ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'destination': destination,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalBudget': totalBudget,
      'currency': currency,
      'totalSpent': totalSpent,
      'isActive': isActive,
      'tripStarted': tripStarted,
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'members': members,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// ─── EXPENSE MODEL ────────────────────────────────────────────────────────────

class ExpenseModel {
  final String id;
  final String tripId;
  final String userId;
  final double amount;
  final double convertedAmountINR;
  final String originalCurrency;
  final String category;
  final String? note;
  final String paidBy;
  final bool splitEqually;
  final List<String> splitBetween;
  final DateTime date;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.amount,
    required this.convertedAmountINR,
    required this.originalCurrency,
    required this.category,
    this.note,
    required this.paidBy,
    this.splitEqually = false,
    this.splitBetween = const [],
    required this.date,
    required this.createdAt,
  });

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      tripId: d['tripId'] as String? ?? '',
      userId: d['userId'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      convertedAmountINR:
          (d['convertedAmountINR'] as num?)?.toDouble() ?? 0.0,
      originalCurrency: d['originalCurrency'] as String? ?? 'INR',
      category: d['category'] as String? ?? 'Other',
      note: d['note'] as String?,
      paidBy: d['paidBy'] as String? ?? '',
      splitEqually: d['splitEqually'] as bool? ?? false,
      splitBetween: List<String>.from(d['splitBetween'] as List? ?? []),
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tripId': tripId,
      'userId': userId,
      'amount': amount,
      'convertedAmountINR': convertedAmountINR,
      'originalCurrency': originalCurrency,
      'category': category,
      'note': note,
      'paidBy': paidBy,
      'splitEqually': splitEqually,
      'splitBetween': splitBetween,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
