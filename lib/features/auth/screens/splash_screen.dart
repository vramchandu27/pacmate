import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Progress bar — 0 → 1 over 3 seconds
  late final AnimationController _progressCtrl;
  late final Animation<double>    _progressAnim;

  // Staggered entrance animations
  late final AnimationController _entranceCtrl;
  late final Animation<double>    _logoFade;
  late final Animation<Offset>    _logoSlide;
  late final Animation<double>    _textFade;
  late final Animation<Offset>    _textSlide;
  late final Animation<double>    _pillsFade;
  late final Animation<Offset>    _pillsSlide;

  // Bag floating + rotation animations
  late final AnimationController _floatCtrl;
  late final Animation<double>    _floatAnim;
  late final AnimationController _rotateCtrl;
  late final Animation<double>    _rotateAnim;
  late final AnimationController _glowCtrl;
  late final Animation<double>    _glowAnim;

  bool _lottieError = false;

  static const Duration _splashDuration = Duration(seconds: 3);
  static const Duration _entranceDuration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _setupProgressAnimation();
    _setupEntranceAnimations();
    _setupBagAnimations();
    _scheduleNavigation();
  }

  void _setupProgressAnimation() {
    _progressCtrl = AnimationController(
      vsync:    this,
      duration: _splashDuration,
    );
    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve:  Curves.easeInOut,
    );
    _progressCtrl.forward();
  }

  void _setupEntranceAnimations() {
    _entranceCtrl = AnimationController(
      vsync:    this,
      duration: _entranceDuration,
    );

    // Logo: fades + slides up — starts immediately
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve:  const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end:   Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve:  const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );

    // Text: staggered after logo
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve:  const Interval(0.3, 0.75, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end:   Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve:  const Interval(0.3, 0.75, curve: Curves.easeOut),
      ),
    );

    // Pills: last to appear
    _pillsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve:  const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );
    _pillsSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end:   Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve:  const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceCtrl.forward();
  }

  void _setupBagAnimations() {
    // Gentle float up/down
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // Subtle rotation wobble
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
    _rotateAnim = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _rotateCtrl, curve: Curves.easeInOut),
    );

    // Glow pulse
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _scheduleNavigation() async {
    // Load all async data before touching context
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('onboarding_done') ?? false;

    await Future.delayed(_splashDuration);

    final user = FirebaseAuth.instance.currentUser;
    String destination;

    if (user != null) {
      // Only reload to catch truly deleted/disabled accounts.
      // Network errors and App Check timeouts are NOT sign-out reasons —
      // Firebase Auth persists the session locally and refreshes tokens lazily.
      try {
        await user.reload().timeout(const Duration(seconds: 5));
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'user-disabled') {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          context.go(seenOnboarding ? AppRoutes.login : AppRoutes.onboarding);
          return;
        }
        // Any other FirebaseAuthException (network, App Check) → stay logged in
      } catch (_) {
        // Timeout / network error → stay logged in
      }
      destination = AppRoutes.home;
    } else {
      destination = seenOnboarding ? AppRoutes.login : AppRoutes.onboarding;
    }

    if (!mounted) return;
    context.go(destination);
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _entranceCtrl.dispose();
    _floatCtrl.dispose();
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLottie(),
                  const SizedBox(height: 28),
                  _buildTitle(),
                  const SizedBox(height: 10),
                  _buildTagline(),
                  const SizedBox(height: 40),
                  _buildFeaturePills(),
                ],
              ),
            ),
            _buildProgressBar(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── Lottie / Fallback ──────────────────────────────────────────────────────

  Widget _buildLottie() {
    return FadeTransition(
      opacity: _logoFade,
      child: SlideTransition(
        position: _logoSlide,
        child: SizedBox(
          width:  200,
          height: 200,
          child: _lottieError ? _buildFallbackIcon() : _buildLottieWidget(),
        ),
      ),
    );
  }

  Widget _buildLottieWidget() {
    return Lottie.asset(
      AppLottie.splash,
      fit:    BoxFit.contain,
      repeat: true,
      errorBuilder: (context, error, stackTrace) {
        // Schedule state update outside of build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _lottieError = true);
        });
        return _buildFallbackIcon();
      },
    );
  }

  Widget _buildFallbackIcon() {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatCtrl, _rotateCtrl, _glowCtrl]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: Transform.rotate(
            angle: _rotateAnim.value,
            child: Container(
              width:  160,
              height: 160,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.teal],
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.primary.withAlpha((80 * _glowAnim.value).round()),
                    blurRadius: 32 + 16 * _glowAnim.value,
                    spreadRadius: 4 + 4 * _glowAnim.value,
                    offset:     const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Transform.scale(
                  scale: 0.95 + 0.1 * _glowAnim.value,
                  child: const Text(
                    '🎒',
                    style: TextStyle(fontSize: 72),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Title ──────────────────────────────────────────────────────────────────

  Widget _buildTitle() {
    return FadeTransition(
      opacity: _textFade,
      child: SlideTransition(
        position: _textSlide,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin:  Alignment.centerLeft,
            end:    Alignment.centerRight,
            colors: [
              AppColors.primary,
              Color(0xFF60B8FF),   // lighter blue midpoint
              AppColors.teal,
            ],
            stops: [0.0, 0.5, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text(
            AppStrings.appName,
            style: TextStyle(
              fontFamily:    'Poppins',
              fontSize:      48,
              fontWeight:    FontWeight.w700,
              letterSpacing: 1.5,
              color:         Colors.white, // overridden by ShaderMask
            ),
          ),
        ),
      ),
    );
  }

  // ── Tagline ────────────────────────────────────────────────────────────────

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _textFade,
      child: SlideTransition(
        position: _textSlide,
        child: const Text(
          AppStrings.appTagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily:    'Poppins',
            fontSize:      15,
            fontWeight:    FontWeight.w400,
            color:         Colors.white70,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ── Feature Pills ──────────────────────────────────────────────────────────

  static const List<_FeaturePill> _pills = [
    _FeaturePill(label: 'Plan',       icon: Icons.map_outlined,                 color: AppColors.primary),
    _FeaturePill(label: 'Budget',     icon: Icons.account_balance_wallet_outlined, color: AppColors.success),
    _FeaturePill(label: 'Stay Safe',  icon: Icons.shield_outlined,              color: AppColors.danger),
    _FeaturePill(label: 'Discover',   icon: Icons.diamond_outlined,             color: AppColors.teal),
  ];

  Widget _buildFeaturePills() {
    return FadeTransition(
      opacity: _pillsFade,
      child: SlideTransition(
        position: _pillsSlide,
        child: Wrap(
          alignment:  WrapAlignment.center,
          spacing:    10,
          runSpacing: 10,
          children: _pills.map(_buildPill).toList(),
        ),
      ),
    );
  }

  Widget _buildPill(_FeaturePill pill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color:        Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(24),
        border:       Border.all(color: Colors.white.withAlpha(45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pill.icon, color: Colors.white70, size: 15),
          const SizedBox(width: 7),
          Text(
            pill.label,
            style: const TextStyle(
              fontFamily:    'Poppins',
              fontSize:      12,
              fontWeight:    FontWeight.w500,
              color:         Colors.white70,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress Bar ──────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value:           _progressAnim.value,
                  minHeight:       3,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.lerp(AppColors.primary, AppColors.teal, _progressAnim.value)!,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Loading…',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize:   11,
              fontWeight: FontWeight.w400,
              color:      Colors.white30,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DATA CLASS ───────────────────────────────────────────────────────────────

class _FeaturePill {
  const _FeaturePill({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String   label;
  final IconData icon;
  final Color    color;
}
