import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── WEATHER SERVICE ──────────────────────────────────────────────────────────
// Open Meteo API — free, no key required.
// Docs: https://open-meteo.com/en/docs
// ─────────────────────────────────────────────────────────────────────────────

final weatherServiceProvider = Provider<WeatherService>(
  (ref) => WeatherService(),
);

class WeatherData {
  const WeatherData({
    required this.temperatureC,
    required this.windspeedKmh,
    required this.weatherCode,
    required this.isDay,
  });

  final double temperatureC;
  final double windspeedKmh;
  final int weatherCode;
  final bool isDay;

  String get description => _codeToDescription(weatherCode);
  String get iconEmoji => _codeToEmoji(weatherCode, isDay);

  List<String> get packingTips {
    final tips = <String>[];
    if (temperatureC < 10) tips.add('Pack warm layers — it\'s cold');
    if (temperatureC > 30) tips.add('Light breathable clothes recommended');
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(weatherCode)) {
      tips.add('Pack a rain jacket or umbrella');
    }
    if (windspeedKmh > 40) tips.add('Secure loose items — strong winds expected');
    if (tips.isEmpty) tips.add('Weather looks great for travel!');
    return tips;
  }

  static String _codeToDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code <= 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code <= 57) return 'Drizzle / Fog';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    if (code <= 82) return 'Showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  static String _codeToEmoji(int code, bool isDay) {
    if (code == 0) return isDay ? '☀️' : '🌙';
    if (code <= 2) return '⛅';
    if (code == 3) return '☁️';
    if (code <= 57) return '🌫️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌦️';
    return '⛈️';
  }
}

// ─── TRIP WEATHER SUMMARY ─────────────────────────────────────────────────────

class TripWeather {
  const TripWeather({
    required this.avgTemperatureC,
    required this.dominantCondition,
    required this.cityName,
  });

  final double avgTemperatureC;
  final String dominantCondition; // 'sunny' | 'cloudy' | 'rainy' | 'snowy'
  final String cityName;
}

class WeatherService {
  final _forecast = Dio(BaseOptions(
    baseUrl: 'https://api.open-meteo.com/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final _archive = Dio(BaseOptions(
    baseUrl: 'https://archive-api.open-meteo.com/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final _geo = Dio(BaseOptions(
    baseUrl: 'https://geocoding-api.open-meteo.com/v1',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  // Nominatim handles states, districts, fuzzy spelling (OpenStreetMap)
  final _nominatim = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'User-Agent': 'PackMate/1.0'},
  ));

  // ── Current weather (used elsewhere in the app) ────────────────────────────

  Future<WeatherData?> getWeather(double latitude, double longitude) async {
    try {
      final response = await _forecast.get('/forecast', queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'current_weather': true,
        'timezone': 'auto',
      });

      final current = response.data['current_weather'] as Map<String, dynamic>;
      return WeatherData(
        temperatureC: (current['temperature'] as num).toDouble(),
        windspeedKmh: (current['windspeed'] as num).toDouble(),
        weatherCode: current['weathercode'] as int,
        isDay: (current['is_day'] as int) == 1,
      );
    } catch (_) {
      return null;
    }
  }

  // ── City autocomplete (free, no key) ─────────────────────────────────────

  /// Returns up to [count] city suggestions for [query] using the Open Meteo
  /// geocoding API (free, no key required). Each result has a display [name]
  /// (city only) and an [address] (state/country for subtitle).
  Future<List<({String name, String address})>> geocodeCities(
      String query, {int count = 6}) async {
    try {
      final res = await _geo.get('/search', queryParameters: {
        'name': query.trim(),
        'count': count,
        'language': 'en',
        'format': 'json',
      });
      final results = res.data['results'] as List?;
      if (results == null || results.isEmpty) return [];
      return results.map((r) {
        final m       = r as Map<String, dynamic>;
        final name    = m['name'] as String? ?? '';
        final admin1  = m['admin1'] as String? ?? '';
        final country = m['country'] as String? ?? '';
        final address = [
          if (admin1.isNotEmpty)  admin1,
          if (country.isNotEmpty) country,
        ].join(', ');
        return (name: name, address: address);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Geocode city name → lat/lng ───────────────────────────────────────────
  // Tries Open Meteo first (fast, city-focused).
  // Falls back to Nominatim (OpenStreetMap) which handles states, districts,
  // and fuzzy/partial spellings like "Rajasthan" or "Vishakaptna".

  Future<({double lat, double lng, String name})?> geocodeCity(
      String city) async {
    final result = await _geocodeOpenMeteo(city) ?? await _geocodeNominatim(city);
    return result;
  }

  Future<({double lat, double lng, String name})?> _geocodeOpenMeteo(
      String city) async {
    try {
      final res = await _geo.get('/search', queryParameters: {
        'name': city.trim(),
        'count': 1,
        'language': 'en',
        'format': 'json',
      });
      final results = res.data['results'] as List?;
      if (results == null || results.isEmpty) return null;
      final r = results.first as Map<String, dynamic>;
      return (
        lat: (r['latitude'] as num).toDouble(),
        lng: (r['longitude'] as num).toDouble(),
        name: r['name'] as String? ?? city,
      );
    } catch (_) {
      return null;
    }
  }

  Future<({double lat, double lng, String name})?> _geocodeNominatim(
      String city) async {
    try {
      final res = await _nominatim.get('/search', queryParameters: {
        'q': city.trim(),
        'format': 'json',
        'limit': 1,
        'addressdetails': 0,
      });
      final results = res.data as List?;
      if (results == null || results.isEmpty) return null;
      final r = results.first as Map<String, dynamic>;
      final displayName = (r['display_name'] as String? ?? city).split(',').first.trim();
      return (
        lat: double.parse(r['lat'] as String),
        lng: double.parse(r['lon'] as String),
        name: displayName,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Weather for a date range ───────────────────────────────────────────────
  // Uses forecast API for trips within 16 days, archive (prior year) for
  // anything further out — giving a seasonal estimate.

  Future<TripWeather?> getWeatherForPeriod({
    required double lat,
    required double lng,
    required DateTime startDate,
    required DateTime endDate,
    required String cityName,
  }) async {
    try {
      final today = DateTime.now();
      final daysUntilStart = startDate.difference(today).inDays;

      List<double> temps;
      List<int> codes;

      if (daysUntilStart <= 15) {
        // Use real forecast
        final clamped = endDate.isAfter(today.add(const Duration(days: 15)))
            ? today.add(const Duration(days: 15))
            : endDate;
        final res = await _forecast.get('/forecast', queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'daily': ['temperature_2m_max', 'temperature_2m_min', 'weather_code'],
          'start_date': _fmt(startDate),
          'end_date': _fmt(clamped),
          'timezone': 'auto',
        });
        temps = _dailyAvgTemps(res.data);
        codes = _dailyCodes(res.data);
      } else {
        // Use same period from last year as seasonal estimate
        final refStart =
            DateTime(startDate.year - 1, startDate.month, startDate.day);
        final refEnd =
            DateTime(endDate.year - 1, endDate.month, endDate.day);
        final res = await _archive.get('/archive', queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'daily': ['temperature_2m_max', 'temperature_2m_min', 'weather_code'],
          'start_date': _fmt(refStart),
          'end_date': _fmt(refEnd),
          'timezone': 'auto',
        });
        temps = _dailyAvgTemps(res.data);
        codes = _dailyCodes(res.data);
      }

      if (temps.isEmpty) return null;

      final avgTemp = temps.reduce((a, b) => a + b) / temps.length;
      final condition = _dominantCondition(codes);

      return TripWeather(
        avgTemperatureC: double.parse(avgTemp.toStringAsFixed(1)),
        dominantCondition: condition,
        cityName: cityName,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  List<double> _dailyAvgTemps(Map<String, dynamic> data) {
    final daily = data['daily'] as Map<String, dynamic>?;
    if (daily == null) return [];
    final maxList = (daily['temperature_2m_max'] as List?)
            ?.map((v) => (v as num?)?.toDouble() ?? 0.0)
            .toList() ??
        [];
    final minList = (daily['temperature_2m_min'] as List?)
            ?.map((v) => (v as num?)?.toDouble() ?? 0.0)
            .toList() ??
        [];
    final len = maxList.length < minList.length
        ? maxList.length
        : minList.length;
    return List.generate(len, (i) => (maxList[i] + minList[i]) / 2);
  }

  List<int> _dailyCodes(Map<String, dynamic> data) {
    final daily = data['daily'] as Map<String, dynamic>?;
    if (daily == null) return [];
    return (daily['weather_code'] as List?)
            ?.map((v) => (v as num?)?.toInt() ?? 0)
            .toList() ??
        [];
  }

  String _dominantCondition(List<int> codes) {
    if (codes.isEmpty) return 'sunny';
    int snow = 0, rain = 0, cloudy = 0, sunny = 0;
    for (final c in codes) {
      if (c >= 71 && c <= 77) {
        snow++;
      } else if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) {
        rain++;
      } else if (c >= 3 && c <= 48) {
        cloudy++;
      } else {
        sunny++;
      }
    }
    final max = [snow, rain, cloudy, sunny]
        .reduce((a, b) => a > b ? a : b);
    if (max == snow) return 'snowy';
    if (max == rain) return 'rainy';
    if (max == cloudy) return 'cloudy';
    return 'sunny';
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
