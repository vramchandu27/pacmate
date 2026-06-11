import 'package:cloud_firestore/cloud_firestore.dart';

// ─── NOTIFICATION MODEL (Firestore-backed) ────────────────────────────────────

enum NotificationType {
  medicine,
  sos,
  familyAlert,
  chat,
  tripReminder,
  gemAdded,
  system,
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final String? actionRoute;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    this.actionRoute,
    this.metadata = const {},
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      type: _parseType(d['type'] as String?),
      isRead: d['isRead'] as bool? ?? false,
      actionRoute: d['actionRoute'] as String?,
      metadata: Map<String, dynamic>.from(d['metadata'] as Map? ?? {}),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'title': title,
        'body': body,
        'type': type.name,
        'isRead': isRead,
        'actionRoute': actionRoute,
        'metadata': metadata,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        isRead: isRead ?? this.isRead,
        actionRoute: actionRoute,
        metadata: metadata,
        createdAt: createdAt,
      );

  static NotificationType _parseType(String? raw) {
    return NotificationType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => NotificationType.system,
    );
  }
}
