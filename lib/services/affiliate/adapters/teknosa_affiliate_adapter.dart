import 'package:flutter/foundation.dart' show kDebugMode;
import '../base_affiliate_adapter.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Teknosa Paylaş Kazan (Winfluenced / TUNE HasOffers) gelir ortaklığı adaptörü.
class TeknosaAffiliateAdapter extends BaseAffiliateAdapter {
  /// Varsayılan Winfluenced / Teknosa Paylaş Kazan Kullanıcı GUID'i
  final String userId;

  /// TUNE Kampanya (Offer) ID'si (Teknosa Paylaş Kazan için 5)
  final String offerId;

  /// TUNE Affiliate Network ID'si (Winfluenced için 1016)
  final String affId;

  TeknosaAffiliateAdapter({
    this.userId = '906bd201-92dc-4898-914a-10309b2cd576',
    this.offerId = '5',
    this.affId = '1016',
    bool enabled = true,
  }) {
    isEnabled = enabled;
  }

  @override
  bool get isEnabled => super.isEnabled && userId.trim().isNotEmpty;

  @override
  String get storeName => 'Teknosa';

  @override
  String get storeKey => 'teknosa';

  @override
  bool get isAffiliateReady => true;

  @override
  bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('teknosa.com') ||
        host.contains('paylaskazan.teknosa.com') ||
        host.contains('btrck.com');
  }

  @override
  bool isAlreadyAffiliate(Uri uri) {
    final host = uri.host.toLowerCase();
    // Yalnızca ve yalnızca host btrck.com ise VE source/aff_sub adminin kendi userId'si ise true'dur.
    if (host.contains('btrck.com')) {
      final source = uri.queryParameters['source'] ?? uri.queryParameters['aff_sub'];
      final isOwner = source != null && source.trim().toLowerCase() == userId.trim().toLowerCase();
      if (!isOwner) return false;

      // Normalizasyon: Eğer link eski %2F formatında ise (aff_sub3=teknosa.com%2F...),
      // henüz normalize edilmemiş kabul et ki convert() onu Teknosa'nın yerel düz slash standardına yükseltsin.
      final rawQuery = uri.query;
      if (rawQuery.contains('aff_sub3=teknosa.com%2F') || rawQuery.contains('aff_sub3=teknosa.com%2f')) {
        return false;
      }

      return true;
    }
    // paylaskazan.teknosa.com veya başkasına ait btrck linki ASLA bizim linkimiz değildir.
    return false;
  }

  @override
  String convert(Uri uri) {
    Uri targetProductUri = uri;

    // 1. Eğer link bir btrck.com linki ise (eski %2F'li link veya yabancı affiliate), içindeki gerçek ürün linkini çıkar
    if (uri.host.toLowerCase().contains('btrck.com')) {
      final embeddedUrl = uri.queryParameters['url'];
      if (embeddedUrl != null && embeddedUrl.isNotEmpty) {
        final parsed = Uri.tryParse(embeddedUrl);
        if (parsed != null && parsed.host.toLowerCase().contains('teknosa.com') && !parsed.host.toLowerCase().contains('paylaskazan.')) {
          targetProductUri = parsed;
          _log('🔄 [AFFILIATE-TEST] btrck linkinden asıl ürün URL\'i ayıklandı (0 ms unwrap): $targetProductUri');
        }
      } else {
        // url parametresi yoksa aff_sub3 parametresinden ürünü kurtar
        final affSub3Param = uri.queryParameters['aff_sub3'];
        if (affSub3Param != null && affSub3Param.contains('teknosa.com')) {
          final decoded = Uri.decodeComponent(affSub3Param);
          final parsed = Uri.tryParse('https://www.$decoded');
          if (parsed != null) {
            targetProductUri = parsed;
            _log('🔄 [AFFILIATE-TEST] aff_sub3 parametresinden asıl ürün URL\'i kurtarıldı: $targetProductUri');
          }
        }
      }
    }

    // 2. Fallback / Emniyet: Eğer adaptör kapalıysa (enabled=false) veya userId boşsa,
    //    temiz ürün linkini (başkasına ait btrck'den arındırılmış) döndür.
    if (!isEnabled) {
      _log('⚠️ [AFFILIATE-TEST] Teknosa Affiliate Şalteri KAPALI (enabled=false). Fallback Modu: Temiz ürün linki döndürülüyor: $targetProductUri');
      return targetProductUri.toString();
    }

    try {
      // Eğer hala paylaskazan.teknosa.com gibi bir kısa link ise unshorten edilmeden dönüştürülemez
      if (targetProductUri.host.toLowerCase().contains('paylaskazan.teknosa.com')) {
        _log('ℹ️ [AFFILIATE-TEST] Link henüz kısa link durumunda (unshorten bekleniyor): $uri');
        return uri.toString();
      }

      String productPath = targetProductUri.path;
      if (productPath.startsWith('/')) {
        productPath = productPath.substring(1);
      }
      // %2F veya encode edilmiş slash karakterlerini decode ederek saf ürün yoluna ulaş
      productPath = Uri.decodeComponent(productPath).replaceAll(RegExp(r'^/+'), '');
      
      // Fallback: Geçersiz veya boş ürün yolu varsa dönüştürme, orijinal ürün linkini koru
      if (productPath.isEmpty) {
        return targetProductUri.toString();
      }

      // Teknosa yerel Paylaş Kazan yönlendirmesiyle birebir aynı formatta (düz slash): teknosa.com/product-slug-p-id
      final affSub3 = 'teknosa.com/$productPath';

      // Hedef linke Teknosa analitik/kampanya parametrelerini enjekte et
      final queryParams = Map<String, String>.from(targetProductUri.queryParameters);
      queryParams['utm_source'] = 'social_affiliate';
      queryParams['utm_medium'] = 'paylaskazan';
      queryParams['utm_campaign'] = userId;
      final targetUrlWithUtm = targetProductUri.replace(queryParameters: queryParams).toString();

      // TUNE (HasOffers) doğrudan yönlendirme URL'si oluştur
      // ÖNEMLİ: aff_sub3 parametresindeki slash '/' işaretleri encode edilmez (teknosa.com/product-slug-p-id).
      // Böylece Teknosa'nın kendi Paylaş Kazan 302 yönlendirmesiyle %100 birebir aynı anahtar oluşur ve
      // Teknosa raporlama panelinde (%2F vs /) şeklinde iki ayrı ürün/satır oluşması tamamen engellenir.
      final encodedTargetUrl = Uri.encodeComponent(targetUrlWithUtm);
      final finalAffiliateUrl = 'https://rdr.btrck.com/aff_c'
          '?offer_id=$offerId'
          '&aff_id=$affId'
          '&source=$userId'
          '&aff_sub=$userId'
          '&aff_sub3=$affSub3'
          '&url=$encodedTargetUrl';

      _log('🎯 [AFFILIATE-TEST] Teknosa TUNE Deep-Link Sentezlendi (Normalleştirilmiş Slash): $finalAffiliateUrl');
      return finalAffiliateUrl;
    } catch (e) {
      _log('⚠️ [AFFILIATE-TEST] Sentezleme hatası ($e), güvenli fallback: $targetProductUri');
      // Hata durumunda güvenli fallback: Temiz ürün linkini döndür, asla sistemi kırma
      return targetProductUri.toString();
    }
  }

  /// Teknosa mobil uygulamasını doğrudan (0 ms App Link) açan hedef URL'yi döner.
  /// Teknosa'nın kendi Paylaş Kazan analitik parametrelerini (`utm_campaign=userId`) içerir.
  String buildNativeAppUrl(Uri uri) {
    Uri targetProductUri = uri;
    if (uri.host.toLowerCase().contains('btrck.com')) {
      final embeddedUrl = uri.queryParameters['url'];
      if (embeddedUrl != null && embeddedUrl.isNotEmpty) {
        final parsed = Uri.tryParse(embeddedUrl);
        if (parsed != null && parsed.host.toLowerCase().contains('teknosa.com')) {
          targetProductUri = parsed;
        }
      }
    }
    final queryParams = Map<String, String>.from(targetProductUri.queryParameters);
    queryParams['utm_source'] = 'social_affiliate';
    queryParams['utm_medium'] = 'paylaskazan';
    queryParams['utm_campaign'] = userId;
    return targetProductUri.replace(queryParameters: queryParams).toString();
  }
}

