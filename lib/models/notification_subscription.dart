import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionType {
  keyword,
  category,
  author;

  String toJson() => name;

  static SubscriptionType fromJson(String value) {
    return SubscriptionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SubscriptionType.keyword,
    );
  }
}

class NotificationSubscription {
  final String id; // Deterministic: {uid}_{type}_{keyHash}
  final String uid;
  final SubscriptionType type;
  final String key;
  final String displayValue;
  final String normalizedValue;
  final bool includeDescendants;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationSubscription({
    required this.id,
    required this.uid,
    required this.type,
    required this.key,
    required this.displayValue,
    required this.normalizedValue,
    this.includeDescendants = true,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationSubscription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationSubscription(
      id: doc.id,
      uid: data['uid'] ?? '',
      type: SubscriptionType.fromJson(data['type'] ?? 'keyword'),
      key: data['key'] ?? '',
      displayValue: data['displayValue'] ?? '',
      normalizedValue: data['normalizedValue'] ?? '',
      includeDescendants: data['includeDescendants'] ?? true,
      enabled: data['enabled'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'type': type.toJson(),
      'key': key,
      'displayValue': displayValue,
      'normalizedValue': normalizedValue,
      'includeDescendants': includeDescendants,
      'enabled': enabled,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
