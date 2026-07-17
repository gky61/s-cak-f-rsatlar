import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';

void main() {
  group('Deal Oylama ve Sıralama Algoritması Testleri', () {
    test('Wilson Score doğru şekilde hesaplanmalı ve oy hacmini dikkate almalı', () {
      // Hiç oy yoksa Wilson Score 0 olmalı
      final zeroVote = Deal(
        id: '1', title: 'Test 1', price: 10, store: 'Trendyol', category: 'elektronik',
        link: 'http://link.com', imageUrl: '', hotVotes: 0, coldVotes: 0, commentCount: 0,
        postedBy: 'user', createdAt: DateTime.now(), isEditorPick: false
      );
      expect(zeroVote.wilsonScore, 0.0);

      // Çok Sıcak oy alanın skoru, az oy alanla karşılaştırıldığında hacmi korumalı
      final manyVotes = Deal(
        id: '2', title: 'Test 2', price: 10, store: 'Trendyol', category: 'elektronik',
        link: 'http://link.com', imageUrl: '', hotVotes: 100, coldVotes: 10, commentCount: 0,
        postedBy: 'user', createdAt: DateTime.now(), isEditorPick: false
      );

      final fewVotes = Deal(
        id: '3', title: 'Test 3', price: 10, store: 'Trendyol', category: 'elektronik',
        link: 'http://link.com', imageUrl: '', hotVotes: 10, coldVotes: 1, commentCount: 0,
        postedBy: 'user', createdAt: DateTime.now(), isEditorPick: false
      );

      // İki fırsatın da başarı oranı aynı (%90.9) ama 100 oy alanın Wilson Score'u (güvenilirliği) daha yüksek olmalıdır.
      expect(manyVotes.wilsonScore > fewVotes.wilsonScore, true);
    });

    test('Sorting Group doğru kategorize edilmeli', () {
      // 1. Sıcak Grubu: Toplam oy >= 3 ve başarı oranı >= 70%
      final hotDeal = Deal(
        id: '1', title: 'Sıcak Fırsat', price: 10, store: 'Trendyol', category: 'elektronik',
        link: 'http://link.com', imageUrl: '', hotVotes: 8, coldVotes: 2, commentCount: 0,
        postedBy: 'user', createdAt: DateTime.now(), isEditorPick: false
      );
      expect(hotDeal.sortingGroup, 1);

      // 2. Normal/Yeni Grubu: Yetersiz oy
      final newDeal = Deal(
        id: '2', title: 'Yeni Fırsat', price: 10, store: 'Trendyol', category: 'elektronik',
        link: 'http://link.com', imageUrl: '', hotVotes: 1, coldVotes: 0, commentCount: 0,
        postedBy: 'user', createdAt: DateTime.now(), isEditorPick: false
      );
      expect(newDeal.sortingGroup, 2);

      // 3. Çöp Grubu: Net skor <= -8
      final trashDeal = Deal(
        id: '3', title: 'Çöp Fırsat', price: 10, store: 'Trendyol', category: 'elektronik',
        link: 'http://link.com', imageUrl: '', hotVotes: 2, coldVotes: 11, commentCount: 0,
        postedBy: 'user', createdAt: DateTime.now(), isEditorPick: false
      );
      expect(trashDeal.sortingGroup, 3);
    });

    test('compareDeals algoritması Sıcak > Normal > Çöp sırasını korumalı', () {
      final now = DateTime.now();

      final hotDeal = Deal(
        id: 'hot', title: 'Sıcak Fırsat', price: 10, store: 'Trendyol', category: 'elektronik',
        link: 'http://link.com', imageUrl: '', hotVotes: 15, coldVotes: 2, commentCount: 0,
        postedBy: 'user', createdAt: now.subtract(const Duration(hours: 5)), isEditorPick: false
      );

      final normalNewDeal = Deal(
        id: 'normal_new', title: 'Normal Yeni Fırsat', price: 10, store: 'Trendyol', category: 'elektronik',
        link: 'http://link.com', imageUrl: '', hotVotes: 0, coldVotes: 0, commentCount: 0,
        postedBy: 'user', createdAt: now, isEditorPick: false
      );

      final normalOldDeal = Deal(
        id: 'normal_old', title: 'Normal Eski Fırsat', price: 10, store: 'Trendyol', category: 'elektronik',
        link: 'http://link.com', imageUrl: '', hotVotes: 0, coldVotes: 0, commentCount: 0,
        postedBy: 'user', createdAt: now.subtract(const Duration(hours: 1)), isEditorPick: false
      );

      final trashDeal = Deal(
        id: 'trash', title: 'Çöp Fırsat', price: 10, store: 'Trendyol', category: 'elektronik',
        link: 'http://link.com', imageUrl: '', hotVotes: 0, coldVotes: 10, commentCount: 0,
        postedBy: 'user', createdAt: now.subtract(const Duration(minutes: 5)), isEditorPick: false
      );

      final list = [normalOldDeal, trashDeal, hotDeal, normalNewDeal];
      list.sort(Deal.compareDeals);

      // Sıralama sonucu:
      // 1. Sıcak (hot)
      // 2. Normal Yeni (normal_new)
      // 3. Normal Eski (normal_old)
      // 4. Çöp (trash)
      expect(list[0].id, 'hot');
      expect(list[1].id, 'normal_new');
      expect(list[2].id, 'normal_old');
      expect(list[3].id, 'trash');
    });
  });
}
