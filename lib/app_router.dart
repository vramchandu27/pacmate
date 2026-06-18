import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'features/auth/screens/profile_setup_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/verify_email_screen.dart';
import 'features/budget/screens/add_expense_screen.dart';
import 'features/budget/screens/all_trips_screen.dart';
import 'shared/models/budget_model.dart';
import 'features/budget/screens/budget_report_screen.dart';
import 'features/budget/screens/budget_screen.dart';
import 'features/budget/screens/create_trip_screen.dart';
import 'features/hidden_gems/screens/add_gem_screen.dart';
import 'features/route_planner/models/route_model.dart';
import 'features/route_planner/screens/route_planner_screen.dart';
import 'features/route_planner/screens/route_result_screen.dart';
import 'features/hidden_gems/screens/gem_detail_screen.dart';
import 'features/hidden_gems/screens/gems_map_screen.dart';
import 'features/hidden_gems/screens/new_gems_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/auth/screens/session_expired_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/packing/screens/packing_list_screen.dart';
import 'features/packing/screens/packing_screen.dart';

// ─── AUTH CHANGE NOTIFIER ────────────────────────────────────────────────────
// Bridges Firebase auth state changes to GoRouter's refreshListenable so the
// router re-evaluates redirects whenever the user signs in or out.

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// Routes that do not require authentication.
const _publicRoutes = {
  AppRoutes.splash,
  AppRoutes.onboarding,
  AppRoutes.login,
  AppRoutes.signup,
  AppRoutes.forgotPassword,
  AppRoutes.sessionExpired,
};

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier();
  ref.onDispose(notifier.dispose);
  return GoRouter(
    refreshListenable: notifier,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final user   = FirebaseAuth.instance.currentUser;
      final isAuthed = user != null;
      final loc    = state.matchedLocation;

      // Unauthenticated → login
      if (!isAuthed && !_publicRoutes.contains(loc)) return AppRoutes.login;

      // Email/password user whose email isn't verified yet → verify screen.
      // Google users are always verified by Google, so skip them.
      if (isAuthed && user.emailVerified == false) {
        final isEmailUser =
            user.providerData.any((p) => p.providerId == 'password');
        if (isEmailUser &&
            loc != AppRoutes.verifyEmail &&
            !_publicRoutes.contains(loc)) {
          return AppRoutes.verifyEmail;
        }
      }

      return null;
    },
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
    routes: [
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      pageBuilder: (context, state) =>
          _fadeRoute(state: state, child: const SplashScreen()),
    ),

    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      pageBuilder: (context, state) =>
          _fadeRoute(state: state, child: const OnboardingScreen()),
    ),

    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const LoginScreen()),
    ),
    GoRoute(
      path: AppRoutes.signup,
      name: 'signup',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const SignupScreen()),
    ),
    GoRoute(
      path: AppRoutes.verifyEmail,
      name: 'verifyEmail',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const VerifyEmailScreen()),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      name: 'forgotPassword',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const ForgotPasswordScreen()),
    ),
    GoRoute(
      path: AppRoutes.profileSetup,
      name: 'profileSetup',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const ProfileSetupScreen()),
    ),

    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      pageBuilder: (context, state) =>
          _fadeRoute(state: state, child: const HomeScreen()),
    ),

    // ── Budget ───────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.budget,
      name: 'budget',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const BudgetScreen()),
      routes: [
        GoRoute(
          path: 'create-trip',
          name: 'createTrip',
          pageBuilder: (context, state) =>
              _slideRoute(state: state, child: const CreateTripScreen()),
        ),
        GoRoute(
          path: 'add-expense',
          name: 'addExpense',
          pageBuilder: (context, state) {
            final trip = state.extra as BudgetModel?;
            return _modalRoute(state: state, child: AddExpenseScreen(trip: trip));
          },
        ),
        GoRoute(
          path: 'report',
          name: 'budgetReport',
          pageBuilder: (context, state) =>
              _slideRoute(state: state, child: const BudgetReportScreen()),
        ),
        GoRoute(
          path: 'all-trips',
          name: 'allTrips',
          pageBuilder: (context, state) =>
              _slideRoute(state: state, child: const AllTripsScreen()),
        ),
      ],
    ),

    // ── Packing ──────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.packing,
      name: 'packing',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const PackingScreen()),
      routes: [
        GoRoute(
          path: 'list/:listId',
          name: 'packingList',
          pageBuilder: (context, state) {
            final listId = state.pathParameters['listId'] ?? '';
            return _slideRoute(
              state: state,
              child: PackingListScreen(listId: listId),
            );
          },
        ),
      ],
    ),

    // ── Hidden Gems ──────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.gemsMap,
      name: 'gemsMap',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const GemsMapScreen()),
      routes: [
        GoRoute(
          path: 'new',
          name: 'newGems',
          pageBuilder: (context, state) {
            final ids  = (state.uri.queryParameters['ids'] ?? '')
                .split(',')
                .where((s) => s.isNotEmpty)
                .toList();
            final city = Uri.decodeComponent(
                state.uri.queryParameters['city'] ?? '');
            return _slideRoute(
              state: state,
              child: NewGemsScreen(gemIds: ids, city: city),
            );
          },
        ),
        GoRoute(
          path: 'add',
          name: 'addGem',
          pageBuilder: (context, state) {
            final lat = double.tryParse(
                state.uri.queryParameters['lat'] ?? '');
            final lng = double.tryParse(
                state.uri.queryParameters['lng'] ?? '');
            return _modalRoute(
              state: state,
              child: AddGemScreen(lat: lat, lng: lng),
            );
          },
        ),
        GoRoute(
          path: ':gemId',
          name: 'gemDetail',
          pageBuilder: (context, state) {
            final gemId = state.pathParameters['gemId'] ?? '';
            return _slideRoute(
              state: state,
              child: GemDetailScreen(gemId: gemId),
            );
          },
        ),
      ],
    ),

    // ── Route Planner ────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.routePlanner,
      name: 'routePlanner',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const RoutePlannerScreen()),
    ),
    GoRoute(
      path: AppRoutes.routeResult,
      name: 'routeResult',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final days  = (extra['days'] as List).cast<RouteDayModel>();
        return _slideRoute(
          state: state,
          child: RouteResultScreen(
            days:           days,
            startCity:      extra['startCity'] as String,
            endCity:        extra['endCity'] as String,
            durationDays:   extra['durationDays'] as int,
            dailyBudgetINR: extra['dailyBudgetINR'] as int,
          ),
        );
      },
    ),

    // ── Profile & Settings ───────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.profile,
      name: 'profile',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const ProfileScreen()),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      pageBuilder: (context, state) => _slideRoute(
        state: state,
        child: const _ScreenPlaceholder(
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      name: 'notifications',
      pageBuilder: (context, state) =>
          _slideRoute(state: state, child: const NotificationsScreen()),
    ),
    GoRoute(
      path: AppRoutes.sessionExpired,
      name: 'sessionExpired',
      pageBuilder: (context, state) =>
          _fadeRoute(state: state, child: const SessionExpiredScreen()),
    ),
  ],
  );
});

// ─── PAGE TRANSITION HELPERS ─────────────────────────────────────────────────

CustomTransitionPage<void> _fadeRoute({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.pageTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

CustomTransitionPage<void> _slideRoute({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.pageTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

CustomTransitionPage<void> _modalRoute({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.pageTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

// ─── SCREEN PLACEHOLDER ───────────────────────────────────────────────────────

class _ScreenPlaceholder extends StatelessWidget {
  const _ScreenPlaceholder({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.primary.withAlpha(180)),
            const SizedBox(height: 20),
            Text(label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.lightOnSurfaceVar,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SPLASH PLACEHOLDER ───────────────────────────────────────────────────────

class SplashPlaceholder extends StatefulWidget {
  const SplashPlaceholder({super.key});

  @override
  State<SplashPlaceholder> createState() => _SplashPlaceholderState();
}

class _SplashPlaceholderState extends State<SplashPlaceholder> {
  @override
  void initState() {
    super.initState();
    Future.delayed(AppDurations.splashMin, () {
      if (mounted) context.go(AppRoutes.onboarding);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.backpack_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.appTagline,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: 64),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ERROR SCREEN ─────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({this.error});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 64, color: AppColors.danger),
              const SizedBox(height: 24),
              Text(
                'Page not found',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                error?.toString() ?? 'The route you requested does not exist.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.splash),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
