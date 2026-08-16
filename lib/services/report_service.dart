import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/report.dart';
import 'auth_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Koleksiyon referansı
  CollectionReference get _reportsCollection => _firestore.collection('reports');

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
        'status': 'pending', // pending, reviewed, dismissed, action_taken
      };

      await reportDocRef.set(reportData);
      
      if (kDebugMode) print('✅ Rapor başarıyla oluşturuldu: $type - $reportedId');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Rapor oluşturma hatası: $e');
      return false;
    }
  }

  /// Belirli bir türdeki raporları getirir (Admin paneli için kullanılabilir)
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
}
