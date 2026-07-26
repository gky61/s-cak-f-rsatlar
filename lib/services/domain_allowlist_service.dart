import 'dart:async';
import 'link_preview_service.dart';

class DomainAllowlistService {
  static const Map<String, List<String>> stores = {
    "trendyol": ["trendyol.com"],
    "hepsiburada": ["hepsiburada.com"],
    "amazon_tr": ["amazon.com.tr"],
    "n11": ["n11.com"],
    "pazarama": ["pazarama.com"],
    "idefix": ["idefix.com"],
    "pttavm": ["pttavm.com"],
    "teknosa": ["teknosa.com"],
    "mediamarkt_tr": ["mediamarkt.com.tr"],
    "vatan_bilgisayar": ["vatanbilgisayar.com"],
    "itopya": ["itopya.com"],
    "incehesap": ["incehesap.com"],
    "mavi": ["mavi.com"],
    "defacto_tr": ["defacto.com.tr"],
    "zara_tr": ["zara.com"],
    "mango_tr": ["mango.com"],
    "beymen": ["beymen.com"],
    "migros": ["migros.com.tr"],
    "getir": ["getir.com"],
    "havit_turkiye": ["havitstore.com.tr"]
  };

  static final Set<String> _allowedDomains = stores.values
      .expand((domains) => domains)
      .map((d) => d.toLowerCase())
      .toSet();

  /// Bilinen kısa link veya yönlendirme domainleri listesi
  static const List<String> _shortLinkDomains = [
    'ty.gl',
    'hb.biz',
    'amzn.eu',
    'amzn.to',
    'link.amazon',
    'amzlinks.in',
    'sl.n11.com',
    'n11.com/n/',
    'publicis.link',
    'bit.ly',
    'tinyurl.com',
    't.co',
    'rebrand.ly',
    'rdrtr.com',
    'onelink.me'
  ];

  /// Verilen URL'nin domain'inin (hostname) allowlist'te olup olmadığını kontrol eder.
  /// Hostname exact match ("trendyol.com") veya subdomain match (".trendyol.com") olmalıdır.
  static bool isDomainAllowed(String urlStr) {
    if (urlStr.trim().isEmpty) return false;
    try {
      final trimmed = urlStr.trim();
      Uri uri = Uri.parse(trimmed);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$trimmed');
      }
      final host = uri.host.toLowerCase();
      if (host.isEmpty) return false;

      for (final allowed in _allowedDomains) {
        if (host == allowed || host.endsWith('.$allowed')) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// URL bir kısa link ise yönlendirmeyi çözer ve nihai URL'yi allowlist ile kontrol eder.
  static Future<bool> isResolvedUrlAllowed(String urlStr) async {
    if (urlStr.trim().isEmpty) return false;
    
    // Doğrudan eşleşiyorsa çözmeye gerek kalmadan onay ver
    if (isDomainAllowed(urlStr)) return true;

    // Kısa link yönlendirmesini çöz ve tekrar kontrol et
    try {
      final linkPreviewService = LinkPreviewService();
      String resolved = await linkPreviewService.extractAdjustFallback(urlStr);
      if (resolved.toLowerCase().contains('sl.n11.com/n/') || resolved.toLowerCase().contains('n11.com/n/')) {
        resolved = await linkPreviewService.resolveN11ShortLink(resolved);
      }
      
      final lowerResolved = resolved.toLowerCase();
      final isShort = _shortLinkDomains.any((domain) => lowerResolved.contains(domain));
      if (isShort) {
        resolved = await linkPreviewService.resolveUrlRedirects(resolved);
      }
      
      return isDomainAllowed(resolved);
    } catch (_) {
      return false;
    }
  }

  /// URL'ye karşılık gelen mağaza adını verir
  static String? getStoreNameForUrl(String urlStr) {
    if (urlStr.trim().isEmpty) return null;
    try {
      final trimmed = urlStr.trim();
      Uri uri = Uri.parse(trimmed);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$trimmed');
      }
      final host = uri.host.toLowerCase();
      if (host.isEmpty) return null;

      for (final entry in stores.entries) {
        for (final allowed in entry.value) {
          if (host == allowed || host.endsWith('.$allowed')) {
            return entry.key;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
