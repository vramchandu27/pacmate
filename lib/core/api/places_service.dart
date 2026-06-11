import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';

// ─── PLACES SERVICE ───────────────────────────────────────────────────────────
// Nearby search: tries the getNearbyPlaces Cloud Function first (PLACES_KEY in
// Firebase Secrets), falls back to direct Places API using EnvConfig.placesKey
// when the function is unavailable / not deployed.
//
// Geocoding, autocomplete, text search, and photo URLs always use the direct
// API with EnvConfig.placesKey (a separate key from the Maps SDK key).
// ─────────────────────────────────────────────────────────────────────────────

final placesServiceProvider = Provider<PlacesService>(
  (ref) => PlacesService(),
);

class PlaceResult {
  const PlaceResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.userRatingsTotal,
    required this.types,
    this.photoReference,
    this.priceLevel,
    this.isOpen,
  });

  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final int userRatingsTotal;
  final List<String> types;
  final String? photoReference;
  final int? priceLevel;
  final bool? isOpen;

  String photoUrl(int maxWidth) {
    if (photoReference == null) return '';
    final key = EnvConfig.placesKey;
    if (key.isEmpty) return '';
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=$maxWidth'
        '&photo_reference=$photoReference'
        '&key=$key';
  }
}

class NearbySearchResult {
  const NearbySearchResult({required this.places, this.error});
  final List<PlaceResult> places;
  final String? error;
}

class PlacesService {
  static final _fn = FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<List<PlaceResult>> searchNearby({
    required double latitude,
    required double longitude,
    required String type,
    int radius = 2000,
    String? keyword,
  }) async {
    final result = await searchNearbyRaw(
      latitude: latitude,
      longitude: longitude,
      type: type,
      radius: radius,
      keyword: keyword,
    );
    return result.places;
  }

  static const _fnFallbackCodes = {
    'not-found', 'unauthenticated', 'unavailable',
    'internal', 'failed-precondition', 'resource-exhausted',
  };

  Future<NearbySearchResult> searchNearbyRaw({
    required double latitude,
    required double longitude,
    required String type,
    int radius = 2000,
    String? keyword,
  }) async {
    // Try Cloud Function first.
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.getIdToken(true).timeout(const Duration(seconds: 8));
        } catch (_) {}
      }

      final payload = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
        'radius': radius,
      };
      if (keyword != null && keyword.isNotEmpty) payload['keyword'] = keyword;

      final result = await _fn.httpsCallable('getNearbyPlaces').call(payload);
      final data = result.data as Map<dynamic, dynamic>;
      final places = (data['places'] as List? ?? [])
          .map((r) => _parseResult(r as Map<dynamic, dynamic>))
          .toList();
      return NearbySearchResult(places: places);
    } catch (e) {
      final msg = e.toString();
      final shouldFallback = _fnFallbackCodes.any((c) => msg.contains(c));
      debugPrint('[PlacesService] getNearbyPlaces CF failed: $msg'
          '${shouldFallback ? ' — trying direct API' : ''}');

      if (shouldFallback) {
        return _searchNearbyDirect(
          latitude: latitude,
          longitude: longitude,
          type: type,
          radius: radius,
          keyword: keyword,
        );
      }
      return NearbySearchResult(places: [], error: msg);
    }
  }

  Future<NearbySearchResult> _searchNearbyDirect({
    required double latitude,
    required double longitude,
    required String type,
    int radius = 2000,
    String? keyword,
  }) async {
    final key = EnvConfig.placesKey;
    if (key.isEmpty) {
      return const NearbySearchResult(
        places: [],
        error: 'Places API key not configured.',
      );
    }
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final params = <String, dynamic>{
        'location': '$latitude,$longitude',
        'radius': radius,
        'type': type,
        'key': key,
      };
      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: params,
      );
      final status = response.data['status'] as String? ?? 'UNKNOWN';
      debugPrint('[PlacesService] nearbysearch direct → status=$status');
      if (status == 'ZERO_RESULTS') return const NearbySearchResult(places: []);
      if (status != 'OK') {
        final errMsg = response.data['error_message'] as String? ?? '';
        return NearbySearchResult(places: [], error: 'Places API: $status — $errMsg');
      }
      final results = (response.data['results'] as List? ?? [])
          .map((r) => _parseResult(r as Map<dynamic, dynamic>))
          .toList();
      return NearbySearchResult(places: results);
    } catch (e) {
      debugPrint('[PlacesService] _searchNearbyDirect error: $e');
      return NearbySearchResult(places: [], error: e.toString());
    }
  }

  Future<List<String>> autocompleteDestinations(String input) async {
    final key = EnvConfig.placesKey;
    if (key.isEmpty || input.trim().length < 2) return [];
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://maps.googleapis.com/maps/api/place',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final response = await dio.get('/autocomplete/json', queryParameters: {
        'input': input.trim(),
        'types': 'geocode',
        'key': key,
      });
      final predictions = response.data['predictions'] as List? ?? [];
      return predictions
          .map((p) => p['description'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .take(5)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns null when no results are found or on error.
  Future<({double latitude, double longitude})?> geocodeQuery(String query) async {
    final key = EnvConfig.placesKey;
    if (key.isEmpty || query.trim().isEmpty) return null;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {'address': query.trim(), 'key': key},
      );
      final status   = response.data['status'] as String? ?? 'UNKNOWN';
      final errMsg   = response.data['error_message'] as String? ?? '';
      debugPrint('[PlacesService] geocodeQuery "$query" → status=$status $errMsg');
      if (status != 'OK') throw Exception('Geocoding API: $status — $errMsg');
      final results = response.data['results'] as List?;
      if (results == null || results.isEmpty) return null;
      final loc = results[0]['geometry']['location'] as Map;
      return (
        latitude:  (loc['lat'] as num).toDouble(),
        longitude: (loc['lng'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('[PlacesService] geocodeQuery error: $e');
      rethrow;
    }
  }

  Future<List<PlaceResult>> textSearch(String query, {String? type}) async {
    final key = EnvConfig.placesKey;
    if (key.isEmpty || query.trim().isEmpty) return [];
    final dio = Dio(BaseOptions(
      baseUrl: 'https://maps.googleapis.com/maps/api/place',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final params = <String, dynamic>{
      'query': query.trim(),
      'key': key,
    };
    if (type != null) params['type'] = type;
    final response = await dio.get('/textsearch/json', queryParameters: params);
    final status = response.data['status'] as String? ?? 'UNKNOWN';
    if (status == 'ZERO_RESULTS') return [];
    if (status != 'OK') {
      throw Exception('Places API error: $status');
    }
    final results = response.data['results'] as List? ?? [];
    return results.map((r) => _parseResult(r as Map<dynamic, dynamic>)).toList();
  }

  Future<List<PlaceResult>> searchNearbyHotels({
    required double latitude,
    required double longitude,
    int radius = 3000,
  }) =>
      searchNearby(
        latitude: latitude,
        longitude: longitude,
        type: 'lodging',
        radius: radius,
      );

  Future<List<PlaceResult>> searchNearbyRestaurants({
    required double latitude,
    required double longitude,
    int radius = 1500,
  }) =>
      searchNearby(
        latitude: latitude,
        longitude: longitude,
        type: 'restaurant',
        radius: radius,
      );

  PlaceResult _parseResult(Map<dynamic, dynamic> r) {
    final geometry = r['geometry']['location'] as Map<dynamic, dynamic>;
    final photos = r['photos'] as List?;
    final openingHours = r['opening_hours'] as Map<dynamic, dynamic>?;

    return PlaceResult(
      placeId: r['place_id'] as String? ?? '',
      name: r['name'] as String? ?? '',
      address: r['vicinity'] as String? ?? r['formatted_address'] as String? ?? '',
      latitude: (geometry['lat'] as num).toDouble(),
      longitude: (geometry['lng'] as num).toDouble(),
      rating: (r['rating'] as num?)?.toDouble() ?? 0.0,
      userRatingsTotal: (r['user_ratings_total'] as num?)?.toInt() ?? 0,
      types: (r['types'] as List?)?.map((e) => e.toString()).toList() ?? [],
      photoReference: photos?.isNotEmpty == true
          ? photos![0]['photo_reference'] as String?
          : null,
      priceLevel: (r['price_level'] as num?)?.toInt(),
      isOpen: openingHours?['open_now'] as bool?,
    );
  }
}
