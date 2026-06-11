import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';

// ─── ROUTE RESULT SCREEN ──────────────────────────────────────────────────────
// Displays the Gemini-generated day-by-day itinerary.
// ─────────────────────────────────────────────────────────────────────────────

class RouteResultScreen extends ConsumerStatefulWidget {
  const RouteResultScreen({
    super.key,
    required this.days,
    required this.startCity,
    required this.endCity,
    required this.durationDays,
    required this.dailyBudgetINR,
  });

  final List<RouteDayModel> days;
  final String startCity;
  final String endCity;
  final int durationDays;
  final int dailyBudgetINR;

  @override
  ConsumerState<RouteResultScreen> createState() => _RouteResultScreenState();
}

class _RouteResultScreenState extends ConsumerState<RouteResultScreen> {
  bool _saving = false;
  bool _saved  = false;

  int get _totalCost =>
      widget.days.fold(0, (s, d) => s + d.estimatedCostINR);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(routeServiceProvider).saveRoute(
        startCity:      widget.startCity,
        endCity:        widget.endCity,
        durationDays:   widget.durationDays,
        dailyBudgetINR: widget.dailyBudgetINR,
        days:           widget.days,
      );
      if (mounted) setState(() => _saved = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Itinerary saved!',
                style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e',
                style: const TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildSummaryCard()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildDayCard(widget.days[i]),
                childCount: widget.days.length,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      leading: GestureDetector(
        onTap: () { if (context.canPop()) context.pop(); },
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
      actions: [
        if (!_saved)
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.bookmark_add_outlined,
                    color: Colors.white, size: 20),
            label: Text(_saving ? 'Saving…' : 'Save',
                style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14,
                  fontWeight: FontWeight.w600, color: Colors.white,
                )),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: const [
                Icon(Icons.bookmark_rounded, color: AppColors.success, size: 20),
                SizedBox(width: 4),
                Text('Saved',
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 14,
                      fontWeight: FontWeight.w600, color: AppColors.success,
                    )),
              ],
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1A3A6B)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Text('${widget.startCity}  →  ${widget.endCity}',
                          style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 18,
                            fontWeight: FontWeight.w700, color: Colors.white,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.durationDays} days · ₹${widget.dailyBudgetINR}/day',
                    style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Summary card ────────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withAlpha(20), AppColors.teal.withAlpha(15)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          _statChip(Icons.calendar_today_rounded,
              '${widget.days.length} days', AppColors.primary),
          const SizedBox(width: 12),
          _statChip(Icons.currency_rupee_rounded,
              '₹${_totalCost.toString()}', AppColors.success),
          const SizedBox(width: 12),
          _statChip(Icons.place_rounded,
              '${widget.days.map((d) => d.location).toSet().length} cities',
              AppColors.warning),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12,
                  fontWeight: FontWeight.w600, color: color,
                ),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Day card ────────────────────────────────────────────────────────────────

  Widget _buildDayCard(RouteDayModel day) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8),
              blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('${day.day}',
                        style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 14,
                          fontWeight: FontWeight.w700, color: Colors.white,
                        )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.title,
                          style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 14,
                            fontWeight: FontWeight.w700, color: AppColors.navy,
                          )),
                      if (day.location.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                color: AppColors.lightOnSurfaceVar, size: 12),
                            const SizedBox(width: 2),
                            Text(day.location,
                                style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 11,
                                  color: AppColors.lightOnSurfaceVar,
                                )),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Activities
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (day.morning.isNotEmpty)
                  _activityRow('🌅', 'Morning', day.morning),
                if (day.afternoon.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _activityRow('☀️', 'Afternoon', day.afternoon),
                ],
                if (day.evening.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _activityRow('🌙', 'Evening', day.evening),
                ],
                if (day.accommodation.isNotEmpty) ...[
                  const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🏨 ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(day.accommodation,
                            style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 13,
                              color: AppColors.lightOnSurfaceVar,
                            )),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.success.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_rupee_rounded,
                              color: AppColors.success, size: 13),
                          Text('${day.estimatedCostINR}',
                              style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              )),
                        ],
                      ),
                    ),
                    if (day.tips.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💡 ',
                                style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Text(day.tips,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 12,
                                    color: AppColors.lightOnSurfaceVar,
                                    fontStyle: FontStyle.italic,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityRow(String emoji, String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$emoji ', style: const TextStyle(fontSize: 15)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightOnSurfaceVar,
                  )),
              const SizedBox(height: 2),
              Text(text,
                  style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13,
                    color: AppColors.navy,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bottom bar ──────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad > 0 ? bottomPad + 8 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12),
              blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () { if (context.canPop()) context.pop(); },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Redo',
                  style: TextStyle(fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: (_saving || _saved) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      _saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                      size: 18),
              label: Text(
                _saved ? 'Saved' : (_saving ? 'Saving…' : 'Save Itinerary'),
                style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _saved ? AppColors.success : AppColors.primary,
                disabledBackgroundColor:
                    (_saved ? AppColors.success : AppColors.primary)
                        .withAlpha(100),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
