/// FırsatKolik - Ticari Reklam Yönetmeliği Uyum Servisi
/// 
/// 1 Ağustos Ticari Reklam Yönetmeliği gereğince, indirim/fırsat platformlarında
/// paylaşılan affiliate ve bilgilendirme içeriklerinin #tanıtım etiketi ile
/// etiketlenmesini sağlar. Varsa eski #reklam/#işbirliği etiketlerini #tanıtım'a çevirir.
class AdvertisingComplianceService {
  // Temizlenecek eski reklam/tanıtım/işbirliği kalıpları
  static final RegExp _adCleanupRegex = RegExp(
    r'(?:#|\[|\()(?:reklam|reklamdır|reklamdir|tanıtım|tanitim|işbirliği|isbirligi|sponsorlu|ortaklık|ortaklik|affiliate)(?:\]|\))?',
    caseSensitive: false,
  );

  static final RegExp _adRegex = RegExp(
    r'(?:#|\b)(?:reklam|reklamdır|reklamdir|tanıtım|tanitim|işbirliği|isbirligi|sponsorlu|ortaklık|ortaklik|affiliate)\b',
    caseSensitive: false,
  );

  /// Verilen metinde reklam/tanıtım/işbirliği etiketinin olup olmadığını kontrol eder.
  static bool hasDisclosure(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    return _adRegex.hasMatch(trimmed.toLowerCase()) || _adRegex.hasMatch(trimmed);
  }

  /// Açıklama metnini normalize eder:
  /// - Varsa eski #reklam, #işbirliği, [REKLAM] vb. etiketleri temizler.
  /// - Metnin sonuna standart tek bir '#tanıtım' etiketi ekler.
  static String ensureDisclosure(String? text, {String defaultTag = '#tanıtım'}) {
    if (text == null) return defaultTag;
    var safeText = text.trim();

    if (safeText.isEmpty) {
      return defaultTag;
    }

    // Var olan eski etiketleri temizle
    safeText = safeText.replaceAll(_adCleanupRegex, '').trim();
    safeText = safeText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    if (safeText.isEmpty) {
      return defaultTag;
    }

    // Standart #tanıtım etiketini ekle
    return '$safeText\n\n$defaultTag';
  }
}
