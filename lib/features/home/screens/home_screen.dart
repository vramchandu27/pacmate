import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../budget/screens/budget_screen.dart';
import '../../budget/services/budget_service.dart';
import '../../hidden_gems/screens/gems_map_screen.dart';
import '../../packing/screens/packing_screen.dart';
import 'home_dashboard_view.dart';

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

class _DownArrowPainter extends CustomPainter {
  const _DownArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _showHint = false;
  Timer? _hintTimer;
  DateTime? _pausedAt;

  // After this much time in the background, reset to the Home tab on resume.
  static const _backgroundResetThreshold = Duration(minutes: 5);

  static const List<Widget> _screens = [
    HomeDashboardView(),
    BudgetScreen(),
    PackingScreen(),
    GemsMapScreen(),
  ];

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_wallet_outlined),
      activeIcon: Icon(Icons.account_balance_wallet_rounded),
      label: 'Budget',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.luggage_outlined),
      activeIcon: Icon(Icons.luggage_rounded),
      label: 'Packing',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.diamond_outlined),
      activeIcon: Icon(Icons.diamond_rounded),
      label: 'Gems',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final paused = _pausedAt;
      if (paused != null &&
          DateTime.now().difference(paused) >= _backgroundResetThreshold) {
        // User was away long enough — clear any pushed routes and go to Home tab.
        if (mounted) {
          ref.read(homeTabIndexProvider.notifier).state = 0;
          context.go(AppRoutes.home);
        }
      }
      _pausedAt = null;
    }
  }

  void _onTabChanged(int index, bool hasActiveTrip) {
    ref.read(homeTabIndexProvider.notifier).state = index;
    if (index == 1 && hasActiveTrip) {
      _triggerHint();
    } else {
      _hideHint();
    }
  }

  void _triggerHint() {
    _hintTimer?.cancel();
    setState(() => _showHint = true);
    _hintTimer = Timer(const Duration(seconds: 6), _hideHint);
  }

  void _hideHint() {
    if (mounted) setState(() => _showHint = false);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(homeTabIndexProvider);
    final now = DateTime.now();
    final hasActiveTrip = ref.watch(allTripsProvider).valueOrNull
            ?.any((t) =>
                t.isActive &&
                !t.startDate.isAfter(now) &&
                !t.endDate.isBefore(now)) ??
        false;
    final showFab = selectedIndex == 1 && hasActiveTrip;

    return Scaffold(
      body: _screens[selectedIndex],
      floatingActionButton: showFab
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedOpacity(
                  opacity: _showHint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: AnimatedSlide(
                    offset: _showHint ? Offset.zero : const Offset(0, 0.4),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Bubble
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(50),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded,
                                  color: Colors.white70, size: 15),
                              SizedBox(width: 7),
                              Text(
                                'Tap to add an expense',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Downward arrow pointing at FAB
                        Padding(
                          padding: const EdgeInsets.only(right: 22),
                          child: CustomPaint(
                            size: const Size(14, 8),
                            painter: _DownArrowPainter(AppColors.navy),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
                FloatingActionButton(
                  heroTag: 'home_add_expense_fab',
                  onPressed: () {
                    // Pass whichever trip is currently visible in the carousel.
                    // Falls back to the activeTripProvider if the budget screen
                    // hasn't seeded the selection yet (e.g., first load).
                    final trip = ref.read(selectedCarouselTripProvider)
                        ?? ref.read(activeTripProvider).valueOrNull;
                    context.push(AppRoutes.addExpense, extra: trip);
                  },
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  child: const Icon(Icons.add_rounded, size: 28),
                ),
              ],
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: selectedIndex,
        onTap: (index) => _onTabChanged(index, hasActiveTrip),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.lightOnSurfaceVar,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        elevation: 8,
        showUnselectedLabels: true,
      ),
    );
  }
}
