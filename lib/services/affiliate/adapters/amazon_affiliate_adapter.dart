import 'package:flutter/foundation.dart' show kDebugMode;
import '../base_affiliate_adapter.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Amazon Gelir Ortaklığı (Associates TR / amazon.com.tr) adaptörü.
class AmazonAffiliateAdapter extends BaseAffiliateAdapter {
  /// Amazon Associates Takip Kimliği (Store / Tracking ID)
  final String tag;

  AmazonAffiliateAdapter({
    this.tag = 'firsatkolik-21',
    bool enabled = true,
  }) {
    isEnabled = enabled;
  }

  @override
  bool get isEnabled => super.isEnabled && tag.trim().isNotEmpty;

  @override
  String get storeName => 'Amazon';

  @override
  String get storeKey => 'amazon';

  @override
  bool get isAffiliateReady => true;

  @override
  bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('amazon.') ||
        host.contains('amzn.') ||
        host.contains('link.amazon');
  }

  @override
  bool isAlreadyAffiliate(Uri uri) {
    final host = uri.host.toLowerCase();

    // 1. Kısa linkler (amzn.to / amzn.eu / link.amazon) çözülmeden bizim linkimiz sayılamaz
    if (host.contains('amzn.') || host.contains('link.amazon')) {
      return false;
    }

    if (tag.trim().isEmpty) return false;

    // 2. tag parametresi bizim takip kimliğimizle eşleşiyor mu?
    final currentTag = uri.queryParameters['tag'];
    if (currentTag != null && currentTag.trim().toLowerCase() == tag.trim().toLowerCase()) {
      return true;
    }

    return false;
  }

  @override
  String convert(Uri uri) {
    try {
      final host = uri.host.toLowerCase();

      // 1. Fallback / Emniyet: Eğer adaptör kapalıysa (enabled=false) veya tag boşsa,
      //    temiz kanonik ürün linkini döndür (başkasına ait tag ve takip çöplerinden arındırılmış).
      if (!isEnabled) {
        _log('⚠️ [AFFILIATE-TEST] Amazon Affiliate Şalteri KAPALI (enabled=false). Fallback Modu: Temiz ürün linki döndürülüyor: $uri');
        return _buildCleanProductUrl(uri);
      }

      // 2. Eğer link henüz amzn.eu / amzn.to gibi bir kısa link ise unshorten edilmeden dönüştürülemez
      if (host.contains('amzn.') || host.contains('link.amazon')) {
        _log('ℹ️ [AFFILIATE-TEST] Amazon linki henüz kısa link durumunda (unshorten bekleniyor): $uri');
        return uri.toString();
      }

      // 3. ASIN (Amazon Standard Identification Number) Ayıklama
      final asin = extractAsin(uri.toString());

      // 4. Hedef Host ve Protokol Tespiti
      final effectiveHost = uri.host.isNotEmpty ? uri.host : 'www.amazon.com.tr';
      final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'https';

      // 5. Parametre Temizleme ve Anti-Hijack:
      // Yabancı tag, ref, linkCode, ascsubtag ve sosyal paylaşım çöplerini temizle
      final cleanParams = <String, String>{};
      uri.queryParameters.forEach((key, value) {
        final lowerKey = key.toLowerCase();
        // Takip ve kampanya parametrelerini ayıkla
        if (lowerKey == 'tag' ||
            lowerKey == 'ref' ||
            lowerKey.startsWith('ref_') ||
            lowerKey == 'linkcode' ||
            lowerKey == 'ascsubtag' ||
            lowerKey == 'social_share' ||
            lowerKey == 'creative' ||
            lowerKey == 'camp' ||
            lowerKey == 'creativeasin') {
          return;
        }
        // İlgili varyant / satıcı parametreleri varsa koru (th, psc vb.)
        cleanParams[key] = value;
      });

      // Kendi resmi tag'imizi ekle
      cleanParams['tag'] = tag.trim();

      String finalAffiliateUrl;
      if (asin != null && asin.isNotEmpty) {
        // En temiz ve kanonik Amazon URL formatı: /dp/{ASIN}?tag={tag}
        final finalUri = Uri(
          scheme: scheme,
          host: effectiveHost,
          path: '/dp/$asin',
          queryParameters: cleanParams,
        );
        finalAffiliateUrl = finalUri.toString();
      } else {
        // ASIN doğrudan bulunamazsa mevcut path üzerinden temiz parametrelerle inşa et
        final finalUri = uri.replace(queryParameters: cleanParams);
        finalAffiliateUrl = finalUri.toString();
      }

      _log('🚀 [AFFILIATE-TEST] Amazon Associates affiliate linki başarıyla sentezlendi (0 ms):');
      _log('   👉 Girdi: $uri');
      _log('   👉 Çıktı: $finalAffiliateUrl');

      return finalAffiliateUrl;
    } catch (e) {
      _log('⚠️ [AFFILIATE-TEST] Amazon affiliate dönüştürme hatası: $e, orijinal link korunuyor: $uri');
      return uri.toString();
    }
  }

  /// URL'deki tüm takip kodlarını (tag, ref, linkCode vb.) temizleyerek saf kanonik Amazon linki üretir
  String _buildCleanProductUrl(Uri uri) {
    try {
      final asin = extractAsin(uri.toString());
      final host = uri.host.isNotEmpty ? uri.host : 'www.amazon.com.tr';
      final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'https';

      if (asin != null && asin.isNotEmpty) {
        return '$scheme://$host/dp/$asin';
      }

      // ASIN yoksa query parametrelerini tamamen temizle
      return uri.replace(queryParameters: {}).toString().replaceAll(RegExp(r'\?$'), '');
    } catch (_) {
      return uri.toString();
    }
  }

  /// Verilen URL metninden 10 haneli standart Amazon ASIN kodunu ayıklar.
  /// Desteklenen kalıplar:
  /// - /dp/B08N5WRWNW
  /// - /gp/product/B08N5WRWNW
  /// - /gp/aw/d/B08N5WRWNW
  /// - /slug/dp/B08N5WRWNW
  /// - ?asin=B08N5WRWNW
  static String? extractAsin(String url) {
    if (url.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(url.trim());

      // 1. Query parameter kontrolü
      final qAsin = uri.queryParameters['asin'] ?? uri.queryParameters['ASIN'];
      if (qAsin != null && _isValidAsin(qAsin)) {
        return qAsin.toUpperCase();
      }

      // 2. Path regex kontrolü
      final path = uri.path;
      final pathRegex = RegExp(
        r'/(?:dp|gp/product|gp/aw/d|product)/([A-Z0-9]{10})(?:[/?]|$)',
        caseSensitive: false,
      );
      final match = pathRegex.firstMatch(path);
      if (match != null && match.group(1) != null) {
        final asin = match.group(1)!;
        if (_isValidAsin(asin)) {
          return asin.toUpperCase();
        }
      }

      // 3. Genel 10 karakterli ASIN arama (URL içinde /B0... veya /10... formatı)
      final generalRegex = RegExp(r'/([B0-9][A-Z0-9]{9})(?:[/?]|$)', caseSensitive: false);
      final generalMatch = generalRegex.firstMatch(path);
      if (generalMatch != null && generalMatch.group(1) != null) {
        final candidate = generalMatch.group(1)!;
        if (_isValidAsin(candidate)) {
          return candidate.toUpperCase();
        }
      }
    } catch (_) {}
    return null;
  }

  /// ASIN kodunun standart 10 karakterli alfasayısal olduğunu doğrular
  static bool _isValidAsin(String asin) {
    return RegExp(r'^[A-Z0-9]{10}$', caseSensitive: false).hasMatch(asin.trim());
  }
}

