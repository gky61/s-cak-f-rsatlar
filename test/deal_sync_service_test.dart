import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/deal.dart';
import 'package:sicak_firsatlar/services/deal_sync_service.dart';

void main() {
  group('Deal.copyWith Testleri', () {
    final baseDeal = Deal(
      id: 'test_deal_1',
      title: 'Kablosuz Kulaklık',
      description: 'Aktif Gürültü Engelleyici',
      price: 1499.0,
      originalPrice: 2499.0,
      discountRate: 40,
      store: 'Amazon',
      category: 'elektronik',
      subCategory: 'kulaklik',
      link: 'https://amazon.com.tr/dp/B000000',
      imageUrl: 'https://images.example.com/headphone.jpg',
      hotVotes: 10,
      coldVotes: 2,
      expiredVotes: 3,
      commentCount: 5,
      postedBy: 'user_123',
      postedByName: 'Ahmet Yılmaz',
      postedByAvatar: 'https://avatar.example.com/ahmet.jpg',
      createdAt: DateTime(2026, 10, 10, 12, 0),
      isEditorPick: false,
      isApproved: true,
      isRejected: false,
      isExpired: false,
      isUserSubmitted: true,
    );

    test('copyWith tekil alanları başarıyla güncellemeli, diğer alanları korumalı', () {
      final updated = baseDeal.copyWith(
        hotVotes: 15,
        coldVotes: 4,
        commentCount: 8,
        isExpired: true,
        price: 1299.0,
      );

      expect(updated.id, baseDeal.id);
      expect(updated.title, baseDeal.title);
      expect(updated.store, baseDeal.store);
      expect(updated.category, baseDeal.category);
      expect(updated.hotVotes, 15);
      expect(updated.coldVotes, 4);
      expect(updated.commentCount, 8);
      expect(updated.isExpired, true);
      expect(updated.price, 1299.0);
      expect(updated.originalPrice, 2499.0);
    });

    test('copyWith parametresiz çağrıldığında orijinal değerleri korumalı', () {
      final copy = baseDeal.copyWith();
      expect(copy.id, baseDeal.id);
      expect(copy.title, baseDeal.title);
      expect(copy.hotVotes, baseDeal.hotVotes);
      expect(copy.coldVotes, baseDeal.coldVotes);
      expect(copy.commentCount, baseDeal.commentCount);
    });
  });

  group('DealSyncEvent.applyTo Testleri', () {
    final baseDeal = Deal(
      id: 'deal_abc',
      title: 'Akıllı Saat',
      price: 999.0,
      store: 'Hepsiburada',
      category: 'elektronik',
      link: 'https://hepsiburada.com/test',
      imageUrl: 'https://images.example.com/watch.jpg',
      hotVotes: 20,
      coldVotes: 5,
      expiredVotes: 0,
      commentCount: 12,
      postedBy: 'user_456',
      createdAt: DateTime.now(),
      isEditorPick: false,
    );

    test('Farklı bir dealId olayında deal nesnesi değişmemeli (id guard)', () {
      const event = DealSyncEvent(
        dealId: 'different_id',
        action: DealSyncAction.voteUpdated,
        hotVotes: 99,
        coldVotes: 99,
      );

      final result = event.applyTo(baseDeal);
      expect(result.hotVotes, 20);
      expect(result.coldVotes, 5);
    });

    test('voteUpdated aksiyonu oyları doğru güncellemeli', () {
      const event = DealSyncEvent(
        dealId: 'deal_abc',
        action: DealSyncAction.voteUpdated,
        hotVotes: 21,
        coldVotes: 4,
      );

      final result = event.applyTo(baseDeal);
      expect(result.hotVotes, 21);
      expect(result.coldVotes, 4);
      expect(result.commentCount, 12); // Yorum değişmemeli
    });

    test('commentCountUpdated doğrudan yorum sayısını güncellemeli', () {
      const event = DealSyncEvent(
        dealId: 'deal_abc',
        action: DealSyncAction.commentCountUpdated,
        commentCount: 25,
      );

      final result = event.applyTo(baseDeal);
      expect(result.commentCount, 25);
    });

    test('commentCountDelta bağıl artış (+1) ve azalış (-1) yapmalı, 0 altına düşmemeli', () {
      // +1 Artış
      const incrementEvent = DealSyncEvent(
        dealId: 'deal_abc',
        action: DealSyncAction.commentCountDelta,
        commentDelta: 1,
      );
      final incremented = incrementEvent.applyTo(baseDeal);
      expect(incremented.commentCount, 13);

      // -1 Azalış
      const decrementEvent = DealSyncEvent(
        dealId: 'deal_abc',
        action: DealSyncAction.commentCountDelta,
        commentDelta: -1,
      );
      final decremented = decrementEvent.applyTo(baseDeal);
      expect(decremented.commentCount, 11);

      // 0'ın altına düşme koruması
      final zeroDeal = baseDeal.copyWith(commentCount: 0);
      final clamped = decrementEvent.applyTo(zeroDeal);
      expect(clamped.commentCount, 0);
    });

    test('expiredVoteUpdated stok durumunu ve oyunu güncellemeli', () {
      const event = DealSyncEvent(
        dealId: 'deal_abc',
        action: DealSyncAction.expiredVoteUpdated,
        expiredVotes: 15,
        isExpired: true,
      );

      final result = event.applyTo(baseDeal);
      expect(result.expiredVotes, 15);
      expect(result.isExpired, true);
      expect(result.isArchived, true); // 15 oy eşiği ile otomatik isArchived olmalı
    });

    test('dealUpdated tüm nesneyi yerinde değiştirmeli', () {
      final updatedDeal = baseDeal.copyWith(
        title: 'Akıllı Saat 2. Nesil (Güncellendi)',
        price: 899.0,
      );

      final event = DealSyncEvent(
        dealId: 'deal_abc',
        action: DealSyncAction.dealUpdated,
        updatedDeal: updatedDeal,
      );

      final result = event.applyTo(baseDeal);
      expect(result.title, 'Akıllı Saat 2. Nesil (Güncellendi)');
      expect(result.price, 899.0);
    });
  });

  group('DealSyncService Broadcast Akış Testleri', () {
    final service = DealSyncService.instance;

    test('Singleton referansı tekil olmalı', () {
      expect(DealSyncService.instance, same(service));
    });

    test('notifyVoteChanged doğru olayı yayınlamalı', () async {
      expectLater(
        service.stream,
        emits(predicate<DealSyncEvent>((e) =>
            e.dealId == 'deal_1' &&
            e.action == DealSyncAction.voteUpdated &&
            e.hotVotes == 14 &&
            e.coldVotes == 1)),
      );

      service.notifyVoteChanged(dealId: 'deal_1', hotVotes: 14, coldVotes: 1);
    });

    test('notifyCommentCountDelta doğru olayı yayınlamalı', () async {
      expectLater(
        service.stream,
        emits(predicate<DealSyncEvent>((e) =>
            e.dealId == 'deal_2' &&
            e.action == DealSyncAction.commentCountDelta &&
            e.commentDelta == 1)),
      );

      service.notifyCommentCountDelta(dealId: 'deal_2', delta: 1);
    });

    test('notifyExpiredVoteChanged doğru olayı yayınlamalı', () async {
      expectLater(
        service.stream,
        emits(predicate<DealSyncEvent>((e) =>
            e.dealId == 'deal_3' &&
            e.action == DealSyncAction.expiredVoteUpdated &&
            e.expiredVotes == 16 &&
            e.isExpired == true)),
      );

      service.notifyExpiredVoteChanged(
        dealId: 'deal_3',
        expiredVotes: 16,
        isExpired: true,
      );
    });

    test('notifyDealDeleted doğru olayı yayınlamalı', () async {
      expectLater(
        service.stream,
        emits(predicate<DealSyncEvent>((e) =>
            e.dealId == 'deal_4' &&
            e.action == DealSyncAction.dealDeleted)),
      );

      service.notifyDealDeleted('deal_4');
    });

    test('notifyFavoriteToggled doğru olayı yayınlamalı', () async {
      expectLater(
        service.stream,
        emits(predicate<DealSyncEvent>((e) =>
            e.dealId == 'deal_5' &&
            e.action == DealSyncAction.favoriteToggled &&
            e.isFavorite == false)),
      );

      service.notifyFavoriteToggled(dealId: 'deal_5', isFavorite: false);
    });

    test('notifyDealUpdated doğru olayı ve güncel deal nesnesini yayınlamalı', () async {
      final updatedDeal = Deal(
        id: 'deal_6',
        title: 'Yenilenmiş Ürün',
        price: 500.0,
        store: 'Trendyol',
        category: 'moda',
        link: 'https://trendyol.com',
        imageUrl: 'https://img.com/t.jpg',
        hotVotes: 5,
        coldVotes: 0,
        commentCount: 2,
        postedBy: 'user_1',
        createdAt: DateTime.now(),
        isEditorPick: false,
      );

      expectLater(
        service.stream,
        emits(predicate<DealSyncEvent>((e) =>
            e.dealId == 'deal_6' &&
            e.action == DealSyncAction.dealUpdated &&
            e.updatedDeal?.title == 'Yenilenmiş Ürün')),
      );

      service.notifyDealUpdated(updatedDeal);
    });

    test('dealDeleted ve favoriteToggled durumunda applyTo nesneyi değiştirmemeli', () {
      final base = Deal(
        id: 'deal_7',
        title: 'Test',
        price: 100.0,
        store: 'Mağaza',
        category: 'tumu',
        link: 'https://link.com',
        imageUrl: '',
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        postedBy: 'user_1',
        createdAt: DateTime.now(),
        isEditorPick: false,
      );

      const delEvent = DealSyncEvent(dealId: 'deal_7', action: DealSyncAction.dealDeleted);
      expect(delEvent.applyTo(base), same(base));

      const favEvent = DealSyncEvent(dealId: 'deal_7', action: DealSyncAction.favoriteToggled, isFavorite: true);
      expect(favEvent.applyTo(base), same(base));
    });
  });
}
