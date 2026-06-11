import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/security/rate_limiter.dart';
import '../../../core/theme/app_theme.dart';

// ─── SIGNUP SCREEN ───────────────────────────────────────────────────────────

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePassword  = true;
  bool _obscureConfirm   = true;
  bool _isEmailLoading   = false;
  bool _isGoogleLoading  = false;

  // Entrance animation
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    if (value.trim().length < 2) return AppStrings.nameTooShort;
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final emailRx = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!emailRx.hasMatch(value.trim())) return AppStrings.emailInvalid;
    final domain = value.trim().split('@').last.toLowerCase();
    if (_kDisposableDomains.contains(domain)) {
      return 'Please use a real email address (not a temporary one)';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.fieldRequired;
    if (value.length < 8) return AppStrings.passwordTooShort;
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must contain an uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Must contain a number';
    if (!RegExp(r'[!@#\$&*~%^()\-+=\[\]{};:,.<>?]').hasMatch(value)) {
      return 'Must contain a special character';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.fieldRequired;
    if (value != _passwordCtrl.text) return AppStrings.passwordNoMatch;
    return null;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _onSignup() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final rl = await ref.read(rateLimiterProvider).check('signup');
    if (!rl.allowed) {
      _showError('Too many sign-up attempts. ${rl.retryMessage}');
      return;
    }

    setState(() => _isEmailLoading = true);
    try {
      await ref.read(authServiceProvider).signUpWithEmail(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            fullName: _nameCtrl.text,
          );
      if (!mounted) return;
      context.go(AppRoutes.verifyEmail);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_authErrorMessage(e.code));
    } catch (e) {
      if (!mounted) return;
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
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
      _showError('Google sign-in failed. Please try again.');
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
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password must be at least 8 characters with uppercase, number, and special character.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Sign-up failed. Please try again.';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildFormCard()),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF1A3A5C)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  if (context.canPop()) context.pop();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Logo
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(80),
                      ),
                    ),
                    child: const Icon(
                      Icons.backpack_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    AppStrings.appName,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Welcome heading
              const Text(
                'Join PacMate',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your account to start planning',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Form Card ──────────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildNameField(),
                    const SizedBox(height: 18),
                    _buildEmailField(),
                    const SizedBox(height: 18),
                    _buildPasswordField(),
                    const SizedBox(height: 6),
                    const Text(
                      'Min 8 chars · uppercase · number · special character',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.lightOnSurfaceVar,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildConfirmPasswordField(),
                    const SizedBox(height: 28),
                    _buildSignupButton(),
                    const SizedBox(height: 24),
                    _buildOrDivider(),
                    const SizedBox(height: 24),
                    _buildGoogleButton(),
                    const SizedBox(height: 32),
                    _buildLoginLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Fields ─────────────────────────────────────────────────────────────────

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(AppStrings.nameLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameCtrl,
          focusNode: _nameFocus,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          validator: _validateName,
          onFieldSubmitted: (_) => _emailFocus.requestFocus(),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.lightOnSurface,
          ),
          decoration: _inputDecoration(
            hint: AppStrings.nameHint,
            prefixIcon: Icons.person_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(AppStrings.emailLabel),
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
            hint: AppStrings.emailHint,
            prefixIcon: Icons.alternate_email_rounded,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 13, color: AppColors.lightOnSurfaceVar),
            const SizedBox(width: 5),
            const Text(
              'A verification link will be sent to this email',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: AppColors.lightOnSurfaceVar,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(AppStrings.passwordLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordCtrl,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          validator: _validatePassword,
          onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.lightOnSurface,
          ),
          decoration: _inputDecoration(
            hint: AppStrings.passwordHint,
            prefixIcon: Icons.lock_outline_rounded,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
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

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(AppStrings.confirmPasswordLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmCtrl,
          focusNode: _confirmFocus,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          validator: _validateConfirmPassword,
          onFieldSubmitted: (_) => _onSignup(),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.lightOnSurface,
          ),
          decoration: _inputDecoration(
            hint: 'Re-enter your password',
            prefixIcon: Icons.lock_outline_rounded,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(
                _obscureConfirm
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

  // ── Buttons ────────────────────────────────────────────────────────────────

  Widget _buildSignupButton() {
    final anyLoading = _isEmailLoading || _isGoogleLoading;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: anyLoading ? null : _onSignup,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(120),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isEmailLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppStrings.signup,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.lightOutlineVar, thickness: 1),
        ),
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
          child: Divider(color: AppColors.lightOutlineVar, thickness: 1),
        ),
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
            borderRadius: BorderRadius.circular(14),
          ),
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

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          AppStrings.alreadyHaveAccount,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.lightOnSurfaceVar,
          ),
        ),
        GestureDetector(
          onTap: () => context.go(AppRoutes.login),
          child: const Text(
            AppStrings.loginLink,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.lightOnSurface,
        letterSpacing: 0.1,
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
        child: Icon(prefixIcon, color: AppColors.lightOnSurfaceVar, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 14), child: suffix)
          : null,
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightOutline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightOutline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
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

// ─── DISPOSABLE EMAIL DOMAIN BLOCKLIST ───────────────────────────────────────

const _kDisposableDomains = <String>{
  // Mailinator family
  'mailinator.com', 'mailinater.com', 'mailinator2.com', 'mailinator.net',
  // YOPmail
  'yopmail.com', 'yopmail.fr', 'cool.fr.nf', 'jetable.fr.nf',
  // TempMail
  'tempmail.com', 'temp-mail.org', 'tmpmail.net', 'tmpmail.org',
  'tempmail.net', 'tempmail.de', 'tempmail.io',
  // Guerrilla Mail
  'guerrillamail.com', 'guerrillamail.net', 'guerrillamail.org',
  'guerrillamail.biz', 'guerrillamail.de', 'guerrillamail.info',
  'grr.la', 'guerrillamailblock.com', 'spam4.me',
  // 10 Minute Mail
  '10minutemail.com', '10minutemail.net', '10minutemail.org',
  '10minemail.com', '10mail.org',
  // Throwam / Trashmail
  'trashmail.com', 'trashmail.at', 'trashmail.io', 'trashmail.me',
  'trashmail.net', 'trashmail.org', 'trashmail.xyz',
  // Dispostable
  'dispostable.com', 'disposablemail.com', 'disposableaddress.com',
  // Fake / random generators
  'fakeinbox.com', 'fakemail.fr', 'fake-box.com',
  'mailnull.com', 'maildrop.cc', 'mailnesia.com',
  'spamgourmet.com', 'spamgourmet.net', 'spamgourmet.org',
  'spam.la', 'spamfree24.org', 'spamhereplease.com',
  'spamoff.de', 'spamspot.com', 'spamthisplease.com',
  'throwam.com', 'throwam.net',
  // Misc popular disposable services
  'getairmail.com', 'mailexpire.com', 'mailfreeonline.com',
  'mailme.lv', 'mailmetrash.com', 'mailmoat.com', 'mailnew.com',
  'mailpick.biz', 'mailrock.biz', 'mailscrap.com',
  'mailshell.com', 'mailsiphon.com', 'mailslapping.com', 'mailslite.com',
  'mailtemporaire.com', 'mailtemporaire.fr',
  'spamgob.com', 'spamherelots.com',
  'mt2015.com', 'mt2016.com', 'mt2017.com',
  'owlpic.com', 'proxymail.eu', 'rcpt.at', 'rklips.com',
  'rmqkr.net', 'royal.net', 'rtrtr.com',
  's0ny.net', 'safe-mail.net', 'safersignup.de',
  'safetymail.info', 'safetypost.de', 'sandelf.de',
  'SendSpamHere.com',
  'shieldedmail.com', 'shiftmail.com', 'shitmail.me', 'shitware.nl',
  'skeefmail.com', 'slopsbox.com', 'smellfear.com', 'smellrear.com',
  'snakemail.com', 'sneakemail.com', 'sofimail.com', 'sofort-mail.de',
  'spamcorpse.com', 'spamdecoy.net', 'spamfree.eu',
  'superrito.com', 'suremail.info',
  'teleworm.com', 'teleworm.us', 'tempalias.com',
  'tempinbox.co.uk', 'tempinbox.com', 'tempomail.fr',
  'temporarioemail.com.br', 'temporaryemail.net', 'temporaryemail.us',
  'temporaryforwarding.com', 'temporaryinbox.com', 'tempthe.net',
  'thanksnospam.info', 'thisisnotmyrealemail.com',
  'tilien.com', 'tittbit.in', 'tmail.com',
  'tmailinator.com', 'toiea.com', 'tradermail.info',
  'trash2009.com', 'trash2010.com', 'trash2011.com',
  'trashdevil.com', 'trashdevil.de', 'trashmailer.com',
  'trasz.com', 'trbvm.com', 'turual.com', 'twinmail.de',
  'tyldd.com', 'uggsrock.com', 'uroid.com',
  'venompen.com', 'veryrealemail.com', 'viditag.com',
  'viralplays.com', 'vyplsidky.cz',
  'webemail.me', 'weg-werf-email.de', 'wegwerf-emails.de',
  'wetrainbayarea.org', 'wh4f.org', 'whyspam.me',
  'wilemail.com', 'willhackforfood.biz', 'willselfdestruct.com',
  'wmail.cf', 'writeme.us',
  'xagloo.co', 'xagloo.com', 'xemaps.com', 'xents.com',
  'xmaily.com', 'xoxy.net',
  'yapped.net', 'yeah.net',
  'yogamaven.com', 'yomail.info', 'yopweb.com', 'yourdomain.com',
  'ypmail.webarnak.fr.eu.org', 'yuurok.com',
  'z1p.biz', 'za.com', 'zehnminutenmail.de', 'zetmail.com',
  'zippymail.info', 'zoaxe.com', 'zoemail.net', 'zoemail.org',
  'zomg.info', 'zxcv.com', 'zxcvbnm.com', 'zzz.com',
};
