import 'package:cloud_firestore/cloud_firestore.dart';

// ─── HIDDEN GEM MODEL ─────────────────────────────────────────────────────────

class GemModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final GeoPoint location;
  final String city;
  final String country;
  final List<String> photos;
  final String addedBy;
  final int upvotes;
  final int downvotes;
  final bool isVerified;
  final double averageRating;
  final int ratingCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.location,
    required this.city,
    required this.country,
    this.photos = const [],
    required this.addedBy,
    this.upvotes = 0,
    this.downvotes = 0,
    this.isVerified = false,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GemModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GemModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: d['category'] as String? ?? 'Other',
      location: d['location'] as GeoPoint? ??
          const GeoPoint(0, 0),
      city: d['city'] as String? ?? '',
      country: d['country'] as String? ?? '',
      photos: List<String>.from(d['photos'] as List? ?? []),
      addedBy: d['addedBy'] as String? ?? '',
      upvotes: d['upvotes'] as int? ?? 0,
      downvotes: d['downvotes'] as int? ?? 0,
      isVerified: d['isVerified'] as bool? ?? false,
      averageRating: (d['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: d['ratingCount'] as int? ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'location': location,
      'city': city,
      'country': country,
      'photos': photos,
      'addedBy': addedBy,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'isVerified': isVerified,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
