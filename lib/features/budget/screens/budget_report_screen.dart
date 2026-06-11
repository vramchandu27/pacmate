import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/budget_model.dart';
import '../services/budget_service.dart';

class BudgetReportScreen extends ConsumerStatefulWidget {
  const BudgetReportScreen({super.key});

  @override
  ConsumerState<BudgetReportScreen> createState() => _BudgetReportScreenState();
}

class _BudgetReportScreenState extends ConsumerState<BudgetReportScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _anim;
  int _touchedPieIndex = -1;

  static const List<Color> _chartColors = [
    AppColors.primary,
    AppColors.success,
    AppColors.teal,
    AppColors.purple,
    AppColors.warning,
    AppColors.danger,
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String _fmtMoney(double v) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(v.abs().round());
  }

  String _fmtFull(double v) => _fmtMoney(v);

  void _shareReport(BudgetModel trip) {
    final isOver = trip.remaining < 0;
    final lines = [
      '📊 Budget Report — ${trip.destination}',
      '',
      '💰 Budget:    ${_fmtFull(trip.totalBudget)}',
      '📤 Spent:     ${_fmtFull(trip.totalSpent)}',
      '${isOver ? '🔴' : '🟢'} Remaining: ${_fmtFull(trip.remaining.abs())}${isOver ? ' (over budget)' : ''}',
      '',
      'Shared via PacMate 🎒',
    ];
    Share.share(lines.join('\n'), subject: 'Budget Report — ${trip.destination}');
  }

  Color _categoryColor(String category) {
    const map = {
      'Food': AppColors.warning,
      'Transport': AppColors.success,
      'Stay': AppColors.primary,
      'Activities': AppColors.teal,
      'Shopping': AppColors.purple,
      'Emergency': AppColors.danger,
    };
    return map[category] ?? AppColors.primary;
  }

  IconData _categoryIcon(String category) {
    const map = {
      'Food': Icons.restaurant_outlined,
      'Transport': Icons.directions_bus_outlined,
      'Stay': Icons.hotel_outlined,
      'Activities': Icons.local_activity_outlined,
      'Shopping': Icons.shopping_bag_outlined,
      'Emergency': Icons.medical_services_outlined,
    };
    return map[category] ?? Icons.receipt_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(activeTripProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.navy,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget Report',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            tripAsync.whenOrNull(
                  data: (trip) => trip != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withAlpha(15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trip.destination,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.teal,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ) ??
                const SizedBox.shrink(),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () {
              final trip = tripAsync.valueOrNull;
              if (trip != null) _shareReport(trip);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.teal],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share_outlined, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Share',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
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
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trip) {
          if (trip == null) return _buildNoTripState();
          return _buildReport(trip);
        },
      ),
    );
  }

  // ── No Trip ────────────────────────────────────────────────────────────────

  Widget _buildNoTripState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.bar_chart_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'No active trip',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a trip to see your spending report',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: AppColors.lightOnSurfaceVar,
            ),
          ),
        ],
      ),
    );
  }

  // ── Report ─────────────────────────────────────────────────────────────────

  Widget _buildReport(BudgetModel trip) {
    final expensesAsync = ref.watch(tripExpensesProvider(trip.id));

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (expenses) {
        final categoryTotals = <String, double>{};
        for (final e in expenses) {
          categoryTotals[e.category] =
              (categoryTotals[e.category] ?? 0) + e.convertedAmountINR;
        }
        final sortedCategories = categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final dailyMap = <String, double>{};
        for (final e in expenses) {
          final key = DateFormat('d MMM').format(e.date);
          dailyMap[key] = (dailyMap[key] ?? 0) + e.convertedAmountINR;
        }
        final dailyEntries = dailyMap.entries.toList();
        final savings = trip.totalBudget - trip.totalSpent;

        final bottomInset = MediaQuery.of(context).padding.bottom;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 40 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(trip),
              const SizedBox(height: 28),
              if (sortedCategories.isNotEmpty) ...[
                _buildSectionHeader(
                    'Spending by Category', AppColors.primary, AppColors.teal),
                const SizedBox(height: 14),
                _buildCategoryChart(sortedCategories, trip.totalSpent),
                const SizedBox(height: 28),
              ],
              if (dailyEntries.isNotEmpty) ...[
                _buildSectionHeader(
                    'Daily Spending Trend', AppColors.teal, AppColors.success),
                const SizedBox(height: 14),
                _buildDailySpendingChart(dailyEntries),
                const SizedBox(height: 28),
              ],
              if (sortedCategories.isNotEmpty) ...[
                _buildSectionHeader(
                    'Category Breakdown', AppColors.purple, AppColors.teal),
                const SizedBox(height: 14),
                _buildCategoryBreakdown(sortedCategories, trip.totalSpent),
                const SizedBox(height: 16),
              ],
              if (expenses.isEmpty)
                _buildEmptyExpenses()
              else if (savings > 0)
                _buildSavingsCard(savings)
              else if (savings < 0)
                _buildOverBudgetCard(-savings),
            ],
          ),
        );
      },
    );
  }

  // ── Section Header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, Color colorA, Color colorB) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colorA, colorB],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }

  // ── Summary Card ───────────────────────────────────────────────────────────

  Widget _buildSummaryCard(BudgetModel trip) {
    final pct = trip.spentPercent.clamp(0.0, 1.0);
    final isOver = trip.totalSpent > trip.totalBudget;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A4A), AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withAlpha(80),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(8),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -36,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row — label + status pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.analytics_outlined,
                              size: 12, color: Colors.white60),
                          SizedBox(width: 5),
                          Text(
                            'Trip Summary',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOver
                            ? AppColors.danger.withAlpha(40)
                            : AppColors.success.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOver ? 'Over Budget' : 'On Track ✓',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOver
                              ? AppColors.danger
                              : const Color(0xFF6FCF97),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 3-stat row
                Row(
                  children: [
                    Expanded(
                      child: _summaryStatItem(
                        'Budget',
                        _fmtFull(trip.totalBudget),
                        Colors.white,
                        Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    Container(
                        width: 1, height: 40, color: Colors.white.withAlpha(22)),
                    Expanded(
                      child: _summaryStatItem(
                        'Spent',
                        _fmtFull(trip.totalSpent),
                        isOver ? AppColors.danger : Colors.white,
                        Icons.arrow_upward_rounded,
                      ),
                    ),
                    Container(
                        width: 1, height: 40, color: Colors.white.withAlpha(22)),
                    Expanded(
                      child: _summaryStatItem(
                        'Remaining',
                        _fmtFull(trip.remaining.abs()),
                        isOver
                            ? AppColors.danger
                            : const Color(0xFF6FCF97),
                        isOver
                            ? Icons.warning_amber_rounded
                            : Icons.savings_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Animated progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => LinearProgressIndicator(
                      value: (pct * _anim.value).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withAlpha(20),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOver
                            ? AppColors.danger
                            : const Color(0xFF6FCF97),
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(pct * 100).toStringAsFixed(1)}% used',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white54,
                      ),
                    ),
                    Text(
                      isOver
                          ? '${_fmtFull(-trip.remaining)} over'
                          : '${_fmtFull(trip.remaining)} left',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOver
                            ? AppColors.danger
                            : const Color(0xFF6FCF97),
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

  Widget _summaryStatItem(
      String label, String value, Color valueColor, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 15, color: Colors.white30),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  // ── Pie Chart ──────────────────────────────────────────────────────────────

  Widget _buildCategoryChart(
      List<MapEntry<String, double>> categories, double totalSpent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Interactive donut with center text overlay
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) {
                    return PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedPieIndex = -1;
                                return;
                              }
                              _touchedPieIndex = pieTouchResponse
                                  .touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sections: categories.asMap().entries.map((e) {
                          final isTouched = e.key == _touchedPieIndex;
                          final color =
                              _chartColors[e.key % _chartColors.length];
                          final pct = totalSpent > 0
                              ? e.value.value / totalSpent * 100
                              : 0.0;
                          return PieChartSectionData(
                            value: e.value.value,
                            title: isTouched
                                ? '${pct.toStringAsFixed(0)}%'
                                : '',
                            color: color,
                            radius:
                                (isTouched ? 82.0 : 68.0) * _anim.value,
                            titleStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        centerSpaceRadius: 58,
                        sectionsSpace: 3,
                      ),
                    );
                  },
                ),
                // Center label — tappable to deselect
                GestureDetector(
                  onTap: () => setState(() => _touchedPieIndex = -1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _touchedPieIndex >= 0 &&
                                _touchedPieIndex < categories.length
                            ? categories[_touchedPieIndex].key
                            : 'Total Spent',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.lightOnSurfaceVar,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _touchedPieIndex >= 0 &&
                                _touchedPieIndex < categories.length
                            ? _fmtMoney(categories[_touchedPieIndex].value)
                            : _fmtMoney(totalSpent),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: Color(0xFFEEF0F3)),
          const SizedBox(height: 14),
          // Legend — tappable rows with mini progress bars
          ...categories.asMap().entries.map((e) {
            final color = _chartColors[e.key % _chartColors.length];
            final pct =
                totalSpent > 0 ? e.value.value / totalSpent : 0.0;
            final isTouched = e.key == _touchedPieIndex;

            return GestureDetector(
              onTap: () => setState(() {
                _touchedPieIndex = isTouched ? -1 : e.key;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isTouched
                      ? color.withAlpha(14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isTouched
                        ? color.withAlpha(50)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                e.value.key,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: isTouched
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: AppColors.navy,
                                ),
                              ),
                              Text(
                                _fmtMoney(e.value.value),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: AnimatedBuilder(
                              animation: _anim,
                              builder: (context, _) =>
                                  LinearProgressIndicator(
                                value: (pct * _anim.value).clamp(0.0, 1.0),
                                backgroundColor: const Color(0xFFEEF0F3),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Bar Chart ──────────────────────────────────────────────────────────────

  Widget _buildDailySpendingChart(List<MapEntry<String, double>> daily) {
    final maxVal =
        daily.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final barWidth = daily.length > 7 ? 14.0 : 22.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 10),
      child: SizedBox(
        height: 220,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => BarChart(
            BarChartData(
              maxY: maxVal * 1.3,
              barGroups: daily.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.value * _anim.value,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.teal],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }).toList(),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.navy.withAlpha(230),
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${daily[group.x].key}\n',
                      const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white60,
                      ),
                      children: [
                        TextSpan(
                          text: _fmtMoney(rod.toY),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      if (value == meta.max) return const SizedBox.shrink();
                      return Text(
                        _fmtMoney(value),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          color: AppColors.lightOnSurfaceVar,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= daily.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          daily[idx].key,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            color: AppColors.lightOnSurfaceVar,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVal / 4,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: const Color(0xFFEEF0F3), strokeWidth: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Category Breakdown List ────────────────────────────────────────────────

  Widget _buildCategoryBreakdown(
      List<MapEntry<String, double>> categories, double totalSpent) {
    return Column(
      children: categories.asMap().entries.map((e) {
        final color = _chartColors[e.key % _chartColors.length];
        final categoryColor = _categoryColor(e.value.key);
        final effectiveColor =
            e.key < 6 ? color : categoryColor;
        final pct = totalSpent > 0 ? e.value.value / totalSpent : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.white,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 4, color: effectiveColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: effectiveColor.withAlpha(18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _categoryIcon(e.value.key),
                                color: effectiveColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.value.key,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  Text(
                                    '${(pct * 100).toStringAsFixed(1)}% of total',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: AppColors.lightOnSurfaceVar,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _fmtMoney(e.value.value),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: effectiveColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: AnimatedBuilder(
                            animation: _anim,
                            builder: (context, _) => LinearProgressIndicator(
                              value: (pct * _anim.value).clamp(0.0, 1.0),
                              backgroundColor: const Color(0xFFEEF0F3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  effectiveColor),
                              minHeight: 4,
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
      }).toList(),
    );
  }

  // ── Empty / Savings / Over-budget ─────────────────────────────────────────

  Widget _buildEmptyExpenses() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 52, color: AppColors.lightOutline),
            SizedBox(height: 14),
            Text(
              'No expenses yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Add some expenses to see your\nspending report',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.lightOnSurfaceVar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsCard(double savings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B8A6B), AppColors.teal],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -12,
            top: -12,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(12),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.savings_outlined,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Under Budget!',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'You saved ${_fmtFull(savings)} — great budgeting!',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _fmtFull(savings),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverBudgetCard(double overspend) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB03030), AppColors.danger],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Over Budget',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'You exceeded your budget by ${_fmtFull(overspend)}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
