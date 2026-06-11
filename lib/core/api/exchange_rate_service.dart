import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env_config.dart';

// ─── EXCHANGE RATE SERVICE ────────────────────────────────────────────────────
// Fetches live exchange rates directly from exchangerate-api.com.
// Caches results 1 hour in SharedPreferences.
// ─────────────────────────────────────────────────────────────────────────────

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return ExchangeRateService();
});

class ExchangeRateService {
  final _dio = Dio();

  static const _cacheKey = 'exchange_rates_INR';
  static const _cacheTimeKey = 'exchange_rates_time';
  static const _cacheDurationMs = 60 * 60 * 1000; // 1 hour

  Map<String, double>? _memoryCache;
  DateTime? _memoryCacheTime;

  /// Get all rates from INR. Returns cached value if fresh.
  /// Returns an empty map on any network/key error so callers fall back to
  /// the hardcoded rates stored on each CurrencyEntry.
  Future<Map<String, double>> getAllRates() async {
    try {
      // Memory cache
      if (_memoryCache != null && _memoryCacheTime != null) {
        final age = DateTime.now().difference(_memoryCacheTime!).inMilliseconds;
        if (age < _cacheDurationMs) return _memoryCache!;
      }

      // Disk cache
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final cachedTime = prefs.getInt(_cacheTimeKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cachedJson != null && (now - cachedTime) < _cacheDurationMs) {
        final decoded = Map<String, dynamic>.from(jsonDecode(cachedJson));
        _memoryCache = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
        _memoryCacheTime = DateTime.fromMillisecondsSinceEpoch(cachedTime);
        return _memoryCache!;
      }

      // Fetch from API
      final rates = await _fetchRates();
      if (rates.isEmpty) return {};

      _memoryCache = rates;
      _memoryCacheTime = DateTime.now();
      await prefs.setString(_cacheKey, jsonEncode(rates));
      await prefs.setInt(_cacheTimeKey, now);

      return rates;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, double>> _fetchRates() async {
    if (EnvConfig.exchangeRateKey.isEmpty) return {};
    final url =
        'https://v6.exchangerate-api.com/v6/${EnvConfig.exchangeRateKey}/latest/INR';
    final response = await _dio.get<Map<String, dynamic>>(url);
    final conversionRates =
        response.data!['conversion_rates'] as Map<String, dynamic>;
    return conversionRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  /// Get the exchange rate from [from] to [to].
  Future<double> getRate(String from, String to) async {
    if (from == to) return 1.0;

    final rates = await getAllRates();

    if (from == 'INR') return rates[to] ?? 1.0;

    final fromRate = rates[from];
    final toRate = rates[to];
    if (fromRate == null || toRate == null) return 1.0;

    // Convert: from → INR → to
    return toRate / fromRate;
  }

  /// Convert [amount] from [from] currency to [to] currency.
  Future<double> convert(double amount, String from, String to) async {
    final rate = await getRate(from, to);
    return amount * rate;
  }
}
