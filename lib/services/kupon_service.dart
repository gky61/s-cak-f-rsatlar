import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kupon.dart';

class KuponlarPageResult {
  final List<Kupon> kuponlar;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool isFromCache;

  const KuponlarPageResult({
    required this.kuponlar,
    this.lastDocument,
    required this.hasMore,
    this.isFromCache = false,
  });
}

class KuponService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // FS-19: Kuponları sayfalı ve SWR önbellek destekli getirme
  // 100k kullanıcıda her oyda 100 dokümanlık broadcast okuma patlamasını ortadan kaldırır.
  Future<KuponlarPageResult> getKuponlarPaginated({
    int limit = 30,
    DocumentSnapshot? lastDocument,
    Source source = Source.serverAndCache,
  }) async {
    try {
      Query query = _firestore
          .collection('kuponlar')
          .where('durum', isEqualTo: 'aktif')
          .orderBy('olusturulmaTarihi', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get(GetOptions(source: source));
      final kuponlar = snapshot.docs.map((doc) => Kupon.fromFirestore(doc)).toList();
      final newLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      final hasMore = snapshot.docs.length >= limit;

      return KuponlarPageResult(
        kuponlar: kuponlar,
        lastDocument: newLastDoc,
        hasMore: hasMore,
        isFromCache: snapshot.metadata.isFromCache,
      );
    } catch (e) {
      return KuponlarPageResult(
        kuponlar: [],
        lastDocument: lastDocument,
        hasMore: false,
      );
    }
  }

  // Kuponları real-time dinleme (Maksimum 100 güncel onaylı kupon ile sınırlandırılmış güvenli akış)
  Stream<List<Kupon>> getKuponlarStream() {
    return _firestore
        .collection('kuponlar')
        .where('durum', isEqualTo: 'aktif')
        .orderBy('olusturulmaTarihi', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Kupon.fromFirestore(doc)).toList();
    });
  }

  // Onay bekleyen kuponları dinleme (Admin Paneli Moderasyon Akışı)
  Stream<List<Kupon>> getPendingKuponlarStream() {
    return _firestore
        .collection('kuponlar')
        .where('durum', isEqualTo: 'beklemede')
        .orderBy('olusturulmaTarihi', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Kupon.fromFirestore(doc)).toList();
    });
  }

  // Yeni kupon paylaşma (Varsayılan durum: 'beklemede' - Admin onayı gerektirir)
  Future<void> shareKupon({
    required String magazaAdi,
    required String baslik,
    required String aciklama,
    required String kuponKodu,
    required String paylasanKullaniciId,
    String paylasanKullaniciAdi = '',
    DateTime? bitisTarihi,
  }) async {
    final kupon = Kupon(
      id: '',
      magazaAdi: magazaAdi,
      baslik: baslik,
      aciklama: aciklama,
      kuponKodu: kuponKodu,
      olusturulmaTarihi: DateTime.now(),
      bitisTarihi: bitisTarihi,
      paylasanKullaniciId: paylasanKullaniciId,
      paylasanKullaniciAdi: paylasanKullaniciAdi,
      kaynakTipi: 'topluluk',
      sicakOySayisi: 0,
      sogukOySayisi: 0,
      durum: 'beklemede',
    );

    await _firestore.collection('kuponlar').add(kupon.toFirestore());
  }

  // Admin: Kupon Onaylama (durum: 'aktif' yapar, Cloud Function FCM bildirimini fırlatır)
  Future<bool> approveKupon({
    required String kuponId,
    required String adminId,
  }) async {
    try {
      await _firestore.collection('kuponlar').doc(kuponId).update({
        'durum': 'aktif',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // Admin: Kupon Reddetme (durum: 'reddedildi' yapar ve gerekçe ekler)
  Future<bool> rejectKupon({
    required String kuponId,
    required String adminId,
    required String reason,
  }) async {
    try {
      await _firestore.collection('kuponlar').doc(kuponId).update({
        'durum': 'reddedildi',
        'redNedeni': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // Kupon güncelleme
  Future<void> updateKupon({
    required String kuponId,
    required String magazaAdi,
    required String baslik,
    required String aciklama,
    required String kuponKodu,
    DateTime? bitisTarihi,
  }) async {
    await _firestore.collection('kuponlar').doc(kuponId).update({
      'magazaAdi': magazaAdi,
      'baslik': baslik,
      'aciklama': aciklama,
      'kuponKodu': kuponKodu,
      'bitisTarihi': bitisTarihi != null ? Timestamp.fromDate(bitisTarihi) : null,
    });
  }

  // Kupon silme
  Future<void> deleteKupon(String kuponId) async {
    await _firestore.collection('kuponlar').doc(kuponId).delete();
  }

  // Kupona oy verme işlemi (FS-08: Kilitsiz Atomik Pipeline & Alt Doküman İzolasyonu)
  Future<bool> setKuponVote({
    required String kuponId,
    required String userId,
    required String? targetVoteType, // "hot", "cold" veya null (kaldırma)
  }) async {
    final cleanKuponId = kuponId.trim();
    final cleanUserId = userId.trim();
    if (cleanKuponId.isEmpty || cleanUserId.isEmpty) {
      return false;
    }
    if (targetVoteType != null && targetVoteType != 'hot' && targetVoteType != 'cold') {
      return false;
    }

    final kuponRef = _firestore.collection('kuponlar').doc(cleanKuponId);
    final voteRef = kuponRef.collection('votes').doc(cleanUserId);

    try {
      final voteDoc = await voteRef.get();
      String? currentDbVote;
      if (voteDoc.exists) {
        currentDbVote = voteDoc.data()?['type'] as String?;
      }

      if (currentDbVote == targetVoteType) {
        // Zaten veritabanındaki durum ile hedef durum aynı, bir şey yapma (idempotent no-op)
        return true;
      }

      int hotDelta = 0;
      int coldDelta = 0;

      // Önceki oyu düşür
      if (currentDbVote == 'hot') {
        hotDelta -= 1;
      } else if (currentDbVote == 'cold') {
        coldDelta -= 1;
      }

      // Yeni oyu uygula
      if (targetVoteType == 'hot') {
        hotDelta += 1;
      } else if (targetVoteType == 'cold') {
        coldDelta += 1;
      }

      final batch = _firestore.batch();

      if (targetVoteType == 'hot') {
        batch.set(voteRef, {'type': 'hot', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      } else if (targetVoteType == 'cold') {
        batch.set(voteRef, {'type': 'cold', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      } else {
        batch.delete(voteRef);
      }

      // CRITICAL (FS-01, P0-06 & firestore.rules):
      // firestore.rules kuponlar için normal kullanıcılara SADECE 'sicakOySayisi' ve 'sogukOySayisi'
      // alanlarını güncelletir (hasOnly(['sicakOySayisi', 'sogukOySayisi'])).
      // Bu nedenle 'updatedAt' ana kupon dokümanına eklenmemelidir (aksi halde PERMISSION_DENIED alır).
      final Map<String, dynamic> kuponUpdates = {};
      if (hotDelta != 0) {
        kuponUpdates['sicakOySayisi'] = FieldValue.increment(hotDelta);
      }
      if (coldDelta != 0) {
        kuponUpdates['sogukOySayisi'] = FieldValue.increment(coldDelta);
      }

      if (kuponUpdates.isNotEmpty) {
        batch.update(kuponRef, kuponUpdates);
      }

      await batch.commit();
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('setKuponVote hatası: $e');
      return false;
    }
  }

  // Kupona oy verme işlemi (Toggle bazlı metod - setKuponVote'a delege edilir)
  Future<bool> voteKupon({
    required String kuponId,
    required String userId,
    required String voteType, // "hot" veya "cold"
  }) async {
    final cleanKuponId = kuponId.trim();
    final cleanUserId = userId.trim();
    if (cleanKuponId.isEmpty || cleanUserId.isEmpty) {
      return false;
    }
    if (voteType != 'hot' && voteType != 'cold') {
      return false;
    }

    try {
      final voteRef = _firestore.collection('kuponlar').doc(cleanKuponId).collection('votes').doc(cleanUserId);
      final voteDoc = await voteRef.get();
      String? oldVoteType;
      if (voteDoc.exists) {
        oldVoteType = voteDoc.data()?['type'] as String?;
      }

      final String? targetVoteType = (oldVoteType == voteType) ? null : voteType;
      return await setKuponVote(
        kuponId: cleanKuponId,
        userId: cleanUserId,
        targetVoteType: targetVoteType,
      );
    } catch (e) {
      // ignore: avoid_print
      print('voteKupon hatası: $e');
      return false;
    }
  }

  // Kullanıcının kupona verdiği oyu dinleme / getirme
  Future<String?> getUserKuponVote({
    required String kuponId,
    required String userId,
  }) async {
    final cleanKuponId = kuponId.trim();
    final cleanUserId = userId.trim();
    if (cleanKuponId.isEmpty || cleanUserId.isEmpty) return null;

    try {
      final doc = await _firestore
          .collection('kuponlar')
          .doc(cleanKuponId)
          .collection('votes')
          .doc(cleanUserId)
          .get();
      if (doc.exists) {
        return doc.data()?['type'] as String?;
      }
    } catch (e) {
      // ignore: avoid_print
      print('getUserKuponVote hatası: $e');
    }
    return null;
  }
}
