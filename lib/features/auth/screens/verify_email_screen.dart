import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

// ─── VERIFY EMAIL SCREEN ──────────────────────────────────────────────────────
// Shown after email/password signup. User must click the verification link
// sent to their inbox before they can proceed to profile setup.
// ─────────────────────────────────────────────────────────────────────────────

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  Timer?  _pollTimer;
  bool    _resending    = false;
  bool    _checking     = false;
  int     _resendCooldown = 0;
  Timer?  _cooldownTimer;

  late final AnimationController _iconCtrl;
  late final Animation<double>   _iconAnim;

  String get _email =>
      FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _iconAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.easeInOut),
    );

    // Auto-poll every 4 seconds to detect when user verifies in their email app
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _autoCheck());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    _iconCtrl.dispose();
    super.dispose();
  }

  // Silently check in the background — navigates automatically if verified
  Future<void> _autoCheck() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    if (!mounted) return;
    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      _pollTimer?.cancel();
      context.go(AppRoutes.profileSetup);
    }
  }

  // Manual "I've verified" button
  Future<void> _onContinue() async {
    setState(() => _checking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        context.go(AppRoutes.profileSetup);
      } else {
        _showSnack(
          'Email not verified yet. Please click the link in your inbox.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _onResend() async {
    if (_resending || _resendCooldown > 0) return;
    setState(() => _resending = true);
    try {
      // User is already signed in — send verification directly
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      _showSnack('Verification link resent! Check your inbox.');
      _startCooldown(60);
    } catch (_) {
      if (mounted) _showSnack('Could not resend. Try again shortly.', isError: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown(int seconds) {
    setState(() => _resendCooldown = seconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _onWrongEmail() async {
    // Delete the unverified account so they can start fresh
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {}
    if (!mounted) return;
    context.go(AppRoutes.signup);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildIcon(),
              const SizedBox(height: 32),
              _buildTitle(),
              const SizedBox(height: 12),
              _buildSubtitle(),
              const SizedBox(height: 8),
              _buildEmail(),
              const SizedBox(height: 40),
              _buildContinueButton(),
              const SizedBox(height: 16),
              _buildResendRow(),
              const SizedBox(height: 32),
              _buildWrongEmailLink(),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return AnimatedBuilder(
      animation: _iconAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _iconAnim.value),
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_unread_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Check your inbox',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.navy,
      ),
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'We sent a verification link to',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: AppColors.lightOnSurfaceVar,
      ),
    );
  }

  Widget _buildEmail() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.email_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            _email,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _checking ? null : _onContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _checking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                "I've verified my email",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildResendRow() {
    final canResend = !_resending && _resendCooldown == 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't receive it? ",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.lightOnSurfaceVar,
          ),
        ),
        GestureDetector(
          onTap: canResend ? _onResend : null,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _resending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    _resendCooldown > 0
                        ? 'Resend in ${_resendCooldown}s'
                        : 'Resend link',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: canResend
                          ? AppColors.primary
                          : AppColors.lightOnSurfaceVar,
                      decoration: canResend
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor: AppColors.primary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildWrongEmailLink() {
    return GestureDetector(
      onTap: _onWrongEmail,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Wrong email address? Go back',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: AppColors.lightOnSurfaceVar,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.lightOnSurfaceVar,
          ),
        ),
      ),
    );
  }
}
