import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String reportedId; // ID of the deal, comment, or user being reported
  final String reportedBy; // User ID of the reporter
  final String type; // 'deal', 'comment', 'user'
  final String reason;
  final String? description;
  final DateTime createdAt;
  final String status; // 'pending', 'reviewed', 'dismissed'

  Report({
    required this.id,
    required this.reportedId,
    required this.reportedBy,
    required this.type,
    required this.reason,
    this.description,
    required this.createdAt,
    this.status = 'pending',
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      reportedId: data['reportedId'] ?? '',
      reportedBy: data['reportedBy'] ?? '',
      type: data['type'] ?? 'unknown',
      reason: data['reason'] ?? '',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reportedId': reportedId,
      'reportedBy': reportedBy,
      'type': type,
      'reason': reason,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      'status': status,
    };
  }
}
