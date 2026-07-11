import 'package:cloud_firestore/cloud_firestore.dart';

class UserDevice {
  final String id; // Deterministic: {uid}_{deviceId}
  final String uid;
  final String deviceId;
  final String platform; // "android", "ios", "web"
  final String fcmToken;
  final String permissionStatus; // "authorized", "denied", "notDetermined"
  final bool active;
  final DateTime lastSeenAt;
  final DateTime updatedAt;

  UserDevice({
    required this.id,
    required this.uid,
    required this.deviceId,
    required this.platform,
    required this.fcmToken,
    required this.permissionStatus,
    this.active = true,
    required this.lastSeenAt,
    required this.updatedAt,
  });

  factory UserDevice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserDevice(
      id: doc.id,
      uid: data['uid'] ?? '',
      deviceId: data['deviceId'] ?? '',
      platform: data['platform'] ?? '',
      fcmToken: data['fcmToken'] ?? '',
      permissionStatus: data['permissionStatus'] ?? 'notDetermined',
      active: data['active'] ?? true,
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'deviceId': deviceId,
      'platform': platform,
      'fcmToken': fcmToken,
      'permissionStatus': permissionStatus,
      'active': active,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
