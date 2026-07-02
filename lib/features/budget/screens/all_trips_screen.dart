import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/budget_model.dart';
import '../../../shared/models/currency_data.dart';
import '../services/budget_service.dart';

// ─── ALL TRIPS SCREEN ─────────────────────────────────────────────────────────
// Shows every trip (active, upcoming, past) as tappable cards.
// Tapping a card opens a detail bottom sheet with budget summary + categories.
// Reached via the "Trips Done" stat card on the home dashboard.
// ─────────────────────────────────────────────────────────────────────────────

class AllTripsScreen extends ConsumerWidget {
  const AllTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTripsAsync = ref.watch(allTripsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Trip History',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: allTripsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allTrips) {
          if (allTrips.isEmpty) return _buildEmpty(context);
          final sections = _split(allTrips);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              if (sections.active.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Active Trip',
                    icon: Icons.flight_takeoff_rounded,
                    color: AppColors.success),
                const SizedBox(height: 12),
                ...sections.active.map(
                    (t) => _TripCard(trip: t, tripStatus: _TripStatus.active)),
                const SizedBox(height: 28),
              ],
              if (sections.upcoming.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Upcoming',
                    icon: Icons.event_rounded,
                    color: AppColors.warning),
                const SizedBox(height: 12),
                ...sections.upcoming.map(
                    (t) => _TripCard(trip: t, tripStatus: _TripStatus.upcoming)),
                const SizedBox(height: 28),
              ],
              if (sections.past.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Past Trips',
                    icon: Icons.history_rounded,
                    color: AppColors.lightOnSurfaceVar),
                const SizedBox(height: 12),
                ...sections.past.map(
                    (t) => _TripCard(trip: t, tripStatus: _TripStatus.past)),
              ],
            ],
          );
        },
      ),
    );
  }

  static _TripSections _split(List<BudgetModel> trips) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final active = trips.where((t) {
      if (t.completedAt != null) return false;
      final s = DateTime(t.startDate.year, t.startDate.month, t.startDate.day);
      final e = DateTime(t.endDate.year,   t.endDate.month,   t.endDate.day);
      return !s.isAfter(today) && !e.isBefore(today);
    }).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));

    final upcoming = trips.where((t) {
      if (t.completedAt != null) return false;
      final s = DateTime(t.startDate.year, t.startDate.month, t.startDate.day);
      return s.isAfter(today);
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final past = trips.where((t) {
      final e = DateTime(t.endDate.year, t.endDate.month, t.endDate.day);
      return e.isBefore(today) || t.completedAt != null;
    }).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return _TripSections(active: active, upcoming: upcoming, past: past);
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flight_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'No trips yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first trip from the Budget Tracker',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.lightOnSurfaceVar,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── SECTION HEADER ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}

// ─── TRIP STATUS ENUM ─────────────────────────────────────────────────────────

enum _TripStatus { active, upcoming, past }

// ─── TRIP CARD ────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.tripStatus});
  final BudgetModel trip;
  final _TripStatus tripStatus;

  @override
  Widget build(BuildContext context) {
    final fmt         = DateFormat('d MMM yy');
    final dateRange   = '${fmt.format(trip.startDate)} – ${fmt.format(trip.endDate)}';
    final days        = trip.endDate.difference(trip.startDate).inDays + 1;
    final pct         = trip.spentPercent;
    final overBudget  = trip.totalSpent > trip.totalBudget;
    final remaining   = trip.totalBudget - trip.totalSpent;

    final (badgeColor, badgeLabel) = switch (tripStatus) {
      _TripStatus.active   => (AppColors.success,              'ACTIVE'),
      _TripStatus.upcoming => (AppColors.warning,              'UPCOMING'),
      _TripStatus.past     => (AppColors.lightOnSurfaceVar,    'DONE'),
    };

    final barColor = overBudget ? AppColors.danger : AppColors.primary;

    final sym = kAllCurrencies
        .firstWhere((c) => c.code == trip.currency,
            orElse: () => const CurrencyEntry(
                code: 'INR', name: '', symbol: '₹', flag: '', toInrRate: 1.0))
        .symbol;
    final nf = trip.currency == 'INR'
        ? NumberFormat('#,##,##0', 'en_IN')
        : NumberFormat('#,##0');

    String fmtAmt(double v) => '$sym${nf.format(v.abs())}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetail(context),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEF0F3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row 1: destination + badge ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip.destination,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: badgeColor.withAlpha(80), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: badgeColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              badgeLabel,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // ── Row 2: dates + days ─────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 12, color: AppColors.lightOnSurfaceVar),
                      const SizedBox(width: 5),
                      Text(
                        '$dateRange  ·  $days ${days == 1 ? 'day' : 'days'}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.lightOnSurfaceVar,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Budget bar ──────────────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEEF0F3),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ── Row 3: spent / budget  +  arrow ────────────────────────
                  Row(
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontFamily: 'Poppins'),
                          children: [
                            TextSpan(
                              text: fmtAmt(trip.totalSpent),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: overBudget
                                    ? AppColors.danger
                                    : AppColors.navy,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${fmtAmt(trip.totalBudget)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.lightOnSurfaceVar,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (tripStatus == _TripStatus.past && trip.totalBudget > 0)
                        Text(
                          remaining >= 0
                              ? 'Saved ${fmtAmt(remaining)}'
                              : 'Over ${fmtAmt(remaining.abs())}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: remaining >= 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 13, color: AppColors.lightOnSurfaceVar),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TripDetailSheet(trip: trip, tripStatus: tripStatus),
    );
  }
}

// ─── TRIP DETAIL BOTTOM SHEET ─────────────────────────────────────────────────

class _TripDetailSheet extends ConsumerWidget {
  const _TripDetailSheet({required this.trip, required this.tripStatus});
  final BudgetModel trip;
  final _TripStatus tripStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(tripExpensesProvider(trip.id));
    final fmtDate = DateFormat('d MMMM yyyy');
    final days = trip.endDate.difference(trip.startDate).inDays + 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day);
    final isUpcoming = trip.completedAt == null && startDay.isAfter(today);
    final overBudget = trip.totalSpent > trip.totalBudget;
    final remaining  = trip.totalBudget - trip.totalSpent;
    final accentColor = overBudget ? AppColors.danger : AppColors.success;

    final sym = kAllCurrencies
        .firstWhere((c) => c.code == trip.currency,
            orElse: () => const CurrencyEntry(
                code: 'INR', name: '', symbol: '₹', flag: '', toInrRate: 1.0))
        .symbol;
    final nf = trip.currency == 'INR'
        ? NumberFormat('#,##,##0', 'en_IN')
        : NumberFormat('#,##0');
    String fmtAmt(double v) => '$sym${nf.format(v.abs())}';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE1E7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.destination,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.lightOnSurfaceVar, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 13, color: AppColors.lightOnSurfaceVar),
                  const SizedBox(width: 5),
                  Text(
                    '${fmtDate.format(trip.startDate)} – ${fmtDate.format(trip.endDate)}  ·  $days ${days == 1 ? 'day' : 'days'}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.lightOnSurfaceVar,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEEF0F3)),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  // ── Budget summary ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEF0F3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _DetailStat(
                              label: 'Budget',
                              value: fmtAmt(trip.totalBudget),
                              color: AppColors.navy,
                              align: CrossAxisAlignment.start,
                            ),
                            _DetailStat(
                              label: 'Spent',
                              value: fmtAmt(trip.totalSpent),
                              color: AppColors.navy,
                              align: CrossAxisAlignment.center,
                            ),
                            _DetailStat(
                              label: overBudget ? 'Over' : 'Saved',
                              value: fmtAmt(remaining),
                              color: accentColor,
                              align: CrossAxisAlignment.end,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: trip.spentPercent.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: const Color(0xFFEEF0F3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                overBudget ? AppColors.danger : AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(trip.spentPercent * 100).clamp(0, 100).toStringAsFixed(1)}% used',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.lightOnSurfaceVar,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Category breakdown from expenses ──────────────────────
                  if (isUpcoming) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEEF0F3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.event_rounded,
                              color: AppColors.warning, size: 32),
                          const SizedBox(height: 10),
                          const Text(
                            'Trip hasn\'t started yet',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Starts ${fmtDate.format(trip.startDate)}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.lightOnSurfaceVar,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[ // past or active — show real expense data
                  expensesAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2)),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (expenses) {
                      if (expenses.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEEF0F3)),
                          ),
                          child: const Center(
                            child: Text(
                              'No expenses recorded',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: AppColors.lightOnSurfaceVar,
                              ),
                            ),
                          ),
                        );
                      }

                      // Build category totals
                      final cats = <String, double>{};
                      for (final e in expenses) {
                        cats[e.category] =
                            (cats[e.category] ?? 0) + e.convertedAmountINR;
                      }
                      final sorted = cats.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      final total = sorted.fold<double>(0, (s, e) => s + e.value);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Spending by Category',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...sorted.map((entry) {
                            final share = total > 0 ? entry.value / total : 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${(share * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: AppColors.lightOnSurfaceVar,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: share.clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor:
                                          const Color(0xFFEEF0F3),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                  ],  // end else [...] for past/active expense section
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DETAIL STAT WIDGET ───────────────────────────────────────────────────────

class _DetailStat extends StatelessWidget {
  const _DetailStat({
    required this.label,
    required this.value,
    required this.color,
    required this.align,
  });
  final String label;
  final String value;
  final Color color;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: AppColors.lightOnSurfaceVar,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── DATA CLASSES ─────────────────────────────────────────────────────────────

class _TripSections {
  const _TripSections(
      {required this.active,
      required this.upcoming,
      required this.past});
  final List<BudgetModel> active;
  final List<BudgetModel> upcoming;
  final List<BudgetModel> past;
}
