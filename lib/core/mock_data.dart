// ─── MOCK DATA ─────────────────────────────────────────────────────────────
// Temporary mock data for development and testing.
// Replace with real data from Firebase/Firestore later.
// ─────────────────────────────────────────────────────────────────────────────

class MockData {
  MockData._();

  // ── Home Dashboard ─────────────────────────────────────────────────────────

  static const Map<String, dynamic> userProfile = {
    'name': 'Arjun',
    'avatar': null,
    'currentLocation': 'Bangkok, Thailand',
  };

  static const Map<String, dynamic> activeTrip = {
    'id': 'trip_active',
    'name': 'Thailand Adventure',
    'destination': 'Bangkok, Thailand',
    'startDate': '2024-12-15',
    'endDate': '2024-12-25',
    'totalBudget': 75000,
    'spent': 32000,
    'remaining': 43000,
    'daysLeft': 8,
    'totalDays': 10,
  };

  static const List<Map<String, dynamic>> stats = [
    {'label': 'Total Trips', 'value': '12', 'icon': 'flight', 'color': 'primary'},
    {'label': 'Countries', 'value': '8', 'icon': 'flag', 'color': 'success'},
    {'label': 'Saved', 'value': '₹2.5L', 'icon': 'savings', 'color': 'teal'},
    {'label': 'Lists', 'value': '0', 'icon': 'luggage', 'color': 'purple'},
  ];

  static const List<Map<String, dynamic>> quickActions = [
    {
      'title': 'Budget',
      'subtitle': 'Track expenses',
      'icon': 'wallet',
      'route': '/budget',
    },
    {
      'title': 'Pack',
      'subtitle': 'Organize gear',
      'icon': 'luggage',
      'route': '/packing',
    },
    {
      'title': 'Gems',
      'subtitle': 'Hidden spots',
      'icon': 'diamond',
      'route': '/gems',
    },
  ];

  static const List<Map<String, dynamic>> recentTrips = [
    {
      'id': 'trip_001',
      'name': 'Goa Beach Trip',
      'destination': 'Goa, India',
      'dates': 'Dec 15-20, 2024',
      'status': 'completed',
      'budget': 25000,
      'spent': 22000,
    },
    {
      'id': 'trip_002',
      'name': 'Kashmir Adventure',
      'destination': 'Srinagar, Kashmir',
      'dates': 'Jan 5-12, 2025',
      'status': 'upcoming',
      'budget': 45000,
      'spent': 0,
    },
    {
      'id': 'trip_003',
      'name': 'Rajasthan Heritage',
      'destination': 'Jaipur, Rajasthan',
      'dates': 'Feb 10-15, 2025',
      'status': 'planning',
      'budget': 30000,
      'spent': 0,
    },
  ];

  // ── Budget ─────────────────────────────────────────────────────────────────

  static const Map<String, dynamic> budgetSummary = {
    'totalBudget': 100000,
    'totalSpent': 45000,
    'remaining': 55000,
    'currency': 'INR',
    'dailyBudget': 5000,
    'todaySpent': 3200,
    'tripDays': 20,
    'daysPassed': 9,
  };

  static const List<Map<String, dynamic>> categoryBreakdown = [
    {'category': 'Accommodation', 'spent': 25000, 'budget': 35000, 'percentage': 71.4, 'color': 'primary'},
    {'category': 'Food', 'spent': 12000, 'budget': 20000, 'percentage': 60.0, 'color': 'success'},
    {'category': 'Transport', 'spent': 6500, 'budget': 15000, 'percentage': 43.3, 'color': 'teal'},
    {'category': 'Activities', 'spent': 1500, 'budget': 5000, 'percentage': 30.0, 'color': 'purple'},
  ];

  static const List<Map<String, dynamic>> recentExpenses = [
    {'id': 'exp_001', 'title': 'Hotel Booking', 'amount': 8500, 'category': 'Accommodation', 'date': '2024-12-10', 'currency': 'INR'},
    {'id': 'exp_002', 'title': 'Flight Tickets', 'amount': 15000, 'category': 'Transport', 'date': '2024-12-08', 'currency': 'INR'},
    {'id': 'exp_003', 'title': 'Food & Drinks', 'amount': 3200, 'category': 'Food', 'date': '2024-12-09', 'currency': 'INR'},
    {'id': 'exp_004', 'title': 'Local Transport', 'amount': 1200, 'category': 'Transport', 'date': '2024-12-09', 'currency': 'INR'},
  ];

  static const Map<String, dynamic> budgetReport = {
    'tripName': 'Thailand Adventure',
    'totalBudget': 50000,
    'totalSpent': 32400,
    'savings': 17600,
    'currency': 'INR',
  };

  static const List<Map<String, dynamic>> categorySpending = [
    {'category': 'Flights', 'amount': 14500, 'percentage': 29.0, 'color': 'primary'},
    {'category': 'Hotel', 'amount': 12000, 'percentage': 24.0, 'color': 'success'},
    {'category': 'Activities', 'amount': 11000, 'percentage': 22.0, 'color': 'teal'},
    {'category': 'Food', 'amount': 8000, 'percentage': 16.0, 'color': 'purple'},
    {'category': 'Shopping', 'amount': 4000, 'percentage': 8.0, 'color': 'warning'},
  ];

  static const List<Map<String, dynamic>> dailySpending = [
    {'day': 'Day 1', 'amount': 2500},
    {'day': 'Day 2', 'amount': 1800},
    {'day': 'Day 3', 'amount': 3200},
    {'day': 'Day 4', 'amount': 2800},
    {'day': 'Day 5', 'amount': 3500},
    {'day': 'Day 6', 'amount': 2200},
    {'day': 'Day 7', 'amount': 4100},
    {'day': 'Day 8', 'amount': 2900},
    {'day': 'Day 9', 'amount': 3600},
    {'day': 'Day 10', 'amount': 3200},
  ];

  // ── Packing ───────────────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> packingLists = [
    {
      'id': 'list_001',
      'name': 'Beach Trip Essentials',
      'destination': 'Goa',
      'items': [
        {'name': 'Swimwear', 'packed': true},
        {'name': 'Sunscreen', 'packed': false},
        {'name': 'Beach Towel', 'packed': true},
        {'name': 'Flip Flops', 'packed': true},
      ],
    },
    {
      'id': 'list_002',
      'name': 'Mountain Trek Gear',
      'destination': 'Kashmir',
      'items': [
        {'name': 'Hiking Boots', 'packed': true},
        {'name': 'Thermal Jacket', 'packed': false},
        {'name': 'Water Bottle', 'packed': true},
        {'name': 'First Aid Kit', 'packed': false},
      ],
    },
  ];

  // ── Hidden Gems ───────────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> hiddenGems = [
    {
      'id': 'gem_001',
      'name': 'Secret Beach Cove',
      'location': 'Palolem, Goa',
      'description': 'A hidden beach accessible only by boat, perfect for snorkeling.',
      'rating': 4.8,
      'reviews': 127,
      'coordinates': {'lat': 15.0100, 'lng': 74.0230},
    },
    {
      'id': 'gem_002',
      'name': 'Ancient Temple Ruins',
      'location': 'Hampi, Karnataka',
      'description': 'Forgotten temple ruins dating back to the Vijayanagara Empire.',
      'rating': 4.6,
      'reviews': 89,
      'coordinates': {'lat': 15.3350, 'lng': 76.4600},
    },
    {
      'id': 'gem_003',
      'name': 'Mountain Viewpoint',
      'location': 'Coorg, Karnataka',
      'description': 'Breathtaking sunrise views over the Western Ghats.',
      'rating': 4.9,
      'reviews': 203,
      'coordinates': {'lat': 12.4200, 'lng': 75.7400},
    },
  ];
}
