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

  // Süresi dolmuş mu kontrolü
  bool get isExpired => bitisTarihi != null && bitisTarihi!.isBefore(DateTime.now());

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
  // Grup 1: Sıcak Kuponlar (aktif, süresi dolmamış, toplam oy >= 3 ve başarı oranı >= 70%)
  // Grup 2: Normal / Yeni Kuponlar (aktif, süresi dolmamış, netScore > -5)
  // Grup 3: Çöp / Geçersiz / Süresi Dolan Kuponlar (durum == 'gecersiz' veya isExpired veya netScore <= -5)
  int get sortingGroup {
    if (durum == 'gecersiz' || isExpired || netScore <= -5) return 3;
    final toplamOy = sicakOySayisi + sogukOySayisi;
    if (toplamOy >= 3 && (sicakOySayisi / toplamOy) >= 0.7) return 1;
    return 2;
  }

  // Dünya Standartlarında (PROD-READY) Sıralama Karşılaştırıcısı
  // isCommunity: true  -> Topluluk Kuponları (Topluluk akışı: Oy farkı ve tazelik/tarih öncelikli)
  // isCommunity: false -> Kupon Radarı (Mağaza dizini: Mağaza popülerliği ve oy farkı öncelikli)
  static int compareKuponlar(
    Kupon a,
    Kupon b,
    int Function(String) getStoreRank, {
    bool isCommunity = false,
  }) {
    // 1. Önce Geçerlilik/Sıralama Gruplarına Göre Sırala
    final groupA = a.sortingGroup;
    final groupB = b.sortingGroup;

    if (groupA != groupB) {
      return groupA.compareTo(groupB); // Sıcaklar (1) en üstte, çöpler (3) en altta
    }

    // HER İKİ KUPON DA SICAK GRUBU'NDAYSA (GRUP 1)
    if (groupA == 1) {
      // 1. Wilson Score'a göre azalan sırada sırala (istatistiksel güvenilirlik)
      final cmp = b.wilsonScore.compareTo(a.wilsonScore);
      if (cmp != 0) return cmp;

      // 2. Wilson Score eşitse Net Skor (Sıcak - Soğuk)
      final netCmp = b.netScore.compareTo(a.netScore);
      if (netCmp != 0) return netCmp;

      if (isCommunity) {
        // Topluluk Kuponları: Taze/güncel paylaşımlar üstte
        final dateCmp = b.olusturulmaTarihi.compareTo(a.olusturulmaTarihi);
        if (dateCmp != 0) return dateCmp;

        return getStoreRank(a.magazaAdi).compareTo(getStoreRank(b.magazaAdi));
      } else {
        // Kupon Radarı: Popüler mağaza öncelikli
        final rankCmp = getStoreRank(a.magazaAdi).compareTo(getStoreRank(b.magazaAdi));
        if (rankCmp != 0) return rankCmp;

        return b.olusturulmaTarihi.compareTo(a.olusturulmaTarihi);
      }
    }

    // HER İKİ KUPON DA NORMAL / YENİ GRUBU'NDAYSA (GRUP 2)
    if (groupA == 2) {
      // Oylama Katmanı: Pozitif net skorlu kuponlar > Nötr kuponlar > Negatif kuponlar
      // Bu sayede çalışan/beğenilen kuponlar henüz Grup 1 eşiğine (3 oy & %70) gelmemiş olsa bile
      // sıfır oylu veya negatif oylu kuponların önüne geçer!
      final tierA = a.netScore > 0 ? 2 : (a.netScore == 0 ? 1 : 0);
      final tierB = b.netScore > 0 ? 2 : (b.netScore == 0 ? 1 : 0);

      if (tierA != tierB) {
        return tierB.compareTo(tierA); // Pozitif (2) > Nötr (1) > Negatif (0)
      }

      if (isCommunity) {
        // Topluluk Kuponları:
        // 1. Net skor azalan
        final netCmp = b.netScore.compareTo(a.netScore);
        if (netCmp != 0) return netCmp;

        // 2. Oluşturulma tarihi azalan (Yeni paylaşılan kuponlar üstte)
        final dateCmp = b.olusturulmaTarihi.compareTo(a.olusturulmaTarihi);
        if (dateCmp != 0) return dateCmp;

        // 3. Mağaza popülerliği
        return getStoreRank(a.magazaAdi).compareTo(getStoreRank(b.magazaAdi));
      } else {
        // Kupon Radarı:
        // 1. Mağaza popülerliğine (rank) göre sırala
        final rankCmp = getStoreRank(a.magazaAdi).compareTo(getStoreRank(b.magazaAdi));
        if (rankCmp != 0) return rankCmp;

        // 2. Net skor azalan
        final netCmp = b.netScore.compareTo(a.netScore);
        if (netCmp != 0) return netCmp;

        // 3. Oluşturulma tarihi azalan
        return b.olusturulmaTarihi.compareTo(a.olusturulmaTarihi);
      }
    }

    // HER İKİ KUPON DA ÇÖP / GEÇERSİZ / SÜRESİ DOLAN GRUBU'NDAYSA (GRUP 3)
    // Henüz süresi dolmamış olanlar (örneğin sadece -5 almış olanlar), süresi dolmuş olanların üstünde
    if (a.isExpired != b.isExpired) {
      return a.isExpired ? 1 : -1; // Süresi dolmayan üstte (-1)
    }

    if (isCommunity) {
      final netCmp = b.netScore.compareTo(a.netScore);
      if (netCmp != 0) return netCmp;

      return b.olusturulmaTarihi.compareTo(a.olusturulmaTarihi);
    } else {
      final rankCmp = getStoreRank(a.magazaAdi).compareTo(getStoreRank(b.magazaAdi));
      if (rankCmp != 0) return rankCmp;

      final netCmp = b.netScore.compareTo(a.netScore);
      if (netCmp != 0) return netCmp;

      return b.olusturulmaTarihi.compareTo(a.olusturulmaTarihi);
    }
  }
}
