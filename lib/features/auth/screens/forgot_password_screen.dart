import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/security/rate_limiter.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/theme/app_theme.dart';

// ─── FORGOT PASSWORD SCREEN ──────────────────────────────────────────────────
// Dark-themed screen for sending Firebase password reset emails.
// Two states: form entry → success confirmation.
// ─────────────────────────────────────────────────────────────────────────────

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final rl = await ref.read(rateLimiterProvider).check('password_reset');
    if (!rl.allowed) {
      setState(() => _error = 'Too many requests. ${rl.retryMessage}');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordResetEmail(_emailCtrl.text.trim());
    } on FirebaseAuthException catch (e) {
      // Never reveal whether an email is registered — treat user-not-found as
      // success to prevent account enumeration attacks.
      if (e.code != 'user-not-found') {
        if (mounted) setState(() => _error = _mapError(e.code));
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.somethingWrong);
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() { _emailSent = true; _isLoading = false; });
  }

  String _mapError(String code) {
    switch (code) {
      case 'invalid-email':
        return AppStrings.emailInvalid;
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return AppStrings.somethingWrong;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _emailSent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.success,
            size: 44,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Check your inbox',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a password reset link to\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.white60,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go(AppRoutes.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back to Login',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _emailSent = false),
          child: const Text(
            'Resend email',
            style: TextStyle(fontFamily: 'Poppins', color: Colors.white60),
          ),
        ),
      ],
    );
  }

  // ── Email form ─────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Back button
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 32),

        // Lock icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: AppColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Forgot\nPassword?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "No worries — enter your email and we'll send you a reset link.",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.white60,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),

        // Email field
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofocus: true,
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
            decoration: InputDecoration(
              labelText: AppStrings.emailLabel,
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: AppStrings.emailHint,
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: Colors.white60,
              ),
              filled: true,
              fillColor: Colors.white.withAlpha(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 2),
              ),
              errorStyle: const TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.danger,
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return AppStrings.fieldRequired;
              final rx = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!rx.hasMatch(v.trim())) return AppStrings.emailInvalid;
              return null;
            },
          ),
        ),

        // Error banner
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.danger,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),

        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withAlpha(60),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Send Reset Link',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text(
              'Back to Login',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white60),
            ),
          ),
        ),
      ],
    );
  }
}
