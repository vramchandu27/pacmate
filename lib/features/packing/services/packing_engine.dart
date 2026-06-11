import '../models/packing_input.dart';
import '../models/packing_result.dart';

// ─── PACKING ENGINE ───────────────────────────────────────────────────────────
// Deterministic, rule-based packing list generator.
// No network calls — works fully offline.
// ─────────────────────────────────────────────────────────────────────────────

class PackingEngine {
  const PackingEngine._();

  // ── Public entry point ─────────────────────────────────────────────────────

  static PackingResult generate(PackingInput input) {
    final clothing = _buildClothing(input);
    final essentials = _buildEssentials(input);
    final toiletries = _buildToiletries(input.duration);
    final electronics = _buildElectronics(input);
    final documents = _buildDocuments(input);
    final misc = _buildMiscellaneous(input);

    return PackingResult(
      clothing: _dedup(clothing),
      essentials: _dedup(essentials),
      toiletries: _dedup(toiletries),
      electronics: _dedup(electronics),
      documents: _dedup(documents),
      miscellaneous: _dedup(misc),
    );
  }

  // ── Clothing ───────────────────────────────────────────────────────────────

  static List<PackingItem> _buildClothing(PackingInput input) {
    final items = <PackingItem>[
      PackingItem(name: 'Underwear', category: 'clothing'),
      PackingItem(name: 'Socks', category: 'clothing'),
    ];

    items.addAll(getClothingByTemperature(input.temperature));
    items.addAll(getWeatherExtras(input.weatherCondition));
    items.addAll(getTripTypeClothing(input.tripType));

    return items;
  }

  /// Temperature-based clothing selection.
  static List<PackingItem> getClothingByTemperature(double temp) {
    if (temp > 30) {
      return [
        PackingItem(name: 'T-Shirts', category: 'clothing'),
        PackingItem(name: 'Shorts', category: 'clothing'),
        PackingItem(name: 'Sunglasses', category: 'clothing'),
        PackingItem(name: 'Sun Hat / Cap', category: 'clothing'),
        PackingItem(name: 'Light Sandals', category: 'clothing'),
      ];
    } else if (temp >= 15) {
      return [
        PackingItem(name: 'Shirts / Tops', category: 'clothing'),
        PackingItem(name: 'Jeans / Trousers', category: 'clothing'),
        PackingItem(name: 'Light Jacket', category: 'clothing'),
        PackingItem(name: 'Comfortable Shoes', category: 'clothing'),
      ];
    } else {
      return [
        PackingItem(name: 'Thermal Base Layer', category: 'clothing'),
        PackingItem(name: 'Heavy Trousers', category: 'clothing'),
        PackingItem(name: 'Heavy Winter Jacket', category: 'clothing'),
        PackingItem(name: 'Gloves', category: 'clothing'),
        PackingItem(name: 'Woollen Cap / Beanie', category: 'clothing'),
        PackingItem(name: 'Scarf', category: 'clothing'),
        PackingItem(name: 'Warm Boots', category: 'clothing'),
        PackingItem(name: 'Thermal Leggings', category: 'clothing'),
      ];
    }
  }

  /// Weather-condition extras on top of temperature clothing.
  static List<PackingItem> getWeatherExtras(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.rainy:
        return [
          PackingItem(name: 'Umbrella', category: 'clothing'),
          PackingItem(name: 'Raincoat / Poncho', category: 'clothing'),
          PackingItem(name: 'Waterproof Shoes', category: 'clothing'),
        ];
      case WeatherCondition.snowy:
        return [
          PackingItem(name: 'Snow Boots', category: 'clothing'),
          PackingItem(name: 'Heavy Waterproof Jacket', category: 'clothing'),
          PackingItem(name: 'Thermal Gloves', category: 'clothing'),
          PackingItem(name: 'Hand Warmers', category: 'miscellaneous'),
        ];
      case WeatherCondition.sunny:
        return [
          PackingItem(name: 'Sunscreen SPF 50+', category: 'essentials',
              isImportant: true),
          PackingItem(name: 'Lip Balm with SPF', category: 'essentials'),
        ];
      case WeatherCondition.cloudy:
        return [
          PackingItem(name: 'Light Jacket', category: 'clothing'),
        ];
    }
  }

  /// Trip-type specific clothing.
  static List<PackingItem> getTripTypeClothing(TripType type) {
    switch (type) {
      case TripType.beach:
        return [
          PackingItem(name: 'Swimwear', category: 'clothing'),
          PackingItem(name: 'Flip Flops', category: 'clothing'),
          PackingItem(name: 'Beach Cover-Up', category: 'clothing'),
          PackingItem(name: 'Rash Guard', category: 'clothing'),
        ];
      case TripType.business:
        return [
          PackingItem(name: 'Formal Shirts', category: 'clothing'),
          PackingItem(name: 'Formal Trousers / Skirt', category: 'clothing'),
          PackingItem(name: 'Formal Shoes', category: 'clothing'),
          PackingItem(name: 'Blazer / Suit Jacket', category: 'clothing'),
          PackingItem(name: 'Tie / Belt', category: 'clothing'),
        ];
      case TripType.trekking:
        return [
          PackingItem(name: 'Moisture-Wicking T-Shirts', category: 'clothing'),
          PackingItem(name: 'Trekking Trousers', category: 'clothing'),
          PackingItem(name: 'Trekking Shoes / Boots', category: 'clothing'),
          PackingItem(name: 'Gaiters', category: 'clothing'),
          PackingItem(name: 'Quick-Dry Towel', category: 'clothing'),
        ];
      case TripType.vacation:
        return [
          PackingItem(name: 'Casual Shoes / Sneakers', category: 'clothing'),
          PackingItem(name: 'Smart-Casual Outfit', category: 'clothing'),
        ];
    }
  }

  // ── Essentials ─────────────────────────────────────────────────────────────

  static List<PackingItem> _buildEssentials(PackingInput input) {
    final items = [
      PackingItem(
          name: 'Prescription Medicines',
          category: 'essentials',
          isImportant: true),
      PackingItem(
          name: 'Basic First Aid Kit',
          category: 'essentials',
          isImportant: true),
      PackingItem(name: 'Paracetamol / Pain Reliever', category: 'essentials'),
      PackingItem(name: 'Antacids', category: 'essentials'),
      PackingItem(name: 'Hand Sanitizer', category: 'essentials'),
      PackingItem(name: 'Face Mask (x5)', category: 'essentials'),
      PackingItem(name: 'Reusable Water Bottle', category: 'essentials'),
      PackingItem(name: 'Insect Repellent', category: 'essentials'),
    ];

    // Trip-type extras
    if (input.tripType == TripType.trekking) {
      items.addAll([
        PackingItem(name: 'Trekking Backpack (40–60L)', category: 'essentials',
            isImportant: true),
        PackingItem(name: 'Water Purification Tablets', category: 'essentials'),
        PackingItem(name: 'Energy Bars / Trail Mix', category: 'essentials'),
        PackingItem(name: 'Blister Plasters', category: 'essentials'),
        PackingItem(name: 'Trekking Poles', category: 'essentials'),
        PackingItem(name: 'Headlamp + Extra Batteries', category: 'essentials'),
      ]);
    }

    if (input.tripType == TripType.beach) {
      items.addAll([
        PackingItem(name: 'Sunscreen SPF 50+', category: 'essentials',
            isImportant: true),
        PackingItem(name: 'After-Sun Lotion', category: 'essentials'),
        PackingItem(name: 'Waterproof Bag / Dry Bag', category: 'essentials'),
      ]);
    }

    if (input.tripType == TripType.business) {
      items.addAll([
        PackingItem(name: 'Business Cards', category: 'essentials'),
        PackingItem(name: 'Notebook & Pen', category: 'essentials'),
        PackingItem(name: 'Laptop Bag / Briefcase', category: 'essentials',
            isImportant: true),
      ]);
    }

    return items;
  }

  // ── Toiletries ─────────────────────────────────────────────────────────────

  static List<PackingItem> _buildToiletries(int duration) {
    // Use travel-size for short trips; full-size reminder for long ones
    final sizeNote = duration <= 3 ? ' (travel size)' : '';
    return [
      PackingItem(name: 'Toothbrush', category: 'toiletries'),
      PackingItem(name: 'Toothpaste$sizeNote', category: 'toiletries'),
      PackingItem(name: 'Shampoo$sizeNote', category: 'toiletries'),
      PackingItem(name: 'Conditioner$sizeNote', category: 'toiletries'),
      PackingItem(name: 'Body Wash / Soap$sizeNote', category: 'toiletries'),
      PackingItem(name: 'Deodorant', category: 'toiletries'),
      PackingItem(name: 'Moisturizer$sizeNote', category: 'toiletries'),
      PackingItem(name: 'Razor / Shaving Kit', category: 'toiletries'),
      PackingItem(name: 'Comb / Hair Brush', category: 'toiletries'),
      PackingItem(name: 'Nail Cutter', category: 'toiletries'),
      if (duration > 3) PackingItem(name: 'Laundry Bag', category: 'toiletries'),
      if (duration > 7)
        PackingItem(name: 'Travel Laundry Detergent', category: 'toiletries'),
    ];
  }

  // ── Electronics ────────────────────────────────────────────────────────────

  static List<PackingItem> _buildElectronics(PackingInput input) {
    final items = [
      PackingItem(name: 'Phone Charger', category: 'electronics',
          isImportant: true),
      PackingItem(name: 'Power Bank', category: 'electronics', isImportant: true),
      PackingItem(name: 'Universal Travel Adapter', category: 'electronics'),
      PackingItem(name: 'Earphones / Headphones', category: 'electronics'),
    ];

    if (input.tripType == TripType.business) {
      items.addAll([
        PackingItem(name: 'Laptop', category: 'electronics', isImportant: true),
        PackingItem(name: 'Laptop Charger', category: 'electronics',
            isImportant: true),
        PackingItem(name: 'USB-C Hub / Dongle', category: 'electronics'),
        PackingItem(name: 'Portable Mouse', category: 'electronics'),
        PackingItem(name: 'Presentation Clicker', category: 'electronics'),
      ]);
    }

    if (input.tripType == TripType.trekking) {
      items.addAll([
        PackingItem(name: 'Offline GPS Device / Downloaded Maps',
            category: 'electronics'),
        PackingItem(name: 'Solar Charger', category: 'electronics'),
      ]);
    }

    if (input.tripType == TripType.beach || input.tripType == TripType.vacation) {
      items.addAll([
        PackingItem(name: 'Camera / GoPro', category: 'electronics'),
        PackingItem(name: 'Waterproof Phone Case', category: 'electronics'),
      ]);
    }

    return items;
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  static List<PackingItem> _buildDocuments(PackingInput input) {
    return [
      PackingItem(name: 'Passport', category: 'documents', isImportant: true),
      PackingItem(name: 'Visa / e-Visa Printout', category: 'documents',
          isImportant: true),
      PackingItem(name: 'Flight / Train Tickets', category: 'documents',
          isImportant: true),
      PackingItem(name: 'Hotel Booking Confirmation', category: 'documents',
          isImportant: true),
      PackingItem(name: 'Travel Insurance Certificate', category: 'documents',
          isImportant: true),
      PackingItem(name: 'Government-issued Photo ID', category: 'documents',
          isImportant: true),
      PackingItem(name: 'Emergency Contact Card', category: 'documents'),
      PackingItem(name: 'Foreign Currency / Cash', category: 'documents',
          isImportant: true),
      PackingItem(name: 'Credit / Debit Card', category: 'documents',
          isImportant: true),
      if (input.tripType == TripType.business)
        PackingItem(name: 'Invitation / Conference Letter', category: 'documents',
            isImportant: true),
      if (input.tripType == TripType.trekking)
        PackingItem(name: 'Trek Permit / Park Entry Pass', category: 'documents',
            isImportant: true),
    ];
  }

  // ── Miscellaneous ──────────────────────────────────────────────────────────

  static List<PackingItem> _buildMiscellaneous(PackingInput input) {
    final items = [
      PackingItem(name: 'Padlock for Bags', category: 'miscellaneous'),
      PackingItem(name: 'Packing Cubes', category: 'miscellaneous'),
      PackingItem(name: 'Ziplock Bags (assorted)', category: 'miscellaneous'),
      PackingItem(name: 'Eye Mask & Earplugs', category: 'miscellaneous'),
      PackingItem(name: 'Neck Pillow', category: 'miscellaneous'),
      PackingItem(name: 'Snacks for Journey', category: 'miscellaneous'),
    ];

    if (input.tripType == TripType.trekking) {
      items.addAll([
        PackingItem(name: 'Emergency Whistle', category: 'miscellaneous'),
        PackingItem(name: 'Compact Sleeping Bag', category: 'miscellaneous'),
        PackingItem(name: 'Tarp / Emergency Blanket', category: 'miscellaneous'),
        PackingItem(name: 'Multi-tool / Swiss Army Knife',
            category: 'miscellaneous'),
        PackingItem(name: 'Map & Compass', category: 'miscellaneous'),
      ]);
    }

    if (input.tripType == TripType.beach) {
      items.addAll([
        PackingItem(name: 'Beach Towel', category: 'miscellaneous'),
        PackingItem(name: 'Snorkelling Mask', category: 'miscellaneous'),
      ]);
    }

    if (input.duration > 14) {
      items.add(PackingItem(
          name: 'Portable Clothes Drying Rack', category: 'miscellaneous'));
    }

    return items;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Remove exact-name duplicates; first occurrence wins (preserves isImportant).
  static List<PackingItem> _dedup(List<PackingItem> items) {
    final seen = <String>{};
    return items.where((i) => seen.add(i.name.toLowerCase())).toList();
  }
}

