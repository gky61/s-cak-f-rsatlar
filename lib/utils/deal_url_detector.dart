class DealUrlDetector {
  DealUrlDetector._();

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  /// Bilinen e-ticaret mağaza alan adları (şemasız veya www ile başlayan paylaşımlar için)
  static final RegExp _bareDomainRegex = RegExp(
    r'(?:^|[\s(])((?:www\.)?(?:mavi\.com|boyner\.com\.tr|trendyol\.com|ty\.gl|hepsiburada\.com|(?:app\.)?hb\.biz|amazon\.com\.tr|amazon\.com|amzn\.eu|amzn\.to|link\.amazon|amzlinks\.in|teknosa\.com|(?:sl\.)?n11\.com|pazarama\.com|pzrm\.me|vatanbilgisayar\.com|mediamarkt\.com\.tr|idefix\.com|itopya\.com|incehesap\.com|migros\.com\.tr|getir\.com|beymen\.com|zara\.com|mango\.com|defacto\.com\.tr|pttavm\.com|havitstore\.com\.tr|gamer\.gen\.tr|gaming\.gen\.tr|fenom\.io)\/[^\s)]*)',
    caseSensitive: false,
  );

  static String _cleanTrailingPunctuation(String url) {
    var clean = url.trim();
    while (clean.endsWith('.') ||
        clean.endsWith(',') ||
        clean.endsWith(';') ||
        clean.endsWith(')') ||
        clean.endsWith('!') ||
        clean.endsWith('?') ||
        clean.endsWith('"') ||
        clean.endsWith('\'') ||
        clean.endsWith('>') ||
        clean.endsWith(']')) {
      clean = clean.substring(0, clean.length - 1);
    }
    while (clean.startsWith('"') ||
        clean.startsWith('\'') ||
        clean.startsWith('<') ||
        clean.startsWith('[')) {
      clean = clean.substring(1);
    }
    return clean;
  }

  /// Metin içerisinden ilk geçerli e-ticaret URL'sini ayıklar ve kanonikleştirir (normalize eder).
  ///
  /// Desteklenen Giriş Türleri:
  /// 1. Standart HTTP/HTTPS URL'leri (Örn: https://www.mavi.com/... veya https://ty.gl/...)
  /// 2. Şemasız Mağaza Alan Adları (Örn: www.boyner.com.tr/... -> https://www.boyner.com.tr/...)
  static String? extractUrl(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return null;

    // 1. Standart HTTP/HTTPS URL
    final httpMatch = _urlRegex.firstMatch(trimmedText);
    if (httpMatch != null) {
      final raw = httpMatch.group(0) ?? '';
      final clean = _cleanTrailingPunctuation(raw);
      if (clean.isNotEmpty) return clean;
    }

    // 2. Şemasız mağaza alan adı (Örn: www.mavi.com/... veya boyner.com.tr/...)
    final bareMatch = _bareDomainRegex.firstMatch(trimmedText);
    if (bareMatch != null) {
      final raw = bareMatch.group(1) ?? '';
      final clean = _cleanTrailingPunctuation(raw);
      if (clean.isNotEmpty) {
        return 'https://$clean';
      }
    }

    return null;
  }

  /// Verilen URL'nin desteklenen bir e-ticaret mağazasına ait olup olmadığını tespit eder
  /// ve mağazanın kullanıcı dostu adını döndürür.
  static String? detectStoreName(String url) {
    final normalized = extractUrl(url) ?? url;
    final lower = normalized.toLowerCase();

    if (lower.contains('trendyol.com') || lower.contains('ty.gl')) {
      return 'Trendyol';
    }
    if (lower.contains('hepsiburada.com') || lower.contains('hb.biz') || lower.contains('hepsiburada.net')) {
      return 'Hepsiburada';
    }
    if (lower.contains('amazon.com.tr') || lower.contains('amazon.com') || lower.contains('amzn.to') || lower.contains('amzn.eu') || lower.contains('link.amazon') || lower.contains('amzlinks.') || lower.contains('fenom.io')) {
      return 'Amazon';
    }
    if (lower.contains('teknosa.com')) {
      return 'Teknosa';
    }
    if (lower.contains('n11.com')) {
      return 'N11';
    }
    if (lower.contains('pazarama.com') || lower.contains('pzrm.me')) {
      return 'Pazarama';
    }
    if (lower.contains('vatanbilgisayar.com')) {
      return 'Vatan Bilgisayar';
    }
    if (lower.contains('mediamarkt.com.tr')) {
      return 'MediaMarkt';
    }
    if (lower.contains('idefix.com')) {
      return 'İdefix';
    }
    if (lower.contains('itopya.com')) {
      return 'İtopya';
    }
    if (lower.contains('incehesap.com')) {
      return 'İncehesap';
    }
    if (lower.contains('migros.com.tr')) {
      return 'Migros';
    }
    if (lower.contains('carrefoursa.com')) {
      return 'CarrefourSA';
    }
    if (lower.contains('getir.com')) {
      return 'Getir';
    }
    if (lower.contains('boyner.com.tr')) {
      return 'Boyner';
    }
    if (lower.contains('gamer.gen.tr')) {
      return 'Gamer Gen';
    }
    if (lower.contains('gaming.gen.tr')) {
      return 'Gaming Gen';
    }
    if (lower.contains('beymen.com')) {
      return 'Beymen';
    }
    if (lower.contains('zara.com')) {
      return 'Zara';
    }
    if (lower.contains('mango.com')) {
      return 'Mango';
    }
    if (lower.contains('mavi.com')) {
      return 'Mavi';
    }
    if (lower.contains('defacto.com.tr')) {
      return 'DeFacto';
    }
    if (lower.contains('pttavm.com')) {
      return 'PttAVM';
    }
    if (lower.contains('havitstore.com.tr') || lower.contains('havit.com.tr')) {
      return 'Havit';
    }
    if (lower.contains('watsons.com.tr')) {
      return 'Watsons';
    }
    if (lower.contains('gratis.com')) {
      return 'Gratis';
    }
    if (lower.contains('dr.com.tr')) {
      return 'D&R';
    }

    return null;
  }

  /// URL'nin desteklenen popüler bir e-ticaret platformu olup olmadığını denetler
  static bool isSupportedEcommerceUrl(String url) {
    return detectStoreName(url) != null;
  }
}
