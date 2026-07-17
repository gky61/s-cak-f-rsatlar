import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/kupon.dart';

void main() {
  group('Kupon Model Unit Tests', () {
    test('Kupon constructor and property getters should work correctly with new fields', () {
      final now = DateTime.now();
      final kupon = Kupon(
        id: 'test_id',
        magazaAdi: 'Trendyol',
        baslik: '100 TL İndirim',
        aciklama: '300 TL üzeri geçerlidir.',
        kuponKodu: 'TREND100',
        olusturulmaTarihi: now,
        paylasanKullaniciId: 'test_user_123',
        kaynakTipi: 'web',
        sicakOySayisi: 3,
        sogukOySayisi: 1,
        durum: 'aktif',
      );

      expect(kupon.id, 'test_id');
      expect(kupon.magazaAdi, 'Trendyol');
      expect(kupon.baslik, '100 TL İndirim');
      expect(kupon.aciklama, '300 TL üzeri geçerlidir.');
      expect(kupon.kuponKodu, 'TREND100');
      expect(kupon.olusturulmaTarihi, now);
      expect(kupon.paylasanKullaniciId, 'test_user_123');
      expect(kupon.kaynakTipi, 'web');
      expect(kupon.sicakOySayisi, 3);
      expect(kupon.sogukOySayisi, 1);
      expect(kupon.durum, 'aktif');
    });

    test('toFirestore serialization should serialize all values correctly', () {
      final now = DateTime.now();
      final kupon = Kupon(
        id: 'test_id',
        magazaAdi: 'Getir',
        baslik: '50 TL İndirim',
        aciklama: 'İlk siparişe özel',
        kuponKodu: 'GETIR50',
        olusturulmaTarihi: now,
        paylasanKullaniciId: 'test_user_456',
        kaynakTipi: 'topluluk',
        sicakOySayisi: 10,
        sogukOySayisi: 2,
        durum: 'gecersiz',
      );

      final map = kupon.toFirestore();
      expect(map['magazaAdi'], 'Getir');
      expect(map['baslik'], '50 TL İndirim');
      expect(map['aciklama'], 'İlk siparişe özel');
      expect(map['kuponKodu'], 'GETIR50');
      expect(map['paylasanKullaniciId'], 'test_user_456');
      expect(map['olusturulmaTarihi'], isNotNull);
      expect(map['kaynakTipi'], 'topluluk');
      expect(map['sicakOySayisi'], 10);
      expect(map['sogukOySayisi'], 2);
      expect(map['durum'], 'gecersiz');
    });

    test('Wilson Score doğru şekilde hesaplanmalı ve oy hacmini dikkate almalı', () {
      final now = DateTime.now();
      
      // Hiç oy yoksa Wilson Score 0 olmalı
      final zeroVote = Kupon(
        id: '1', magazaAdi: 'Trendyol', baslik: 'Kupon 1', kuponKodu: 'TEST1',
        olusturulmaTarihi: now, paylasanKullaniciId: 'user', sicakOySayisi: 0, sogukOySayisi: 0
      );
      expect(zeroVote.wilsonScore, 0.0);

      // 100 Sıcak / 10 Soğuk alan ile 10 Sıcak / 1 Soğuk alan karşılaştırması
      final manyVotes = Kupon(
        id: '2', magazaAdi: 'Trendyol', baslik: 'Kupon 2', kuponKodu: 'TEST2',
        olusturulmaTarihi: now, paylasanKullaniciId: 'user', sicakOySayisi: 100, sogukOySayisi: 10
      );

      final fewVotes = Kupon(
        id: '3', magazaAdi: 'Trendyol', baslik: 'Kupon 3', kuponKodu: 'TEST3',
        olusturulmaTarihi: now, paylasanKullaniciId: 'user', sicakOySayisi: 10, sogukOySayisi: 1
      );

      // Hacmi büyük olanın güvenilirlik skoru daha yüksek olmalı
      expect(manyVotes.wilsonScore > fewVotes.wilsonScore, true);
    });

    test('sortingGroup doğru gruplandırma yapmalı', () {
      final now = DateTime.now();

      // 1. Sıcak Grubu (toplam oy >= 3 ve başarı oranı >= 70%)
      final hotKupon = Kupon(
        id: 'hot', magazaAdi: 'Trendyol', baslik: 'Kupon', kuponKodu: 'TEST',
        olusturulmaTarihi: now, paylasanKullaniciId: 'user', sicakOySayisi: 5, sogukOySayisi: 1
      );
      expect(hotKupon.sortingGroup, 1);

      // 2. Normal/Yeni Grubu (yetersiz oy)
      final newKupon = Kupon(
        id: 'new', magazaAdi: 'Trendyol', baslik: 'Kupon', kuponKodu: 'TEST',
        olusturulmaTarihi: now, paylasanKullaniciId: 'user', sicakOySayisi: 1, sogukOySayisi: 0
      );
      expect(newKupon.sortingGroup, 2);

      // 3. Çöp Grubu (durum == gecersiz veya netScore <= -5)
      final invalidKupon = Kupon(
        id: 'invalid', magazaAdi: 'Trendyol', baslik: 'Kupon', kuponKodu: 'TEST',
        olusturulmaTarihi: now, paylasanKullaniciId: 'user', sicakOySayisi: 0, sogukOySayisi: 0,
        durum: 'gecersiz'
      );
      final coldKupon = Kupon(
        id: 'cold', magazaAdi: 'Trendyol', baslik: 'Kupon', kuponKodu: 'TEST',
        olusturulmaTarihi: now, paylasanKullaniciId: 'user', sicakOySayisi: 1, sogukOySayisi: 6
      );
      expect(invalidKupon.sortingGroup, 3);
      expect(coldKupon.sortingGroup, 3);
    });

    test('compareKuponlar algoritması Sıcak > Normal > Çöp sırasını korumalı', () {
      final now = DateTime.now();

      // Mock Mağaza Sıralaması: Trendyol en popüler (rank 1), Mavi en az (rank 203)
      int mockGetStoreRank(String name) {
        if (name == 'Trendyol') return 1;
        if (name == 'Mavi') return 203;
        return 99;
      }

      final hotKupon = Kupon(
        id: 'hot', magazaAdi: 'Mavi', baslik: 'Sıcak Kupon', kuponKodu: 'TEST',
        olusturulmaTarihi: now.subtract(const Duration(hours: 5)), paylasanKullaniciId: 'user',
        sicakOySayisi: 5, sogukOySayisi: 1
      );

      final normalNewTrendyol = Kupon(
        id: 'normal_trendyol', magazaAdi: 'Trendyol', baslik: 'Normal Yeni Trendyol', kuponKodu: 'TEST',
        olusturulmaTarihi: now.subtract(const Duration(minutes: 30)), paylasanKullaniciId: 'user',
        sicakOySayisi: 0, sogukOySayisi: 0
      );

      final normalOldMavi = Kupon(
        id: 'normal_mavi', magazaAdi: 'Mavi', baslik: 'Normal Eski Mavi', kuponKodu: 'TEST',
        olusturulmaTarihi: now.subtract(const Duration(hours: 1)), paylasanKullaniciId: 'user',
        sicakOySayisi: 0, sogukOySayisi: 0
      );

      final trashKupon = Kupon(
        id: 'trash', magazaAdi: 'Trendyol', baslik: 'Çöp Kupon', kuponKodu: 'TEST',
        olusturulmaTarihi: now, paylasanKullaniciId: 'user',
        sicakOySayisi: 0, sogukOySayisi: 6
      );

      final list = [normalOldMavi, trashKupon, hotKupon, normalNewTrendyol];
      list.sort((a, b) => Kupon.compareKuponlar(a, b, mockGetStoreRank));

      // Sıralama Sonucu Beklenen:
      // 1. Sıcak Kupon (id: hot) - Mavi olmasına rağmen Sıcak grubunda olduğu için en üstte
      // 2. Normal Trendyol (id: normal_trendyol) - Trendyol ranki (1) Mavi'den (203) daha popüler olduğu için üstte
      // 3. Normal Eski Mavi (id: normal_mavi) - Ranki düşük olduğu için Trendyol'un altında
      // 4. Çöp Kupon (id: trash) - Net skoru çok düşük olduğu için en altta
      expect(list[0].id, 'hot');
      expect(list[1].id, 'normal_trendyol');
      expect(list[2].id, 'normal_mavi');
      expect(list[3].id, 'trash');
    });
  });
}
