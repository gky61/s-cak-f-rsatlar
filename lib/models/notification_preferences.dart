import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPreferences {
  final bool pushMasterEnabled;
  final bool dealNotificationsEnabled;
  final bool categoryNotificationsEnabled;
  final bool keywordNotificationsEnabled;
  final bool communityNotificationsEnabled;
  final bool submissionStatusNotificationsEnabled;
  final bool marketingNotificationsEnabled;
  final bool quietHoursEnabled;
  final String quietHoursStart; // "HH:mm"
  final String quietHoursEnd; // "HH:mm"
  final String timezone;
  final DateTime updatedAt;
  final int schemaVersion;
  final Map<String, bool> lastStates;

  NotificationPreferences({
    this.pushMasterEnabled = true,
    this.dealNotificationsEnabled = true,
    this.categoryNotificationsEnabled = true,
    this.keywordNotificationsEnabled = true,
    this.communityNotificationsEnabled = true,
    this.submissionStatusNotificationsEnabled = true,
    this.marketingNotificationsEnabled = false,
    this.quietHoursEnabled = false,
    this.quietHoursStart = "23:00",
    this.quietHoursEnd = "08:00",
    this.timezone = "Europe/Istanbul",
    required this.updatedAt,
    this.schemaVersion = 1,
    this.lastStates = const {},
  });

  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return NotificationPreferences.defaultPreferences();
    }
    final data = doc.data() as Map<String, dynamic>;
    
    final rawLastStates = data['lastStates'] as Map<String, dynamic>? ?? {};
    final Map<String, bool> parsedLastStates = {};
    rawLastStates.forEach((key, value) {
      if (value is bool) {
        parsedLastStates[key] = value;
      }
    });

    return NotificationPreferences(
      pushMasterEnabled: data['pushMasterEnabled'] ?? true,
      dealNotificationsEnabled: data['dealNotificationsEnabled'] ?? true,
      categoryNotificationsEnabled: data['categoryNotificationsEnabled'] ?? true,
      keywordNotificationsEnabled: data['keywordNotificationsEnabled'] ?? true,
      communityNotificationsEnabled: data['communityNotificationsEnabled'] ?? true,
      submissionStatusNotificationsEnabled: data['submissionStatusNotificationsEnabled'] ?? true,
      marketingNotificationsEnabled: data['marketingNotificationsEnabled'] ?? false,
      quietHoursEnabled: data['quietHoursEnabled'] ?? false,
      quietHoursStart: data['quietHoursStart'] ?? "23:00",
      quietHoursEnd: data['quietHoursEnd'] ?? "08:00",
      timezone: data['timezone'] ?? "Europe/Istanbul",
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      schemaVersion: data['schemaVersion'] ?? 1,
      lastStates: parsedLastStates,
    );
  }

  factory NotificationPreferences.defaultPreferences() {
    return NotificationPreferences(
      pushMasterEnabled: true,
      dealNotificationsEnabled: true,
      categoryNotificationsEnabled: true,
      keywordNotificationsEnabled: true,
      communityNotificationsEnabled: true,
      submissionStatusNotificationsEnabled: true,
      marketingNotificationsEnabled: false,
      quietHoursEnabled: false,
      quietHoursStart: "23:00",
      quietHoursEnd: "08:00",
      timezone: "Europe/Istanbul",
      updatedAt: DateTime.now(),
      schemaVersion: 1,
      lastStates: const {
        'dealNotificationsEnabled': true,
        'categoryNotificationsEnabled': true,
        'keywordNotificationsEnabled': true,
        'communityNotificationsEnabled': true,
        'submissionStatusNotificationsEnabled': true,
        'marketingNotificationsEnabled': false,
        'quietHoursEnabled': false,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pushMasterEnabled': pushMasterEnabled,
      'dealNotificationsEnabled': dealNotificationsEnabled,
      'categoryNotificationsEnabled': categoryNotificationsEnabled,
      'keywordNotificationsEnabled': keywordNotificationsEnabled,
      'communityNotificationsEnabled': communityNotificationsEnabled,
      'submissionStatusNotificationsEnabled': submissionStatusNotificationsEnabled,
      'marketingNotificationsEnabled': marketingNotificationsEnabled,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'timezone': timezone,
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
      'lastStates': lastStates,
    };
  }
}
