import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── RATE LIMITER ─────────────────────────────────────────────────────────────
// Sliding-window rate limiter backed by SharedPreferences.
// Enforces limits per-device as a first defence; server-side limits are the
// authoritative gate. Does NOT reset on app restart for the configured window.
// ─────────────────────────────────────────────────────────────────────────────

class RateLimitConfig {
  const RateLimitConfig({required this.maxRequests, required this.window});
  final int maxRequests;
  final Duration window;
}

class RateLimitResult {
  const RateLimitResult({
    required this.allowed,
    required this.remaining,
    this.retryAfter,
  });

  final bool allowed;
  final int remaining;
  final Duration? retryAfter;

  String get retryMessage {
    if (retryAfter == null) return '';
    final s = retryAfter!.inSeconds;
    if (s < 60) return 'Try again in ${s}s.';
    if (s < 3600) return 'Try again in ${retryAfter!.inMinutes}min.';
    return 'Try again in ${retryAfter!.inHours}h.';
  }
}

class RateLimiter {
  RateLimiter(this._prefs);

  final SharedPreferences _prefs;

  // ── Action configs ────────────────────────────────────────────────────────

  static const configs = <String, RateLimitConfig>{
    'login':          RateLimitConfig(maxRequests: 5,  window: Duration(minutes: 15)),
    'signup':         RateLimitConfig(maxRequests: 3,  window: Duration(hours: 1)),
    'password_reset': RateLimitConfig(maxRequests: 3,  window: Duration(hours: 1)),
    'ai_packing':     RateLimitConfig(maxRequests: 10, window: Duration(hours: 24)),
    'ai_route':       RateLimitConfig(maxRequests: 5,  window: Duration(hours: 24)),
    'gem_submit':     RateLimitConfig(maxRequests: 10, window: Duration(hours: 1)),
    'gem_review':     RateLimitConfig(maxRequests: 20, window: Duration(hours: 1)),
    'places_api':     RateLimitConfig(maxRequests: 30, window: Duration(hours: 1)),
  };

  // ── Sliding window ────────────────────────────────────────────────────────

  /// Checks the limit for [action]. Records the attempt only when allowed.
  Future<RateLimitResult> check(String action) async {
    final config = configs[action];
    if (config == null) return const RateLimitResult(allowed: true, remaining: 999);

    final key = '_rl_$action';
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - config.window.inMilliseconds;

    final raw = _prefs.getString(key);
    final all = raw != null
        ? (jsonDecode(raw) as List).cast<int>()
        : <int>[];

    // Prune timestamps outside the current window.
    final active = all.where((t) => t > cutoff).toList();

    if (active.length >= config.maxRequests) {
      active.sort();
      final unlockAt = active.first + config.window.inMilliseconds;
      final waitMs = unlockAt - now;
      return RateLimitResult(
        allowed: false,
        remaining: 0,
        retryAfter: Duration(milliseconds: waitMs > 0 ? waitMs : 1000),
      );
    }

    active.add(now);
    await _prefs.setString(key, jsonEncode(active));

    return RateLimitResult(
      allowed: true,
      remaining: config.maxRequests - active.length,
    );
  }

  /// Returns how many requests remain in the current window (non-destructive).
  Future<int> getRemaining(String action) async {
    final config = configs[action];
    if (config == null) return 999;

    final key = '_rl_$action';
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - config.window.inMilliseconds;

    final raw = _prefs.getString(key);
    final count = raw != null
        ? (jsonDecode(raw) as List).where((t) => (t as int) > cutoff).length
        : 0;

    return (config.maxRequests - count).clamp(0, config.maxRequests);
  }

  /// Clears the record for [action] — call after a successful privileged action.
  Future<void> reset(String action) async {
    await _prefs.remove('_rl_$action');
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────────────────────

/// Override this in ProviderScope with the resolved SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(
    'Provide SharedPreferences via ProviderScope overrides.',
  ),
);

final rateLimiterProvider = Provider<RateLimiter>(
  (ref) => RateLimiter(ref.read(sharedPreferencesProvider)),
);
