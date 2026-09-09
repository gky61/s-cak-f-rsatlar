import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'base_affiliate_adapter.dart';
import 'adapters/teknosa_affiliate_adapter.dart';
import 'adapters/trendyol_affiliate_adapter.dart';
import 'adapters/hepsiburada_affiliate_adapter.dart';
import 'adapters/amazon_affiliate_adapter.dart';
import 'adapters/n11_affiliate_adapter.dart';
import 'adapters/gittigidiyor_affiliate_adapter.dart';
import 'adapters/incehesap_affiliate_adapter.dart';
import '../link_preview_service.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Tüm mağaza gelir ortaklığı (affiliate) adaptörlerini yöneten merkezi servis.
class AffiliateService {
  AffiliateService._();

  static StreamSubscription<DocumentSnapshot>? _settingsSubscription;

  /// Kayıtlı mağaza adaptörleri listesi (Genişletilebilir, izole mimari)
  static final List<BaseAffiliateAdapter> _adapters = [
    TeknosaAffiliateAdapter(),
    TrendyolAffiliateAdapter(),
    HepsiburadaAffiliateAdapter(),
    AmazonAffiliateAdapter(),
    N11AffiliateAdapter(),
    GittigidiyorAffiliateAdapter(),
    IncehesapAffiliateAdapter(),
  ];

  /// Firestore settings/app belgesini dinleyerek adaptör şalterlerini anlık senkronize eder
  static void initSettingsListener([FirebaseFirestore? firestore]) {
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      _settingsSubscription?.cancel();
      _settingsSubscription = db.collection('settings').doc('app').snapshots().listen((snap) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data() as Map<String, dynamic>;
          syncFromMap(data);
        }
      }, onError: (e) {
        _log('⚠️ [AFFILIATE-SETTINGS] Firestore settings dinleme hatası: $e');
      });
    } catch (e) {
      _log('⚠️ [AFFILIATE-SETTINGS] initSettingsListener hatası: $e');
    }
  }

  /// Map üzerinden şalterleri anında senkronize eder
  static void syncFromMap(Map<String, dynamic> data) {
    if (data.containsKey('teknosaAffiliateEnabled')) {
      final enabled = data['teknosaAffiliateEnabled'] != false;
      setStoreEnabled('teknosa', enabled);
      _log('⚙️ [AFFILIATE-SETTINGS] Teknosa şalteri senkronize edildi: $enabled');
    }
    if (data.containsKey('hepsiburadaAffiliateEnabled')) {
      final enabled = data['hepsiburadaAffiliateEnabled'] != false;
      setStoreEnabled('hepsiburada', enabled);
      _log('⚙️ [AFFILIATE-SETTINGS] Hepsiburada şalteri senkronize edildi: $enabled');
    }
    if (data.containsKey('amazonAffiliateEnabled')) {
      final enabled = data['amazonAffiliateEnabled'] != false;
      setStoreEnabled('amazon', enabled);
      _log('⚙️ [AFFILIATE-SETTINGS] Amazon şalteri senkronize edildi: $enabled');
    }
    if (data.containsKey('incehesapAffiliateEnabled') ||
        data.containsKey('incehesapSessionCookie')) {
      final enabled = data['incehesapAffiliateEnabled'] != false;
      final cookie = data['incehesapSessionCookie']?.toString();
      updateIncehesapSettings(
        isEnabled: enabled,
        sessionCookie: cookie,
      );
      _log('⚙️ [AFFILIATE-SETTINGS] İncehesap ayarları senkronize edildi: enabled=$enabled');
    }
  }

  /// Tek seferlik Firestore'dan anlık durum çeker (awaitable)
  static Future<void> syncSettingsNow([FirebaseFirestore? firestore]) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      final doc = await db.collection('settings').doc('app').get();
      if (doc.exists && doc.data() != null) {
        syncFromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      _log('⚠️ [AFFILIATE-SETTINGS] syncSettingsNow hatası: $e');
    }
  }

  /// Dinamik olarak mağaza affiliate şalterini günceller (Örn: Firestore settings/app senkronizasyonu)
  static void setStoreEnabled(String storeKey, bool enabled) {
    for (final adapter in _adapters) {
      if (adapter.storeKey.toLowerCase() == storeKey.toLowerCase()) {
        adapter.isEnabled = enabled;
        break;
      }
    }
  }

  /// Mağaza affiliate şalterinin açık olup olmadığını döner
  static bool isStoreEnabled(String storeKey) {
    for (final adapter in _adapters) {
      if (adapter.storeKey.toLowerCase() == storeKey.toLowerCase()) {
        return adapter.isEnabled;
      }
    }
    return false;
  }

  /// Amazon adaptör ayarlarını günceller
  static void updateAmazonSettings({bool? isEnabled, String? tag}) {
    for (var i = 0; i < _adapters.length; i++) {
      if (_adapters[i] is AmazonAffiliateAdapter) {
        final current = _adapters[i] as AmazonAffiliateAdapter;
        _adapters[i] = AmazonAffiliateAdapter(
          tag: tag ?? current.tag,
          enabled: isEnabled ?? current.isEnabled,
        );
        break;
      }
    }
  }

  /// Hepsiburada adaptör ayarlarını günceller
  static void updateHepsiburadaSettings({bool? isEnabled, String? accountName}) {
    for (var i = 0; i < _adapters.length; i++) {
      if (_adapters[i] is HepsiburadaAffiliateAdapter) {
        final current = _adapters[i] as HepsiburadaAffiliateAdapter;
        _adapters[i] = HepsiburadaAffiliateAdapter(
          accountName: accountName ?? current.accountName,
          trackerToken: current.trackerToken,
          campaign: current.campaign,
          utmSource: current.utmSource,
          utmMedium: current.utmMedium,
          utmCampaign: current.utmCampaign,
          wtInf: current.wtInf,
          enabled: isEnabled ?? current.isEnabled,
        );
        break;
      }
    }
  }

  /// Teknosa adaptör ayarlarını günceller
  static void updateTeknosaSettings({bool? isEnabled, String? userId}) {
    for (var i = 0; i < _adapters.length; i++) {
      if (_adapters[i] is TeknosaAffiliateAdapter) {
        final current = _adapters[i] as TeknosaAffiliateAdapter;
        _adapters[i] = TeknosaAffiliateAdapter(
          userId: userId ?? current.userId,
          offerId: current.offerId,
          affId: current.affId,
          enabled: isEnabled ?? current.isEnabled,
        );
        break;
      }
    }
  }

  /// İncehesap adaptör ayarlarını günceller
  static void updateIncehesapSettings({
    bool? isEnabled,
    String? sessionCookie,
  }) {
    for (var i = 0; i < _adapters.length; i++) {
      if (_adapters[i] is IncehesapAffiliateAdapter) {
        final current = _adapters[i] as IncehesapAffiliateAdapter;
        _adapters[i] = IncehesapAffiliateAdapter(
          sessionCookie: sessionCookie ?? current.sessionCookie,
          enabled: isEnabled ?? current.isEnabled,
        );
        break;
      }
    }
  }

  /// Verilen URL'e karşılık gelen adaptörü bulur
  static BaseAffiliateAdapter? getAdapter(String url) {
    if (url.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(url.trim());
      for (final adapter in _adapters) {
        if (adapter.canHandle(uri)) {
          return adapter;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Bir mağazanın veya URL'in şu an aktif/doğrulanmış ve AÇIK bir affiliate sistemine sahip olup olmadığını kontrol eder.
  /// Yalnızca prodüksiyona hazır VE şalteri açık olan adaptörler için true döner.
  /// Bu kontrol sayesinde arayüzde (Mobil/Web Admin) gereksiz affiliate akışları gizlenir.
  static bool isStoreSupported(String? storeNameOrUrl) {
    if (storeNameOrUrl == null || storeNameOrUrl.trim().isEmpty) return false;
    final clean = storeNameOrUrl.trim().toLowerCase();

    // 1. Mağaza adına göre kontrol (hem hazır hem de açık olmalı)
    for (final adapter in _adapters) {
      if (adapter.isAffiliateReady &&
          adapter.isEnabled &&
          (clean == adapter.storeKey.toLowerCase() || clean.contains(adapter.storeName.toLowerCase()))) {
        return true;
      }
    }

    // 2. URL'e göre kontrol (hem hazır hem de açık olmalı)
    final adapter = getAdapter(storeNameOrUrl);
    if (adapter != null && adapter.isAffiliateReady && adapter.isEnabled) {
      return true;
    }

    return false;
  }

  /// Orijinal mağaza linkini ilgili mağaza adaptörü üzerinden affiliate linkine dönüştürür.
  /// Hata veya devre dışı durumunda güvenli fallback olarak orijinal temiz linki döndürür.
  static String convertToAffiliateLink(String originalUrl) {
    if (originalUrl.trim().isEmpty) return originalUrl;

    try {
      final cleanUrl = originalUrl.trim();
      final uri = Uri.parse(cleanUrl);
      final adapter = getAdapter(cleanUrl);

      if (adapter != null) {
        // Canlı affiliate hazır olma kontrolü: Taslak adaptörler için dönüştürme yapma
        if (!adapter.isAffiliateReady) {
          _log('ℹ️ [AFFILIATE-TEST] ${adapter.storeName} adaptörü henüz taslak aşamasında, link korunuyor: $originalUrl');
          return originalUrl;
        }

        // Kill-switch: Mağaza adaptörü kapalıysa dönüşüm yapma, adaptörün unwrap/fallback metodunu çağır
        if (!adapter.isEnabled) {
          _log('🛑 [AFFILIATE-TEST] ${adapter.storeName} affiliate şalteri KAPALI (enabled=false).');
          _log('   🛡️ Güvenli Fallback Modu: Orijinal temiz linke unwrap ediliyor: $originalUrl');
          return adapter.convert(uri);
        }

        if (adapter.isAlreadyAffiliate(uri)) {
          _log('✨ [AFFILIATE-TEST] Link zaten admine ait hazır bir affiliate linki: $originalUrl');
          return originalUrl;
        }
        final converted = adapter.convert(uri);
        _log('🎉 [AFFILIATE-TEST] ${adapter.storeName} linki başarıyla affiliate linke dönüştürüldü:');
        _log('   👉 Eski: $originalUrl');
        _log('   👉 Yeni: $converted');
        return converted;
      }

      _log('ℹ️ [AFFILIATE-TEST] Bu mağaza için aktif affiliate adaptörü yok: $originalUrl');
      return originalUrl;
    } catch (e) {
      _log('⚠️ [AFFILIATE-TEST] Link dönüştürme hatası: $e');
      return originalUrl;
    }
  }

  /// Kısa link veya yönlendirmeli linkleri (paylaskazan, hb.biz, ty.gl vb.) asıl ürün sayfasına çözüp
  /// ardından mağaza adaptörü üzerinden admin affiliate linkine dönüştürür.
  static Future<String> resolveAndConvertToAffiliate(String originalUrl) async {
    if (originalUrl.trim().isEmpty) return originalUrl;

    String targetUrl = originalUrl.trim();
    try {
      final lower = targetUrl.toLowerCase();
      final isShortOrRedirect = lower.contains('paylaskazan.teknosa.com') ||
          lower.contains('hb.biz') ||
          lower.contains('app.hb.biz') ||
          lower.contains('ty.gl') ||
          lower.contains('sl.n11.com') ||
          lower.contains('amzn.to') ||
          lower.contains('amzn.eu') ||
          lower.contains('link.amazon') ||
          lower.contains('bit.ly') ||
          lower.contains('tinyurl.com');

      if (isShortOrRedirect) {
        _log('🔍 [AFFILIATE-TEST] Kısa / yönlendirmeli link tespit edildi: $targetUrl');
        _log('⏳ [AFFILIATE-TEST] Kanonik ürün linkine çözümleniyor (unshorten)...');
        final linkPreviewService = LinkPreviewService();
        final resolved = await linkPreviewService.resolveUrlRedirects(targetUrl);
        if (resolved.isNotEmpty && resolved.startsWith('http')) {
          _log('✅ [AFFILIATE-TEST] Kısa link başarıyla kanonik ürün linkine çözüldü:');
          _log('   👉 Çözülen: $resolved');
          targetUrl = resolved;
        }
      } else if (lower.contains('incehesap.com/u/')) {
        // İncehesap /u/ kısa linki için: Eğer bu link zaten geçerli bir /u/ linki ise ve aktifse doğrudan dönüştür/koru
        final adapter = getAdapter(targetUrl);
        if (adapter is IncehesapAffiliateAdapter && adapter.isEnabled) {
          _log('✨ [AFFILIATE-TEST] İncehesap Paylaştıkça Kazan linki korundu: $targetUrl');
          return convertToAffiliateLink(targetUrl);
        }
      }
    } catch (e) {
      _log('⚠️ [AFFILIATE-TEST] Kısa link çözme hatası ($e), mevcut URL ile devam ediliyor: $targetUrl');
    }

    // İncehesap kanonik ürün linki için dinamik canlı AJAX üretimi
    final adapter = getAdapter(targetUrl);
    if (adapter is IncehesapAffiliateAdapter && adapter.isEnabled) {
      final uri = Uri.tryParse(targetUrl);
      if (uri != null) {
        final productId = adapter.extractProductId(uri);
        if (productId != null) {
          final dynamicLink = await adapter.generateAffiliateLink(productId);
          if (dynamicLink != null && dynamicLink.isNotEmpty) {
            return dynamicLink;
          }
        }
      }
    }

    return convertToAffiliateLink(targetUrl);
  }

  /// URL'den mağaza adını tespit eder (Adaptörlerden ve fallback listesinden)
  static String detectStore(String url) {
    if (url.trim().isEmpty) return 'Bilinmeyen';

    try {
      final cleanUrl = url.trim();
      final adapter = getAdapter(cleanUrl);
      if (adapter != null) {
        return adapter.storeName;
      }

      final uri = Uri.parse(cleanUrl);
      final hostname = uri.host.toLowerCase();
      if (hostname.contains('havitstore.com.tr')) return 'Havit';
      if (hostname.contains('migros.com.tr')) return 'Migros';
      if (hostname.contains('getir.com')) return 'Getir';
      if (hostname.contains('boyner.com.tr')) return 'Boyner';
      if (hostname.contains('vatanbilgisayar.com')) return 'Vatan Bilgisayar';
      if (hostname.contains('mediamarkt.com.tr')) return 'MediaMarkt';
      if (hostname.contains('itopya.com')) return 'İtopya';
      if (hostname.contains('incehesap.com')) return 'İncehesap';
      if (hostname.contains('pazarama.com')) return 'Pazarama';
      if (hostname.contains('idefix.com')) return 'İdefix';
      if (hostname.contains('pttavm.com')) return 'PttAVM';
      if (hostname.contains('mavi.com')) return 'Mavi';
      if (hostname.contains('defacto.com.tr')) return 'DeFacto';
      if (hostname.contains('zara.com')) return 'Zara';
      if (hostname.contains('mango.com')) return 'Mango';
      if (hostname.contains('beymen.com')) return 'Beymen';

      return 'Bilinmeyen';
    } catch (_) {
      return 'Bilinmeyen';
    }
  }
}
