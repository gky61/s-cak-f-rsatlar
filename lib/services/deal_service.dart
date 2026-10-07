import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/deal.dart';
import 'auth_service.dart';
import 'content_moderation_service.dart';
import 'user_service.dart';
import 'link_preview_service.dart';
import 'advertising_compliance_service.dart';
import 'affiliate/affiliate_service.dart';
import '../utils/asset_path_migration.dart';
import 'system_log_service.dart';
import 'deal_search_engine.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class DealsSnapshot {
  final List<Deal> deals;
  final bool isFromCache;
  DealsSnapshot({required this.deals, required this.isFromCache});
}

/// FS-09: Sayfalı ve önbellek (SWR) destekli fırsat akış modeli.
class DealsPageResult {
  final List<Deal> deals;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool isFromCache;

  const DealsPageResult({
    required this.deals,
    this.lastDocument,
    this.hasMore = false,
    this.isFromCache = false,
  });
}

/// Fırsat paylaşımı tamamlandığında dönen sonuç modeli.
class DealSubmitResult {
  final String dealId;
  final bool isApproved;

  const DealSubmitResult({
    required this.dealId,
    required this.isApproved,
  });
}

class DealService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Bozuk veya eksik Firestore verisi içeren dokümanları loglar ve güvenli şekilde null döndürür
  Deal? _safeParseDeal(DocumentSnapshot doc) {
    try {
      return Deal.fromFirestore(doc);
    } catch (e, stack) {
      _log('❌ Deal parse hatası (doc.id: ${doc.id}): $e');
      SystemLogService.instance.logError(
        category: 'data_parsing',
        errorType: 'DealDeserializationException',
        message: 'Fırsat dokümanı parse edilemedi (${doc.id}): $e',
        stack: stack,
        severity: SystemErrorSeverity.error,
        metadata: {'docId': doc.id},
      );
      return null;
    }
  }

  // Deals koleksiyonunu dinleme (En son 100 onaylı fırsat ile sınırlandırılmış güvenli akış)
  // Geriye dönük uyumluluk için korunmuştur. Anasayfa FS-09 gereğince getDealsPaginated ve getLatestDealStream kullanır.
  Stream<DealsSnapshot> getDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 48));
      
      final deals = snapshot.docs
          .map((doc) => _safeParseDeal(doc))
          .where((deal) {
            if (deal == null) return false;
            if (deal.isTest == true) return false;
            if (deal.createdAt.isBefore(cutoffTime)) return false;
            return true;
          })
          .cast<Deal>()
          .toList();
      
      // Home Feed Skoru (homeFeedScore) ile sırala (Freshness + Trending - TrollPenalty - ExpiredFOMO)
      deals.sort((a, b) => b.homeFeedScore.compareTo(a.homeFeedScore));
      return DealsSnapshot(deals: deals, isFromCache: snapshot.metadata.isFromCache);
    });
  }

  // FS-09: Sayfalı ve SWR / Cache-First Destekli Fırsat Getirme
  // Tek seferlik sorgu (One-shot .get()), lastDocument ile gerçek imleçli sayfalama
  // ve isteğe bağlı Source (cache / server) kontrolü ile devasa kota tasarrufu sağlar.
  Future<DealsPageResult> getDealsPaginated({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? category,
    String? subCategory,
    Source source = Source.serverAndCache,
  }) async {
    try {
      Query query = _firestore
          .collection('deals')
          .where('isApproved', isEqualTo: true);

      if (category != null && category != 'tumu') {
        query = query.where('category', isEqualTo: category);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get(GetOptions(source: source));
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 48));

      final List<Deal> parsedDeals = [];
      DocumentSnapshot? newLastDoc;

      if (snapshot.docs.isNotEmpty) {
        newLastDoc = snapshot.docs.last;
      }

      for (final doc in snapshot.docs) {
        final deal = _safeParseDeal(doc);
        if (deal == null) continue;
        if (deal.isTest == true) continue;
        if (deal.createdAt.isBefore(cutoffTime)) continue;
        if (subCategory != null && subCategory.isNotEmpty && deal.subCategory != subCategory) {
          continue;
        }
        parsedDeals.add(deal);
      }

      // Sadece ilk sayfa yüklemesinde (lastDocument == null) feed skoruyla sırala;
      // Sayfalandıkça gelen sayfalarda liste zıplamasını engellemek için kronolojik/skor akışını koru
      if (lastDocument == null) {
        parsedDeals.sort((a, b) => b.homeFeedScore.compareTo(a.homeFeedScore));
      }

      final bool hasMore = snapshot.docs.length >= limit;
      final bool isFromCache = snapshot.metadata.isFromCache;

      return DealsPageResult(
        deals: parsedDeals,
        lastDocument: newLastDoc,
        hasMore: hasMore,
        isFromCache: isFromCache,
      );
    } catch (e, stack) {
      _log('Pagination hatası: $e');
      SystemLogService.instance.logError(
        category: 'deal_pagination',
        errorType: 'PaginationException',
        message: 'Fırsatlar sayfalanırken hata oluştu: $e',
        stack: stack,
        severity: SystemErrorSeverity.warning,
      );
      return DealsPageResult(
        deals: [],
        lastDocument: lastDocument,
        hasMore: false,
      );
    }
  }

  // FS-18: Popüler Fırsatlar Sayfalı ve SWR Destekli Getirme
  // 200 dokümanlık açık WebSocket .snapshots() akışını tasfiye eder.
  Future<DealsPageResult> getPopularDealsPaginated({
    int limit = 40,
    DocumentSnapshot? lastDocument,
    int minHotVotes = 3,
    Source source = Source.serverAndCache,
  }) async {
    try {
      Query query = _firestore
          .collection('deals')
          .where('isApproved', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get(GetOptions(source: source));
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 48));

      final List<Deal> parsedDeals = [];
      DocumentSnapshot? newLastDoc;

      if (snapshot.docs.isNotEmpty) {
        newLastDoc = snapshot.docs.last;
      }

      for (final doc in snapshot.docs) {
        final deal = _safeParseDeal(doc);
        if (deal == null) continue;
        if (deal.isTest == true) continue;
        if (deal.isExpired == true) continue;
        if (deal.hotVotes < minHotVotes) continue;
        if (deal.netScore <= 0) continue;
        if (deal.createdAt.isBefore(cutoffTime)) continue;
        parsedDeals.add(deal);
      }

      // Popülerlik skoruna göre sırala (Wilson Score + Zaman Çürümesi)
      if (lastDocument == null) {
        parsedDeals.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
      }

      final bool hasMore = snapshot.docs.length >= limit;
      final bool isFromCache = snapshot.metadata.isFromCache;

      return DealsPageResult(
        deals: parsedDeals,
        lastDocument: newLastDoc,
        hasMore: hasMore,
        isFromCache: isFromCache,
      );
    } catch (e) {
      _log('getPopularDealsPaginated hatası: $e');
      return DealsPageResult(
        deals: [],
        lastDocument: lastDocument,
        hasMore: false,
      );
    }
  }

  // FS-18: Favori Kategorilerim Sayfalı ve SWR Destekli Getirme
  Future<DealsPageResult> getFollowedCategoriesDealsPaginated({
    required String userId,
    int limit = 40,
    DocumentSnapshot? lastDocument,
    Source source = Source.serverAndCache,
  }) async {
    try {
      // 1. Kullanıcının takip ettiği kategorileri al
      final subSnap = await _firestore
          .collection('notificationSubscriptions')
          .where('uid', isEqualTo: userId)
          .where('type', isEqualTo: 'category')
          .where('enabled', isEqualTo: true)
          .limit(100)
          .get();

      final Set<String> followedCategoryKeys = {};
      final Set<String> followedSubCategoryKeys = {};

      for (var doc in subSnap.docs) {
        final key = (doc.data()['key'] as String? ?? '').toLowerCase();
        if (key.isEmpty) continue;
        if (key.contains(':')) {
          followedSubCategoryKeys.add(key);
        } else {
          followedCategoryKeys.add(key);
        }
      }

      if (followedCategoryKeys.isEmpty && followedSubCategoryKeys.isEmpty) {
        return const DealsPageResult(
          deals: [],
          lastDocument: null,
          hasMore: false,
          isFromCache: false,
        );
      }

      // 2. Fırsatları sayfalı çek
      Query query = _firestore
          .collection('deals')
          .where('isApproved', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get(GetOptions(source: source));
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 48));

      final List<Deal> parsedDeals = [];
      DocumentSnapshot? newLastDoc;

      if (snapshot.docs.isNotEmpty) {
        newLastDoc = snapshot.docs.last;
      }

      for (final doc in snapshot.docs) {
        final deal = _safeParseDeal(doc);
        if (deal == null) continue;
        if (deal.isTest == true) continue;
        if (deal.createdAt.isBefore(cutoffTime)) continue;

        final catLower = deal.category.toLowerCase();
        bool matches = followedCategoryKeys.contains(catLower);
        if (!matches && deal.subCategory != null && deal.subCategory!.isNotEmpty) {
          final subKey = '$catLower:${deal.subCategory!.toLowerCase()}';
          matches = followedSubCategoryKeys.contains(subKey);
        }

        if (matches) {
          parsedDeals.add(deal);
        }
      }

      if (lastDocument == null) {
        parsedDeals.sort((a, b) => b.homeFeedScore.compareTo(a.homeFeedScore));
      }

      final bool hasMore = snapshot.docs.length >= limit;
      final bool isFromCache = snapshot.metadata.isFromCache;

      return DealsPageResult(
        deals: parsedDeals,
        lastDocument: newLastDoc,
        hasMore: hasMore,
        isFromCache: isFromCache,
      );
    } catch (e) {
      _log('getFollowedCategoriesDealsPaginated hatası: $e');
      return DealsPageResult(
        deals: [],
        lastDocument: lastDocument,
        hasMore: false,
      );
    }
  }

  // FS-09: Yalnızca en yeni onaylı fırsatı dinleyen ultra hafif dinleyici (limit: 1)
  // 100 doküman yerine yalnızca tek bir doküman izlenir; oy/yorum değişimlerinde tetiklenmez.
  Stream<Deal?> getLatestDealStream({String? category}) {
    Query query = _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true);

    if (category != null && category != 'tumu') {
      query = query.where('category', isEqualTo: category);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final deal = _safeParseDeal(snapshot.docs.first);
      if (deal == null || deal.isTest == true) return null;
      return deal;
    });
  }

  /// FS-20: Hibrit Arama Kademe 2 — Firestore Sunucu Tabanlı Hedefli Arama.
  /// 40 Milyon okuma maliyeti patlamasını engeller.
  /// Sadece en fazla [limit] dokümanlık tekil `array-contains` hedefli sorgu atar.
  Future<List<Deal>> searchDealsServer({
    required String query,
    String? category,
    int limit = 30,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final tokens = DealSearchEngine.tokenize(cleanQuery);
    if (tokens.isEmpty) return [];

    try {
      // En ayırt edici / en uzun anahtar kelimeyi seç (örn: "playstation" veya "supurge")
      final sortedTokens = List<String>.from(tokens)..sort((a, b) => b.length.compareTo(a.length));
      final primaryToken = sortedTokens.first;

      final queryRef = _firestore
          .collection('deals')
          .where('searchKeywords', arrayContains: primaryToken)
          .limit(limit);

      final snapshot = await queryRef.get();
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(days: 30)); // Son 30 günün fırsatları

      final List<Deal> serverDeals = [];
      for (final doc in snapshot.docs) {
        final deal = _safeParseDeal(doc);
        if (deal == null) continue;
        if (deal.isApproved != true) continue;
        if (deal.isTest == true) continue;
        if (deal.createdAt.isBefore(cutoffTime)) continue;
        if (category != null && category.isNotEmpty && category != 'tumu' && deal.category != category) {
          continue;
        }
        serverDeals.add(deal);
      }

      // Alaka düzeyi puanlaması (Relevance score) uygulayarak döndür
      return DealSearchEngine.searchDeals(serverDeals, cleanQuery);
    } catch (e, stack) {
      _log('⚠️ searchDealsServer hatası: $e');
      SystemLogService.instance.logError(
        category: 'search',
        errorType: 'ServerSearchException',
        message: 'Sunucu araması başarısız: $e',
        stack: stack,
        severity: SystemErrorSeverity.warning,
        metadata: {'query': query, 'category': category},
      );
      return [];
    }
  }

  // Onay bekleyen deal'leri dinleme (Maksimum 100 kayıt)
  Stream<List<Deal>> getPendingDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: false)
        .where('isUserSubmitted', isEqualTo: false)
        .where('isExpired', isEqualTo: false)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs
          .map((doc) => _safeParseDeal(doc))
          .where((deal) => deal != null && deal.isTest != true)
          .cast<Deal>()
          .toList();
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Kullanıcıların paylaştığı onay bekleyen deal'leri dinleme (Maksimum 100 kayıt)
  Stream<List<Deal>> getUserSubmittedPendingDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: false)
        .where('isExpired', isEqualTo: false)
        .where('isUserSubmitted', isEqualTo: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs
          .map((doc) => _safeParseDeal(doc))
          .where((deal) => deal != null && deal.isApproved != true && deal.isTest != true)
          .cast<Deal>()
          .toList();
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Yayınlanmış (onaylanmış) deal'leri dinleme (Maksimum 100 güncel kayıt)
  Stream<List<Deal>> getApprovedDealsStream() {
    return _firestore
        .collection('deals')
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 48));
      final deals = snapshot.docs
          .map((doc) => _safeParseDeal(doc))
          .where((deal) => deal != null && deal.isApproved == true && deal.isExpired != true && !deal.createdAt.isBefore(cutoffTime) && deal.isTest != true)
          .cast<Deal>()
          .toList();
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Süresi bitmiş deal'leri getir (Maksimum 100 kayıt)
  Stream<List<Deal>> getExpiredDealsStream() {
    return _firestore
        .collection('deals')
        .where('isExpired', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs
          .map((doc) => _safeParseDeal(doc))
          .where((deal) => deal != null && deal.isTest != true)
          .cast<Deal>()
          .toList();
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  Future<Deal?> getDeal(String dealId) async {
    try {
      final doc = await _firestore.collection('deals').doc(dealId).get();
      if (doc.exists) {
        return Deal.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _log('Deal getirme hatası: $e');
      return null;
    }
  }

  // Yeni deal oluşturma
  Future<DealSubmitResult?> createDeal({
    required String title,
    required String description,
    required double price,
    required String store,
    required String category,
    String? subCategory,
    required String imageUrl,
    required String url,
    required String userId,
    String? postedByName,
    String? postedByAvatar,
    double? originalPrice,
    String? priceLabel,
    double? ratingValue,
    int? ratingCount,
    String? brand,
    bool isAmazonWarehouse = false,
    bool hidePrice = false,
  }) async {
    try {
      // Fırsat paylaşım engeli kontrolü: Admin dahil kimse paylaşım yasağındayken fırsat ekleyemez
      final dealBanDoc = await _firestore.collection('dealBannedUsers').doc(userId).get();
      if (dealBanDoc.exists) {
        throw Exception('Fırsat paylaşım izniniz kısıtlanmıştır. Topluluk kurallarına uyum nedeniyle yeni fırsat paylaşamazsınız.');
      }

      final isAdmin = await _authService.isAdmin();
      
      if (!isAdmin) {
        final isSharingEnabled = await isDealSharingEnabled();
        if (!isSharingEnabled) {
          throw Exception('Fırsat paylaşımı şu anda bakım nedeniyle geçici olarak durdurulmuştur.');
        }
      }
      
      final moderationResult = ContentModerationService.moderateContent(
        title: title,
        description: description,
      );
      
      if (!moderationResult.isSafe) {
        throw Exception(moderationResult.reason ?? 'İçerik uygunsuz');
      }
            _log('═══════════════════════════════════════════════════════════');
      _log('📥 [AFFILIATE-TEST] DealService.createDeal Başlatıldı');
      _log('   🔗 Ham URL: $url');
      _log('   🏷️ Başlık: $title');
      _log('   🏪 Mağaza: $store');

      // Akıllı Mükerrer Link Kontrolü
      // Önce yönlendirmeleri çözüyoruz (short link vb. durumları için)
      String resolvedUrl = url;
      try {
        final linkPreviewService = LinkPreviewService();
        _log('🔄 [AFFILIATE-TEST] Kısa link ve yönlendirme kontrolü yapılıyor...');
        resolvedUrl = await linkPreviewService.resolveUrlRedirects(url);
        _log('🎯 [AFFILIATE-TEST] Çözümlenen Kanonik URL: $resolvedUrl');
      } catch (e) {
        _log('⚠️ [AFFILIATE-TEST] Yönlendirme çözülemedi: $e');
      }

      final cleanUrl = Deal.cleanProductUrl(resolvedUrl);
      _log('🧹 [AFFILIATE-TEST] Clean URL (Mükerrerlik için): $cleanUrl');
      if (cleanUrl.isNotEmpty) {
        final querySnapshot = await _firestore
            .collection('deals')
            .where('cleanUrl', isEqualTo: cleanUrl)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          final now = DateTime.now();
          for (var doc in querySnapshot.docs) {
            final dealData = doc.data();
            
            // 1. Reddedilmiş fırsat kontrolü (Reddedilenler yeni paylaşımı engellemez)
            final isRejected = dealData['isRejected'] == true || dealData['status'] == 'rejected';
            if (isRejected) {
              continue;
            }

            // 2. Yaş Kontrolü (48 saatlik aktif pencere - Cron beklenmeden anında tespit)
            final createdAtRaw = dealData['createdAt'] ?? dealData['timestamp'];
            DateTime? dealCreatedAt;
            if (createdAtRaw is Timestamp) {
              dealCreatedAt = createdAtRaw.toDate();
            } else if (createdAtRaw is DateTime) {
              dealCreatedAt = createdAtRaw;
            } else if (createdAtRaw is String) {
              dealCreatedAt = DateTime.tryParse(createdAtRaw);
            }

            if (dealCreatedAt != null && dealCreatedAt.isBefore(now.subtract(const Duration(hours: 48)))) {
              continue; // 48 saati geçmiş, arşiv fırsat, mükerrer sayılmaz!
            }
            
            // 3. Pasif/Biten Kontrolleri
            final isExpired = dealData['isExpired'] == true || dealData['status'] == 'expired';
            final expiredVotes = dealData['expiredVotes'] ?? 0;
            if (isExpired || expiredVotes >= 15) {
              continue;
            }
            
            // 4. Soğuk oylama kontrolü (Topluluk tarafından reddedilenler yeni paylaşımı engellemez)
            final hotVotes = dealData['hotVotes'] ?? 0;
            final coldVotes = dealData['coldVotes'] ?? 0;
            final totalVotes = hotVotes + coldVotes;
            if (totalVotes >= 5) {
              final hotPercentage = (hotVotes / totalVotes * 100);
              if (hotPercentage < 20) {
                continue;
              }
            }
            if (hotVotes - coldVotes <= -5) {
              continue;
            }

            // 5. Fiyat Düşüşü (Price Drop) Toleransı
            // Eğer yeni girilen fiyat, mevcut aktif fırsatın fiyatından en az %5 daha ucuzsa yeni fırsat olarak izin ver
            double existingPrice = PriceFormatUtil.parse(dealData['price']) ?? 0.0;

            if (price > 0 && existingPrice > 0 && price <= (existingPrice * 0.95)) {
              _log('🏷️ [DEDUPLICATION] Fiyat düşüşü tespit edildi (Eski: $existingPrice, Yeni: $price). Paylaşıma izin veriliyor.');
              continue;
            }

            // 6. Onay Durumu Kontrolü (Onay bekleyen fırsat kuyrukta spam olmasın)
            final isDocApproved = dealData['isApproved'] == true;
            if (!isDocApproved) {
              throw Exception('pending_approval:${doc.id}');
            }
            
            // 7. Aktif onaylı fırsat eşleşti -> paylaşımı engelle
            throw Exception('already_shared:${doc.id}');
          }
        }
      }
      
      bool isApprovalRequired = true;
      try {
        final settingsDoc = await _firestore.collection('settings').doc('app').get();
        if (settingsDoc.exists && settingsDoc.data() != null) {
          final sData = settingsDoc.data()!;
          isApprovalRequired = sData['dealApprovalRequired'] ?? true;
          AffiliateService.syncFromMap(sData);
        }
      } catch (e) {
        _log('⚠️ Settings loading error: $e');
      }
      _log('📋 [AFFILIATE-TEST] Onay Modu: ${isApprovalRequired ? "Admin Onayı Bekliyor (isApproved: false)" : "Doğrudan Yayında (isApproved: true)"}');

      // Yazar bilgilerini al (snapshot)
      String? finalPosterName = (postedByName != null && postedByName.trim().isNotEmpty) ? postedByName.trim() : null;
      String? finalPosterAvatar = (postedByAvatar != null && postedByAvatar.trim().isNotEmpty) ? postedByAvatar.trim() : null;
      if (finalPosterName == null || finalPosterAvatar == null) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final uData = userDoc.data();
            final usernameVal = uData?['username']?.toString() ?? uData?['displayName']?.toString() ?? uData?['nickname']?.toString();
            if (finalPosterName == null && usernameVal != null && usernameVal.trim().isNotEmpty) {
              finalPosterName = usernameVal.trim();
            }
            final rawAvatar = uData?['profileImageUrl']?.toString() ?? uData?['photoURL']?.toString();
            if (finalPosterAvatar == null && rawAvatar != null && rawAvatar.trim().isNotEmpty) {
              finalPosterAvatar = migrateAssetPath(rawAvatar.trim());
            }
          }
        } catch (_) {}
      }

      finalPosterName ??= 'Kullanıcı';
      if (finalPosterAvatar != null && finalPosterAvatar.isNotEmpty) {
        finalPosterAvatar = migrateAssetPath(finalPosterAvatar);
      } else {
        finalPosterAvatar = null;
      }

      final compliantDescription = AdvertisingComplianceService.ensureDisclosure(description);

      // Eğer girilen URL zaten geçerli bir Paylaştıkça Kazan affiliate linki (/u/) ise doğrudan url'i koru,
      // değilse resolvedUrl üzerinden affiliate dönüştürmesini yap.
      String sourceForAffiliate = url;
      if (url.toLowerCase().contains('incehesap.com/u/')) {
        sourceForAffiliate = url;
      } else if (resolvedUrl.isNotEmpty && resolvedUrl.startsWith('http')) {
        sourceForAffiliate = resolvedUrl;
      }

      String finalDealLink = sourceForAffiliate;
      try {
        _log('⚡ [AFFILIATE-TEST] Fırsat kaydedilirken affiliate dönüştürme kontrolü yapılıyor...');
        final converted = await AffiliateService.resolveAndConvertToAffiliate(sourceForAffiliate);
        if (converted.isNotEmpty && converted != sourceForAffiliate) {
          finalDealLink = converted;
          _log('🎉 [AFFILIATE-TEST] Fırsat linki başarıyla affiliate linkine dönüştürüldü: $finalDealLink');
        } else {
          finalDealLink = converted.isNotEmpty ? converted : sourceForAffiliate;
          _log('ℹ️ [AFFILIATE-TEST] Affiliate kontrolü tamamlandı: $finalDealLink');
        }
      } catch (e) {
        _log('⚠️ [AFFILIATE-TEST] Fırsat oluşturulurken affiliate dönüştürme hatası: $e');
      }


      final deal = Deal(
        id: '',
        title: title,
        description: compliantDescription,
        price: price,
        store: store,
        category: category,
        subCategory: subCategory,
        link: finalDealLink,
        imageUrl: imageUrl,
        postedBy: userId,
        postedByName: finalPosterName,
        postedByAvatar: finalPosterAvatar,
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        createdAt: DateTime.now(),
        isEditorPick: false,
        isApproved: isApprovalRequired ? false : true,
        isUserSubmitted: true,
        cleanUrl: cleanUrl,
        originalPrice: originalPrice,
        priceLabel: priceLabel,
        ratingValue: ratingValue,
        ratingCount: ratingCount,
        brand: brand,
        isAmazonWarehouse: isAmazonWarehouse || Deal.checkIsAmazonWarehouse(url) || Deal.checkIsAmazonWarehouse(resolvedUrl),
        hidePrice: hidePrice,
        searchKeywords: DealSearchEngine.generateSearchKeywords(
          title: title,
          brand: brand,
          store: store,
          category: category,
          subCategory: subCategory,
        ),
      );

      final docRef = await _firestore.collection('deals').add(deal.toFirestore());
      
      // P1-11 (R-AUTH-04): İstemci doğrudan points/badges artıramaz (RBAC Kalkanı).
      // Puan ve rozetler Cloud Functions (onDealCreated / onDealUpdated) tarafından atomik ve güvenli olarak verilir.
      final userService = UserService();
      
      // Profil geçmişine minimalist fırsat kartı ekle
      await userService.addLastSharedDeal(
        userId,
        dealId: docRef.id,
        title: title,
        price: price,
        store: store,
        link: url,
      );
      return DealSubmitResult(
        dealId: docRef.id,
        isApproved: !isApprovalRequired,
      );
    } catch (e, stack) {
      _log('Deal oluşturma hatası: $e');
      final errorStr = e.toString();
      final isBusinessValidation = errorStr.contains('already_shared:') ||
          errorStr.contains('pending_approval:');
      if (!isBusinessValidation) {
        SystemLogService.instance.logError(
          category: 'submit_deal',
          subCategory: store,
          errorType: 'DealCreateException',
          message: errorStr,
          stack: stack,
          metadata: {'title': title, 'store': store, 'userId': userId},
        );
      }
      if (e is FirebaseException && e.code == 'permission-denied') {
        throw Exception('Fırsat paylaşım izniniz kısıtlanmıştır veya bu işlem için yetkiniz bulunmamaktadır.');
      } else if (e.toString().contains('permission-denied')) {
        throw Exception('Fırsat paylaşım izniniz kısıtlanmıştır veya bu işlem için yetkiniz bulunmamaktadır.');
      }
      rethrow;
    }
  }

  Future<bool> updateDeal(String dealId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('deals').doc(dealId).update(updates);
      return true;
    } catch (e) {
      _log('Deal güncelleme hatası: $e');
      return false;
    }
  }

  Future<bool> deleteDeal(String dealId) async {
    try {
      await _firestore.collection('deals').doc(dealId).delete();
      return true;
    } catch (e) {
      _log('Deal silme hatası: $e');
      return false;
    }
  }

  // Vote İşlemleri (FS-08: Kilitsiz Atomik Pipeline & Alt Doküman İzolasyonu)
  // runTransaction kaldırılmıştır; alt koleksiyon (deals/{dealId}/votes/{userId}) üzerinden
  // kullanıcı bazlı izole okuma/yazma yapılır ve ana doküman sayaçları (hotVotes, coldVotes)
  // FieldValue.increment(delta) ile çekişmesiz, kuyruklu ve atomik olarak güncellenir.
  Future<bool> _updateVoteInternal(String dealId, String userId, String? newType) async {
    final cleanDealId = dealId.trim();
    final cleanUserId = userId.trim();
    if (cleanDealId.isEmpty || cleanUserId.isEmpty) {
      return false;
    }
    if (newType != null && newType != 'hot' && newType != 'cold') {
      return false;
    }

    try {
      final dealRef = _firestore.collection('deals').doc(cleanDealId);
      final voteRef = dealRef.collection('votes').doc(cleanUserId);

      // 1. Kullanıcının mevcut oyu izole subcollection'dan kilit olmadan okunur
      final voteSnapshot = await voteRef.get();

      String? oldType;
      bool hasExpired = false;
      if (voteSnapshot.exists) {
        final data = voteSnapshot.data();
        oldType = data?['type'] as String?;
        hasExpired = data?['expired'] == true;
      }

      // Eğer eski oy ile yeni oy aynı ise hiçbir şey yapma (idempotent no-op)
      if (oldType == newType) {
        return true;
      }

      int hotDelta = 0;
      int coldDelta = 0;

      // 2. Eski oyun deltasını hesapla
      if (oldType == 'hot') {
        hotDelta -= 1;
      } else if (oldType == 'cold') {
        coldDelta -= 1;
      }

      // 3. Yeni oyun deltasını hesapla
      if (newType == 'hot') {
        hotDelta += 1;
      } else if (newType == 'cold') {
        coldDelta += 1;
      }

      final batch = _firestore.batch();

      // 4. votes/{userId} alt dokümanını güncelle (Kullanıcıya özel izole doküman)
      if (newType == null) {
        if (hasExpired) {
          // 'expired' oyu da verilmişse dokümanı silme, sadece 'type' alanını kaldır
          batch.update(voteRef, {
            'type': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Başka alan kalmadıysa dokümanı tamamen sil
          batch.delete(voteRef);
        }
      } else {
        batch.set(voteRef, {
          'type': newType,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 5. deals/{dealId} ana dokümanını FieldValue.increment ile çekişmesiz atomik güncelle
      final Map<String, dynamic> dealUpdates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (hotDelta != 0) {
        dealUpdates['hotVotes'] = FieldValue.increment(hotDelta);
      }
      if (coldDelta != 0) {
        dealUpdates['coldVotes'] = FieldValue.increment(coldDelta);
      }

      batch.update(dealRef, dealUpdates);

      await batch.commit();

      // Deal sahibine puan ver / geri al (exploit ve yetki güvenliği):
      // Puan (+2) ve beğeni (+1) artışı ile rozet kazanımları, Firestore RBAC güvenliği gereği
      // sunucu tarafında Cloud Functions 'onDealUpdated' trigger'ı üzerinden Admin SDK ile atomik işletilir.
      return true;
    } catch (e) {
      _log('updateVoteInternal hatası: $e');
      return false;
    }
  }

  Future<bool> addHotVote(String dealId, String userId) => _updateVoteInternal(dealId, userId, 'hot');
  Future<bool> addColdVote(String dealId, String userId) => _updateVoteInternal(dealId, userId, 'cold');
  Future<bool> removeVote(String dealId, String userId) => _updateVoteInternal(dealId, userId, null);
  Future<bool> removeHotVote(String dealId, String userId) => _updateVoteInternal(dealId, userId, null);
  Future<bool> removeColdVote(String dealId, String userId) => _updateVoteInternal(dealId, userId, null);

  // Bağımsız Fırsat Bitti Oylaması (FS-08: Kilitsiz Atomik Pipeline)
  Future<bool> addExpiredVote(String dealId, String userId) async {
    final cleanDealId = dealId.trim();
    final cleanUserId = userId.trim();
    if (cleanDealId.isEmpty || cleanUserId.isEmpty) {
      return false;
    }

    try {
      final dealRef = _firestore.collection('deals').doc(cleanDealId);
      final voteRef = dealRef.collection('votes').doc(cleanUserId);

      final voteSnapshot = await voteRef.get();
      if (voteSnapshot.exists && voteSnapshot.data()?['expired'] == true) {
        return true; // Zaten bitirme oyu verilmiş
      }

      final dealSnapshot = await dealRef.get();
      if (!dealSnapshot.exists) return false;

      final dealData = dealSnapshot.data() ?? {};
      final int hotVotes = (dealData['hotVotes'] as num?)?.toInt() ?? 0;
      final int currentExpired = (dealData['expiredVotes'] as num?)?.toInt() ?? 0;
      final bool isAlreadyExpired = dealData['isExpired'] == true;

      final dynamicLimit = (5 + (hotVotes / 5).floor()).clamp(5, 20);
      final bool shouldMarkExpired = (currentExpired + 1) >= dynamicLimit;

      final batch = _firestore.batch();
      batch.set(voteRef, {
        'expired': true,
        'expiredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final Map<String, dynamic> dealUpdates = {
        'expiredVotes': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (shouldMarkExpired && !isAlreadyExpired) {
        dealUpdates['isExpired'] = true;
        dealUpdates['status'] = 'expired';
      }

      batch.update(dealRef, dealUpdates);
      await batch.commit();

      return true;
    } catch (e) {
      _log('addExpiredVote hatası: $e');
      return false;
    }
  }

  Future<bool> removeExpiredVote(String dealId, String userId) async {
    final cleanDealId = dealId.trim();
    final cleanUserId = userId.trim();
    if (cleanDealId.isEmpty || cleanUserId.isEmpty) {
      return false;
    }

    try {
      final dealRef = _firestore.collection('deals').doc(cleanDealId);
      final voteRef = dealRef.collection('votes').doc(cleanUserId);

      final voteSnapshot = await voteRef.get();
      if (!voteSnapshot.exists) return false;

      final bool alreadyVotedExpired = voteSnapshot.data()?['expired'] == true;
      if (!alreadyVotedExpired) return true; // Zaten oy verilmemiş

      final batch = _firestore.batch();
      final String? type = voteSnapshot.data()?['type'] as String?;
      if (type == null) {
        batch.delete(voteRef);
      } else {
        batch.update(voteRef, {
          'expired': FieldValue.delete(),
          'expiredAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      batch.update(dealRef, {
        'expiredVotes': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      _log('removeExpiredVote hatası: $e');
      return false;
    }
  }

  Future<bool> hasUserVotedExpired(String dealId, String userId) async {
    final cleanDealId = dealId.trim();
    final cleanUserId = userId.trim();
    if (cleanDealId.isEmpty || cleanUserId.isEmpty) return false;
    try {
      final doc = await _firestore.collection('deals').doc(cleanDealId).collection('votes').doc(cleanUserId).get();
      return doc.data()?['expired'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getUserVote(String dealId, String userId) async {
    final cleanDealId = dealId.trim();
    final cleanUserId = userId.trim();
    if (cleanDealId.isEmpty || cleanUserId.isEmpty) return null;
    try {
      final doc = await _firestore.collection('deals').doc(cleanDealId).collection('votes').doc(cleanUserId).get();
      return doc.data()?['type'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Fırsatı bitir/başlat
  Future<bool> markDealAsExpired(String dealId) async => updateDeal(dealId, {
        'isExpired': true,
        'status': 'expired',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<bool> unexpireDeal(
    String dealId, {
    bool refreshTimestamp = false,
    bool hidePrice = false,
    bool isEditorPick = false,
  }) async {
    final Map<String, dynamic> updates = {
      'isExpired': false,
      'isApproved': true,
      'isRejected': false,
      'status': 'active',
      'expiredVotes': 0,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (refreshTimestamp) {
      updates['createdAt'] = FieldValue.serverTimestamp();
      updates['timestamp'] = FieldValue.serverTimestamp();
    }
    if (hidePrice) {
      updates['hidePrice'] = true;
    }
    if (isEditorPick) {
      updates['isEditorPick'] = true;
    }
    return updateDeal(dealId, updates);
  }

  // Toplu süresi bitenleri yayına alma (Batch Unexpire - 400 dokümanlık parçalama korumalı)
  Future<bool> unexpireDealsBatch(
    List<String> dealIds, {
    bool refreshTimestamp = false,
  }) async {
    if (dealIds.isEmpty) return true;
    try {
      for (var i = 0; i < dealIds.length; i += 400) {
        final end = (i + 400 > dealIds.length) ? dealIds.length : i + 400;
        final chunk = dealIds.sublist(i, end);
        final batch = _firestore.batch();
        for (final id in chunk) {
          final Map<String, dynamic> updates = {
            'isExpired': false,
            'isApproved': true,
            'isRejected': false,
            'status': 'active',
            'expiredVotes': 0,
            'approvedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (refreshTimestamp) {
            updates['createdAt'] = FieldValue.serverTimestamp();
            updates['timestamp'] = FieldValue.serverTimestamp();
          }
          batch.update(_firestore.collection('deals').doc(id), updates);
        }
        await batch.commit();
      }
      return true;
    } catch (e) {
      _log('Batch unexpire hatası: $e');
      return false;
    }
  }

  // Deal paylaşım ayarları
  Future<bool> isDealSharingEnabled() async {
    try {
      final doc = await _firestore.collection('settings').doc('app').get();
      return doc.data()?['dealSharingEnabled'] ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<bool> setDealSharingEnabled(bool enabled) async {
    try {
      await _firestore.collection('settings').doc('app').set({
        'dealSharingEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  // Test deals dinleme stream'i
  Stream<List<Deal>> getTestDealsStream() {
    return _firestore
        .collection('deals')
        .where('isTest', isEqualTo: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final deals = snapshot.docs
          .map((doc) => _safeParseDeal(doc))
          .where((deal) => deal != null)
          .cast<Deal>()
          .toList();
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    });
  }

  // Toplu deal silme (Maks 400 dokümanlık parçalar ile batch commit taşma koruması)
  Future<bool> deleteDealsBatch(List<String> dealIds) async {
    try {
      if (dealIds.isEmpty) return true;
      for (var i = 0; i < dealIds.length; i += 400) {
        final end = (i + 400 > dealIds.length) ? dealIds.length : i + 400;
        final chunk = dealIds.sublist(i, end);
        final batch = _firestore.batch();
        for (final id in chunk) {
          batch.delete(_firestore.collection('deals').doc(id));
        }
        await batch.commit();
      }
      return true;
    } catch (e) {
      _log('Batch silme hatası: $e');
      return false;
    }
  }
}
