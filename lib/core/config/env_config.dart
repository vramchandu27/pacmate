import 'dev_keys.dart';

// ─── ENV CONFIG ───────────────────────────────────────────────────────────────
// Only client-safe keys live here — keys that MUST be embedded in the app
// binary (Google Maps SDK requires it in the manifest).
//
// Secret keys (Gemini, Places backend, Exchange Rate backend) are
// Firebase Secrets accessed only by Cloud Functions — they never touch
// the client.
//
// Keys are injected at build time via --dart-define:
//   flutter run --dart-define=GOOGLE_MAPS_KEY=YOUR_KEY
//
// For local development without CI, dev_keys.dart provides fallbacks.
// dev_keys.dart is gitignored — never commit it with real keys.
// ─────────────────────────────────────────────────────────────────────────────

class EnvConfig {
  const EnvConfig._();

  /// Google Maps SDK key — needed by google_maps_flutter in AndroidManifest
  /// and iOS AppDelegate. Restrict this key in GCP Console by package name.
  static const String googleMapsKey =
      String.fromEnvironment('GOOGLE_MAPS_KEY', defaultValue: kDevGoogleMapsKey);

  /// Google Places API key — used for Geocoding, Autocomplete, Text Search,
  /// and photo URLs. Keep separate from the Maps SDK key.
  static const String placesKey =
      String.fromEnvironment('PLACES_CLIENT_KEY', defaultValue: kDevPlacesKey);

  /// Exchange Rate API key — optional. When empty the app falls back to the
  /// Cloud Function proxy (getExchangeRates). Providing it here enables the
  /// client-side cache path in exchange_rate_service.dart.
  static const String exchangeRateKey =
      String.fromEnvironment('EXCHANGE_RATE_KEY', defaultValue: kDevExchangeKey);

  static bool get hasGoogleMapsKey => googleMapsKey.isNotEmpty;

  /// Optional client-side Gemini key. Used only as a fallback when the
  /// Cloud Functions (generatePackingList / generateRoute) are unreachable.
  /// In production the key should live in Firebase Secrets; this is a
  /// development shortcut injected via --dart-define=GEMINI_KEY=...
  static const String geminiKey =
      String.fromEnvironment('GEMINI_KEY', defaultValue: kDevGeminiKey);

  // ── Keys intentionally absent from client in production ───────────────────
  // PLACES_KEY    → Firebase Secret in Cloud Functions; photo URLs use Maps key
  // EXCHANGE_RATE_KEY → Firebase Secret in Cloud Functions
  // REVENUECAT_KEY    → injected natively via RevenueCat SDK setup, not here
}
