import 'dart:async';
import 'dart:ui';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/budget/services/budget_service.dart';
import '../../../features/notifications/services/notification_service.dart';
import '../../../features/packing/services/packing_service.dart';
import '../../../shared/models/budget_model.dart';
import '../../../shared/models/currency_data.dart';
import '../../../shared/providers/user_provider.dart';
import 'home_screen.dart';

// ─── HOME DASHBOARD VIEW ─────────────────────────────────────────────────────
// Main dashboard: greeting, trips carousel, XP, stats, quick-actions.
// ─────────────────────────────────────────────────────────────────────────────

class HomeDashboardView extends ConsumerStatefulWidget {
  const HomeDashboardView({super.key});

  @override
  ConsumerState<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends ConsumerState<HomeDashboardView> {
  final _tripPageCtrl = PageController(viewportFraction: 0.92);
  int _tripPage = 0;
  bool _didInitialScroll = false;
  bool _showNewTripHint      = false;
  bool _countryPromptShown   = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showNewTripHint = true);
      _hintTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _showNewTripHint = false);
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _tripPageCtrl.dispose();
    super.dispose();
  }


  Future<void> _maybePromptCountry(String homeCountry) async {
    if (_countryPromptShown || homeCountry.trim().isNotEmpty) return;
    _countryPromptShown = true;
    await Future.delayed(Duration.zero); // let the frame settle
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CountrySetupSheet(),
    );
  }

  static List<BudgetModel> _sortByDate(List<BudgetModel> trips) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Active (user's selected trip) always first
    final active = trips.where((t) => t.isActive).toList();

    // Ongoing — started but not yet ended, not manually completed, not active
    final ongoing = trips.where((t) {
      if (t.isActive || t.completedAt != null) return false;
      final s = DateTime(t.startDate.year, t.startDate.month, t.startDate.day);
      final e = DateTime(t.endDate.year,   t.endDate.month,   t.endDate.day);
      return !s.isAfter(today) && !e.isBefore(today);
    }).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));

    // Upcoming — not started yet, not manually completed, not active
    final upcoming = trips.where((t) {
      if (t.isActive || t.completedAt != null) return false;
      final s = DateTime(t.startDate.year, t.startDate.month, t.startDate.day);
      return s.isAfter(today);
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // Past — ended before today OR manually completed
    final past = trips.where((t) {
      if (t.isActive) return false;
      final e = DateTime(t.endDate.year, t.endDate.month, t.endDate.day);
      return e.isBefore(today) || t.completedAt != null;
    }).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return [...active, ...ongoing, ...upcoming, ...past];
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final userName = user?.fullName.split(' ').first ?? 'Traveler';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'T';
    final allTripsAsync = ref.watch(allTripsProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final w = MediaQuery.sizeOf(context).width;

    // Prompt for home country if not set — non-dismissible until filled
    ref.listen<AsyncValue>(currentUserProvider, (_, next) {
      final country = next.valueOrNull?.homeCountry ?? '';
      _maybePromptCountry(country);
    });
    if (user != null) _maybePromptCountry(user.homeCountry);

    // Location is requested lazily when the user opens Hidden Gems → Nearby tab,
    // not here — prompting on trip creation is confusing when the user hasn't traveled yet.
    final hp = w < 360 ? 14.0 : 20.0; // horizontal padding

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(context, userName, userInitial, w, unreadCount),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hp, vertical: hp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreeting(w),
                  SizedBox(height: w < 360 ? 14 : 20),
                  _buildTripsCarousel(allTripsAsync, w),
                  SizedBox(height: w < 360 ? 16 : 24),
                  _buildTravelerXP(
                    allTripsAsync.value
                            ?.where((t) => t.endDate.isBefore(DateTime.now()))
                            .length ??
                        0,
                    w,
                  ),
                  SizedBox(height: w < 360 ? 16 : 24),
                  _buildStatsGrid(context, allTripsAsync.value ?? [], w),
                  const SizedBox(height: 32),
                  _buildQuickActions(context, w),
                ],
              ),
            ),
          ),
          // ── New Trip hint bubble ─────────────────────────────────────────
          Positioned(
            top: 6,
            right: hp,
            child: AnimatedOpacity(
              opacity: _showNewTripHint ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showNewTripHint,
                child: _buildNewTripHint(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String userName,
    String userInitial,
    double w,
    int unreadCount,
  ) {
    final hp      = w < 360 ? 14.0 : 20.0;
    final avatarSz = w < 360 ? 36.0 : 42.0;
    final avatarFz = w < 360 ? 15.0 : 17.0;
    final nameFz  = w < 360 ? 13.0 : 15.0;
    final subFz   = w < 360 ? 10.0 : 11.0;
    final user    = ref.watch(currentUserProvider).valueOrNull;
    final photoUrl = user?.photoUrl;

    return AppBar(
      backgroundColor: const Color(0xFFF5F7FA),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: hp,
      title: Row(
        children: [
          // ── Gradient-ring avatar ──────────────────────────────────────
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.teal],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF5F7FA),
                ),
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? CircleAvatar(
                        radius: avatarSz / 2,
                        backgroundImage: NetworkImage(photoUrl),
                        onBackgroundImageError: (_, _) {},
                      )
                    : Container(
                        width: avatarSz,
                        height: avatarSz,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.teal],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            userInitial,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: avatarFz,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(width: w < 360 ? 10 : 12),
          // ── Greeting text ─────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: nameFz,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                      children: [
                        const TextSpan(text: 'Hey '),
                        TextSpan(
                          text: '$userName!',
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  _WavingHand(fontSize: nameFz),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                'Ready to explore?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: subFz,
                  fontWeight: FontWeight.w400,
                  color: AppColors.lightOnSurfaceVar,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // ── Notification bell ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _appBarIconBtn(
                icon: Icons.notifications_outlined,
                onTap: () => context.push(AppRoutes.notifications),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // ── New Trip button ───────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8, right: hp),
          child: _appBarIconBtn(
            icon: Icons.add_rounded,
            onTap: () => context.push(AppRoutes.createTrip),
          ),
        ),
      ],
    );
  }

  Widget _buildNewTripHint() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Upward arrow pointing toward the + in the AppBar
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: CustomPaint(
            size: const Size(14, 8),
            painter: _UpArrowPainter(AppColors.navy),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white70, size: 15),
              SizedBox(width: 7),
              Text(
                'Tap + to plan a new trip',
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
      ],
    );
  }

  Widget _appBarIconBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.navy, size: 20),
      ),
    );
  }

  // ── Greeting ──────────────────────────────────────────────────────────────

  Widget _buildGreeting(double w) {
    final allTrips = ref.watch(allTripsProvider).valueOrNull ?? [];
    final now = DateTime.now();

    // Find the soonest upcoming / active trip with a future start date
    BudgetModel? nextTrip;
    int? daysUntil;
    for (final trip in allTrips) {
      if (!trip.isActive) continue;
      final days = trip.startDate.difference(now).inDays;
      if (days >= 0 && (daysUntil == null || days < daysUntil)) {
        daysUntil = days;
        nextTrip = trip;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: w < 360 ? 22 : 28,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
            height: 1.2,
          ),
        ),
        if (nextTrip != null && daysUntil != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withAlpha(40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✈️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  daysUntil == 0
                      ? '${nextTrip.destination} — Today!'
                      : daysUntil == 1
                          ? '${nextTrip.destination} — Tomorrow!'
                          : '${nextTrip.destination} in $daysUntil days',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            _dailyQuote(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: w < 360 ? 12 : 13,
              fontWeight: FontWeight.w400,
              color: AppColors.lightOnSurfaceVar,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  static const _quotes = [
    '"The world is a book — those who do not travel read only one page."',
    '"Travel far enough, you meet yourself."',
    '"Life is short and the world is wide."',
    '"Adventure is worthwhile in itself."',
    '"Not all those who wander are lost."',
    '"Travel is the only thing you buy that makes you richer."',
    '"To travel is to live."',
    '"Wherever you go, go with all your heart."',
    '"Jobs fill your pocket, adventures fill your soul."',
    '"Travel makes one modest — you see what a tiny place you occupy in the world."',
    '"The journey of a thousand miles begins with a single step."',
    '"Travel and change of place impart new vigour to the mind."',
  ];

  String _dailyQuote() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _quotes[dayOfYear % _quotes.length];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.homeGreetingMorning;
    if (hour < 17) return AppStrings.homeGreetingAfternoon;
    return AppStrings.homeGreetingEvening;
  }

  // ── Trips Carousel ────────────────────────────────────────────────────────

  Widget _buildTripsCarousel(AsyncValue<List<BudgetModel>> allTripsAsync, double w) {
    final cardH = w < 360 ? 240.0 : 270.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: allTripsAsync.when(
        loading: () => Container(
          height: cardH + 32,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
                color: Colors.white38, strokeWidth: 2),
          ),
        ),
        error: (err, stack) => const SizedBox.shrink(),
        data: (allTrips) {
          final trips = _sortByDate(allTrips);

          if (!_didInitialScroll) {
            _didInitialScroll = true;
            final activeIdx = trips.indexWhere((t) => t.isActive);
            if (activeIdx > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _tripPageCtrl.hasClients) {
                  _tripPageCtrl.jumpToPage(activeIdx);
                  setState(() => _tripPage = activeIdx);
                }
              });
            }
          }

          final safePage =
              trips.isEmpty ? 0 : _tripPage.clamp(0, trips.length - 1);

          // No trips — return card directly with no dark background
          if (trips.isEmpty) return _buildNoTripCard();

          // Stack: background fills completely; content sits on top
          return Stack(
            children: [
              // ── Dark gradient background ───────────────────────────────
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                  ),
                ),
              ),
              // ── Decorative blobs ───────────────────────────────────────
              Positioned(
                left: -40, top: -40,
                child: _gradientBlob(AppColors.primary, 180),
              ),
              Positioned(
                right: -30, bottom: -30,
                child: _gradientBlob(AppColors.teal, 150),
              ),
              Positioned(
                right: 40, top: -20,
                child: _gradientBlob(AppColors.purple, 100),
              ),
              // ── Carousel content ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: cardH,
                            child: PageView.builder(
                              controller: _tripPageCtrl,
                              itemCount: trips.length,
                              onPageChanged: (i) =>
                                  setState(() => _tripPage = i),
                              itemBuilder: (_, i) {
                                return AnimatedBuilder(
                                  animation: _tripPageCtrl,
                                  builder: (_, child) {
                                    double page;
                                    try {
                                      page = _tripPageCtrl.hasClients &&
                                              _tripPageCtrl.page != null
                                          ? _tripPageCtrl.page!
                                          : _tripPage.toDouble();
                                    } catch (_) {
                                      page = _tripPage.toDouble();
                                    }
                                    final diff =
                                        (page - i).abs().clamp(0.0, 1.0);
                                    return Transform.scale(
                                      scale: 1.0 - diff * 0.07,
                                      child: Opacity(
                                        opacity: 1.0 - diff * 0.38,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: GestureDetector(
                                    onTap: () => ref
                                        .read(homeTabIndexProvider.notifier)
                                        .state = 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: _buildHomeTripCard(trips[i]),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (trips.length > 1) ...[
                            const SizedBox(height: 10),
                            _buildDots(trips.length, safePage),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _gradientBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withAlpha(100), color.withAlpha(0)],
        ),
      ),
    );
  }


  Widget _buildNoTripCard() => _NoTripCard(
        onTap: () => context.push(AppRoutes.createTrip),
      );

  Widget _buildHomeTripCard(BudgetModel trip) {
    final fmt = DateFormat('d MMM');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripStart = DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day);
    final tripEnd = DateTime(trip.endDate.year, trip.endDate.month, trip.endDate.day);

    final tripDays = trip.endDate.difference(trip.startDate).inDays + 1;
    final daysPassed = now.difference(trip.startDate).inDays.clamp(0, tripDays);
    final daysUntilStart = tripStart.difference(today).inDays;
    final daysLeft = tripEnd.difference(today).inDays;
    final overBudget = trip.totalSpent > trip.totalBudget;
    // A trip is "upcoming" only if its START date is still in the future.
    // A trip that has already started (even if not the active one) is "ongoing".
    final isUpcoming = tripStart.isAfter(today) && trip.completedAt == null;
    final isOngoing  = !tripStart.isAfter(today) && !tripEnd.isBefore(today) && trip.completedAt == null;

    if (trip.isActive) {
      // ── State machine ──────────────────────────────────────────────────────
      final isPastEnd = today.isAfter(tripEnd);
      final isStartDay = !trip.tripStarted && !isPastEnd && daysUntilStart <= 0;
      final isNearEnd = trip.tripStarted && !isPastEnd && daysLeft <= 3;

      String badge;
      bool showStartBtn = false;
      bool showCompleteBtn = false;

      if (isPastEnd) {
        badge = 'TRIP ENDED';
        showCompleteBtn = true;
      } else if (isStartDay) {
        badge = "TRIP DAY 🎒";
        showStartBtn = true;
      } else if (isNearEnd) {
        badge = 'ACTIVE';
        showCompleteBtn = true;
      } else if (daysUntilStart > 0) {
        badge = 'UPCOMING';
      } else {
        badge = 'ACTIVE';
      }


      final remaining = (trip.totalBudget - trip.totalSpent).clamp(0, double.infinity);
      final spentPct  = (trip.spentPercent * 100).clamp(0.0, 100.0).round();

      return Stack(
        children: [
          // ── Decorative background plane ──────────────────────────────────
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.flight_rounded,
              size: 110,
              color: Colors.white.withAlpha(12),
            ),
          ),
          // ── Glassmorphism card ───────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isPastEnd
              ? const Color(0xFFB71C1C).withAlpha(80)
              : Colors.white.withAlpha(28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withAlpha(60),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.destination,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(badge, isPastEnd, daysUntilStart),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${fmt.format(trip.startDate)} – ${fmt.format(trip.endDate)}  ·  $tripDays days',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.white60,
                letterSpacing: 0.1,
              ),
            ),
            const Spacer(),

            // ── Mini stats row ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _miniStat(
                      _fmtAmt(remaining, trip.currency),
                      'Remaining',
                      Icons.account_balance_wallet_rounded,
                    ),
                    VerticalDivider(
                        color: Colors.white24, thickness: 1, width: 1),
                    _miniStat(
                      isPastEnd
                          ? 'Ended'
                          : daysUntilStart > 0
                              ? 'In $daysUntilStart d'
                              : 'Day $daysPassed/$tripDays',
                      'Timeline',
                      Icons.calendar_today_rounded,
                    ),
                    VerticalDivider(
                        color: Colors.white24, thickness: 1, width: 1),
                    _miniStat(
                      '$spentPct%',
                      'Spent',
                      Icons.pie_chart_rounded,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Progress bar ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_fmtAmt(trip.totalSpent, trip.currency)} spent',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '${_fmtAmt(trip.totalBudget, trip.currency)} budget',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                              begin: 0.0,
                              end: trip.spentPercent.clamp(0.0, 1.0)),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, child) => LinearProgressIndicator(
                            value: v,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              overBudget
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
            // ── Action button ────────────────────────────────────────────────
            if (showStartBtn) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(budgetServiceProvider).startTrip(trip.id);
                    } catch (_) {
                      if (mounted) {
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Could not start trip. Try again.')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const Text('Start Trip',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
            ],
            if (showCompleteBtn) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: OutlinedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Complete Trip?',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600)),
                        content: const Text(
                            'This will archive the trip.',
                            style: TextStyle(fontFamily: 'Poppins')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Not yet')),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.success),
                            child: const Text('Complete',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        await ref
                            .read(budgetServiceProvider)
                            .completeTrip(trip.id);
                      } catch (_) {
                        if (mounted) {
                          messenger.showSnackBar(const SnackBar(
                              content:
                                  Text('Could not complete trip. Try again.')));
                        }
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const Text('Mark as Completed',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),     // Container (glass)
            ),   // BackdropFilter
          ),     // ClipRRect
        ],
      );
    }

    // Past / ongoing / upcoming — glassmorphism to match the dark carousel background
    final badge = isOngoing
        ? 'ONGOING'
        : isUpcoming
            ? 'UPCOMING'
            : overBudget
                ? 'OVER BUDGET'
                : 'COMPLETED';
    final Color badgeDot = isOngoing
        ? AppColors.primary
        : isUpcoming
            ? const Color(0xFFFFB74D)
            : overBudget
                ? const Color(0xFFFF6B6B)
                : const Color(0xFF69F0AE);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(40), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.destination,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
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
                      border:
                          Border.all(color: Colors.white.withAlpha(40), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: badgeDot,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: badgeDot.withAlpha(160),
                                  blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          badge,
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
              const SizedBox(height: 4),
              Text(
                '${fmt.format(trip.startDate)} – ${fmt.format(trip.endDate)}  ·  $tripDays days',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 14),
              // ── Info strip ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: isOngoing
                        ? [
                            _miniStat(
                              daysLeft <= 0 ? 'Today!' : '$daysLeft days',
                              'Days left',
                              Icons.hourglass_bottom_rounded,
                            ),
                            VerticalDivider(
                                color: Colors.white24,
                                thickness: 1,
                                width: 1),
                            _miniStat(
                              _fmtAmt(trip.totalSpent, trip.currency),
                              'Spent so far',
                              Icons.receipt_long_rounded,
                            ),
                            VerticalDivider(
                                color: Colors.white24,
                                thickness: 1,
                                width: 1),
                            _miniStat(
                              _fmtAmt(trip.remaining.clamp(0, double.infinity), trip.currency),
                              'Remaining',
                              Icons.account_balance_wallet_rounded,
                            ),
                          ]
                        : isUpcoming
                        ? [
                            _miniStat(
                              daysUntilStart <= 0
                                  ? 'Today!'
                                  : '$daysUntilStart days',
                              'Starts in',
                              Icons.flight_takeoff_rounded,
                            ),
                            VerticalDivider(
                                color: Colors.white24,
                                thickness: 1,
                                width: 1),
                            _miniStat(
                              '$tripDays days',
                              'Duration',
                              Icons.calendar_today_rounded,
                            ),
                            VerticalDivider(
                                color: Colors.white24,
                                thickness: 1,
                                width: 1),
                            _miniStat(
                              '${_fmtAmt(trip.totalBudget / tripDays, trip.currency)}/d',
                              'Daily budget',
                              Icons.account_balance_wallet_rounded,
                            ),
                          ]
                        : [
                            _miniStat(
                              _fmtAmt(trip.totalSpent, trip.currency),
                              'Total spent',
                              Icons.receipt_long_rounded,
                            ),
                            VerticalDivider(
                                color: Colors.white24,
                                thickness: 1,
                                width: 1),
                            _miniStat(
                              '$tripDays days',
                              'Duration',
                              Icons.calendar_today_rounded,
                            ),
                            VerticalDivider(
                                color: Colors.white24,
                                thickness: 1,
                                width: 1),
                            _miniStat(
                              _fmtAmt(trip.remaining.abs(), trip.currency),
                              overBudget ? 'Over budget' : 'Saved',
                              overBudget
                                  ? Icons.trending_up_rounded
                                  : Icons.savings_rounded,
                            ),
                          ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _fmtAmt(trip.totalBudget, trip.currency),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: trip.spentPercent.clamp(0.0, 1.0),
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    overBudget
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF69F0AE),
                  ),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_fmtAmt(trip.totalSpent, trip.currency)} spent',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                  Text(
                    isUpcoming
                        ? '${_fmtAmt(trip.totalBudget, trip.currency)} budget'
                        : overBudget
                            ? '${_fmtAmt(trip.totalSpent - trip.totalBudget, trip.currency)} over'
                            : '${_fmtAmt(trip.remaining, trip.currency)} saved',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeDot,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String badge, bool isPastEnd, int daysUntilStart) {
    final Color dotColor;
    final bool pulse;

    if (isPastEnd) {
      dotColor = const Color(0xFFFF6B6B);
      pulse = false;
    } else if (daysUntilStart > 0) {
      dotColor = const Color(0xFFFFB74D);
      pulse = false;
    } else {
      dotColor = const Color(0xFF69F0AE);
      pulse = true;                              // active — pulsing green dot
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(40), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pulse
              ? _PulsingDot(color: dotColor)
              : Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: dotColor.withAlpha(180), blurRadius: 4),
                    ],
                  ),
                ),
          const SizedBox(width: 5),
          Text(
            badge.replaceAll('🎒', '').trim(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: dotColor,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white54, size: 13),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              fontWeight: FontWeight.w400,
              color: Colors.white38,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _currencySymbol(String code) {
    try {
      return kAllCurrencies.firstWhere((c) => c.code == code).symbol;
    } catch (_) {
      return code;
    }
  }

  String _fmtAmt(num value, String currency) {
    final sym = _currencySymbol(currency);
    final nf  = currency == 'INR'
        ? NumberFormat('#,##,##0', 'en_IN')
        : NumberFormat('#,##0');
    return '$sym${nf.format(value)}';
  }

  Widget _buildDots(int count, int current) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.lightOutline,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // ── Traveler XP ───────────────────────────────────────────────────────────

  static const List<_Badge> _badges = [
    _Badge(emoji: '🌍', label: 'First Trip',    minTrips: 1),
    _Badge(emoji: '💰', label: 'Budget Pro',    minTrips: 3),
    _Badge(emoji: '💎', label: 'Gem Hunter',    minTrips: 5),
    _Badge(emoji: '✈️', label: 'Wanderer',      minTrips: 8),
    _Badge(emoji: '🏔️', label: 'Explorer',     minTrips: 12),
    _Badge(emoji: '🏆', label: 'Legend',        minTrips: 20),
  ];

  static const List<String> _dailyQuests = [
    'Log an expense today 💸',
    'Discover a hidden gem 💎',
    'Pack 5 items on your list 🎒',
    'Check your budget progress 💰',
    'Plan your next adventure 🗺️',
    'Add a photo to a gem ⭐',
    'Review your packing list 📋',
  ];

  String get _todaysQuest {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _dailyQuests[dayOfYear % _dailyQuests.length];
  }

  _Badge? _nextLockedBadge(int trips) {
    for (final b in _badges) {
      if (trips < b.minTrips) return b;
    }
    return null;
  }

  static ({int level, String title, int xp, int xpToNext, String nextTitle})
      _computeXP(int trips) {
    if (trips == 0) {
      return (
        level: 1,
        title: 'Newcomer',
        xp: 0,
        xpToNext: 200,
        nextTitle: 'Wanderer',
      );
    }
    if (trips < 4) {
      return (
        level: 2,
        title: 'Wanderer',
        xp: trips * 200,
        xpToNext: 800 - trips * 200,
        nextTitle: 'Explorer',
      );
    }
    if (trips < 8) {
      return (
        level: 3,
        title: 'Explorer',
        xp: trips * 200,
        xpToNext: 1600 - trips * 200,
        nextTitle: 'Adventurer',
      );
    }
    return (
      level: 4,
      title: 'Adventurer',
      xp: trips * 200,
      xpToNext: 0,
      nextTitle: '',
    );
  }

  Widget _buildTravelerXP(int trips, double w) {
    final xpData = _computeXP(trips);
    final maxXP = xpData.xp + xpData.xpToNext;
    final progress = maxXP > 0 ? (xpData.xp / maxXP).clamp(0.0, 1.0) : 0.0;

    final xpPad = w < 360 ? 14.0 : 20.0;
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 200),
      child: Container(
        padding: EdgeInsets.all(xpPad),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.purple, Color(0xFF7B68EE)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'Level ${xpData.level} — ${xpData.title}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: w < 360 ? 11 : 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${xpData.xp} XP',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: w < 360 ? 12 : 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    xpData.xpToNext > 0
                        ? '${xpData.xpToNext} XP to Level ${xpData.level + 1} — ${xpData.nextTitle}'
                        : '🏆 Max level reached!',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white70),
                  ),
                ),
                // Next badge hint
                if (_nextLockedBadge(trips) != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Next: ${_nextLockedBadge(trips)!.emoji} ${_nextLockedBadge(trips)!.label}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Badges — horizontally scrollable
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _badges
                    .map((b) => _buildBadge(b, unlocked: trips >= b.minTrips))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            // Daily Quest
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Quest',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _todaysQuest,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '+50 XP',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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

  Widget _buildBadge(_Badge badge, {required bool unlocked}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: unlocked
                      ? Colors.white.withAlpha(28)
                      : Colors.white.withAlpha(8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: unlocked ? Colors.white38 : Colors.white12,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Opacity(
                    opacity: unlocked ? 1.0 : 0.3,
                    child: Text(
                      badge.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
              // Small lock overlay on bottom-right for locked badges
              if (!unlocked)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white24, width: 1),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 10,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            badge.label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              color: unlocked ? Colors.white70 : Colors.white30,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Grid ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildStatsData(
      List<BudgetModel> trips, String homeCurrency, int listsCount) {
    final now = DateTime.now();

    // Count trips that are done — past end date OR manually completed.
    // Does NOT require isActive==false: a trip stays active until the user
    // creates a new one, so we must check the date/completedAt independently.
    final completed = trips
        .where((t) => t.endDate.isBefore(now) || t.completedAt != null)
        .toList();

    final totalTrips = completed.length;

    final destinations =
        completed.map((t) => t.destination.trim().toLowerCase()).toSet().length;

    // Look up home currency entry (fallback to INR)
    final homeEntry = kAllCurrencies.firstWhere(
      (c) => c.code == homeCurrency,
      orElse: () => const CurrencyEntry(
          code: 'INR', name: 'Indian Rupee', symbol: '₹',
          flag: '🇮🇳', toInrRate: 1.0),
    );

    // Sum up savings across all completed trips that had a budget.
    // Clamp to 0 so over-budget trips contribute ₹0, not negative savings.
    final savedInHome = completed
        .where((t) => t.totalBudget > 0)
        .fold<double>(0, (sum, t) {
      final tripEntry = kAllCurrencies.firstWhere(
        (c) => c.code == t.currency,
        orElse: () => const CurrencyEntry(
            code: 'INR', name: 'Indian Rupee', symbol: '₹',
            flag: '🇮🇳', toInrRate: 1.0),
      );
      final savings     = (t.totalBudget - t.totalSpent).clamp(0.0, double.infinity);
      final savingsInInr = savings * tripEntry.toInrRate;
      return sum + (savingsInInr / homeEntry.toInrRate);
    });

    final sym = homeEntry.symbol;
    final nf  = homeEntry.code == 'INR'
        ? NumberFormat('#,##,##0', 'en_IN')
        : NumberFormat('#,##0');
    final savedStr = '$sym${nf.format(savedInHome.round())}';

    return [
      {
        'label': 'Trips Done',
        'value': '$totalTrips',
        'icon': 'flight',
        'color': 'primary',
      },
      {
        'label': 'Destinations',
        'value': '$destinations',
        'icon': 'flag',
        'color': 'success',
      },
      {
        'label': 'Total Saved',
        'value': savedStr,
        'icon': 'savings',
        'color': 'teal',
      },
      {
        'label': 'Lists',
        'value': '$listsCount',
        'icon': 'luggage',
        'color': 'purple',
      },
    ];
  }

  Widget _buildStatsGrid(BuildContext context, List<BudgetModel> trips, double w) {
    final homeCurrency =
        ref.watch(currentUserProvider).valueOrNull?.currency ?? 'INR';
    final listsAsync = ref.watch(packingListsProvider);
    final listsCount = listsAsync.valueOrNull?.length ?? 0;
    final stats = _buildStatsData(trips, homeCurrency, listsCount);
    // Target a fixed card height of ~130dp regardless of screen width.
    // This prevents the tall-card gap issue on large phones.
    final cardW = (w - 40 - 12) / 2; // 40 = 20px padding each side, 12 = spacing
    const targetH = 130.0;
    final ratio = cardW / targetH;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: ratio,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        final isTripsCard = stat['label'] == 'Trips Done';
        return ZoomIn(
          duration: const Duration(milliseconds: 400),
          delay: Duration(milliseconds: index * 80),
          child: _StatCard(
            stat: stat,
            onTap: isTripsCard
                ? () => context.push(AppRoutes.allTrips)
                : null,
          ),
        );
      },
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  static final List<_FeatureCard> _featureCards = [
    _FeatureCard(
      title: 'Budget Tracker',
      subtitle: 'Real-time expenses across currencies',
      icon: Icons.account_balance_wallet_rounded,
      bgIcon: Icons.savings_rounded,
      route: AppRoutes.budget,
      gradientColors: const [Color(0xFF0D47A1), Color(0xFF378ADD)],
      shadowColor: AppColors.primary,
    ),
    _FeatureCard(
      title: 'Smart Packing',
      subtitle: 'AI lists tailored to your weather',
      icon: Icons.luggage_rounded,
      bgIcon: Icons.wb_sunny_rounded,
      route: AppRoutes.packing,
      gradientColors: const [Color(0xFF0D3B0D), Color(0xFF1B6B2A), Color(0xFF639922)],
      shadowColor: AppColors.success,
    ),
    _FeatureCard(
      title: 'Hidden Gems',
      subtitle: 'Secret spots by real travellers',
      icon: Icons.diamond_rounded,
      bgIcon: Icons.explore_rounded,
      route: AppRoutes.gemsMap,
      gradientColors: const [Color(0xFF1A1275), Color(0xFF534AB7)],
      shadowColor: AppColors.purple,
    ),
  ];

  static int _tabForRoute(String route) {
    switch (route) {
      case AppRoutes.budget:
        return 1;
      case AppRoutes.packing:
        return 2;
      case AppRoutes.gemsMap:
        return 3;
      default:
        return 0;
    }
  }

  Widget _buildQuickActions(BuildContext context, double w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
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
              'Explore Features',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: w < 360 ? 16 : 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._featureCards.asMap().entries.map((entry) {
          return FadeInUp(
            duration: const Duration(milliseconds: 350),
            delay: Duration(milliseconds: entry.key * 80),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildFeatureCard(context, entry.value, w),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, _FeatureCard card, double w) {
    final pad = w < 360 ? 14.0 : 18.0;
    final iconSz = w < 360 ? 22.0 : 26.0;
    return GestureDetector(
      onTap: () =>
          ref.read(homeTabIndexProvider.notifier).state = _tabForRoute(card.route),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Gradient background ─────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: card.gradientColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: card.shadowColor.withAlpha(90),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Circular icon
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(22),
                      border: Border.all(
                          color: Colors.white.withAlpha(55), width: 1.5),
                    ),
                    child: Icon(card.icon, color: Colors.white, size: iconSz),
                  ),
                  SizedBox(width: w < 360 ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: w < 360 ? 15 : 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          card.subtitle,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: w < 360 ? 11 : 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withAlpha(60), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.north_east_rounded,
                            color: Colors.white, size: 11),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Decorative background icon — right side, vertically centred ─
            Positioned(
              right: -16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  card.bgIcon,
                  size: 90,
                  color: Colors.white.withAlpha(20),
                ),
              ),
            ),
            // ── Top-shine highlight ─────────────────────────────────────────
            Positioned(
              top: 0,
              left: 24,
              right: 24,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withAlpha(0),
                      Colors.white.withAlpha(70),
                      Colors.white.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── UP ARROW PAINTER ────────────────────────────────────────────────────────

class _UpArrowPainter extends CustomPainter {
  const _UpArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── STAT CARD ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat, this.onTap});
  final Map<String, dynamic> stat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _color(stat['color']);
    const pad = 14.0;
    const iconBox = 32.0;

    return LayoutBuilder(builder: (context, constraints) {
      final cw = constraints.maxWidth;
      final valueFz = (cw * 0.115).clamp(15.0, 22.0);
      final labelFz = (cw * 0.085).clamp(10.0, 13.0);

      final card = Container(
        padding: const EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap != null
                ? color.withAlpha(60)
                : AppColors.lightOutline,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: color.withAlpha(18),
                    borderRadius: BorderRadius.circular(iconBox * 0.28),
                  ),
                  child: Icon(_icon(stat['icon']), color: color, size: 18),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: color.withAlpha(180)),
              ],
            ),
            const Spacer(),
            Text(
              stat['value'],
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: valueFz,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stat['label'],
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: labelFz,
                fontWeight: FontWeight.w500,
                color: AppColors.lightOnSurfaceVar,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      );

      if (onTap == null) return card;
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: card,
        ),
      );
    });
  }

  Color _color(String c) {
    switch (c) {
      case 'primary': return AppColors.primary;
      case 'success': return AppColors.success;
      case 'teal':    return AppColors.teal;
      case 'purple':  return AppColors.purple;
      default:        return AppColors.primary;
    }
  }

  IconData _icon(String i) {
    switch (i) {
      case 'flight':  return Icons.flight_rounded;
      case 'flag':    return Icons.flag_rounded;
      case 'savings': return Icons.savings_rounded;
      case 'luggage': return Icons.luggage_rounded;
      default:        return Icons.star_rounded;
    }
  }
}

// ─── DATA CLASSES ─────────────────────────────────────────────────────────────

class _Badge {
  const _Badge({
    required this.emoji,
    required this.label,
    required this.minTrips,
  });
  final String emoji;
  final String label;
  final int minTrips;
}

class _FeatureCard {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgIcon,
    required this.route,
    required this.gradientColors,
    required this.shadowColor,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData bgIcon;
  final String route;
  final List<Color> gradientColors;
  final Color shadowColor;
}

// ─── PULSING DOT ─────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color.withAlpha((_anim.value * 255).round()),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withAlpha((_anim.value * 200).round()),
              blurRadius: 3 + 4 * _anim.value,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── NO TRIP CARD WITH FLYING PLANE ANIMATION ─────────────────────────────────

class _NoTripCard extends StatefulWidget {
  const _NoTripCard({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_NoTripCard> createState() => _NoTripCardState();
}

class _NoTripCardState extends State<_NoTripCard> {

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A56C4), AppColors.teal],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(70),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('✈️', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'No active trip',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              const Text(
                'Plan your first trip',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Set a destination, budget & dates —\nwe\'ll handle the rest.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Create Trip',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
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


// ── Waving hand emoji with spring-bounce wave animation ──────────────────────

class _WavingHand extends StatefulWidget {
  const _WavingHand({required this.fontSize});
  final double fontSize;

  @override
  State<_WavingHand> createState() => _WavingHandState();
}

class _WavingHandState extends State<_WavingHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _angle;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Waving sequence: tilt right → left → right → left → settle back to 0
    _angle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.45), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.45, end: -0.2), weight: 1.5),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.45), weight: 1.5),
      TweenSequenceItem(tween: Tween(begin: 0.45, end: -0.2), weight: 1.5),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // Short delay so the greeting fades in first, then the hand waves
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _angle,
      builder: (_, child) => Transform.rotate(
        angle: _angle.value,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: Text(
        '👋',
        style: TextStyle(fontSize: widget.fontSize + 1),
      ),
    );
  }
}

// ─── COUNTRY SETUP SHEET ─────────────────────────────────────────────────────
// Non-dismissible bottom sheet shown on home screen when homeCountry is empty.
// Forces the user to pick their country before using the app.
// ─────────────────────────────────────────────────────────────────────────────

const _countryCurrencyMap = {
  'Afghanistan': 'USD',   'Albania': 'EUR',        'Algeria': 'USD',
  'Argentina': 'USD',     'Armenia': 'USD',         'Australia': 'AUD',
  'Austria': 'EUR',       'Azerbaijan': 'USD',      'Bahrain': 'AED',
  'Bangladesh': 'USD',    'Belgium': 'EUR',         'Bhutan': 'INR',
  'Bolivia': 'USD',       'Brazil': 'BRL',          'Cambodia': 'THB',
  'Canada': 'CAD',        'Chile': 'USD',           'China': 'HKD',
  'Colombia': 'USD',      'Croatia': 'EUR',         'Czech Republic': 'EUR',
  'Denmark': 'NOK',       'Egypt': 'USD',           'Ethiopia': 'USD',
  'Finland': 'EUR',       'France': 'EUR',          'Georgia': 'USD',
  'Germany': 'EUR',       'Ghana': 'USD',           'Greece': 'EUR',
  'Hungary': 'EUR',       'Iceland': 'USD',         'India': 'INR',
  'Indonesia': 'IDR',     'Iran': 'USD',            'Iraq': 'USD',
  'Ireland': 'EUR',       'Israel': 'USD',          'Italy': 'EUR',
  'Japan': 'JPY',         'Jordan': 'AED',          'Kazakhstan': 'USD',
  'Kenya': 'USD',         'Kuwait': 'AED',          'Laos': 'THB',
  'Lebanon': 'USD',       'Malaysia': 'MYR',        'Maldives': 'USD',
  'Mexico': 'MXN',        'Mongolia': 'USD',        'Morocco': 'USD',
  'Myanmar': 'THB',       'Nepal': 'INR',           'Netherlands': 'EUR',
  'New Zealand': 'NZD',   'Nigeria': 'USD',         'Norway': 'NOK',
  'Oman': 'AED',          'Pakistan': 'USD',        'Peru': 'USD',
  'Philippines': 'PHP',   'Poland': 'EUR',          'Portugal': 'EUR',
  'Qatar': 'AED',         'Romania': 'EUR',         'Russia': 'USD',
  'Saudi Arabia': 'AED',  'Senegal': 'USD',         'Serbia': 'EUR',
  'Singapore': 'SGD',     'South Africa': 'ZAR',   'South Korea': 'KRW',
  'Spain': 'EUR',         'Sri Lanka': 'INR',       'Sweden': 'SEK',
  'Switzerland': 'CHF',   'Taiwan': 'USD',          'Tajikistan': 'USD',
  'Tanzania': 'USD',      'Thailand': 'THB',        'Turkey': 'TRY',
  'Turkmenistan': 'USD',  'Uganda': 'USD',          'Ukraine': 'USD',
  'United Arab Emirates': 'AED', 'United Kingdom': 'GBP', 'United States': 'USD',
  'Uzbekistan': 'USD',    'Vietnam': 'VND',         'Yemen': 'USD',
  'Zimbabwe': 'ZAR',
};

const _setupCountries = [
  'Afghanistan', 'Albania', 'Algeria', 'Argentina', 'Armenia', 'Australia',
  'Austria', 'Azerbaijan', 'Bahrain', 'Bangladesh', 'Belgium', 'Bhutan',
  'Bolivia', 'Brazil', 'Cambodia', 'Canada', 'Chile', 'China', 'Colombia',
  'Croatia', 'Czech Republic', 'Denmark', 'Egypt', 'Ethiopia', 'Finland',
  'France', 'Georgia', 'Germany', 'Ghana', 'Greece', 'Hungary', 'Iceland',
  'India', 'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy',
  'Japan', 'Jordan', 'Kazakhstan', 'Kenya', 'Kuwait', 'Laos', 'Lebanon',
  'Malaysia', 'Maldives', 'Mexico', 'Mongolia', 'Morocco', 'Myanmar',
  'Nepal', 'Netherlands', 'New Zealand', 'Nigeria', 'Norway', 'Oman',
  'Pakistan', 'Peru', 'Philippines', 'Poland', 'Portugal', 'Qatar',
  'Romania', 'Russia', 'Saudi Arabia', 'Senegal', 'Serbia', 'Singapore',
  'South Africa', 'South Korea', 'Spain', 'Sri Lanka', 'Sweden',
  'Switzerland', 'Taiwan', 'Tanzania', 'Thailand', 'Turkey', 'Uganda',
  'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States',
  'Uzbekistan', 'Vietnam', 'Yemen', 'Zimbabwe',
];

class _CountrySetupSheet extends ConsumerStatefulWidget {
  const _CountrySetupSheet();

  @override
  ConsumerState<_CountrySetupSheet> createState() => _CountrySetupSheetState();
}

class _CountrySetupSheetState extends ConsumerState<_CountrySetupSheet> {
  String? _selected;
  bool _saving = false;

  Future<void> _showPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SetupCountryPicker(),
    );
    if (result != null) setState(() => _selected = result);
  }

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _saving = true);
    try {
      final currency = _countryCurrencyMap[_selected!] ?? 'USD';
      await ref.read(authServiceProvider).updateProfile({
        'homeCountry': _selected!,
        'currency': currency,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).viewPadding.bottom;
    final isSelected = _selected != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          // Icon + heading
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag_outlined,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'One quick thing!',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      'Where are you from? We need this to personalise your experience.',
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
          const SizedBox(height: 20),
          // Country picker — tappable row that opens a searchable sheet
          GestureDetector(
            onTap: _showPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.lightOutline,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Text('🌍', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selected ?? 'Select your home country',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppColors.navy
                            : AppColors.lightOnSurfaceVar,
                      ),
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.lightOnSurfaceVar,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_selected == null || _saving) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withAlpha(80),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Confirm & Continue',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SEARCHABLE COUNTRY PICKER SHEET ─────────────────────────────────────────

class _SetupCountryPicker extends StatefulWidget {
  const _SetupCountryPicker();

  @override
  State<_SetupCountryPicker> createState() => _SetupCountryPickerState();
}

class _SetupCountryPickerState extends State<_SetupCountryPicker> {
  final _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = _setupCountries;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _setupCountries
          : _setupCountries.where((c) => c.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: (screenH * 0.75 - bottomPad).clamp(280.0, screenH * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('🌍', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Text(
                    'Select Home Country',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.lightOutline),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.navy,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search country…',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.lightOnSurfaceVar,
                    ),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.lightOnSurfaceVar, size: 20),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🔍', style: TextStyle(fontSize: 36)),
                          SizedBox(height: 10),
                          Text(
                            'No countries found',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: AppColors.lightOnSurfaceVar,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                          color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, i) {
                        final country = _filtered[i];
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(country),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Text(
                              country,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
    );
  }
}
