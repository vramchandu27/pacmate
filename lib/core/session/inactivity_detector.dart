import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/auth_service.dart';
import '../theme/app_theme.dart';

// ─── INACTIVITY DETECTOR ──────────────────────────────────────────────────────
// Wraps the entire authenticated app. Starts a 5-minute idle timer that resets
// on every pointer event. When the timer fires a warning dialog counts down
// 10 seconds — if the user taps Yes the session continues; if they tap No or
// the countdown expires, the app is signed out and closed immediately.
// ─────────────────────────────────────────────────────────────────────────────

const _kIdleTimeout    = Duration(minutes: 5);
const _kWarningSeconds = 10;

class InactivityDetector extends ConsumerStatefulWidget {
  const InactivityDetector({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends ConsumerState<InactivityDetector> {
  Timer? _idleTimer;
  bool  _warningVisible = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  // ── Timer management ───────────────────────────────────────────────────────

  void _startTimer() {
    _idleTimer?.cancel();
    if (FirebaseAuth.instance.currentUser == null) return;
    _idleTimer = Timer(_kIdleTimeout, _onIdle);
  }

  void _onUserInteraction() {
    if (_warningVisible) return;
    _startTimer();
  }

  // ── Idle handler ───────────────────────────────────────────────────────────

  Future<void> _onIdle() async {
    if (!mounted || _warningVisible) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    _warningVisible = true;

    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _WarningDialog(),
    );

    _warningVisible = false;
    if (!mounted) return;

    if (shouldContinue == true) {
      _startTimer();
    } else {
      await _closeApp();
    }
  }

  Future<void> _closeApp() async {
    _idleTimer?.cancel();
    // Sign out first so re-opening the app lands on login.
    await ref.read(authServiceProvider).signOut();
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserInteraction(),
      onPointerMove: (_) => _onUserInteraction(),
      child: widget.child,
    );
  }
}

// ─── WARNING DIALOG ───────────────────────────────────────────────────────────

class _WarningDialog extends StatefulWidget {
  const _WarningDialog();

  @override
  State<_WarningDialog> createState() => _WarningDialogState();
}

class _WarningDialogState extends State<_WarningDialog> {
  late int _secondsLeft;
  Timer?   _countdown;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _kWarningSeconds;
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft <= 1) {
        t.cancel();
        Navigator.of(context).pop(false); // timed out → close app
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _secondsLeft / _kWarningSeconds;
    final isUrgent = _secondsLeft <= 3;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Circular countdown ─────────────────────────────────────────
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 6,
                    backgroundColor: AppColors.lightOutline.withAlpha(50),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUrgent ? AppColors.danger : AppColors.primary,
                    ),
                  ),
                  Text(
                    '$_secondsLeft',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isUrgent ? AppColors.danger : AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Title ──────────────────────────────────────────────────────
            const Text(
              'Are you still there?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You've been inactive for a while.\nThe app will close automatically if you don't respond.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.lightOnSurfaceVar,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),

            // ── YES button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Yes, I\'m here',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── NO button ──────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'No, close the app',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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
