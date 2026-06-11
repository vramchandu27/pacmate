import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../security/rate_limiter.dart';

// ─── GEMINI API SERVICE ───────────────────────────────────────────────────────
// Primary path: Cloud Functions (generatePackingList / generateRoute).
//   → GEMINI_KEY lives as a Firebase Secret; never touches the client.
// Fallback path: Direct Gemini REST API.
//   → Used when the Cloud Function returns not-found / unauthenticated /
//     unavailable (e.g. functions not yet deployed in a dev environment).
//   → Requires --dart-define=GEMINI_KEY=... at build time, or kDevGeminiKey
//     set in dev_keys.dart.
// ─────────────────────────────────────────────────────────────────────────────

final geminiServiceProvider = Provider<GeminiApiService>((ref) {
  return GeminiApiService(ref.read(rateLimiterProvider));
});

class GeminiApiService {
  GeminiApiService(this._rateLimiter);

  final RateLimiter _rateLimiter;

  static final _fn = FirebaseFunctions.instanceFor(region: 'asia-south1');

  static const _geminiBase =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // Models tried in order when calling the direct REST API.
  // Falls through to the next on 429 (rate-limited) or 404 (not available for key).
  static const _models = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-pro',
  ];

  // Error codes that indicate the Cloud Function is unreachable or not deployed.
  static const _fallbackCodes = {'not-found', 'unauthenticated', 'unavailable', 'internal'};

  Future<void> _ensureAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true).timeout(const Duration(seconds: 8));
      }
    } catch (_) {}
  }

  // ── Direct Gemini REST call ───────────────────────────────────────────────

  /// Calls the Gemini REST API, trying each model in [_models] until one
  /// succeeds. Falls through to the next model on 429 (rate-limited).
  Future<String> _callGemini(String prompt) async {
    final key = EnvConfig.geminiKey;
    if (key.isEmpty) {
      throw Exception(
        'AI generation unavailable: Cloud Functions not reachable and no '
        'GEMINI_KEY configured. Deploy Cloud Functions or add '
        '--dart-define=GEMINI_KEY=<your-key> to your run command.',
      );
    }
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      },
    };

    DioException? lastError;
    for (final model in _models) {
      try {
        final response = await dio.post(
          '$_geminiBase/$model:generateContent?key=$key',
          data: body,
        );
        final candidates = response.data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('Gemini returned no candidates.');
        }
        return candidates[0]['content']['parts'][0]['text'] as String;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 429 || status == 404) {
          // 429 = rate-limited, 404 = model not available for this key.
          // Either way, try the next model.
          lastError = e;
          debugPrint('[GeminiService] $model returned $status, trying next model.');
          continue;
        }
        if (status == 403) {
          throw Exception('Gemini API key is invalid or the Generative Language API is not enabled.');
        }
        if (status == 400) {
          final msg = e.response?.data?['error']?['message'] as String? ?? 'Bad request';
          throw Exception('Gemini request error: $msg');
        }
        throw Exception('AI request failed (${status ?? 'network error'}). Please try again.');
      }
    }

    // All models rate-limited.
    final retryMsg = lastError?.response?.data?['error']?['message'] as String?;
    throw Exception('rate-limited: ${retryMsg ?? 'All Gemini models are busy. Please try again in a minute.'}');
  }

  // ── Packing list ──────────────────────────────────────────────────────────

  String _packingPrompt({
    required String destination,
    required int durationDays,
    required String month,
    required String travelStyle,
    required List<String> activities,
    required String accommodation,
    required bool isSoloFemale,
    required bool nutAllergy,
    required bool hasKids,
    required List<String> kidsAges,
    required bool isSenior,
    required List<String> medicalConditions,
  }) {
    final buf = StringBuffer();
    buf.writeln('Generate a comprehensive packing list for:');
    buf.writeln('Destination: $destination');
    buf.writeln('Duration: $durationDays days in $month');
    buf.writeln(
        'Style: ${travelStyle.isEmpty ? 'budget' : travelStyle} | Stay: ${accommodation.isEmpty ? 'hostel' : accommodation}');
    buf.writeln('Activities: ${activities.isEmpty ? 'general sightseeing' : activities.join(', ')}');
    if (isSoloFemale) buf.writeln('- Solo female traveler (include safety items)');
    if (nutAllergy) buf.writeln('- Has nut allergy (include allergy card, EpiPen reminder)');
    if (hasKids) buf.writeln('- Travelling with kids aged ${kidsAges.join(', ')}');
    if (isSenior) buf.writeln('- Senior traveler with: ${medicalConditions.join(', ')}');
    buf.writeln();
    buf.writeln(
        'Return a JSON object where keys are category names and values are arrays of item strings.');
    buf.writeln(
        'Categories: Clothing, Toiletries, Documents, Electronics, Health & Medicine, Footwear, Accessories, Snacks & Food, Safety, Miscellaneous');
    buf.write('Only return valid JSON, no markdown.');
    return buf.toString();
  }

  /// Generate an AI packing list.
  /// Tries the Cloud Function first; falls back to direct Gemini API.
  Future<Map<String, List<String>>> generatePackingList({
    required String destination,
    required int durationDays,
    required String month,
    String travelStyle = 'budget',
    List<String> activities = const [],
    String accommodation = 'hostel',
    bool isSoloFemale = false,
    bool nutAllergy = false,
    bool hasKids = false,
    List<String> kidsAges = const [],
    bool isSenior = false,
    List<String> medicalConditions = const [],
  }) async {
    await _ensureAuth();

    final rl = await _rateLimiter.check('ai_packing');
    if (!rl.allowed) {
      throw Exception('AI packing limit reached. ${rl.retryMessage}');
    }

    // ── 1. Try Cloud Function ─────────────────────────────────────────────
    try {
      final result = await _fn.httpsCallable('generatePackingList').call({
        'destination':       destination,
        'durationDays':      durationDays,
        'month':             month,
        'travelStyle':       travelStyle,
        'activities':        activities,
        'accommodation':     accommodation,
        'isSoloFemale':      isSoloFemale,
        'nutAllergy':        nutAllergy,
        'hasKids':           hasKids,
        'kidsAges':          kidsAges,
        'isSenior':          isSenior,
        'medicalConditions': medicalConditions,
      });
      final data = result.data as Map<dynamic, dynamic>;
      return data.map((k, v) => MapEntry(
            k.toString(),
            (v as List).map((e) => e.toString()).toList(),
          ));
    } on FirebaseFunctionsException catch (e) {
      // If function is unreachable (not deployed, IAM issue, etc.), fall back.
      if (_fallbackCodes.contains(e.code)) {
        debugPrint('[GeminiService] Cloud Function unavailable (${e.code}), using direct API.');
        return _generatePackingListDirect(
          destination:      destination,
          durationDays:     durationDays,
          month:            month,
          travelStyle:      travelStyle,
          activities:       activities,
          accommodation:    accommodation,
          isSoloFemale:     isSoloFemale,
          nutAllergy:       nutAllergy,
          hasKids:          hasKids,
          kidsAges:         kidsAges,
          isSenior:         isSenior,
          medicalConditions: medicalConditions,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, List<String>>> _generatePackingListDirect({
    required String destination,
    required int durationDays,
    required String month,
    required String travelStyle,
    required List<String> activities,
    required String accommodation,
    required bool isSoloFemale,
    required bool nutAllergy,
    required bool hasKids,
    required List<String> kidsAges,
    required bool isSenior,
    required List<String> medicalConditions,
  }) async {
    final prompt = _packingPrompt(
      destination:       destination,
      durationDays:      durationDays,
      month:             month,
      travelStyle:       travelStyle,
      activities:        activities,
      accommodation:     accommodation,
      isSoloFemale:      isSoloFemale,
      nutAllergy:        nutAllergy,
      hasKids:           hasKids,
      kidsAges:          kidsAges,
      isSenior:          isSenior,
      medicalConditions: medicalConditions,
    );
    final text = await _callGemini(prompt);
    final cleaned = text.trim().replaceAll(RegExp(r'```json|```'), '');
    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    return parsed.map((k, v) => MapEntry(
          k,
          (v as List).map((e) => e.toString()).toList(),
        ));
  }

  // ── Route planner ─────────────────────────────────────────────────────────

  String _routePrompt({
    required String startCity,
    required String endCity,
    required int durationDays,
    required int dailyBudgetINR,
    required List<String> interests,
    required String pace,
    required bool isSenior,
    required int maxWalkingKm,
    required bool vegetarianOnly,
  }) {
    final buf = StringBuffer();
    buf.writeln('Plan a $durationDays-day backpacker trip from $startCity to $endCity.');
    buf.writeln('Daily budget: ₹$dailyBudgetINR INR');
    buf.writeln('Interests: ${interests.isEmpty ? 'culture, food, nature' : interests.join(', ')}');
    buf.writeln('Pace: ${pace.isEmpty ? 'moderate' : pace}');
    if (isSenior) buf.writeln('- Senior traveler, max walking: ${maxWalkingKm}km/day');
    if (vegetarianOnly) buf.writeln('- Vegetarian food only');
    buf.writeln();
    buf.writeln('Return a JSON array of day objects. Each day:');
    buf.writeln('{');
    buf.writeln('  "day": 1,');
    buf.writeln('  "title": "Day 1: Arrival in...",');
    buf.writeln('  "location": "City Name",');
    buf.writeln('  "morning": "activity description",');
    buf.writeln('  "afternoon": "activity description",');
    buf.writeln('  "evening": "activity description",');
    buf.writeln('  "accommodation": "hostel/hotel suggestion",');
    buf.writeln('  "estimatedCostINR": 1500,');
    buf.writeln('  "tips": "local tip"');
    buf.writeln('}');
    buf.write('Only return valid JSON array, no markdown.');
    return buf.toString();
  }

  /// Generate a day-by-day AI itinerary.
  /// Tries the Cloud Function first; falls back to direct Gemini API.
  Future<List<Map<String, dynamic>>> generateRoute({
    required String startCity,
    required String endCity,
    required int durationDays,
    required int dailyBudgetINR,
    List<String> interests = const [],
    String pace = 'moderate',
    bool isSenior = false,
    int maxWalkingKm = 10,
    bool vegetarianOnly = false,
  }) async {
    await _ensureAuth();

    // ── 1. Try Cloud Function ─────────────────────────────────────────────
    try {
      final result = await _fn.httpsCallable('generateRoute').call({
        'startCity':      startCity,
        'endCity':        endCity,
        'durationDays':   durationDays,
        'dailyBudgetINR': dailyBudgetINR,
        'interests':      interests,
        'pace':           pace,
        'isSenior':       isSenior,
        'maxWalkingKm':   maxWalkingKm,
        'vegetarianOnly': vegetarianOnly,
      });
      final data = result.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } on FirebaseFunctionsException catch (e) {
      if (_fallbackCodes.contains(e.code)) {
        debugPrint('[GeminiService] Cloud Function unavailable (${e.code}), using direct API.');
        return _generateRouteDirect(
          startCity:      startCity,
          endCity:        endCity,
          durationDays:   durationDays,
          dailyBudgetINR: dailyBudgetINR,
          interests:      interests,
          pace:           pace,
          isSenior:       isSenior,
          maxWalkingKm:   maxWalkingKm,
          vegetarianOnly: vegetarianOnly,
        );
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _generateRouteDirect({
    required String startCity,
    required String endCity,
    required int durationDays,
    required int dailyBudgetINR,
    required List<String> interests,
    required String pace,
    required bool isSenior,
    required int maxWalkingKm,
    required bool vegetarianOnly,
  }) async {
    final prompt = _routePrompt(
      startCity:      startCity,
      endCity:        endCity,
      durationDays:   durationDays,
      dailyBudgetINR: dailyBudgetINR,
      interests:      interests,
      pace:           pace,
      isSenior:       isSenior,
      maxWalkingKm:   maxWalkingKm,
      vegetarianOnly: vegetarianOnly,
    );
    final text = await _callGemini(prompt);
    final cleaned = text.trim().replaceAll(RegExp(r'```json|```'), '');
    final parsed = jsonDecode(cleaned) as List;
    return parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
