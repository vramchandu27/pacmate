// ─── PACKING ENGINE INPUT ─────────────────────────────────────────────────────

enum WeatherCondition { sunny, rainy, snowy, cloudy }

enum TripType { vacation, business, trekking, beach }

class PackingInput {
  const PackingInput({
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.temperature,
    required this.weatherCondition,
    required this.tripType,
  }) : assert(
          !identical(startDate, endDate) || true, // allow same-day trips
        );

  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final double temperature; // average °C
  final WeatherCondition weatherCondition;
  final TripType tripType;

  /// Inclusive day count (1-day trip = 1).
  int get duration => endDate.difference(startDate).inDays + 1;
}
