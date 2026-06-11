import 'dart:math' as math;

import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/theme/app_theme.dart';

// ─── LOGIN SCREEN ─────────────────────────────────────────────────────────────
// Gamified dark-theme login with floating destination chips & traveler stats.
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus   = FocusNode();
  final _passwordFocus= FocusNode();

  bool _obscurePassword  = true;
  bool _isEmailLoading   = false;
  bool _isGoogleLoading  = false;

  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  // Float animation for destination chips
  late final AnimationController _floatCtrl;
  late final Animation<double>   _floatAnim;

  // Glow pulse on the backpack icon
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  // Auto-scroll for destination chips
  final _chipScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScrollChips());
  }

  Future<void> _autoScrollChips() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted || !_chipScrollCtrl.hasClients) return;
    final max = _chipScrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    // Scroll to the end at a constant 40 px/s — with 50× repeated items
    // this takes many minutes, so the user will never see a jump back.
    await _chipScrollCtrl.animateTo(
      max,
      duration: Duration(milliseconds: (max / 40 * 1000).round()),
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    _chipScrollCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return AppStrings.fieldRequired;
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim())) {
      return AppStrings.emailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
    if (v.length < 8) return AppStrings.passwordTooShort;
    return null;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _onLogin() async {
    FocusScope.of(context).unfocus();

    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      final secs = _lockedUntil!.difference(DateTime.now()).inSeconds + 1;
      _showError('Too many failed attempts. Try again in ${secs}s.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isEmailLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithEmail(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
      _failedAttempts = 0;
      _lockedUntil = null;
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-not-verified') {
        _showVerificationError();
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          final backoffSecs = math.min(600, 30 * (1 << (_failedAttempts - 5)));
          _lockedUntil = DateTime.now().add(Duration(seconds: backoffSecs));
        }
        _showError(_authErrorMessage(e.code));
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  void _showVerificationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Please verify your email first. Check your inbox.',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Resend',
          textColor: Colors.white,
          onPressed: () async {
            try {
              final sent = await ref.read(authServiceProvider).resendVerificationEmail(
                email: _emailCtrl.text.trim(),
                password: _passwordCtrl.text,
              );
              if (sent && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Verification email sent!',
                        style: TextStyle(fontFamily: 'Poppins')),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            } catch (_) {}
          },
        ),
      ),
    );
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;
      if (result != null) {
        final isNew = result.additionalUserInfo?.isNewUser ?? false;
        context.go(isNew ? AppRoutes.profileSetup : AppRoutes.home);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_authErrorMessage(e.code));
    } catch (e) {
      if (!mounted) return;
      // Show the actual error in debug so we can diagnose
      debugPrint('Google sign-in error: $e');
      _showError('Google sign-in failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Use "Forgot Password?" to reset.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'email-not-verified':
        return 'Please verify your email address before signing in.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Column(
        children: [
          _buildHero(),
          Expanded(child: _buildFormCard()),
        ],
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1A2E50), Color(0xFF0F172A)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + logo row
              Row(
                children: [
                  GestureDetector(
                    onTap: () { if (context.canPop()) context.pop(); },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (context, child) => Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.teal],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withAlpha((60 * _glowAnim.value).round()),
                            blurRadius: 12 * _glowAnim.value,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.backpack_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.teal],
                    ).createShader(b),
                    blendMode: BlendMode.srcIn,
                    child: const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Floating destination chips
              _buildDestinationChips(),

              const SizedBox(height: 16),

              // Main heading
              FadeInLeft(
                duration: const Duration(milliseconds: 500),
                child: const Text(
                  'Welcome Back,\nAdventurer! 🎒',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              FadeInLeft(
                delay: const Duration(milliseconds: 150),
                duration: const Duration(milliseconds: 500),
                child: const Text(
                  'Sign in to continue your journey',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Traveler stats row
              FadeInUp(
                delay: const Duration(milliseconds: 250),
                duration: const Duration(milliseconds: 500),
                child: _buildStatsRow(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationChips() {
    const baseDestinations = [
      ('🗼', 'Paris'),      ('🌴', 'Bali'),       ('🗻', 'Tokyo'),
      ('🏔️', 'Nepal'),     ('🏝️', 'Maldives'),  ('🗽', 'New York'),
      ('🌉', 'London'),    ('🌁', 'Singapore'),  ('🏯', 'Kyoto'),
      ('🌅', 'Santorini'), ('🌊', 'Phuket'),     ('🦁', 'Kenya'),
    ];
    // 50× repeat so the list is effectively endless — no jump-back ever needed.
    final destinations = List.generate(
      baseDestinations.length * 50,
      (i) => baseDestinations[i % baseDestinations.length],
    );

    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (ctx, anim) {
        return SizedBox(
          height: 52, // extra room so ±4px float never clips top/bottom
          child: ListView.separated(
            controller: _chipScrollCtrl,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: destinations.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final offset = math.sin(
                (_floatAnim.value / 6.0) * math.pi + i * 1.2,
              ) * 4.0;
              return Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withAlpha(25), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(destinations[i].$1,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        destinations[i].$2,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStat('50K+', 'Explorers'),
        _buildStatDivider(),
        _buildStat('200+', 'Countries'),
        _buildStatDivider(),
        _buildStat('1.2M+', 'Trips'),
      ],
    );
  }

  Widget _buildStat(String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1, height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white,
    );
  }

  // ── Form Card ──────────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(28)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightOutline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: _buildEmailField(),
                ),
                const SizedBox(height: 16),

                FadeInUp(
                  delay: const Duration(milliseconds: 80),
                  duration: const Duration(milliseconds: 400),
                  child: _buildPasswordField(),
                ),
                const SizedBox(height: 8),

                FadeInUp(
                  delay: const Duration(milliseconds: 140),
                  duration: const Duration(milliseconds: 400),
                  child: _buildForgotPassword(),
                ),
                const SizedBox(height: 24),

                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 400),
                  child: _buildLoginButton(),
                ),
                const SizedBox(height: 20),

                FadeInUp(
                  delay: const Duration(milliseconds: 260),
                  duration: const Duration(milliseconds: 400),
                  child: _buildOrDivider(),
                ),
                const SizedBox(height: 20),

                FadeInUp(
                  delay: const Duration(milliseconds: 320),
                  duration: const Duration(milliseconds: 400),
                  child: _buildGoogleButton(),
                ),
                const SizedBox(height: 24),

                FadeInUp(
                  delay: const Duration(milliseconds: 380),
                  duration: const Duration(milliseconds: 400),
                  child: _buildSignupLink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Fields ─────────────────────────────────────────────────────────────────

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Email Address'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: _validateEmail,
          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.lightOnSurface,
          ),
          decoration: _inputDecoration(
            hint: 'you@example.com',
            prefixIcon: Icons.alternate_email_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordCtrl,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          validator: _validatePassword,
          onFieldSubmitted: (_) => _onLogin(),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.lightOnSurface,
          ),
          decoration: _inputDecoration(
            hint: 'Min. 8 characters',
            prefixIcon: Icons.lock_outline_rounded,
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.lightOnSurfaceVar,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.forgotPassword),
        child: const Text(
          AppStrings.forgotPassword,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  // ── Buttons ────────────────────────────────────────────────────────────────

  Widget _buildLoginButton() {
    final anyLoading = _isEmailLoading || _isGoogleLoading;
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _isEmailLoading
              ? null
              : const LinearGradient(
            colors: [AppColors.primary, Color(0xFF2563EB)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          color: _isEmailLoading ? AppColors.primary.withAlpha(120) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isEmailLoading
              ? null
              : [
            BoxShadow(
              color: AppColors.primary.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: anyLoading ? null : _onLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isEmailLoading
              ? const SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor:
              AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rocket_launch_rounded, size: 18),
              SizedBox(width: 8),
              Text(
                'Start Adventure',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(
            child: Divider(color: AppColors.lightOutlineVar, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            AppStrings.orDivider,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.lightOnSurfaceVar,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(
            child: Divider(color: AppColors.lightOutlineVar, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    final anyLoading = _isEmailLoading || _isGoogleLoading;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: anyLoading ? null : _onGoogleSignIn,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightOnSurface,
          side: const BorderSide(color: AppColors.lightOutline, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/720255.png',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    AppStrings.continueWithGoogle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.lightOnSurface,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSignupLink() {
    return GestureDetector(
      onTap: () => context.go(AppRoutes.signup),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              AppStrings.dontHaveAccount,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.lightOnSurfaceVar,
              ),
            ),
            const Text(
              AppStrings.signupLink,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.lightOnSurface,
        letterSpacing: 0.2,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.lightOnSurfaceVar,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Icon(prefixIcon,
            color: AppColors.lightOnSurfaceVar, size: 20),
      ),
      prefixIconConstraints:
      const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix != null
          ? Padding(
          padding: const EdgeInsets.only(right: 14), child: suffix)
          : null,
      suffixIconConstraints:
      const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
        const BorderSide(color: AppColors.lightOutline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
        const BorderSide(color: AppColors.lightOutline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
        const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
        const BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
        const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      errorStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.danger,
      ),
    );
  }
}
