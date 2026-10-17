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
  // Budanacak / kesilecek bariz rakip kanal ve CTA tetikleyicileri
  // (NOT: Cümleleri bölecek veya ürün özelliklerinde geçebilecek kelimeler (kanal, yazar, al, katıl, takip)
  // tek başına ASLA aranmaz! Yalnızca bariz yönlendirme butonları, telegram linkleri ve topluluk davetleri budanır.)
  static final RegExp _truncationTriggerRegex = RegExp(
    r'(?:👉|🔗|👇|➡️|🛒)\s*(?:fırsata\s*git|ürüne\s*git|linke\s*git|satın\s*al|tıkla)|'
    r'\b(?:fırsata|firsata|ürüne|urune|linke)\s*(?:git|gidin)\b|'
    r'\b(?:satın|satin)\s*almak\s*için\s*(?:tıkla|tikla|[:\-])|'
    r'^\s*(?:👉|🔗|👇|➡️|🛒)?\s*(?:satın|satin)\s*al(?:mak\s*için)?\s*[:\-]?\s*$|'
    r'\b(?:fırsat|firsat|ürün|urun)\s*linki\s*:|'
    r'\blink\s*(?:aşağıda|asagida|profilde|biyografide)\b|'
    r'\bdiğer\s+kanallar(?:ımız|imiz)?\b|'
    r'\bdiğer\s+kanal(?:ımız|imiz)?\b|'
    r'\b(?:kanalımıza|kanalimiza)\s+(?:katılın|katilin|katıl|katil|abone)\b|'
    r'\b(?:kanala)\s+(?:katılın|katilin|katıl|katil|abone)\b|'
    r'\b(?:telegram|whatsapp)\s+kanal(?:ımız|imiz|ı|i)?\b|'
    r'\b(?:telegram|whatsapp)\s+grub(?:umuz|u)?\b|'
    r'\b(?:t\.me\/|telegram\.me\/|wa\.me\/)\b|'
    r'^\s*(?:editör|editor|paylaşan|paylasan|moderatör|moderator|admin)\s*[:\-]|'
    r'\b(?:tazefırsat|tazefirsat|fırsatkaplanı|firsatkaplani|indirimkaplanı|indirimkaplani|fırsatavcısı|firsatavcisi|sıcakfırsat|sicakfirsat|donanımhaber|donanimhaber)\b|'
    r'^\s*(?:👉|🔗|👇|➡️|🛒)?\s*@([a-zA-Z0-9_]{3,})\b',
    caseSensitive: false,
    multiLine: true,
  );

  /// Açıklama metninden rakip kanal isimlerini, CTA yönlendirme butonlarını (Fırsata Git vb.)
  /// ve editör footer satırlarını keser.
  static String cleanCompetitorAndCtaFooters(String? text) {
    if (text == null || text.trim().isEmpty) return '';

    // ⚡ Yüksek Performans Kalkanı: Zaten FırsatKolik imzası taşıyan temiz yeni fırsatlarda
    // O(1) anında geri dönerek 120 FPS mobil kaydırma hızını korur.
    final trimmedText = text.trim();
    if (trimmedText.startsWith('✨ FırsatKolik') ||
        trimmedText.startsWith('🎯 FırsatKolik') ||
        trimmedText.startsWith('💡 FırsatKolik') ||
        trimmedText.startsWith('🔥 FırsatKolik') ||
        trimmedText.startsWith('⚡ FırsatKolik')) {
      return text;
    }

    final lines = text.split(RegExp(r'\r?\n'));
    final cleanLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        cleanLines.add(line);
        continue;
      }
      if (_truncationTriggerRegex.hasMatch(trimmed)) {
        break;
      }
      cleanLines.add(line);
    }

    var result = cleanLines.join('\n').trim();
    // Eğer orijinal metinde #tanıtım vardıysa ve kesme sonucu silindiyse sonuna ekle
    if (text.toLowerCase().contains('#tanıtım') && !result.toLowerCase().contains('#tanıtım')) {
      result = '$result\n\n#tanıtım';
    }
    return result;
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
