import 'package:flutter/foundation.dart' show kDebugMode;

void _log(String message) {
  if (kDebugMode) print(message);
}

/// İçerik moderasyon servisi - Küfürlü ve uygunsuz içerikleri tespit eder
class ContentModerationService {
  // Türkçe küfür ve uygunsuz kelimeler listesi
  // Bu liste sürekli güncellenebilir ve genişletilebilir
  static const List<String> _profanityWords = [
    // Açık küfürler (kısaltılmış)
    's*k', 's*k*', 's*k**', 's*k***',
    'a*k', 'a*k*', 'a*k**',
    'o*', 'o**', 'o***',
    'p*', 'p**', 'p***',
    'k*', 'k**', 'k***',
    'm*k', 'm*k*',
    'g*t', 'g*t*',
    'ç*k', 'ç*k*',
    'b*k', 'b*k*',
    'd*k', 'd*k*',
    't*k', 't*k*',
    'y*k', 'y*k*',
    'z*k', 'z*k*',
    
    // Tam kelimeler (normalize edilmiş)
    'sik', 'sike', 'siker', 'sikmek', 'sikti', 'siktir',
    'amk', 'amcik', 'amcık',
    'orospu', 'orospu cocugu', 'orospu çocuğu',
    'pezevenk', 'pezeveng',
    'kerhane', 'kerhaneci',
    'mal', 'malk', 'malak',
    'got', 'göt', 'gotu', 'götü',
    'cuk', 'çük', 'cukmek', 'çükmek',
    'bok', 'boka', 'boku',
    'dik', 'dikmek',
    'tik', 'tikmek',
    'yik', 'yikmek',
    'zik', 'zikmek',
    
    // Hakaretler
    'aptal', 'salak', 'gerizekali', 'geri zekalı',
    'beyinsiz', 'akilsiz', 'akılsız',
    'pic', 'piç', 'piclik', 'piçlik',
    'it', 'it oglu it', 'it oğlu it',
    'kopek', 'köpek',
    'domuz', 'domuzluk',
    'haysiyetsiz', 'serefsiz', 'şerefsiz',
    'namussuz', 'namusuz',
    
    // Cinsel içerik
    'porno', 'pornografi', 'seks', 'sex',
    'masturbasyon', 'masturbate',
    'orgazm', 'orgasm',
    
    // Şiddet içerik
    'oldur', 'öldür', 'oldurmek', 'öldürmek',
    'katlet', 'katletmek',
    'bomba', 'bombala', 'bombalamak',
    'silah', 'silahla', 'silahlamak',
    
    // Uyuşturucu
    'esrar', 'eroin', 'kokain', 'kokain',
    'uyusturucu', 'uyuşturucu',
    'sarhos', 'sarhoş', 'alkolik',
    
    // Spam ve dolandırıcılık
    'kazan', 'kazanmak', 'para kazan',
    'bedava para', 'hizli para',
    'dolandir', 'dolandır',
  ];

  // Normalize fonksiyonu - Türkçe karakterleri İngilizce karşılıklarına çevirir
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('İ', 'i')
        .replaceAll('Ç', 'c')
        .replaceAll('Ğ', 'g')
        .replaceAll('Ö', 'o')
        .replaceAll('Ş', 's')
        .replaceAll('Ü', 'u');
  }

  // Kelimeleri ayır ve normalize et
  static List<String> _tokenize(String text) {
    final normalized = _normalize(text);
    // Noktalama işaretlerini kaldır ve kelimelere ayır
    final cleaned = normalized.replaceAll(RegExp(r'[^\w\s]'), ' ');
    return cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  // Küfür kontrolü yap
  static bool containsProfanity(String text) {
    if (text.isEmpty) return false;
    
    final words = _tokenize(text);
    final normalizedText = _normalize(text);
    
    // Her küfür kelimesini kontrol et
    for (final profanity in _profanityWords) {
      final normalizedProfanity = _normalize(profanity);
      
      // Tam kelime eşleşmesi veya metin içinde geçiyor mu kontrol et
      if (normalizedText.contains(normalizedProfanity)) {
        // Kelime sınırları kontrolü (yanlış pozitifleri önlemek için)
        final regex = RegExp(r'\b' + RegExp.escape(normalizedProfanity) + r'\b');
        if (regex.hasMatch(normalizedText)) {
          _log('⚠️ Küfür tespit edildi: "$profanity" içerikte: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
          return true;
        }
        
        // Eğer kelime çok kısa değilse, substring kontrolü yap
        if (normalizedProfanity.length >= 3 && normalizedText.contains(normalizedProfanity)) {
          _log('⚠️ Küfür tespit edildi: "$profanity" içerikte: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
          return true;
        }
      }
    }
    
    return false;
  }

  // İçerik moderasyonu - Başlık ve açıklama kontrolü
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
        reason: 'İçerik uygunsuz kelimeler içeriyor. Lütfen daha uygun bir dil kullanın.',
      );
    }

    return ModerationResult(isSafe: true);
  }

  // Yorum moderasyonu
  static ModerationResult moderateComment(String commentText) {
    if (commentText.isEmpty) {
      return ModerationResult(isSafe: true);
    }

    if (containsProfanity(commentText)) {
      return ModerationResult(
        isSafe: false,
        reason: 'Yorumunuz uygunsuz kelimeler içeriyor. Lütfen daha uygun bir dil kullanın.',
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





