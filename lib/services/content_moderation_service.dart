import 'package:flutter/foundation.dart' show kDebugMode;

void _log(String message) {
  if (kDebugMode) print(message);
}

/// İçerik moderasyon servisi - Yalnızca kesin küfür ve ağır hakaret içeren ifadeleri tespit eder.
/// Günlük e-ticaret ve ürün isimlerinin (örn: kaşar, şık, dik, cif, anakart, bomba) yanlışlıkla engellenmesini önler.
class ContentModerationService {
  // Kesin ve net küfür/hakaret kelimeleri listesi (Yanlış pozitif verebilecek genel e-ticaret kelimeleri ayıklanmıştır)
  static const List<String> _profanityWords = [
    // A Grubu
    'a*k', 'a*k*', 'a.q', 'a.q.', 'amk', 'aq', 'amcık', 'amcik', 'amcuk',
    'amcıklama', 'amına', 'amınakoyim', 'aminakoyim', 'amınakoyarım', 'amınako',
    'amsalak', 'amsız', 'amık', 'amın oğlu', 'amına koyayım', 'amına koyim',
    'amına sokam', 'anani sikerim', 'anani sikeyim', 'ananı sikerim', 'ananı sikeyim',
    'ananın amı', 'ananısikerim', 'anasını sikeyim', 'anasının amı', 'atkafası',
    'atmık', 'ağzına sıçayım',

    // B Grubu
    'babası pezevenk', 'bacağına sıçayım', 'bok', 'boka', 'boktan', 'boku',
    'bombok', 'bızır',

    // C / D Grubu
    'cibiliyetsiz', 'cibilliyetsiz', 'dallama', 'daltassak', 'dalyarak',
    'dalyarrak', 'dangalak', 'daşak', 'daşağı', 'daşşak', 'daşşağı',
    'dildo', 'dkerim', 'domal', 'domalmak', 'domalt', 'döl', 'dölü',

    // E / F Grubu
    'ebeni', 'ebenin amı', 'fahişe', 'fuck', 'fucker', 'fucking',

    // G Grubu
    'gavat', 'gavad', 'gerizekalı', 'gerizekali', 'giberim', 'godoş',
    'godumun', 'gotveren', 'göt', 'götelek', 'götlalesi', 'götlek',
    'götoğlanı', 'götoş', 'götten', 'götveren', 'götüne', 'götünü',

    // H / İ Grubu
    'hasiktir', 'hassikome', 'hassiktir', 'hsktr', 'huur', 'ibne',
    'ibneliği', 'ibneler', 'ibnenin',

    // K Grubu
    'kahpe', 'kaltak', 'kaltağı', 'kancık', 'kerhane', 'kerhaneci',
    'kevaşe', 'kodumun', 'kodumunun', 'koduğumun',

    // M / O / P Grubu
    'malafat', 'motherfucker', 'o.ç', 'o.ç.', 'oç', 'orospu',
    'orospu çocuğu', 'orospucocugu', 'orospunun', 'orospunun evladı',
    'orospuçocuğu', 'oruspu', 'oruspu çocuğu', 'otuzbir', 'oğlancı',
    'pezevenk', 'pezo', 'piç', 'piç kurusu', 'piçin oğlu', 'piçler',
    'porno', 'pornografi', 'pussy', 'puşt',

    // S Grubu
    'sakso', 's1kerim', 'sik', 'sikdiğim', 'sikecem', 'siker', 'sikerim',
    'sikerler', 'sikertmek', 'sikeyim', 'sikeym', 'sikik', 'sikilmiş',
    'sikim', 'sikimde', 'sikime', 'sikimi', 'sikimin', 'sikimsonik',
    'sikiş', 'sikişen', 'sikişme', 'sikko', 'sikmek', 'siksin', 'siksok',
    'siktir', 'siktirgit', 'siktirir', 'siktiği', 'siktiğim', 'siktiğimin',
    'sktr', 'sokuk', 'sürtük', 'sıçarım', 'sıçayım', 'sıçmak', 'sıçtığım',

    // T / V / Y / Z Grubu
    'taşak', 'taşşak', 'totoş', 'vajina', 'veledizina', 'whore',
    'yarrak', 'yarram', 'yarramın', 'yarrağım', 'yarrağımı', 'yavşak',
    'yrrak', 'zikik', 'zikim', 'zikmek', 'çük'
  ];

  /// Türkçe karakterleri koruyarak metni normalize eder ve küçük harfe çevirir.
  static String _cleanText(String text) {
    return text.toLowerCase().trim();
  }

  /// Kelime bazlı tam eşleşme kontrolü yapar.
  static bool containsProfanity(String text) {
    if (text.isEmpty) return false;

    final cleanedText = _cleanText(text);

    for (final profanity in _profanityWords) {
      final cleanProfanity = _cleanText(profanity);

      // Tam kelime/sözcük öbeği sınırı kontrolü (\b)
      final regex = RegExp(
        r'(^|\s|[^a-zA-Z0-9çğıöşüÇĞİÖŞÜ])' +
            RegExp.escape(cleanProfanity) +
            r'($|\s|[^a-zA-Z0-9çğıöşüÇĞİÖŞÜ])',
        caseSensitive: false,
      );

      if (regex.hasMatch(cleanedText)) {
        _log(
            '⚠️ Küfür tespit edildi: "$profanity" içerikte: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
        return true;
      }
    }

    return false;
  }

  /// İçerik moderasyonu - Başlık ve açıklama kontrolü
  static ModerationResult moderateContent({
    required String? title,
    required String? description,
  }) {
    if (title == null && description == null) {
      return ModerationResult(isSafe: true);
    }

    final titleText = title ?? '';
    final descriptionText = description ?? '';
    final combinedText = '$titleText $descriptionText';

    if (containsProfanity(combinedText)) {
      return ModerationResult(
        isSafe: false,
        reason:
            'İçerik uygunsuz kelimeler içeriyor. Lütfen daha uygun bir dil kullanın.',
      );
    }

    return ModerationResult(isSafe: true);
  }

  /// Yorum moderasyonu
  static ModerationResult moderateComment(String commentText) {
    if (commentText.isEmpty) {
      return ModerationResult(isSafe: true);
    }

    if (containsProfanity(commentText)) {
      return ModerationResult(
        isSafe: false,
        reason:
            'Yorumunuz uygunsuz kelimeler içeriyor. Lütfen daha uygun bir dil kullanın.',
      );
    }

    return ModerationResult(isSafe: true);
  }
}

/// Moderasyon sonucu
class ModerationResult {
  final bool isSafe;
  final String? reason;

  ModerationResult({
    required this.isSafe,
    this.reason,
  });
}
