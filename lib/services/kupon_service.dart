import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kupon.dart';

class KuponService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kuponları real-time dinleme
  Stream<List<Kupon>> getKuponlarStream() {
    return _firestore
        .collection('kuponlar')
        .orderBy('olusturulmaTarihi', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Kupon.fromFirestore(doc)).toList();
    });
  }

  // Yeni kupon paylaşma
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
      durum: 'aktif',
    );

    await _firestore.collection('kuponlar').add(kupon.toFirestore());
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

  // Kupona oy verme işlemi (Transaction ile)
  Future<bool> voteKupon({
    required String kuponId,
    required String userId,
    required String voteType, // "hot" veya "cold"
  }) async {
    final kuponRef = _firestore.collection('kuponlar').doc(kuponId);
    final voteRef = kuponRef.collection('votes').doc(userId);

    try {
      return await _firestore.runTransaction((transaction) async {
        final kuponDoc = await transaction.get(kuponRef);
        if (!kuponDoc.exists) return false;

        final voteDoc = await transaction.get(voteRef);
        final data = kuponDoc.data() as Map<String, dynamic>;

        int sicakOySayisi = data['sicakOySayisi'] ?? 0;
        int sogukOySayisi = data['sogukOySayisi'] ?? 0;
        String? oldVoteType;
        if (voteDoc.exists) {
          oldVoteType = voteDoc.data()?['type'] as String?;
        }
        if (oldVoteType == voteType) {
          // Zaten aynı oyu vermiş, oyu geri al (toggle)
          if (voteType == 'hot') {
            sicakOySayisi = (sicakOySayisi > 0) ? sicakOySayisi - 1 : 0;
          } else {
            sogukOySayisi = (sogukOySayisi > 0) ? sogukOySayisi - 1 : 0;
          }
          transaction.delete(voteRef);
        } else {
          // Farklı oya tıklamış (veya ilk defa oy veriyor)
          if (oldVoteType != null) {
            // Eski oyu düşür
            if (oldVoteType == 'hot') {
              sicakOySayisi = (sicakOySayisi > 0) ? sicakOySayisi - 1 : 0;
            } else {
              sogukOySayisi = (sogukOySayisi > 0) ? sogukOySayisi - 1 : 0;
            }
          }

          // Yeni oyu arttır
          if (voteType == 'hot') {
            sicakOySayisi += 1;
          } else {
            sogukOySayisi += 1;
          }
          transaction.set(voteRef, {'type': voteType}, SetOptions(merge: true));
        }

        // Skor kontrolü ve otomatik gecersiz yapma/silme
        // Net skor <= -5 olduğunda:
        // Topluluk kuponu ise durumu 'gecersiz' yapılır.
        // Kupon Radarı (web) ise tamamen veritabanından silinir.
        String durum = data['durum'] ?? 'aktif';
        final kaynakTipi = data['kaynakTipi'] ?? 'topluluk';

        if (sogukOySayisi - sicakOySayisi >= 5) {
          if (kaynakTipi == 'web') {
            transaction.delete(kuponRef);
            return true;
          } else {
            durum = 'gecersiz';
          }
        } else if (durum == 'gecersiz' && (sogukOySayisi - sicakOySayisi < 5)) {
          // Oylarla kurtarıldıysa tekrar aktif yap
          durum = 'aktif';
        }

        transaction.update(kuponRef, {
          'sicakOySayisi': sicakOySayisi,
          'sogukOySayisi': sogukOySayisi,
          'durum': durum,
        });

        return true;
      });
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
    try {
      final doc = await _firestore
          .collection('kuponlar')
          .doc(kuponId)
          .collection('votes')
          .doc(userId)
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
