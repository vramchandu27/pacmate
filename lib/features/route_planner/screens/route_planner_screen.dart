import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../services/route_service.dart';

// ─── ROUTE PLANNER SCREEN ─────────────────────────────────────────────────────
// Input form for AI itinerary generation.
// ─────────────────────────────────────────────────────────────────────────────

const _interests = [
  'Culture', 'Food', 'Nature', 'Adventure',
  'History', 'Shopping', 'Photography', 'Spirituality',
  'Beaches', 'Wildlife',
];

const _paces = ['Relaxed', 'Moderate', 'Fast'];

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl   = TextEditingController();

  int _days          = 5;
  int _dailyBudget   = 2000;
  String _pace       = 'Moderate';
  bool _seniorMode   = false;
  bool _vegOnly      = false;
  bool _generating   = false;
  String? _error;

  final Set<String> _selectedInterests = {'Food', 'Culture'};

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final from = _fromCtrl.text.trim();
    final to   = _toCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      setState(() => _error = 'Enter both origin and destination.');
      return;
    }
    setState(() { _generating = true; _error = null; });
    try {
      final days = await ref.read(routeServiceProvider).generateRoute(
        startCity:      from,
        endCity:        to,
        durationDays:   _days,
        dailyBudgetINR: _dailyBudget,
        interests:      _selectedInterests.toList(),
        pace:           _pace.toLowerCase(),
        isSenior:       _seniorMode,
        vegetarianOnly: _vegOnly,
      );
      if (!mounted) return;
      context.push(AppRoutes.routeResult, extra: {
        'days':           days,
        'startCity':      from,
        'endCity':        to,
        'durationDays':   _days,
        'dailyBudgetINR': _dailyBudget,
      });
    } on Exception catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) _buildError(),
                  _buildRouteFields(),
                  const SizedBox(height: 24),
                  _label('Duration'),
                  const SizedBox(height: 12),
                  _buildDayCounter(),
                  const SizedBox(height: 24),
                  _label('Daily Budget (₹)'),
                  const SizedBox(height: 8),
                  _buildBudgetInput(),
                  const SizedBox(height: 24),
                  _label('Interests'),
                  const SizedBox(height: 12),
                  _buildInterestChips(),
                  const SizedBox(height: 24),
                  _label('Travel Pace'),
                  const SizedBox(height: 12),
                  _buildPaceSelector(),
                  const SizedBox(height: 24),
                  _buildToggles(),
                  SizedBox(height: 32 + bottomPad),
                ],
              ),
            ),
          ),
          _buildGenerateButton(bottomPad),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1A3A6B)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () { if (context.canPop()) context.pop(); },
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(50),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Route Planner',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                      Text('Day-by-day itinerary powered by Gemini',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white60,
                          )),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, color: AppColors.danger,
                )),
          ),
        ],
      ),
    );
  }

  // ── Route fields ───────────────────────────────────────────────────────────

  Widget _buildRouteFields() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightOutline),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _buildCityField(
            ctrl: _fromCtrl,
            hint: 'From — e.g. Mumbai',
            icon: Icons.flight_takeoff_rounded,
            iconColor: AppColors.primary,
          ),
          Divider(height: 1, color: AppColors.lightOutline),
          _buildCityField(
            ctrl: _toCtrl,
            hint: 'To — e.g. Goa',
            icon: Icons.flight_land_rounded,
            iconColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildCityField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 15,
                fontWeight: FontWeight.w500, color: AppColors.navy,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14,
                  color: AppColors.lightOnSurface,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Day counter ─────────────────────────────────────────────────────────────

  Widget _buildDayCounter() {
    return Row(
      children: [
        _counterBtn(Icons.remove_rounded, () {
          if (_days > 1) setState(() => _days--);
        }),
        const SizedBox(width: 20),
        Column(
          children: [
            Text('$_days',
                style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 28,
                  fontWeight: FontWeight.w700, color: AppColors.navy,
                )),
            const Text('days',
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12,
                  color: AppColors.lightOnSurfaceVar,
                )),
          ],
        ),
        const SizedBox(width: 20),
        _counterBtn(Icons.add_rounded, () {
          if (_days < 30) setState(() => _days++);
        }),
        const Spacer(),
        Text('max 30 days',
            style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 11,
              color: AppColors.lightOnSurface,
            )),
      ],
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }

  // ── Budget input ────────────────────────────────────────────────────────────

  Widget _buildBudgetInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightOutline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text('₹', style: TextStyle(
            fontFamily: 'Poppins', fontSize: 18,
            fontWeight: FontWeight.w600, color: AppColors.success,
          )),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: '$_dailyBudget')
                ..selection = TextSelection.collapsed(
                    offset: '$_dailyBudget'.length),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 16,
                fontWeight: FontWeight.w600, color: AppColors.navy,
              ),
              decoration: const InputDecoration(
                hintText: '2000',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (v) {
                final val = int.tryParse(v) ?? 2000;
                _dailyBudget = val.clamp(100, 100000);
              },
            ),
          ),
          const Text('/ day', style: TextStyle(
            fontFamily: 'Poppins', fontSize: 13,
            color: AppColors.lightOnSurfaceVar,
          )),
        ],
      ),
    );
  }

  // ── Interest chips ──────────────────────────────────────────────────────────

  Widget _buildInterestChips() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _interests.map((interest) {
        final selected = _selectedInterests.contains(interest);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedInterests.remove(interest);
            } else {
              _selectedInterests.add(interest);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.lightOutline,
              ),
            ),
            child: Text(interest,
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppColors.navy,
                )),
          ),
        );
      }).toList(),
    );
  }

  // ── Pace selector ───────────────────────────────────────────────────────────

  Widget _buildPaceSelector() {
    return Row(
      children: _paces.map((pace) {
        final selected = _pace == pace;
        final icons = [
          Icons.self_improvement_rounded,
          Icons.directions_walk_rounded,
          Icons.directions_run_rounded,
        ];
        final idx = _paces.indexOf(pace);
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _pace = pace),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: pace == _paces.last ? 0 : 10),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.lightOutline,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(icons[idx],
                      color: selected ? Colors.white : AppColors.navy,
                      size: 22),
                  const SizedBox(height: 4),
                  Text(pace,
                      style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.navy,
                      )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Toggles ─────────────────────────────────────────────────────────────────

  Widget _buildToggles() {
    return Column(
      children: [
        _buildToggle(
          label: 'Senior-friendly mode',
          subtitle: 'Minimal walking, comfort-first stops',
          icon: Icons.elderly_rounded,
          value: _seniorMode,
          onChanged: (v) => setState(() => _seniorMode = v),
        ),
        const SizedBox(height: 12),
        _buildToggle(
          label: 'Vegetarian only',
          subtitle: 'Only suggest vegetarian food options',
          icon: Icons.eco_rounded,
          value: _vegOnly,
          onChanged: (v) => setState(() => _vegOnly = v),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value ? AppColors.primary.withAlpha(10) : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? AppColors.primary.withAlpha(80) : AppColors.lightOutline,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: value ? AppColors.primary : AppColors.lightOnSurfaceVar,
              size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: value ? AppColors.primary : AppColors.navy,
                    )),
                Text(subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 11,
                      color: AppColors.lightOnSurfaceVar,
                    )),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ── Generate button ─────────────────────────────────────────────────────────

  Widget _buildGenerateButton(double bottomPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad > 0 ? bottomPad + 8 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _generating ? null : _generate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withAlpha(100),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _generating
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Text('Gemini is thinking…',
                        style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 15,
                          fontWeight: FontWeight.w600, color: Colors.white,
                        )),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Generate Itinerary',
                        style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 16,
                          fontWeight: FontWeight.w700, color: Colors.white,
                        )),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(
          fontFamily: 'Poppins', fontSize: 15,
          fontWeight: FontWeight.w700, color: AppColors.navy,
        ));
  }
}
