import 'dart:async';
import '../models/deal.dart';

/// Fırsat üzerinde gerçekleşen etkileşimlerin türleri
enum DealSyncAction {
  voteUpdated,
  commentCountUpdated,
  commentCountDelta,
  expiredVoteUpdated,
  dealUpdated,
  dealDeleted,
  favoriteToggled,
}

/// Fırsat senkronizasyon olay veri paketi
class DealSyncEvent {
  final String dealId;
  final DealSyncAction action;
  final int? hotVotes;
  final int? coldVotes;
  final int? expiredVotes;
  final int? commentCount;
  final int? commentDelta;
  final bool? isExpired;
  final bool? isFavorite;
  final Deal? updatedDeal;

  const DealSyncEvent({
    required this.dealId,
    required this.action,
    this.hotVotes,
    this.coldVotes,
    this.expiredVotes,
    this.commentCount,
    this.commentDelta,
    this.isExpired,
    this.isFavorite,
    this.updatedDeal,
  });

  /// Bir Deal nesnesine bu senkronizasyon olayını uygulayarak güncellenmiş yeni bir Deal üretir (Pure function)
  Deal applyTo(Deal current) {
    if (current.id != dealId) return current;

    switch (action) {
      case DealSyncAction.voteUpdated:
        return current.copyWith(
          hotVotes: hotVotes ?? current.hotVotes,
          coldVotes: coldVotes ?? current.coldVotes,
        );

      case DealSyncAction.commentCountUpdated:
        return current.copyWith(
          commentCount: commentCount ?? current.commentCount,
        );

      case DealSyncAction.commentCountDelta:
        final currentCount = current.commentCount;
        final delta = commentDelta ?? 0;
        final newCount = (currentCount + delta) < 0 ? 0 : (currentCount + delta);
        return current.copyWith(commentCount: newCount);

      case DealSyncAction.expiredVoteUpdated:
        return current.copyWith(
          expiredVotes: expiredVotes ?? current.expiredVotes,
          isExpired: isExpired ?? current.isExpired,
        );

      case DealSyncAction.dealUpdated:
        return updatedDeal ?? current;

      case DealSyncAction.dealDeleted:
      case DealSyncAction.favoriteToggled:
        return current;
    }
  }
}

/// FırsatKolik İstemci İçi Reaktif Senkronizasyon Yöneticisi (FS-09 / R-SCL-09 Kalkanı)
///
/// 100.000 kullanıcıda canlı Firestore stream'lerini açmadan (maliyet ve fatura krizini önleyerek),
/// aktif kullanıcının kendi yaptığı oylama, yorum, stok bitti ve düzenleme aksiyonlarını
/// tüm açık ekranlara (Anasayfa, Popüler, Favoriler, Arama) 0ms gecikmeyle ve 0 TL maliyetle
/// yerel olarak yansıtan merkezi Event Bus mimarisi.
class DealSyncService {
  DealSyncService._internal();
  static final DealSyncService instance = DealSyncService._internal();

  final StreamController<DealSyncEvent> _controller =
      StreamController<DealSyncEvent>.broadcast();

  /// Tüm dinleyicilerin (HomeScreen, PopularDealsScreen vb.) abone olduğu yayın akışı
  Stream<DealSyncEvent> get stream => _controller.stream;

  /// Sıcak/Soğuk oylama değiştiğinde tetiklenir
  void notifyVoteChanged({
    required String dealId,
    required int hotVotes,
    required int coldVotes,
  }) {
    final cleanId = dealId.trim();
    if (cleanId.isEmpty) return;
    _controller.add(DealSyncEvent(
      dealId: cleanId,
      action: DealSyncAction.voteUpdated,
      hotVotes: hotVotes < 0 ? 0 : hotVotes,
      coldVotes: coldVotes < 0 ? 0 : coldVotes,
    ));
  }

  /// Yorum sayısı doğrudan değiştiğinde tetiklenir
  void notifyCommentCountChanged({
    required String dealId,
    required int commentCount,
  }) {
    final cleanId = dealId.trim();
    if (cleanId.isEmpty) return;
    _controller.add(DealSyncEvent(
      dealId: cleanId,
      action: DealSyncAction.commentCountUpdated,
      commentCount: commentCount < 0 ? 0 : commentCount,
    ));
  }

  /// Yorum sayısı bağıl olarak arttığında veya azaldığında tetiklenir (+1, -1)
  void notifyCommentCountDelta({
    required String dealId,
    required int delta,
  }) {
    final cleanId = dealId.trim();
    if (cleanId.isEmpty) return;
    _controller.add(DealSyncEvent(
      dealId: cleanId,
      action: DealSyncAction.commentCountDelta,
      commentDelta: delta,
    ));
  }

  /// Fırsat bitti oyu verildiğinde veya geri alındığında tetiklenir
  void notifyExpiredVoteChanged({
    required String dealId,
    required int expiredVotes,
    required bool isExpired,
  }) {
    final cleanId = dealId.trim();
    if (cleanId.isEmpty) return;
    _controller.add(DealSyncEvent(
      dealId: cleanId,
      action: DealSyncAction.expiredVoteUpdated,
      expiredVotes: expiredVotes < 0 ? 0 : expiredVotes,
      isExpired: isExpired,
    ));
  }

  /// Fırsat düzenlendiğinde (başlık, fiyat, kategori vb.) tetiklenir
  void notifyDealUpdated(Deal deal) {
    if (deal.id.trim().isEmpty) return;
    _controller.add(DealSyncEvent(
      dealId: deal.id.trim(),
      action: DealSyncAction.dealUpdated,
      updatedDeal: deal,
    ));
  }

  /// Fırsat silindiğinde veya yayından kaldırıldığında tetiklenir
  void notifyDealDeleted(String dealId) {
    final cleanId = dealId.trim();
    if (cleanId.isEmpty) return;
    _controller.add(DealSyncEvent(
      dealId: cleanId,
      action: DealSyncAction.dealDeleted,
    ));
  }

  /// Fırsat favorilere eklendiğinde veya çıkarıldığında tetiklenir
  void notifyFavoriteToggled({
    required String dealId,
    required bool isFavorite,
  }) {
    final cleanId = dealId.trim();
    if (cleanId.isEmpty) return;
    _controller.add(DealSyncEvent(
      dealId: cleanId,
      action: DealSyncAction.favoriteToggled,
      isFavorite: isFavorite,
    ));
  }
}
