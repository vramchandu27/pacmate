// ─── ROUTE MODEL ─────────────────────────────────────────────────────────────
// Represents one day in a Gemini-generated travel itinerary.
// ─────────────────────────────────────────────────────────────────────────────

class RouteDayModel {
  const RouteDayModel({
    required this.day,
    required this.title,
    required this.location,
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.accommodation,
    required this.estimatedCostINR,
    required this.tips,
  });

  final int day;
  final String title;
  final String location;
  final String morning;
  final String afternoon;
  final String evening;
  final String accommodation;
  final int estimatedCostINR;
  final String tips;

  factory RouteDayModel.fromJson(Map<String, dynamic> json) {
    return RouteDayModel(
      day:              (json['day'] as num?)?.toInt() ?? 0,
      title:            json['title'] as String? ?? '',
      location:         json['location'] as String? ?? '',
      morning:          json['morning'] as String? ?? '',
      afternoon:        json['afternoon'] as String? ?? '',
      evening:          json['evening'] as String? ?? '',
      accommodation:    json['accommodation'] as String? ?? '',
      estimatedCostINR: (json['estimatedCostINR'] as num?)?.toInt() ?? 0,
      tips:             json['tips'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'day':              day,
    'title':            title,
    'location':         location,
    'morning':          morning,
    'afternoon':        afternoon,
    'evening':          evening,
    'accommodation':    accommodation,
    'estimatedCostINR': estimatedCostINR,
    'tips':             tips,
  };
}

class SavedRouteModel {
  const SavedRouteModel({
    required this.id,
    required this.startCity,
    required this.endCity,
    required this.durationDays,
    required this.dailyBudgetINR,
    required this.days,
    required this.createdAt,
  });

  final String id;
  final String startCity;
  final String endCity;
  final int durationDays;
  final int dailyBudgetINR;
  final List<RouteDayModel> days;
  final DateTime createdAt;

  int get totalEstimatedCost =>
      days.fold(0, (sum, d) => sum + d.estimatedCostINR);

  factory SavedRouteModel.fromFirestore(Map<String, dynamic> data, String id) {
    final rawDays = data['days'] as List? ?? [];
    return SavedRouteModel(
      id:             id,
      startCity:      data['startCity'] as String? ?? '',
      endCity:        data['endCity'] as String? ?? '',
      durationDays:   (data['durationDays'] as num?)?.toInt() ?? 0,
      dailyBudgetINR: (data['dailyBudgetINR'] as num?)?.toInt() ?? 0,
      days: rawDays
          .map((e) => RouteDayModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}
