import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/report.dart';
import '../models/admin_moderation_alarm.dart';
import 'auth_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Koleksiyon referansları
  CollectionReference get _reportsCollection => _firestore.collection('reports');
  CollectionReference get _adminMessagesCollection => _firestore.collection('adminMessages');

  /// Yeni bir rapor oluşturur
  Future<bool> submitReport({
    required String reportedId,
    required String type, // 'deal', 'comment', 'user', 'message'
    required String reason,
    String? description,
    String? targetDealId,
    String? targetContent,
    String? targetAuthor,
    String? targetAuthorId,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Rapor oluşturmak için giriş yapmalısınız.');
      }

      // Aynı kullanıcının aynı içeriğe mükerrer rapor açmasını önlemek için deterministik ID kullan
      final docId = '${reportedId}_${user.uid}';
      final reportDocRef = _reportsCollection.doc(docId);
      final existingDoc = await reportDocRef.get();

      if (existingDoc.exists) {
        if (kDebugMode) print('⚠️ Kullanıcı bu içeriği zaten raporlamış.');
        return true;
      }

      final reportData = <String, dynamic>{
        'reportedId': reportedId,
        'reportedBy': user.uid,
        'type': type, // deal, comment, user, message
        'reason': reason,
        'description': description ?? '',
        if (targetDealId != null) 'targetDealId': targetDealId,
        if (targetContent != null) 'targetContent': targetContent,
        if (targetAuthor != null) 'targetAuthor': targetAuthor,
        if (targetAuthorId != null) 'targetAuthorId': targetAuthorId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, action_taken, dismissed
      };

      await reportDocRef.set(reportData);
      
      if (kDebugMode) print('✅ Rapor başarıyla oluşturuldu: $type - $reportedId');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Rapor oluşturma hatası: $e');
      return false;
    }
  }

  /// En son şikayetleri dinleyen stream (Web Admin gibi son 100 rapor, yerel filtreleme için ideal)
  Stream<List<Report>> getRecentReportsStream({int limit = 100}) {
    return _reportsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();
    });
  }

  /// Belirli bir tür veya durumdaki raporları getirir (Geriye dönük uyumluluk için)
  Stream<List<Report>> getReportsStream({String? type, String status = 'pending'}) {
    Query query = _reportsCollection.where('status', isEqualTo: status);
    
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    
    return query.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();
    });
  }

  /// Rapor durumunu günceller
  Future<bool> updateReportStatus(String reportId, String status) async {
    try {
      await _reportsCollection.doc(reportId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Rapor durumu güncelleme hatası: $e');
      return false;
    }
  }

  /// Şikayeti yoksay / kapat
  Future<bool> dismissReport(String reportId) async {
    try {
      await _reportsCollection.doc(reportId).update({
        'status': 'dismissed',
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Rapor yoksayma hatası: $e');
      return false;
    }
  }

  /// Şikayet için işlem yap ve kapat
  Future<bool> executeReportAction({
    required String reportId,
    required String actionType,
    String? actionNote,
  }) async {
    try {
      await _reportsCollection.doc(reportId).update({
        'status': 'action_taken',
        'actionType': actionType,
        'actionNote': actionNote ?? '',
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Rapor aksiyon tamamlama hatası: $e');
      return false;
    }
  }

  // ============================================================================
  // 🚨 OTOMATİK MODERASYON ALARMLARI (adminMessages)
  // ============================================================================

  /// Otomatik moderasyon alarmlarını dinleyen stream
  Stream<List<AdminModerationAlarm>> getAutoModAlarmsStream({int limit = 150}) {
    return _adminMessagesCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AdminModerationAlarm.fromFirestore(doc)).toList();
    });
  }

  /// Alarmı incelendi olarak işaretle
  Future<bool> markAutoModAlarmAsRead(String alarmId) async {
    try {
      await _adminMessagesCollection.doc(alarmId).update({
        'isRead': true,
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Alarm okundu işaretleme hatası: $e');
      return false;
    }
  }

  /// Belirli bir alarmı sil
  Future<bool> deleteAutoModAlarm(String alarmId) async {
    try {
      await _adminMessagesCollection.doc(alarmId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Alarm silme hatası: $e');
      return false;
    }
  }

  /// Tüm moderasyon alarmlarını temizle
  Future<bool> deleteAllAutoModAlarms() async {
    try {
      final snapshot = await _adminMessagesCollection.get();
      if (snapshot.docs.isEmpty) return true;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Tüm alarmları silme hatası: $e');
      return false;
    }
  }

  /// Yorum ve fırsat bilgilerini sorgula (İnceleme ekranı için yardımcı)
  Future<Map<String, dynamic>?> findCommentAndParent(String commentId, String? targetDealId) async {
    try {
      if (targetDealId != null && targetDealId.isNotEmpty) {
        final doc = await _firestore
            .collection('deals')
            .doc(targetDealId)
            .collection('comments')
            .doc(commentId)
            .get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          return {
            'id': doc.id,
            'content': data['content'] ?? data['text'] ?? '',
            'userId': data['userId'] ?? '',
            'userName': data['userName'] ?? 'Kullanıcı',
            'dealId': targetDealId,
          };
        }
      }

      // targetDealId yoksa collectionGroup ile ara
      final querySnap = await _firestore
          .collectionGroup('comments')
          .get();
      for (final doc in querySnap.docs) {
        if (doc.id == commentId) {
          final data = doc.data();
          final parentDealId = doc.reference.parent.parent?.id ?? '';
          return {
            'id': doc.id,
            'content': data['content'] ?? data['text'] ?? '',
            'userId': data['userId'] ?? '',
            'userName': data['userName'] ?? 'Kullanıcı',
            'dealId': parentDealId,
          };
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Yorum arama hatası: $e');
      return null;
    }
  }
}
