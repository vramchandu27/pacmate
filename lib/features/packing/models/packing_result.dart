// ─── PACKING ENGINE OUTPUT ────────────────────────────────────────────────────

class PackingItem {
  const PackingItem({
    required this.name,
    required this.category,
    this.quantity = 1,
    this.isImportant = false,
  });

  final String name;
  final String category;
  final int quantity;

  /// Important items are highlighted in the UI (passport, medicines, charger).
  final bool isImportant;

  Map<String, dynamic> toMap() => {
        'name': quantity > 1 ? '$name (×$quantity)' : name,
        'category': category,
        'quantity': quantity,
        'isImportant': isImportant,
        'checked': false,
      };
}

class PackingResult {
  const PackingResult({
    required this.clothing,
    required this.essentials,
    required this.toiletries,
    required this.electronics,
    required this.documents,
    required this.miscellaneous,
  });

  final List<PackingItem> clothing;
  final List<PackingItem> essentials;
  final List<PackingItem> toiletries;
  final List<PackingItem> electronics;
  final List<PackingItem> documents;
  final List<PackingItem> miscellaneous;

  List<PackingItem> get all => [
        ...clothing,
        ...essentials,
        ...toiletries,
        ...electronics,
        ...documents,
        ...miscellaneous,
      ];

  /// Flat list of maps ready to store in Firestore.
  List<Map<String, dynamic>> toFirestoreItems() {
    int idx = 0;
    return all.map((item) {
      final map = Map<String, dynamic>.from(item.toMap());
      map['id'] = 'rule_${idx++}';
      return map;
    }).toList();
  }

  /// Structured JSON matching the spec.
  Map<String, List<String>> toJson() => {
        'clothing': clothing.map(_label).toList(),
        'essentials': essentials.map(_label).toList(),
        'toiletries': toiletries.map(_label).toList(),
        'electronics': electronics.map(_label).toList(),
        'documents': documents.map(_label).toList(),
        'miscellaneous': miscellaneous.map(_label).toList(),
      };

  static String _label(PackingItem i) =>
      i.quantity > 1 ? '${i.name} ×${i.quantity}' : i.name;
}
