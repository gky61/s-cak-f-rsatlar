import 'package:flutter/foundation.dart' show kDebugMode;
import '../base_affiliate_adapter.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Hepsiburada LinkGelir (Adjust Universal Deep-Link / 7t4g.adj.st) gelir ortaklığı adaptörü.
class HepsiburadaAffiliateAdapter extends BaseAffiliateAdapter {
  /// LinkGelir Hesap / Influencer Adı (Adjust adj_adgroup parametresi)
  final String accountName;

  /// Hepsiburada LinkGelir Adjust Tracker Belirteci (Varsayılan: 10zuiki3_y4q2fze)
  final String trackerToken;

  /// Adjust Kampanya Adı (Varsayılan: ux_gelistirmeleri)
  final String campaign;

  /// UTM Kaynak Parametresi (Varsayılan: influencer)
  final String utmSource;

  /// UTM Araç Parametresi (Varsayılan: linkgelir)
  final String utmMedium;

  /// UTM Kampanya Parametresi
  final String utmCampaign;

  /// WebTrends Analitik Parametresi (Varsayılan: affiliate)
  final String wtInf;

  HepsiburadaAffiliateAdapter({
    this.accountName = 'muratcan gokyokus',
    this.trackerToken = '10zuiki3_y4q2fze',
    this.campaign = 'ux_gelistirmeleri',
    this.utmSource = 'influencer',
    this.utmMedium = 'linkgelir',
    this.utmCampaign = 'sc:hb-ecom.sr:influencer.md:linkgelir',
    this.wtInf = 'affiliate',
    bool enabled = true,
  }) {
    isEnabled = enabled;
  }

  @override
  bool get isEnabled => super.isEnabled && accountName.trim().isNotEmpty;

  @override
  String get storeName => 'Hepsiburada';

  @override
  String get storeKey => 'hepsiburada';

  @override
  bool get isAffiliateReady => true;

  @override
  bool canHandle(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.contains('hepsiburada.com') ||
        host.contains('hb.biz') ||
        host.contains('app.hb.biz') ||
        host.contains('7t4g.adj.st') ||
        (host.contains('adjust.') && uri.query.contains('sku='));
  }

  @override
  bool isAlreadyAffiliate(Uri uri) {
    final host = uri.host.toLowerCase();

    // 1. Kısa linkler (hb.biz / app.hb.biz) çözülmeden bizim linkimiz sayılamaz
    if (host.contains('hb.biz') || host.contains('app.hb.biz')) {
      return false;
    }

    // 2. Adjust linki (7t4g.adj.st veya adjust.com) ise adj_adgroup sahibini kontrol et
    if (host.contains('7t4g.adj.st') || host.contains('adjust.')) {
      final adgroup = uri.queryParameters['adj_adgroup'];
      if (adgroup != null && adgroup.trim().toLowerCase() == accountName.trim().toLowerCase()) {
        return true;
      }
      return false;
    }

    // 3. Kanonik hepsiburada.com linki üzerinde ftid veya utm_medium=linkgelir varsa ancak Adjust değilse
    // tam Adjust deep-link haline getirilmesi için false dönülür
    return false;
  }

  @override
  String convert(Uri uri) {
    Uri targetProductUri = uri;

    try {
      final host = uri.host.toLowerCase();

      // 1. Eğer gelen link bir Adjust linki ise (7t4g.adj.st veya adjust.com),
      // içindeki adj_fallback parametresinden gerçek ürün sayfasını kurtar (0 ms unwrap)
      if (host.contains('7t4g.adj.st') || host.contains('adjust.')) {
        final fallback = uri.queryParameters['adj_fallback'];
        if (fallback != null && fallback.isNotEmpty) {
          final parsed = Uri.tryParse(fallback);
          if (parsed != null && parsed.host.toLowerCase().contains('hepsiburada.com')) {
            targetProductUri = parsed;
            _log('🔄 [AFFILIATE-TEST] Adjust linkinden asıl Hepsiburada URL\'i ayıklandı (0 ms unwrap): $targetProductUri');
          }
        }
      }

      // 2. Fallback / Emniyet: Eğer adaptör kapalıysa (enabled=false) veya accountName boşsa,
      //    temiz kanonik ürün linkini döndür (başkasına ait Adjust/LinkGelir kodlarından arındırılmış).
      if (!isEnabled) {
        _log('⚠️ [AFFILIATE-TEST] Hepsiburada Affiliate Şalteri KAPALI (enabled=false). Fallback Modu: Temiz ürün linki döndürülüyor: $targetProductUri');
        return _buildCleanProductUrl(targetProductUri);
      }

      // 3. Eğer hala app.hb.biz gibi bir kısa link ise unshorten edilmeden dönüştürülemez
      if (targetProductUri.host.toLowerCase().contains('hb.biz')) {
        _log('ℹ️ [AFFILIATE-TEST] Hepsiburada linki henüz kısa link durumunda (unshorten bekleniyor): $uri');
        return uri.toString();
      }

      // 4. SKU (Ürün Kodu) Ayıklama:
      final sku = extractSku(targetProductUri.toString());

      // Eğer SKU hiçbir şekilde bulunamazsa, organik temiz ürün URL'sini koru
      if (sku == null || sku.isEmpty) {
        _log('⚠️ [AFFILIATE-TEST] Hepsiburada linkinden SKU tespit edilemedi, organik link korunuyor: $targetProductUri');
        return targetProductUri.toString();
      }

      // Satıcı mağaza adı varsa koru (merchantName)
      final merchantName = targetProductUri.queryParameters['magaza'] ?? targetProductUri.queryParameters['merchantName'];

      // 5. Hedef Kanonik Web URL'sini (adj_fallback) ve Analitik Parametrelerini İnşa Et
      final cleanBaseUrl = _buildCleanProductUrl(targetProductUri);
      final fallbackUri = Uri.parse(cleanBaseUrl);
      final fallbackQueryParams = <String, String>{
        if (merchantName != null && merchantName.isNotEmpty) 'magaza': merchantName,
        'url_src': 'and-product-detail',
        'utm_campaign': utmCampaign,
        'utm_medium': utmMedium,
        'utm_source': utmSource,
        'wt_inf': wtInf,
      };
      final finalFallbackUrl = fallbackUri.replace(queryParameters: fallbackQueryParams).toString();

      // 6. Mobil Uygulama Deep-Link Şeması (hbapp://product)
      final hbappParams = <String, String>{
        'sku': sku,
        if (merchantName != null && merchantName.isNotEmpty) 'merchantName': merchantName,
        'url_src': 'and-product-detail',
        'utm_source': utmSource,
        'utm_medium': utmMedium,
        'utm_campaign': utmCampaign,
      };
      final hbappDeepLink = Uri(
        scheme: 'hbapp',
        host: 'product',
        queryParameters: hbappParams,
      ).toString();

      // 7. Nihai Adjust 7t4g.adj.st Universal Deep-Link Sentezleme
      final encodedHbapp = Uri.encodeComponent(hbappDeepLink);
      final encodedFallback = Uri.encodeComponent(finalFallbackUrl);
      final encodedAdgroup = Uri.encodeComponent(accountName.trim());
      final encodedUtmCampaign = Uri.encodeComponent(utmCampaign);

      final finalAffiliateUrl = 'https://7t4g.adj.st/product'
          '?sku=$sku'
          '${merchantName != null && merchantName.isNotEmpty ? '&merchantName=${Uri.encodeComponent(merchantName)}' : ''}'
          '&url_src=and-product-detail'
          '&utm_source=$utmSource'
          '&utm_medium=$utmMedium'
          '&utm_campaign=$encodedUtmCampaign'
          '&adj_t=$trackerToken'
          '&adj_deep_link=$encodedHbapp'
          '&adj_fallback=$encodedFallback'
          '&adj_campaign=$campaign'
          '&adj_adgroup=$encodedAdgroup'
          '&adj_creative=$sku';

      _log('🚀 [AFFILIATE-TEST] Hepsiburada LinkGelir (Adjust) affiliate linki başarıyla sentezlendi (0 ms):');
      _log('   👉 Girdi: $uri');
      _log('   👉 Çıktı: $finalAffiliateUrl');

      return finalAffiliateUrl;
    } catch (e) {
      _log('⚠️ [AFFILIATE-TEST] Hepsiburada affiliate dönüştürme hatası: $e, orijinal link korunuyor: $uri');
      return uri.toString();
    }
  }

  /// URL'deki tüm takip parametrelerini temizleyerek saf hepsiburada.com ürün URL'si üretir
  String _buildCleanProductUrl(Uri uri) {
    return '${uri.scheme}://${uri.host}${uri.path}';
  }

  /// Verilen URL veya URI metninden Hepsiburada SKU kodunu ayıklar (-p-HBCV... veya sku=...)
  static String? extractSku(String url) {
    if (url.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(url.trim());
      String? sku = uri.queryParameters['sku'];
      if (sku != null && sku.isNotEmpty) return sku;

      final path = uri.path;
      final match = RegExp(r'-p[m]?-([a-zA-Z0-9]+)', caseSensitive: false).firstMatch(path);
      if (match != null) {
        return match.group(1);
      }
    } catch (_) {}
    return null;
  }

  /// Hepsiburada mobil uygulamasını doğrudan (tarayıcısız ve popupsız 0 ms) açan `hbapp://` URI'sini üretir.
  /// Adjust takip parametreleri (`adjust_tracker`, `adj_adgroup`, `adj_campaign`) doğrudan query parameter
  /// olarak eklenir; böylece Hepsiburada açıldığında içindeki Adjust SDK bu parametreleri okur ve komisyonu kaydeder.
  String? buildNativeAppUrl(Uri uri) {
    try {
      final sku = extractSku(uri.toString());
      if (sku == null || sku.isEmpty) return null;

      final merchantName = uri.queryParameters['magaza'] ?? uri.queryParameters['merchantName'];

      final hbappParams = <String, String>{
        'sku': sku,
        if (merchantName != null && merchantName.isNotEmpty) 'merchantName': merchantName,
        'url_src': 'and-product-detail',
        'utm_source': utmSource,
        'utm_medium': utmMedium,
        'utm_campaign': utmCampaign,
        'adjust_tracker': trackerToken,
        'adj_t': trackerToken,
        'adj_adgroup': accountName.trim(),
        'adj_campaign': campaign,
      };

      return Uri(
        scheme: 'hbapp',
        host: 'product',
        queryParameters: hbappParams,
      ).toString();
    } catch (_) {
      return null;
    }
  }
}
