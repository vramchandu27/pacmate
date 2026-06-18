import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

// ─── ONBOARDING DATA ─────────────────────────────────────────────────────────

class _SlideData {
  const _SlideData({
    required this.bgColor,
    required this.accentColor,
    required this.lottieAsset,
    required this.fallbackIcon,
    required this.tag,
    required this.tagIcon,
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  final Color    bgColor;
  final Color    accentColor;
  final String   lottieAsset;
  final IconData fallbackIcon;
  final String   tag;
  final IconData tagIcon;
  final String   title;
  final String   subtitle;
  final List<String> chips;
}

const List<_SlideData> _slides = [
  _SlideData(
    bgColor:      Color(0xFF0A1628),
    accentColor:  AppColors.primary,
    lottieAsset:  AppLottie.onboarding1,
    fallbackIcon: Icons.map_outlined,
    tag:          'AI Route Planner',
    tagIcon:      Icons.auto_awesome_rounded,
    title:        'Plan your perfect\nadventure',
    subtitle:     'Gemini AI builds a day-by-day itinerary tailored to your budget, travel style, and the weather.',
    chips:        ['AI-powered routes', 'Day-by-day itinerary', 'Weather-aware'],
  ),
  _SlideData(
    bgColor:      Color(0xFF071A0E),
    accentColor:  AppColors.success,
    lottieAsset:  AppLottie.onboarding2,
    fallbackIcon: Icons.luggage_rounded,
    tag:          'Smart Packing',
    tagIcon:      Icons.checklist_rounded,
    title:        'Pack smart,\nnever miss a thing',
    subtitle:     'AI builds your packing list based on your destination, weather forecast, and trip length — so you\'re always prepared.',
    chips:        ['AI-generated lists', 'Weather-aware', 'Trip-specific'],
  ),
  _SlideData(
    bgColor:      Color(0xFF061618),
    accentColor:  AppColors.teal,
    lottieAsset:  AppLottie.onboarding3,
    fallbackIcon: Icons.account_balance_wallet_outlined,
    tag:          'Budget Tracker',
    tagIcon:      Icons.currency_rupee_rounded,
    title:        'Track every rupee,\nstay on budget',
    subtitle:     'Log expenses in any currency with real-time conversion. Visual breakdowns show exactly where your money goes.',
    chips:        ['Multi-currency', 'Expense categories', 'Real-time tracking'],
  ),
];

// ─── SCREEN ──────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {

  final PageController _pageCtrl = PageController();

  double _pageValue = 0.0;

  late final AnimationController _contentCtrl;
  late final Animation<double>    _contentFade;
  late final Animation<Offset>    _contentSlide;

  @override
  void initState() {
    super.initState();

    _contentCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _contentFade = CurvedAnimation(
      parent: _contentCtrl,
      curve:  Curves.easeOut,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));

    _pageCtrl.addListener(() {
      setState(() => _pageValue = _pageCtrl.page ?? 0.0);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int get _currentPage => _pageValue.round().clamp(0, _slides.length - 1);
  bool get _isLastPage  => _currentPage == _slides.length - 1;

  Color get _bgColor {
    final lo = _pageValue.floor().clamp(0, _slides.length - 1);
    final hi = _pageValue.ceil().clamp(0, _slides.length - 1);
    final t  = _pageValue - lo;
    return Color.lerp(_slides[lo].bgColor, _slides[hi].bgColor, t)!;
  }

  Color get _accentColor {
    final lo = _pageValue.floor().clamp(0, _slides.length - 1);
    final hi = _pageValue.ceil().clamp(0, _slides.length - 1);
    final t  = _pageValue - lo;
    return Color.lerp(_slides[lo].accentColor, _slides[hi].accentColor, t)!;
  }

  void _onNext() {
    if (_isLastPage) {
      _finish();
    } else {
      _contentCtrl.reset();
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve:    Curves.easeInOutCubic,
      );
      _contentCtrl.forward();
    }
  }

  void _onSkip() => _finish();

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go(AppRoutes.login);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final h = size.height;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      color: _bgColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: PageView.builder(
                  controller:   _pageCtrl,
                  itemCount:    _slides.length,
                  onPageChanged: (i) {
                    _contentCtrl.reset();
                    _contentCtrl.forward();
                  },
                  itemBuilder: (context, i) => _buildSlide(_slides[i], h),
                ),
              ),
              _buildBottomBar(h),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width:  30,
                height: 30,
                decoration: BoxDecoration(
                  color:        _accentColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: _accentColor.withAlpha(80)),
                ),
                child: Icon(Icons.backpack_rounded, color: _accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.appName,
                style: const TextStyle(
                  fontFamily:  'Poppins',
                  fontSize:    16,
                  fontWeight:  FontWeight.w700,
                  color:       Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (!_isLastPage)
            TextButton(
              onPressed: _onSkip,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              child: const Text(
                AppStrings.skip,
                style: TextStyle(
                  fontFamily:  'Poppins',
                  fontSize:    13,
                  fontWeight:  FontWeight.w500,
                ),
              ),
            )
          else
            const SizedBox(width: 60),
        ],
      ),
    );
  }

  // ── Slide ─────────────────────────────────────────────────────────────────

  Widget _buildSlide(_SlideData slide, double h) {
    final isSmall = h < 700;
    final isTiny  = h < 600;

    return FadeTransition(
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: isTiny ? 60.0 : 80.0,
                    maxHeight: 220.0,
                  ),
                  child: Lottie.asset(
                    slide.lottieAsset,
                    fit: BoxFit.contain,
                    repeat: true,
                    errorBuilder: (_, e, s) =>
                        _buildFallbackLottie(slide, isTiny ? 60.0 : 80.0),
                  ),
                ),
              ),
              SizedBox(height: isTiny ? 8 : isSmall ? 14 : 24),
              _buildTagPill(slide),
              SizedBox(height: isTiny ? 4 : isSmall ? 6 : 10),
              _buildTitle(slide, h),
              SizedBox(height: isTiny ? 4 : 8),
              _buildSubtitle(slide, h),
              SizedBox(height: isTiny ? 8 : isSmall ? 12 : 16),
              _buildChips(slide),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLottie(_SlideData slide, double lottieH) {
    final boxSize  = lottieH.clamp(80.0, 150.0);
    final iconSize = (boxSize * 0.45).clamp(36.0, 70.0);
    final radius   = (boxSize * 0.26).clamp(20.0, 38.0);
    return Center(
      child: Container(
        width:  boxSize,
        height: boxSize,
        decoration: BoxDecoration(
          color:        slide.accentColor.withAlpha(25),
          borderRadius: BorderRadius.circular(radius),
          border:       Border.all(color: slide.accentColor.withAlpha(60), width: 1.5),
        ),
        child: Icon(slide.fallbackIcon, size: iconSize, color: slide.accentColor),
      ),
    );
  }

  Widget _buildTagPill(_SlideData slide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color:        slide.accentColor.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: slide.accentColor.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(slide.tagIcon, color: slide.accentColor, size: 13),
          const SizedBox(width: 6),
          Text(
            slide.tag,
            style: TextStyle(
              fontFamily:  'Poppins',
              fontSize:    12,
              fontWeight:  FontWeight.w600,
              color:       slide.accentColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(_SlideData slide, double h) {
    final fz = h < 700 ? 24.0 : h < 780 ? 26.0 : 28.0;
    return Text(
      slide.title,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily:    'Poppins',
        fontSize:      fz,
        fontWeight:    FontWeight.w700,
        color:         Colors.white,
        height:        1.25,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildSubtitle(_SlideData slide, double h) {
    final fz = h < 700 ? 12.5 : 14.0;
    return Text(
      slide.subtitle,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily:  'Poppins',
        fontSize:    fz,
        fontWeight:  FontWeight.w400,
        color:       Colors.white60,
        height:      1.55,
      ),
    );
  }

  Widget _buildChips(_SlideData slide) {
    return Wrap(
      alignment:  WrapAlignment.center,
      spacing:    8,
      runSpacing: 8,
      children: slide.chips.map((chip) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: Colors.white24, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5, height: 5,
                decoration: BoxDecoration(
                  color:  slide.accentColor,
                  shape:  BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                chip,
                style: const TextStyle(
                  fontFamily:  'Poppins',
                  fontSize:    12,
                  fontWeight:  FontWeight.w500,
                  color:       Colors.white70,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(double h) {
    final vPad      = (h * 0.022).clamp(12.0, 22.0);
    final dotGap    = (h * 0.025).clamp(14.0, 26.0);
    final btnHeight = h < 700 ? 46.0 : 52.0;
    final afterBtn  = (h * 0.018).clamp(10.0, 20.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(28, vPad, 28, vPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SmoothPageIndicator(
            controller: _pageCtrl,
            count:      _slides.length,
            effect: ExpandingDotsEffect(
              dotHeight:      6,
              dotWidth:       6,
              expansionFactor: 4,
              spacing:        6,
              activeDotColor: _accentColor,
              dotColor:       Colors.white24,
            ),
          ),
          SizedBox(height: dotGap),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve:    Curves.easeInOut,
            width:    double.infinity,
            height:   btnHeight,
            child: ElevatedButton(
              onPressed: _onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor:    _accentColor,
                foregroundColor:    Colors.white,
                elevation:          0,
                shadowColor:        Colors.transparent,
                shape:              RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily:  'Poppins',
                  fontSize:    16,
                  fontWeight:  FontWeight.w600,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isLastPage ? AppStrings.getStarted : AppStrings.next),
                  const SizedBox(width: 8),
                  Icon(
                    _isLastPage
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: afterBtn),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                AppStrings.alreadyHaveAccount,
                style: TextStyle(
                  fontFamily:  'Poppins',
                  fontSize:    13,
                  fontWeight:  FontWeight.w400,
                  color:       Colors.white38,
                ),
              ),
              GestureDetector(
                onTap: () => context.go(AppRoutes.login),
                child: Text(
                  AppStrings.loginLink,
                  style: TextStyle(
                    fontFamily:  'Poppins',
                    fontSize:    13,
                    fontWeight:  FontWeight.w600,
                    color:       _accentColor,
                    decoration: TextDecoration.underline,
                    decorationColor: _accentColor.withAlpha(120),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
