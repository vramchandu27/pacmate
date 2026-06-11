import 'package:cloud_firestore/cloud_firestore.dart';

// ─── USER MODEL ───────────────────────────────────────────────────────────────

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String? photoUrl;
  final String homeCountry;
  final String currency;
  final String travelStyle;   // budget / mid / luxury
  final String travelType;    // solo / couple / family / group
  final bool seniorMode;
  final bool familyMode;
  final bool isPro;
  final String plan;          // free / explorer / pro
  final String? fcmToken;
  final GeoPoint? location;
  final bool isOnline;
  final bool profileComplete;
  final int totalTrips;
  final DateTime createdAt;
  final DateTime lastSeen;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    this.photoUrl,
    this.homeCountry = 'India',
    this.currency = 'INR',
    this.travelStyle = 'budget',
    this.travelType = 'solo',
    this.seniorMode = false,
    this.familyMode = false,
    this.isPro = false,
    this.plan = 'free',
    this.fcmToken,
    this.location,
    this.isOnline = false,
    this.profileComplete = false,
    this.totalTrips = 0,
    required this.createdAt,
    required this.lastSeen,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] as String? ?? doc.id,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      homeCountry: data['homeCountry'] as String? ?? 'India',
      currency: data['currency'] as String? ?? 'INR',
      travelStyle: data['travelStyle'] as String? ?? 'budget',
      travelType: data['travelType'] as String? ?? 'solo',
      seniorMode: data['seniorMode'] as bool? ?? false,
      familyMode: data['familyMode'] as bool? ?? false,
      isPro: data['isPro'] as bool? ?? false,
      plan: data['plan'] as String? ?? 'free',
      fcmToken: data['fcmToken'] as String?,
      location: data['location'] as GeoPoint?,
      isOnline: data['isOnline'] as bool? ?? false,
      profileComplete: data['profileComplete'] as bool? ?? false,
      totalTrips: data['totalTrips'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'photoUrl': photoUrl,
      'homeCountry': homeCountry,
      'currency': currency,
      'travelStyle': travelStyle,
      'travelType': travelType,
      'seniorMode': seniorMode,
      'familyMode': familyMode,
      'isPro': isPro,
      'plan': plan,
      'fcmToken': fcmToken,
      'location': location,
      'isOnline': isOnline,
      'profileComplete': profileComplete,
      'totalTrips': totalTrips,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
    };
  }

  UserModel copyWith({
    String? fullName,
    String? photoUrl,
    String? homeCountry,
    String? currency,
    String? travelStyle,
    String? travelType,
    bool? seniorMode,
    bool? familyMode,
    bool? isPro,
    String? plan,
    String? fcmToken,
    GeoPoint? location,
    bool? isOnline,
    bool? profileComplete,
    int? totalTrips,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      homeCountry: homeCountry ?? this.homeCountry,
      currency: currency ?? this.currency,
      travelStyle: travelStyle ?? this.travelStyle,
      travelType: travelType ?? this.travelType,
      seniorMode: seniorMode ?? this.seniorMode,
      familyMode: familyMode ?? this.familyMode,
      isPro: isPro ?? this.isPro,
      plan: plan ?? this.plan,
      fcmToken: fcmToken ?? this.fcmToken,
      location: location ?? this.location,
      isOnline: isOnline ?? this.isOnline,
      profileComplete: profileComplete ?? this.profileComplete,
      totalTrips: totalTrips ?? this.totalTrips,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
