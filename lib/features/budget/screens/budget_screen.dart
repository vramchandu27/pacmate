import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/places_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/budget_model.dart';
import '../../../shared/models/currency_data.dart';
import '../services/budget_service.dart';

// ─── BUDGET SCREEN ────────────────────────────────────────────────────────────
// Wired to Firestore via activeTripProvider + tripExpensesProvider.
// ─────────────────────────────────────────────────────────────────────────────

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  final _pageCtrl = PageController(viewportFraction: 0.88);
  int _currentPage = 0;
  bool _didInitialScroll = false;
  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // In-progress first, then upcoming, then past.
  static List<BudgetModel> _sortByDate(List<BudgetModel> trips) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // In-progress — date range includes today and not yet completed
    final inProgress = trips.where((t) {
      if (t.completedAt != null) return false;
      final s = DateTime(t.startDate.year, t.startDate.month, t.startDate.day);
      final e = DateTime(t.endDate.year,   t.endDate.month,   t.endDate.day);
      return !s.isAfter(today) && !e.isBefore(today);
    }).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));

    // Upcoming — not completed, start date in the future
    final upcoming = trips.where((t) {
      if (t.completedAt != null) return false;
      final s = DateTime(t.startDate.year, t.startDate.month, t.startDate.day);
      return s.isAfter(today);
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // Past — completed OR end date before today
    final past = trips.where((t) {
      final e = DateTime(t.endDate.year, t.endDate.month, t.endDate.day);
      return e.isBefore(today) || t.completedAt != null;
    }).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return [...inProgress, ...upcoming, ...past];
  }

  void _showCreateTripSheet() {
    context.push(AppRoutes.createTrip);
  }

  void _showEditTripSheet(BudgetModel trip) {
    final budgetCtrl = TextEditingController(
        text: trip.totalBudget.toStringAsFixed(0));
    DateTime endDate = trip.endDate;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          final safeBottom = MediaQuery.of(ctx).padding.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + safeBottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.lightOutline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.teal]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Edit Trip',
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy)),
                            Text(trip.destination,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: AppColors.lightOnSurfaceVar),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Budget field
                  Text('Budget (${trip.currency})',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: budgetCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy),
                    decoration: InputDecoration(
                      prefixText: '${trip.currency} ',
                      prefixStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide:
                              const BorderSide(color: AppColors.lightOutline)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide:
                              const BorderSide(color: AppColors.lightOutline)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // End date
                  const Text('End Date',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: endDate,
                        firstDate: trip.startDate,
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setSheet(() => endDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.lightOutline),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('d MMM yyyy').format(endDate),
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                                color: AppColors.navy),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.lightOnSurfaceVar),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Save button
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.teal]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withAlpha(70),
                            blurRadius: 14,
                            offset: const Offset(0, 5)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final budget =
                                  double.tryParse(budgetCtrl.text.trim());
                              if (budget == null || budget <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Enter a valid budget'),
                                      backgroundColor: AppColors.danger),
                                );
                                return;
                              }
                              setSheet(() => isSaving = true);
                              try {
                                await ref
                                    .read(budgetServiceProvider)
                                    .updateTrip(trip.id,
                                        totalBudget: budget,
                                        endDate: endDate);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              } catch (_) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Failed to update trip'),
                                        backgroundColor: AppColors.danger),
                                  );
                                }
                              } finally {
                                if (mounted) setSheet(() => isSaving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTripsAsync = ref.watch(allTripsProvider);

    // When a new active trip is created, snap the carousel to it.
    ref.listen<AsyncValue<BudgetModel?>>(activeTripProvider, (prev, next) {
      final prevId = prev?.value?.id;
      final nextId = next.value?.id;
      if (nextId != null && prevId != nextId && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final sorted = _sortByDate(ref.read(allTripsProvider).value ?? []);
          final idx = sorted.indexWhere((t) => t.id == nextId);
          if (idx >= 0 && _pageCtrl.hasClients) {
            _pageCtrl.animateToPage(idx,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut);
            setState(() => _currentPage = idx);
          }
        });
      }
    });

    final h = MediaQuery.sizeOf(context).height;
    final w = MediaQuery.sizeOf(context).width;
    final carouselH = (h * 0.245).clamp(155.0, 200.0);
    final spTop    = (h * 0.018).clamp(8.0, 18.0);
    final spDots   = (h * 0.014).clamp(6.0, 12.0);
    final spBottom = (h * 0.005).clamp(2.0, 6.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        titleSpacing: w < 360 ? 14.0 : 20.0,
        title: const Text(
          'Budget Tracker',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        actions: [
          Consumer(
            builder: (ctx, ref, _) {
              final trips = _sortByDate(
                  ref.watch(allTripsProvider).valueOrNull ?? []);
              if (trips.isEmpty) return const SizedBox.shrink();
              final selected = trips[_currentPage.clamp(0, trips.length - 1)];
              return IconButton(
                onPressed: () => _showEditTripSheet(selected),
                tooltip: 'Edit Trip',
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.lightOnSurface),
              );
            },
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.budgetReport),
            icon: const Icon(Icons.bar_chart_outlined,
                color: AppColors.lightOnSurface),
          ),
        ],
      ),
      body: allTripsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allTrips) {
          final trips = _sortByDate(allTrips);

          if (trips.isEmpty) return _buildEmptyState();

          // On first data load, jump to the active trip in the sorted list.
          if (!_didInitialScroll) {
            _didInitialScroll = true;
            final now0 = DateTime.now();
            final today0 = DateTime(now0.year, now0.month, now0.day);
            final activeIdx = trips.indexWhere((t) {
              if (t.completedAt != null) return false;
              final s = DateTime(t.startDate.year, t.startDate.month, t.startDate.day);
              final e = DateTime(t.endDate.year, t.endDate.month, t.endDate.day);
              return !s.isAfter(today0) && !e.isBefore(today0);
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              // Seed provider with the trip shown on the initial page.
              final startPage = (activeIdx > 0 ? activeIdx : 0).clamp(0, trips.length - 1);
              ref.read(selectedCarouselTripProvider.notifier).state = trips[startPage];
              if (activeIdx > 0 && _pageCtrl.hasClients) {
                _pageCtrl.jumpToPage(activeIdx);
                setState(() => _currentPage = activeIdx);
              }
            });
          }

          final safePage = _currentPage.clamp(0, trips.length - 1);
          final selected = trips[safePage];

          return Column(
            children: [
              SizedBox(height: spTop),
              // ── Carousel ────────────────────────────────────────────────────
              SizedBox(
                height: carouselH,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: trips.length,
                  onPageChanged: (i) {
                    setState(() => _currentPage = i);
                    if (i < trips.length) {
                      ref.read(selectedCarouselTripProvider.notifier).state = trips[i];
                    }
                  },
                  itemBuilder: (_, i) {
                    return AnimatedBuilder(
                      animation: _pageCtrl,
                      builder: (_, child) {
                        final page = _pageCtrl.hasClients && _pageCtrl.page != null
                            ? _pageCtrl.page!
                            : _currentPage.toDouble();
                        final diff = (page - i).abs().clamp(0.0, 1.0);
                        return Transform.scale(
                          scale: 1.0 - diff * 0.07,
                          child: Opacity(
                            opacity: 1.0 - diff * 0.38,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _buildCarouselCard(trips[i], carouselH, w),
                      ),
                    );
                  },
                ),
              ),
              // ── Dots ────────────────────────────────────────────────────────
              if (trips.length > 1) ...[
                SizedBox(height: spDots),
                _buildDots(trips.length, safePage),
              ],
              SizedBox(height: spBottom),
              // ── Details for selected trip ────────────────────────────────────
              Expanded(child: _buildTripDetails(selected, w)),
            ],
          );
        },
      ),
    );
  }

  // ── Number formatting ────────────────────────────────────────────────────

  String _fmtPercent(double fraction) {
    final pct = (fraction * 100).clamp(0.0, 100.0);
    if (pct == 0.0) return '0%';
    if (pct < 0.1)  return '< 0.1%';
    if (pct >= 99.9 && pct < 100.0) return '> 99.9%';
    if (pct < 1.0)  return '${pct.toStringAsFixed(2)}%';
    return '${pct.toStringAsFixed(1)}%';
  }

  // Number only (no symbol) — used when the currency code is shown separately
  String _fmtNum(double v, [String currency = 'INR']) {
    final nf = currency == 'INR'
        ? NumberFormat('#,##,##0', 'en_IN')
        : NumberFormat('#,##0');
    return nf.format(v.abs());
  }

  String _fmtMoney(double v, [String currency = 'INR']) {
    final abs  = v.abs();
    final sign = v < 0 ? '-' : '';
    final sym  = kAllCurrencies
        .firstWhere((c) => c.code == currency,
            orElse: () => const CurrencyEntry(
                code: 'INR', name: '', symbol: '₹', flag: '', toInrRate: 1.0))
        .symbol;
    final nf = currency == 'INR'
        ? NumberFormat('#,##,##0', 'en_IN')
        : NumberFormat('#,##0');
    return '$sign$sym${nf.format(abs)}';
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.luggage_outlined, size: 80, color: AppColors.lightOutline),
            const SizedBox(height: 24),
            const Text(
              'No trips yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first trip to start tracking your budget',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                color: AppColors.lightOnSurfaceVar,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showCreateTripSheet,
              icon: const Icon(Icons.add),
              label: const Text('Create Trip',
                  style: TextStyle(fontFamily: 'Poppins')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Carousel card ────────────────────────────────────────────────────────

  Widget _buildCarouselCard(BudgetModel trip, double cardH, double w) {
    final fmt = DateFormat('d MMM');
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripDays = trip.endDate.difference(trip.startDate).inDays + 1;
    final daysPassed =
        now.difference(trip.startDate).inDays.clamp(0, tripDays);
    final overBudget = trip.totalSpent > trip.totalBudget;

    // Use date-only comparisons so trips show correctly all day on start/end day.
    final tripStartDay = DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day);
    final tripEndDay   = DateTime(trip.endDate.year,   trip.endDate.month,   trip.endDate.day);
    final isInProgress = trip.completedAt == null &&
                        !tripStartDay.isAfter(today) && !tripEndDay.isBefore(today);
    final isUpcoming   = trip.completedAt == null && tripStartDay.isAfter(today);

    final pad      = (cardH * 0.095).clamp(12.0, 20.0);
    final destFz   = (cardH * 0.090).clamp(13.0, 18.0);
    final budgetFz = (cardH * 0.138).clamp(18.0, 27.0);
    final labelFz  = (cardH * 0.058).clamp(9.0, 12.0);

    if (isInProgress) {
      const badgeLabel = 'ACTIVE';
      const badgeDot   = Color(0xFFFFB74D);

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Container(
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D47A1), Color(0xFF2563EB), AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(80),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.destination,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: destFz,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: badgeDot,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: badgeDot.withAlpha(180), blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeDot,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${fmt.format(trip.startDate)} – ${fmt.format(trip.endDate)}  ·  $tripDays days',
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: labelFz, color: Colors.white60),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmtMoney(trip.totalBudget, trip.currency),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: budgetFz,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ref.read(selectedCarouselTripProvider.notifier).state = trip;
                    context.push(AppRoutes.addExpense, extra: trip);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white54),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Expense',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: labelFz,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: trip.spentPercent.clamp(0.0, 1.0),
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                    overBudget ? AppColors.danger : Colors.white),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Spent ${_fmtMoney(trip.totalSpent, trip.currency)}',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: labelFz,
                        color: Colors.white60)),
                Text(
                    now.isBefore(trip.startDate)
                        ? 'In ${trip.startDate.difference(now).inDays + 1} days'
                        : 'Day $daysPassed / $tripDays',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: labelFz,
                        color: Colors.white60)),
              ],
            ),
          ],
            ),    // Column
            ),    // Container
            // Decorative plane
            Positioned(
              right: -12, top: -12,
              child: Icon(Icons.flight_rounded, size: 90,
                  color: Colors.white.withAlpha(12)),
            ),
            // Top-shine
            Positioned(
              top: 0, left: 24, right: 24,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.white.withAlpha(0),
                    Colors.white.withAlpha(60),
                    Colors.white.withAlpha(0),
                  ]),
                ),
              ),
            ),
          ],   // Stack children
        ),     // Stack
      );       // ClipRRect
    }

    // Upcoming / past / completed card
    final List<Color> cardGradient = isUpcoming
        ? const [Color(0xFF1A3A6B), Color(0xFF2563EB)]
        : overBudget
            ? const [Color(0xFF7F1010), Color(0xFFB71C1C)]
            : const [Color(0xFF0D5C2E), Color(0xFF1E8449)];

    final Color badgeDot = isUpcoming
        ? const Color(0xFFFFB74D)
        : overBudget
            ? const Color(0xFFFF6B6B)
            : const Color(0xFF69F0AE);

    final String badgeLabel = isUpcoming
        ? 'UPCOMING'
        : overBudget
            ? 'OVER BUDGET'
            : 'COMPLETED';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: cardGradient,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: cardGradient.last.withAlpha(80),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trip.destination,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: destFz,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: badgeDot,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: badgeDot.withAlpha(180),
                                    blurRadius: 4)
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            badgeLabel,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeDot,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmt.format(trip.startDate)} – ${fmt.format(trip.endDate)}  ·  $tripDays days',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: labelFz,
                      color: Colors.white60),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmtMoney(trip.totalBudget, trip.currency),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: budgetFz,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ref.read(selectedCarouselTripProvider.notifier).state = trip;
                        context.push(AppRoutes.addExpense, extra: trip);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Expense',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: labelFz,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: trip.spentPercent.clamp(0.0, 1.0),
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        overBudget ? const Color(0xFFFF6B6B) : const Color(0xFF69F0AE)),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Spent ${_fmtMoney(trip.totalSpent, trip.currency)}',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: labelFz,
                            color: Colors.white60)),
                    Text(
                      isUpcoming
                          ? '${_fmtMoney(trip.totalBudget, trip.currency)} budget'
                          : overBudget
                              ? '${_fmtMoney(trip.totalSpent - trip.totalBudget, trip.currency)} over'
                              : '${_fmtMoney(trip.remaining, trip.currency)} saved',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: labelFz,
                        fontWeight: FontWeight.w600,
                        color: badgeDot,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Top-shine
          Positioned(
            top: 0, left: 24, right: 24,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.white.withAlpha(0),
                  Colors.white.withAlpha(60),
                  Colors.white.withAlpha(0),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dots indicator ────────────────────────────────────────────────────────

  Widget _buildDots(int count, int current) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.lightOutline,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // ── Trip details (works for both active and past trips) ───────────────────

  Widget _buildTripDetails(BudgetModel trip, double w) {
    final expensesAsync = ref.watch(tripExpensesProvider(trip.id));

    return expensesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (expenses) {
        final now = DateTime.now();
        final tripDays =
            trip.endDate.difference(trip.startDate).inDays + 1;
        final dailyBudget =
            tripDays > 0 ? trip.totalBudget / tripDays : trip.totalBudget;
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final todaySpent = expenses
            .where(
                (e) => DateFormat('yyyy-MM-dd').format(e.date) == todayStr)
            .fold<double>(0, (sum, e) => sum + e.convertedAmountINR);

        final categoryTotals = <String, double>{};
        for (final e in expenses) {
          categoryTotals[e.category] =
              (categoryTotals[e.category] ?? 0) + e.convertedAmountINR;
        }
        final sortedCategories = categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final detailStart = DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day);
        final detailEnd   = DateTime(trip.endDate.year,   trip.endDate.month,   trip.endDate.day);
        final detailToday = DateTime(now.year, now.month, now.day);
        final tripInProgress = trip.completedAt == null &&
            !detailStart.isAfter(detailToday) && !detailEnd.isBefore(detailToday);
        final isUpcoming = trip.completedAt == null && detailStart.isAfter(detailToday);

        final hp = w < 360 ? 14.0 : 20.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hp, 20, hp, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tripInProgress) ...[
                _buildTodaySpending(todaySpent, dailyBudget, trip.currency, w),
                const SizedBox(height: 24),
              ] else ...[
                _buildBudgetOverview(trip),
                const SizedBox(height: 24),
              ],
              if (!isUpcoming) ...[
                if (sortedCategories.isNotEmpty) ...[
                  _buildCategoryBreakdown(sortedCategories, trip.totalBudget, trip.currency),
                  const SizedBox(height: 24),
                ],
                _buildRecentExpenses(trip.id, expenses),
              ] else ...[
                _buildUpcomingPlaceholder(trip),
              ],
              if (tripInProgress) ...[
                const SizedBox(height: 24),
                _buildCompleteTripSection(trip),
              ],
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodaySpending(double todaySpent, double dailyBudget, String currency, double w) {
    final remainingToday = dailyBudget - todaySpent;
    final todayPercent = dailyBudget > 0 ? todaySpent / dailyBudget : 0.0;

    final pad      = w < 360 ? 14.0 : 18.0;
    final titleFz  = w < 360 ? 15.0 : 17.0;
    final valueFz  = w < 360 ? 20.0 : 24.0;
    final subFz    = w < 360 ? 12.0 : 14.0;
    final remainFz = w < 360 ? 17.0 : 20.0;

    final isOver = remainingToday < 0;
    final accentColor = isOver ? AppColors.danger : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOver
              ? [const Color(0xFF7F1010), const Color(0xFFB71C1C)]
              : [const Color(0xFF0D47A1), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(70),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Top-shine
            Positioned(
              top: 0, left: 24, right: 24,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.white.withAlpha(0),
                    Colors.white.withAlpha(60),
                    Colors.white.withAlpha(0),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.today_rounded,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Today's Spending",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: titleFz - 2,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmtMoney(todaySpent, currency),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: valueFz,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'of ${_fmtMoney(dailyBudget, currency)} daily',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: subFz,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withAlpha(40)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _fmtMoney(remainingToday.abs(), currency),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: remainFz,
                                fontWeight: FontWeight.w800,
                                color: isOver
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF69F0AE),
                              ),
                            ),
                            Text(
                              isOver ? 'over budget' : 'remaining',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: subFz - 2,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                          begin: 0, end: todayPercent.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context2, v, child2) => LinearProgressIndicator(
                        value: v,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOver
                              ? const Color(0xFFFF6B6B)
                              : Colors.white,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingPlaceholder(BudgetModel trip) {
    final daysUntil = trip.startDate.difference(DateTime.now()).inDays + 1;
    final fmt = DateFormat('d MMMM yyyy');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_rounded,
                color: AppColors.warning, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'Trip hasn\'t started yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Starts ${fmt.format(trip.startDate)}  ·  $daysUntil ${daysUntil == 1 ? 'day' : 'days'} to go',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.lightOnSurfaceVar,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Expenses will appear here once the trip begins.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.lightOnSurfaceVar,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetOverview(BudgetModel trip) {
    final overBudget   = trip.totalSpent > trip.totalBudget;
    final remaining    = trip.totalBudget - trip.totalSpent;
    final accentColor  = overBudget ? AppColors.danger : AppColors.success;
    final spentPercent = trip.spentPercent.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary, AppColors.teal],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              overBudget ? 'Trip Overview' : 'Trip Overview',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Three stat chips ──────────────────────────────────────────
          Row(
            children: [
              _overviewStat('Budget', _fmtMoney(trip.totalBudget, trip.currency),
                  AppColors.navy, CrossAxisAlignment.start),
              Container(width: 1, height: 44, color: const Color(0xFFEEF0F3)),
              _overviewStat('Spent', _fmtMoney(trip.totalSpent, trip.currency),
                  AppColors.navy, CrossAxisAlignment.center),
              Container(width: 1, height: 44, color: const Color(0xFFEEF0F3)),
              _overviewStat(
                overBudget ? 'Over' : 'Saved',
                _fmtMoney(remaining.abs(), trip.currency),
                accentColor,
                CrossAxisAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Progress bar ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: spentPercent),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context2, v, child2) => LinearProgressIndicator(
                value: v,
                backgroundColor: const Color(0xFFEEF0F3),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_fmtPercent(spentPercent)} spent',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.lightOnSurfaceVar,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  overBudget
                      ? 'Over budget!'
                      : '${_fmtPercent(1 - spentPercent)} left',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ],       // inner Column children
      ),         // inner Column
      ),         // Container (card)
      ],         // outer Column children
    );           // outer Column
  }

  Widget _overviewStat(String label, String value, Color valueColor,
      CrossAxisAlignment align) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: align,
          children: [
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.lightOnSurfaceVar,
                )),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(
    List<MapEntry<String, double>> categories,
    double totalBudget,
    String currency,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.teal, AppColors.success],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Spending by Category',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...categories.map((entry) => _buildCategoryCard(
          entry.key,
          entry.value,
          totalBudget,
          currency,
        )),
      ],
    );
  }

  Widget _buildCategoryCard(String category, double spent, double totalBudget, String currency) {
    final percent = totalBudget > 0 ? spent / totalBudget : 0.0;
    final color   = _categoryColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(width: 4, color: color),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: color.withAlpha(18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_categoryIcon(category),
                              color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy,
                                ),
                              ),
                              Text(
                                '${_fmtPercent(percent)} of budget',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.lightOnSurfaceVar,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _fmtMoney(spent, currency),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: percent.clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (c, v, _) => LinearProgressIndicator(
                          value: v,
                          backgroundColor: const Color(0xFFEEF0F3),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentExpenses(String tripId, List<ExpenseModel> expenses) {
    final recent = expenses.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.danger, AppColors.warning],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Recent Expenses',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const Spacer(),
            if (recent.isNotEmpty)
              Text(
                '${recent.length} ${recent.length == 1 ? 'expense' : 'expenses'}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.lightOnSurfaceVar,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEF0F3)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 48, color: Color(0xFFCDD5DF)),
                  SizedBox(height: 10),
                  Text(
                    'No expenses yet',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap + to log your first expense',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.lightOnSurfaceVar,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...recent.map((e) => _buildExpenseCard(tripId, e)),
      ],
    );
  }

  Widget _buildExpenseCard(String tripId, ExpenseModel expense) {
    final color = _categoryColor(expense.category);
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete expense?',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
            content: Text(
              'Remove "${expense.note?.isNotEmpty == true ? expense.note : expense.category}" '
              '(₹${expense.convertedAmountINR.toStringAsFixed(0)})?',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(fontFamily: 'Poppins', color: AppColors.lightOnSurfaceVar)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(fontFamily: 'Poppins', color: AppColors.danger,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) async {
        try {
          await ref.read(budgetServiceProvider).deleteExpense(
            expenseId: expense.id,
            tripId: tripId,
            convertedAmountINR: expense.convertedAmountINR,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Delete failed: $e'),
                  backgroundColor: AppColors.danger),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Colors.white,
            child: Stack(
              children: [
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(width: 4, color: color),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withAlpha(18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_categoryIcon(expense.category),
                            color: color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.note?.isNotEmpty == true
                                  ? expense.note!
                                  : expense.category,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    expense.category,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('d MMM').format(expense.date),
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.lightOnSurfaceVar,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '-${expense.originalCurrency} ${_fmtNum(expense.amount, expense.originalCurrency)}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: () => _showEditExpenseSheet(tripId, expense),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 12,
                                      color: AppColors.primary),
                                  SizedBox(width: 3),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );            // Dismissible
  }

  // ── Edit expense ──────────────────────────────────────────────────────────

  void _showEditExpenseSheet(String tripId, ExpenseModel expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditExpenseSheet(tripId: tripId, expense: expense),
    );
  }

  // ── Complete trip ─────────────────────────────────────────────────────────

  Widget _buildCompleteTripSection(BudgetModel trip) {
    final now = DateTime.now();
    final isOverdue = trip.endDate.isBefore(now);

    if (isOverdue) {
      // Trip end date has passed but still marked active — show a prominent banner
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.success.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your trip has ended!',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Mark it complete to archive expenses.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.lightOnSurfaceVar,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmCompleteTrip(trip),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text(
                  'Mark Trip as Complete',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Trip still ongoing — end early option
    return GestureDetector(
      onTap: () => _confirmCompleteTrip(trip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color: AppColors.warning.withAlpha(18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flag_outlined,
                  color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete trip early',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Archive expenses and mark as done',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.lightOnSurfaceVar,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withAlpha(60)),
              ),
              child: const Text(
                'End',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCompleteTrip(BudgetModel trip) async {
    final now = DateTime.now();
    final isOverdue = trip.endDate.isBefore(now);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Complete Trip?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        content: Text(
          isOverdue
              ? 'Your trip to ${trip.destination} has ended. Mark it as complete and archive your expenses?'
              : 'End the trip to ${trip.destination} early and archive it?',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.lightOnSurfaceVar,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.lightOnSurfaceVar,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Complete',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(budgetServiceProvider).completeTrip(trip.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trip to ${trip.destination} completed! 🎉',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e',
                style: const TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'accommodation':
      case 'stay':
        return AppColors.primary;
      case 'transport':
        return AppColors.teal;
      case 'food':
        return AppColors.success;
      case 'activities':
        return AppColors.purple;
      default:
        return AppColors.warning;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'accommodation':
      case 'stay':
        return Icons.hotel_outlined;
      case 'transport':
        return Icons.flight_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'activities':
        return Icons.local_activity_outlined;
      default:
        return Icons.shopping_bag_outlined;
    }
  }
}

// ─── POPULAR DESTINATIONS ─────────────────────────────────────────────────────

const List<String> _kDestinations = [
  'Bangkok, Thailand', 'Bali, Indonesia', 'Barcelona, Spain',
  'Berlin, Germany', 'Dubai, UAE', 'Istanbul, Turkey',
  'Kuala Lumpur, Malaysia', 'London, UK', 'Maldives',
  'Mumbai, India', 'New York, USA', 'Paris, France',
  'Prague, Czech Republic', 'Rome, Italy', 'Seoul, South Korea',
  'Singapore', 'Sydney, Australia', 'Tokyo, Japan',
  'Vienna, Austria', 'Amsterdam, Netherlands', 'Athens, Greece',
  'Bali, Indonesia', 'Beijing, China', 'Budapest, Hungary',
  'Cairo, Egypt', 'Cape Town, South Africa', 'Chiang Mai, Thailand',
  'Copenhagen, Denmark', 'Delhi, India', 'Denpasar, Indonesia',
  'Dubrovnik, Croatia', 'Edinburgh, Scotland', 'Florence, Italy',
  'Goa, India', 'Hanoi, Vietnam', 'Ho Chi Minh City, Vietnam',
  'Hong Kong', 'Honolulu, Hawaii', 'Jaipur, India',
  'Jakarta, Indonesia', 'Kathmandu, Nepal', 'Kochi, India',
  'Kolkata, India', 'Kyoto, Japan', 'Lisbon, Portugal',
  'Madrid, Spain', 'Melbourne, Australia', 'Mexico City, Mexico',
  'Milan, Italy', 'Moscow, Russia', 'Nairobi, Kenya',
  'Nice, France', 'Osaka, Japan', 'Oslo, Norway',
  'Pattaya, Thailand', 'Penang, Malaysia', 'Phnom Penh, Cambodia',
  'Phuket, Thailand', 'Porto, Portugal', 'Queenstown, New Zealand',
  'Reykjavik, Iceland', 'Rio de Janeiro, Brazil', 'Santorini, Greece',
  'Shanghai, China', 'Stockholm, Sweden', 'Taipei, Taiwan',
  'Tbilisi, Georgia', 'Toronto, Canada', 'Vancouver, Canada',
  'Venice, Italy', 'Warsaw, Poland', 'Zurich, Switzerland',
  'Agra, India', 'Amritsar, India', 'Andaman Islands, India',
  'Bengaluru, India', 'Chennai, India', 'Coorg, India',
  'Darjeeling, India', 'Hampi, India', 'Hyderabad, India',
  'Kashmir, India', 'Kerala, India', 'Leh, India',
  'Manali, India', 'Mysore, India', 'Ooty, India',
  'Pune, India', 'Rishikesh, India', 'Udaipur, India',
  'Varanasi, India', 'Bangladesh', 'Sri Lanka',
  'Nepal', 'Bhutan', 'Pakistan',
  'Colombo, Sri Lanka', 'Dhaka, Bangladesh', 'Kathmandu, Nepal',
  'Thimphu, Bhutan', 'Lahore, Pakistan', 'Karachi, Pakistan',
];

// ─── EDIT EXPENSE BOTTOM SHEET ───────────────────────────────────────────────

class _EditExpenseSheet extends ConsumerStatefulWidget {
  const _EditExpenseSheet({required this.tripId, required this.expense});
  final String tripId;
  final ExpenseModel expense;

  @override
  ConsumerState<_EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends ConsumerState<_EditExpenseSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late String _category;
  bool _isLoading = false;

  static const List<_CategoryInfo> _categories = [
    _CategoryInfo(label: 'Food',       icon: Icons.restaurant_rounded,     color: AppColors.success),
    _CategoryInfo(label: 'Transport',  icon: Icons.directions_bus_rounded,  color: AppColors.teal),
    _CategoryInfo(label: 'Stay',       icon: Icons.hotel_rounded,           color: AppColors.primary),
    _CategoryInfo(label: 'Activities', icon: Icons.surfing_rounded,         color: AppColors.purple),
    _CategoryInfo(label: 'Shopping',   icon: Icons.shopping_bag_rounded,    color: AppColors.warning),
    _CategoryInfo(label: 'Other',      icon: Icons.more_horiz_rounded,      color: AppColors.lightOnSurfaceVar),
  ];

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.expense.amount.toStringAsFixed(
            widget.expense.amount == widget.expense.amount.floorToDouble() ? 0 : 2));
    _noteCtrl = TextEditingController(text: widget.expense.note ?? '');
    _category = widget.expense.category;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newAmount = double.tryParse(_amountCtrl.text.trim());
    if (newAmount == null || newAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount'),
            backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isLoading = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Preserve original exchange rate
    final oldAmount = widget.expense.amount;
    final oldConverted = widget.expense.convertedAmountINR;
    final rate = oldAmount > 0 ? oldConverted / oldAmount : 1.0;
    final newConverted = newAmount * rate;

    try {
      await ref.read(budgetServiceProvider).updateExpense(
        expenseId: widget.expense.id,
        tripId: widget.tripId,
        oldConvertedAmountINR: oldConverted,
        newAmount: newAmount,
        newConvertedAmountINR: newConverted,
        category: _category,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) nav.pop();
    } catch (e) {
      if (mounted) nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Update failed: $e'),
            backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightOutline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Edit Expense',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        color: AppColors.lightOnSurfaceVar,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Amount ─────────────────────────────────────────────
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        autofocus: true,
                        style: const TextStyle(fontFamily: 'Poppins'),
                        decoration: InputDecoration(
                          labelText: 'Amount (${widget.expense.originalCurrency})',
                          hintText: '0',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ── Category ───────────────────────────────────────────
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final selected = _category == cat.label;
                          return GestureDetector(
                            onTap: () => setState(() => _category = cat.label),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? cat.color.withAlpha(30)
                                    : AppColors.lightBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? cat.color
                                      : AppColors.lightOutline,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(cat.icon,
                                      size: 16,
                                      color: selected
                                          ? cat.color
                                          : AppColors.lightOnSurfaceVar),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: selected
                                          ? cat.color
                                          : AppColors.lightOnSurfaceVar,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      // ── Note ───────────────────────────────────────────────
                      TextField(
                        controller: _noteCtrl,
                        style: const TextStyle(fontFamily: 'Poppins'),
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                          hintText: 'e.g., Dinner at the beach',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryInfo {
  const _CategoryInfo({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
}

// ─── CREATE TRIP BOTTOM SHEET ─────────────────────────────────────────────────

class _CreateTripSheet extends ConsumerStatefulWidget {
  const _CreateTripSheet();

  @override
  ConsumerState<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends ConsumerState<_CreateTripSheet> {
  final _formKey = GlobalKey<FormState>();
  final _destinationCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  String _currency = 'INR';
  bool _isLoading = false;
  List<String> _suggestions = [];
  Timer? _debounce;

  CurrencyEntry get _selectedCurrencyEntry =>
      kAllCurrencies.firstWhere((c) => c.code == _currency,
          orElse: () => kAllCurrencies.first);

  Future<void> _showCurrencyPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CurrencySearchSheet(
        selected: _currency,
        onSelect: (code) {
          setState(() => _currency = code);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _destinationCtrl.addListener(_onDestinationChanged);
  }

  void _onDestinationChanged() {
    final q = _destinationCtrl.text.trim().toLowerCase();
    if (q.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    // Filter static list immediately
    final matches = _kDestinations
        .where((d) => d.toLowerCase().contains(q))
        .take(6)
        .toList();
    setState(() => _suggestions = matches);

    // Also query Places API; merge results if they arrive
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final api = await ref
          .read(placesServiceProvider)
          .autocompleteDestinations(_destinationCtrl.text.trim());
      if (!mounted) return;
      if (api.isEmpty) return; // keep static results
      // Merge: API first, then static extras not already covered
      final merged = [...api];
      for (final s in matches) {
        if (!merged.any((r) =>
            r.toLowerCase().contains(s.split(',').first.toLowerCase()))) {
          merged.add(s);
        }
      }
      setState(() => _suggestions = merged.take(6).toList());
    });
  }

  void _selectSuggestion(String value) {
    _destinationCtrl.removeListener(_onDestinationChanged);
    _destinationCtrl.text = value;
    _destinationCtrl.selection =
        TextSelection.collapsed(offset: value.length);
    _destinationCtrl.addListener(_onDestinationChanged);
    setState(() => _suggestions = []);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _destinationCtrl.removeListener(_onDestinationChanged);
    _destinationCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 7));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    // Capture before the async gap — after await the sheet context may be gone.
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref.read(budgetServiceProvider).createTrip(
        destination: _destinationCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        totalBudget: double.parse(_budgetCtrl.text.trim()),
        currency: _currency,
      );
      if (mounted) nav.pop();
    } catch (e) {
      // Close the sheet first so the SnackBar is visible on the parent screen.
      if (mounted) nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to create trip: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final kb = MediaQuery.of(context).viewInsets.bottom;
    // SingleChildScrollView wraps everything — no Flexible/Expanded inside
    // Column(mainAxisSize.min), which avoids bottom-sheet layout errors.
    // Padding(bottom: kb) lifts content above the keyboard.
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drag handle ───────────────────────────────────────────────
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightOutline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // ── Header ────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Create Trip',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        color: AppColors.lightOnSurfaceVar,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                // ── Form fields ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _destinationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Destination',
                            hintText: 'e.g., Bali, Thailand',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Enter destination' : null,
                        ),
                        if (_suggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.lightOutline),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _suggestions.map((s) {
                                final isLast = s == _suggestions.last;
                                return InkWell(
                                  onTap: () => _selectSuggestion(s),
                                  borderRadius: BorderRadius.vertical(
                                    top: s == _suggestions.first
                                        ? const Radius.circular(12)
                                        : Radius.zero,
                                    bottom: isLast
                                        ? const Radius.circular(12)
                                        : Radius.zero,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: isLast
                                          ? null
                                          : const Border(
                                              bottom: BorderSide(
                                                color: AppColors.lightOutline,
                                                width: 0.5,
                                              ),
                                            ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            s,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDate(isStart: true),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Start Date',
                                    border: OutlineInputBorder(),
                                    prefixIcon:
                                        Icon(Icons.calendar_today_outlined),
                                  ),
                                  child: Text(
                                    fmt.format(_startDate),
                                    style:
                                        const TextStyle(fontFamily: 'Poppins'),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDate(isStart: false),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'End Date',
                                    border: OutlineInputBorder(),
                                    prefixIcon:
                                        Icon(Icons.calendar_today_outlined),
                                  ),
                                  child: Text(
                                    fmt.format(_endDate),
                                    style:
                                        const TextStyle(fontFamily: 'Poppins'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _budgetCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Total Budget',
                                  hintText: '50000',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(
                                      Icons.account_balance_wallet_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Enter budget';
                                  }
                                  if (double.tryParse(v) == null) {
                                    return 'Invalid number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: _showCurrencyPicker,
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'My Currency',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _selectedCurrencyEntry.flag,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _currency,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: AppColors.lightOnSurfaceVar,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 13, color: AppColors.lightOnSurfaceVar),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Use your home currency. Expenses abroad are converted automatically.',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: AppColors.lightOnSurfaceVar,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Create Trip',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CURRENCY SEARCH SHEET ────────────────────────────────────────────────────

class _CurrencySearchSheet extends StatefulWidget {
  const _CurrencySearchSheet({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  State<_CurrencySearchSheet> createState() => _CurrencySearchSheetState();
}

class _CurrencySearchSheetState extends State<_CurrencySearchSheet> {
  final _searchCtrl = TextEditingController();
  List<CurrencyEntry> _filtered = kAllCurrencies;

  void _onSearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = kAllCurrencies
          .where((c) =>
              c.code.toLowerCase().contains(lower) ||
              c.name.toLowerCase().contains(lower))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightOutline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const Text(
                'Select Currency',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                autofocus: true,
                style: const TextStyle(fontFamily: 'Poppins'),
                decoration: InputDecoration(
                  hintText: 'Search currency or country...',
                  hintStyle: const TextStyle(fontFamily: 'Poppins'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.lightSurfaceVar,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No currencies found',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.lightOnSurfaceVar,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final c = _filtered[i];
                          final isSelected = c.code == widget.selected;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Text(
                              c.flag,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              c.code,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.navy,
                              ),
                            ),
                            subtitle: Text(
                              c.name,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: AppColors.lightOnSurfaceVar,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () => widget.onSelect(c.code),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
