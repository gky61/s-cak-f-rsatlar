class DealUrlDetector {
  DealUrlDetector._();

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  /// Metin içerisinden ilk geçerli HTTP/HTTPS URL'sini ayıklar
  static String? extractUrl(String text) {
    final match = _urlRegex.firstMatch(text.trim());
    if (match == null) return null;
    var url = match.group(0) ?? '';
    // Sondaki noktalama işaretlerini temizle
    while (url.endsWith('.') || url.endsWith(',') || url.endsWith(';') || url.endsWith(')')) {
      url = url.substring(0, url.length - 1);
    }
    return url.isNotEmpty ? url : null;
  }

  /// Verilen URL'nin desteklenen bir e-ticaret mağazasına ait olup olmadığını tespit eder
  /// ve mağazanın kullanıcı dostu adını döndürür.
  static String? detectStoreName(String url) {
    final lower = url.toLowerCase();

    if (lower.contains('trendyol.com') || lower.contains('ty.gl')) {
      return 'Trendyol';
    }
    if (lower.contains('hepsiburada.com') || lower.contains('hb.biz') || lower.contains('hepsiburada.net')) {
      return 'Hepsiburada';
    }
    if (lower.contains('amazon.com.tr') || lower.contains('amazon.com') || lower.contains('amzn.to') || lower.contains('amzn.eu')) {
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
    if (lower.contains('getir.com')) {
      return 'Getir';
    }
    if (lower.contains('boyner.com.tr')) {
      return 'Boyner';
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
