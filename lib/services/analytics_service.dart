import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// FırsatKolik Merkezi Telemetri, Kullanıcı Trafiği ve Analitik Servisi
/// 
/// 1. Google Analytics 4 (GA4) üzerinden kullanıcı aksiyonlarını ve trafiği izler.
/// 2. Her analitik aksiyonunu aynı zamanda Firebase Crashlytics Breadcrumb (Ekmek Kırıntısı)
///    olarak kaydederek çökme öncesi kullanıcı adımlarının film şeridi gibi çıkmasını sağlar.
/// 3. %100 Güvenli Sarmalayıcı (Safe Wrapper) mimarisiyle çalışır; analitik hataları
///    uygulama arayüzünü veya kullanıcı akışını asla bloklamaz veya çökertmez.
class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService instance = AnalyticsService._internal();
  factory AnalyticsService() => instance;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// MaterialApp.navigatorObservers için otomatik sayfa takipçisi
  late final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: _analytics,
  );

  /// Kullanıcı Kimliğini Hem Analytics Hem Crashlytics'e Eşler (KVKK / Anonim UID)
  Future<void> setUser(String? userId) async {
    try {
      if (userId != null && userId.isNotEmpty) {
        await _analytics.setUserId(id: userId);
        await FirebaseCrashlytics.instance.setUserIdentifier(userId);
        if (kDebugMode) {
          print('👤 [Analytics] Kullanıcı kimliği eşlendi: $userId');
        }
      } else {
        await _analytics.setUserId(id: null);
        await FirebaseCrashlytics.instance.setUserIdentifier('');
        if (kDebugMode) {
          print('👤 [Analytics] Kullanıcı kimliği sıfırlandı (Oturum kapatıldı)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [Analytics] setUser hatası: $e');
      }
    }
  }

  /// Crashlytics İçin Otomatik Ekmek Kırıntısı (Breadcrumb) Kaydı
  void _recordBreadcrumb(String eventName, Map<String, Object?>? parameters) {
    try {
      final paramStr = (parameters != null && parameters.isNotEmpty)
          ? ' -> $parameters'
          : '';
      FirebaseCrashlytics.instance.log('📍 [Action] $eventName$paramStr');
    } catch (_) {
      // Breadcrumb hatası sessizce yutulur
    }
  }

  /// Genel Özel Olay (Custom Event) Kaydedici
  Future<void> logCustomEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      _recordBreadcrumb(name, parameters);
      if (kDebugMode) {
        print('📊 [Analytics] Event: $name | Params: $parameters');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [Analytics] Event ($name) hatası: $e');
      }
    }
  }

  // ===========================================================================
  // FIRSATKOLİK ÖZEL İŞ METRİKLERİ (BUSINESS EVENTS)
  // ===========================================================================

  /// 1. Fırsata Git (Mağaza Linki) Tıklaması - EN KRİTİK AFFILIATE GELİR METRİĞİ
  Future<void> logDealOutboundClick({
    required String dealId,
    required String storeName,
    required String category,
    double? price,
    String? url,
  }) async {
    final params = <String, Object>{
      'deal_id': dealId,
      'store_name': storeName.toLowerCase().trim(),
      'category': category,
      if (price != null) 'price': price,
      if (url != null) 'url_domain': Uri.tryParse(url)?.host ?? 'unknown',
    };
    await logCustomEvent('deal_outbound_click', params);
  }

  /// 2. Fırsat Detay Sayfası Görüntüleme
  Future<void> logDealView({
    required String dealId,
    required String storeName,
    required String category,
    String? source,
  }) async {
    final params = <String, Object>{
      'deal_id': dealId,
      'store_name': storeName.toLowerCase().trim(),
      'category': category,
      'source': source ?? 'feed',
    };
    await logCustomEvent('deal_view', params);
  }

  /// 3. Kupon Kodu Kopyalama Aksiyonu
  Future<void> logCouponCopied({
    required String couponId,
    required String storeName,
    required String source,
  }) async {
    final params = <String, Object>{
      'coupon_id': couponId,
      'store_name': storeName.toLowerCase().trim(),
      'source': source,
    };
    await logCustomEvent('coupon_copied', params);
  }

  /// 4. Aktüel Market Broşürü Görüntüleme
  Future<void> logCatalogView({
    required String storeName,
    required String catalogId,
    int? pageNumber,
  }) async {
    final params = <String, Object>{
      'store_name': storeName.toLowerCase().trim(),
      'catalog_id': catalogId,
      if (pageNumber != null) 'page_number': pageNumber,
    };
    await logCustomEvent('catalog_view', params);
  }

  /// 5. Arama Radarı Sorgusu
  Future<void> logSearch({
    required String searchTerm,
    int? resultsCount,
  }) async {
    final params = <String, Object>{
      'search_term': searchTerm.toLowerCase().trim(),
      if (resultsCount != null) 'results_count': resultsCount,
    };
    await logCustomEvent('search_performed', params);
  }

  /// 6. Sosyal / Organik Paylaşım
  Future<void> logDealShared({
    required String contentType,
    required String itemId,
    String? platform,
  }) async {
    final params = <String, Object>{
      'content_type': contentType,
      'item_id': itemId,
      if (platform != null) 'platform': platform,
    };
    await logCustomEvent('deal_shared', params);
  }

  /// 7. Sıcak / Soğuk Topluluk Oyu
  Future<void> logDealVoted({
    required String dealId,
    required String voteType,
  }) async {
    final params = <String, Object>{
      'deal_id': dealId,
      'vote_type': voteType,
    };
    await logCustomEvent('deal_voted', params);
  }

  /// 8. Kullanıcı Tarafından Yeni Fırsat Paylaşımı
  Future<void> logDealSubmitted({
    required String category,
    required String storeName,
    bool hasImage = false,
  }) async {
    final params = <String, Object>{
      'category': category,
      'store_name': storeName.toLowerCase().trim(),
      'has_image': hasImage,
    };
    await logCustomEvent('deal_submitted', params);
  }

  /// 9. FCM Bildirimi Etkileşimi (Bildirime Dokunarak Açma)
  Future<void> logNotificationInteraction({
    required String type,
    required String reason,
    String? dealId,
  }) async {
    final params = <String, Object>{
      'notification_type': type,
      'reason': reason,
      if (dealId != null) 'deal_id': dealId,
    };
    await logCustomEvent('notification_interaction', params);
  }

  /// 10. Kategori veya Sıralama Filtresi Seçimi
  Future<void> logFilterApplied({
    required String filterType,
    required String selectedValue,
  }) async {
    final params = <String, Object>{
      'filter_type': filterType,
      'selected_value': selectedValue,
    };
    await logCustomEvent('filter_applied', params);
  }
}
