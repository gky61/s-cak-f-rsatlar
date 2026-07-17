import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class Kupon {
  final String id;
  final String magazaAdi;
  final String baslik;
  final String aciklama;
  final String kuponKodu;
  final DateTime olusturulmaTarihi;
  final DateTime? bitisTarihi;
  final String paylasanKullaniciId;
  final String paylasanKullaniciAdi; // Paylaşan kullanıcının adı (denormalize)
  final String kaynakTipi; // "topluluk" veya "web"
  final int sicakOySayisi;
  final int sogukOySayisi;
  final String durum; // "aktif" veya "gecersiz"

  Kupon({
    required this.id,
    required this.magazaAdi,
    required this.baslik,
    this.aciklama = '',
    required this.kuponKodu,
    required this.olusturulmaTarihi,
    this.bitisTarihi,
    required this.paylasanKullaniciId,
    this.paylasanKullaniciAdi = '',
    this.kaynakTipi = 'topluluk',
    this.sicakOySayisi = 0,
    this.sogukOySayisi = 0,
    this.durum = 'aktif',
  });

  factory Kupon.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    DateTime parsedOlusturulma = DateTime.now();
    if (data['olusturulmaTarihi'] != null) {
      if (data['olusturulmaTarihi'] is Timestamp) {
        parsedOlusturulma = (data['olusturulmaTarihi'] as Timestamp).toDate();
      } else if (data['olusturulmaTarihi'] is int) {
        parsedOlusturulma = DateTime.fromMillisecondsSinceEpoch(data['olusturulmaTarihi']);
      }
    }

    DateTime? parsedBitis;
    if (data['bitisTarihi'] != null) {
      if (data['bitisTarihi'] is Timestamp) {
        parsedBitis = (data['bitisTarihi'] as Timestamp).toDate();
      } else if (data['bitisTarihi'] is int) {
        parsedBitis = DateTime.fromMillisecondsSinceEpoch(data['bitisTarihi']);
      }
    }

    return Kupon(
      id: doc.id,
      magazaAdi: data['magazaAdi'] ?? '',
      baslik: data['baslik'] ?? '',
      aciklama: data['aciklama'] ?? '',
      kuponKodu: data['kuponKodu'] ?? '',
      olusturulmaTarihi: parsedOlusturulma,
      bitisTarihi: parsedBitis,
      paylasanKullaniciId: data['paylasanKullaniciId'] ?? '',
      paylasanKullaniciAdi: data['paylasanKullaniciAdi'] ?? '',
      kaynakTipi: data['kaynakTipi'] ?? 'topluluk',
      sicakOySayisi: data['sicakOySayisi'] ?? 0,
      sogukOySayisi: data['sogukOySayisi'] ?? 0,
      durum: data['durum'] ?? 'aktif',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'magazaAdi': magazaAdi,
      'baslik': baslik,
      'aciklama': aciklama,
      'kuponKodu': kuponKodu,
      'olusturulmaTarihi': Timestamp.fromDate(olusturulmaTarihi),
      'bitisTarihi': bitisTarihi != null ? Timestamp.fromDate(bitisTarihi!) : null,
      'paylasanKullaniciId': paylasanKullaniciId,
      'paylasanKullaniciAdi': paylasanKullaniciAdi,
      'kaynakTipi': kaynakTipi,
      'sicakOySayisi': sicakOySayisi,
      'sogukOySayisi': sogukOySayisi,
      'durum': durum,
    };
  }

  // Net Skor: Sıcak oylar ile Soğuk oylar arasındaki fark
  int get netScore => sicakOySayisi - sogukOySayisi;

  // Wilson Score: Kuponlar için profesyonel başarı oranı güven skoru
  double get wilsonScore {
    final n = sicakOySayisi + sogukOySayisi;
    if (n == 0) return 0.0;
    
    final p = sicakOySayisi / n;
    const z = 1.96; // %95 Güven aralığı
    
    final p1 = p + (z * z) / (2 * n);
    final p2 = z * sqrt((p * (1 - p) / n) + (z * z) / (4 * n * n));
    final divider = 1 + (z * z) / n;
    
    return (p1 - p2) / divider;
  }

  // Sıralama Grubu:
  // Grup 1: Sıcak Kuponlar (toplam oy >= 3 ve başarı oranı >= 70%)
  // Grup 2: Normal / Yeni Kuponlar (oylanmamışlar veya araftakiler)
  // Grup 3: Çöp / Geçersiz Kuponlar (durum == 'gecersiz' veya netScore <= -5)
  int get sortingGroup {
    if (durum == 'gecersiz' || netScore <= -5) return 3;
    final toplamOy = sicakOySayisi + sogukOySayisi;
    if (toplamOy >= 3 && (sicakOySayisi / toplamOy) >= 0.7) return 1;
    return 2;
  }

  // Profesyonel Sıralama Karşılaştırıcısı (Comparator)
  static int compareKuponlar(Kupon a, Kupon b, int Function(String) getStoreRank) {
    // 1. Önce Geçerlilik/Sıralama Gruplarına Göre Sırala
    final groupA = a.sortingGroup;
    final groupB = b.sortingGroup;

    if (groupA != groupB) {
      return groupA.compareTo(groupB); // Sıcaklar (1) en üstte, çöpler (3) en altta
    }

    // Her iki kupon da Sıcak Grubu'ndaysa (Grup 1)
    if (groupA == 1) {
      // Wilson Score'a göre azalan sırada sırala
      final cmp = b.wilsonScore.compareTo(a.wilsonScore);
      if (cmp != 0) return cmp;
      
      // Wilson Score eşitse mağaza sıralamasına göre sırala
      final rankCmp = getStoreRank(a.magazaAdi).compareTo(getStoreRank(b.magazaAdi));
      if (rankCmp != 0) return rankCmp;

      return b.sicakOySayisi.compareTo(a.sicakOySayisi);
    }

    // Her iki kupon da Normal/Yeni Grubu'ndaysa (Grup 2)
    if (groupA == 2) {
      // Önce mağaza popülerliğine (rank) göre sırala (Önceki gereksinim)
      final rankCmp = getStoreRank(a.magazaAdi).compareTo(getStoreRank(b.magazaAdi));
      if (rankCmp != 0) return rankCmp;
      
      // Mağaza ranki aynı ise oluşturulma tarihine göre azalan sırada (en yeni üstte)
      return b.olusturulmaTarihi.compareTo(a.olusturulmaTarihi);
    }

    // Her iki kupon da Çöp/Geçersiz Grubu'ndaysa (Grup 3)
    // Önce mağaza popülerliğine, sonra net skora göre sırala
    final rankCmp = getStoreRank(a.magazaAdi).compareTo(getStoreRank(b.magazaAdi));
    if (rankCmp != 0) return rankCmp;

    return b.netScore.compareTo(a.netScore);
  }
}
