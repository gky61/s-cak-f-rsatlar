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
    required String type, // 'deal', 'comment', 'user'
    required String reason,
    String? description,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Rapor oluşturmak için giriş yapmalısınız.');
      }

      // Aynı kullanıcı aynı içeriği daha önce raporlamış mı kontrol et
      // Bu sorgu index gerektirebilir, şimdilik basit tutuyoruz.
      // İleride performans sorunu olursa: reportedId_reportedBy kombinasyonu ile doc ID oluşturulabilir.
      final existingReports = await _reportsCollection
          .where('reportedId', isEqualTo: reportedId)
          .where('reportedBy', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existingReports.docs.isNotEmpty) {
        // Zaten raporlamış, spam'i önlemek için başarılı dönelim ama işlem yapmayalım
        if (kDebugMode) print('⚠️ Kullanıcı bu içeriği zaten raporlamış.');
        return true;
      }

      final reportData = {
        'reportedId': reportedId,
        'reportedBy': user.uid,
        'type': type, // deal, comment, user
        'reason': reason,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewed, dismissed, action_taken
      };

      await _reportsCollection.add(reportData);
      
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
    
    // Index oluşturulana kadar sıralamayı kaldırıyoruz.
    // Index oluşturulunca: return query.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
    return query.snapshots().map((snapshot) {
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
