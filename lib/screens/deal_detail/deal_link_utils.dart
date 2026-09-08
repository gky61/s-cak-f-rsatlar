import '../../services/affiliate/affiliate_service.dart';

/// Affiliate link dönüştürme ve mağaza tespiti yardımcıları (AffiliateService cephesi).
class DealLinkUtils {
  DealLinkUtils._();

  /// URL'den mağaza ismini tespit eder (Modüler AffiliateService üzerinden).
  static String detectStoreFromUrl(String url) => AffiliateService.detectStore(url);

  /// Orijinal URL'yi mağaza özelindeki adaptör üzerinden affiliate linkine dönüştürür.
  static String convertToAffiliateLink(String originalUrl) => AffiliateService.convertToAffiliateLink(originalUrl);

  /// Kısa linkleri çözüp mağaza özelindeki adaptör üzerinden affiliate linkine dönüştürür.
  static Future<String> resolveAndConvertToAffiliate(String originalUrl) => AffiliateService.resolveAndConvertToAffiliate(originalUrl);

  /// Verilen mağaza ismi veya URL için affiliate desteğinin aktif/üretim hazır olup olmadığını döner.
  static bool isStoreSupported(String? storeNameOrUrl) => AffiliateService.isStoreSupported(storeNameOrUrl);
}

