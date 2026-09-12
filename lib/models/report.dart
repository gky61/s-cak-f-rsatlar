import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String reportedId; // ID of the deal, comment, user, or message
  final String reportedBy; // User ID of the reporter
  final String type; // 'deal', 'comment', 'user', 'message'
  final String reason;
  final String? description;
  final String? targetDealId;
  final String? targetContent;
  final String? targetAuthor;
  final String? targetAuthorId;
  final DateTime createdAt;
  final String status; // 'pending', 'action_taken', 'dismissed'
  final String? actionType;
  final String? actionNote;
  final DateTime? resolvedAt;

  Report({
    required this.id,
    required this.reportedId,
    required this.reportedBy,
    required this.type,
    required this.reason,
    this.description,
    this.targetDealId,
    this.targetContent,
    this.targetAuthor,
    this.targetAuthorId,
    required this.createdAt,
    this.status = 'pending',
    this.actionType,
    this.actionNote,
    this.resolvedAt,
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Report(
      id: doc.id,
      reportedId: data['reportedId'] as String? ?? '',
      reportedBy: data['reportedBy'] as String? ?? '',
      type: data['type'] as String? ?? 'unknown',
      reason: data['reason'] as String? ?? '',
      description: data['description'] as String?,
      targetDealId: data['targetDealId'] as String?,
      targetContent: data['targetContent'] as String?,
      targetAuthor: data['targetAuthor'] as String?,
      targetAuthorId: data['targetAuthorId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      actionType: data['actionType'] as String?,
      actionNote: data['actionNote'] as String?,
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reportedId': reportedId,
      'reportedBy': reportedBy,
      'type': type,
      'reason': reason,
      'description': description,
      if (targetDealId != null) 'targetDealId': targetDealId,
      if (targetContent != null) 'targetContent': targetContent,
      if (targetAuthor != null) 'targetAuthor': targetAuthor,
      if (targetAuthorId != null) 'targetAuthorId': targetAuthorId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': status,
      if (actionType != null) 'actionType': actionType,
      if (actionNote != null) 'actionNote': actionNote,
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
    };
  }
}
