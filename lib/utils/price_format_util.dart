import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// FırsatKolik merkezi para birimi & fiyat biçimlendirici ve ayrıştırıcısı.
/// Tüm uygulama genelinde (Fırsat Detay, Fırsat Paylaş, Kartlar, Admin vb.)
/// Türk Lirası fiyat gösterimi ve metin girişi için tek doğruluk kaynağıdır.
class PriceFormatUtil {
  PriceFormatUtil._();

  // Performans optimizasyonu: Her tuş basımında veya kart render'ında
  // tekrar tekrar RegExp derlemesini önlemek için statik precompiled regex'ler.
  static final RegExp _thousandRegex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  static final RegExp _nonDigitsOrSeparators = RegExp(r'[^\d.,]');
  static final RegExp _cleanCurrencyRegex = RegExp(r'[₺$€\s]|TL|tl|Tl', caseSensitive: false);
  static final RegExp _leadingZeros = RegExp(r'^0+');
  static final RegExp _onlyDigits = RegExp(r'[^\d]');
  static final RegExp _thousandPattern = RegExp(r'^\d{1,3}(\.\d{3})+$');

  /// Fiyatı Türkiye standartlarında binlik noktalı (.) ve kuruşlu virgüllü (,) olarak formatlar.
  /// Örnekler:
  /// - 43315.09 -> "₺43.315,09" (includeSymbol: true) veya "43.315,09" (includeSymbol: false)
  /// - 48020 -> "₺48.020" veya "48.020"
  /// - 1500 -> "₺1.500" veya "1.500"
  /// - 75.50 -> "₺75,50" veya "75,50"
  /// - 0 -> "₺0" veya "0"
  /// - null / NaN / Infinity -> ""
  static String format(
    num? value, {
    bool includeSymbol = true,
    String symbol = '₺',
    bool forceDecimals = false,
  }) {
    if (value == null) return '';
    final double doubleVal = value.toDouble();
    if (doubleVal.isNaN || doubleVal.isInfinite) return '';

    final double roundVal = (doubleVal * 100).round() / 100;
    final double absVal = roundVal.abs();
    final int wholePart = absVal.truncate();
    final int cents = ((absVal - wholePart) * 100).round();

    // Binlik ayırıcı olarak Nokta (.) kullanılır
    final String wholeStr = wholePart.toString().replaceAllMapped(
      _thousandRegex,
      (Match m) => '${m[1]}.',
    );

    final String sign = roundVal < 0 ? '-' : '';

    String numberStr;
    if (cents == 0 && !forceDecimals) {
      // 1. Tam Sayı Fiyatlar (Kuruşsuz): 75, 1.500, 48.020
      numberStr = '$sign$wholeStr';
    } else {
      // 2. Kuruşlu Fiyatlar (Ondalıklı): 75,50, 1.999,90, 43.315,09
      final String centsStr = cents.toString().padLeft(2, '0');
      numberStr = '$sign$wholeStr,$centsStr';
    }

    if (includeSymbol && symbol.isNotEmpty) {
      return '$symbol$numberStr';
    }
    return numberStr;
  }

  /// Input alanları (TextFormField) için sembolsüz, düzenlenebilir format üretir.
  /// Örn: 48020 -> "48.020", 43315.09 -> "43.315,09", 1500 -> "1.500"
  static String formatForInput(num? value) {
    return format(value, includeSymbol: false);
  }

  /// Kullanıcı girdisi, API verisi veya karmaşık metinlerden fiyatı güvenle parse eder.
  /// Hem Türkçe (43.315,09 / 48.020) hem de uluslararası (43315.09 / 43,315.09) formatları destekler.
  /// Felaket senaryoları (aşırı büyük girdiler, NaN, negatifler vb.) için tam korumalıdır.
  static double? parse(dynamic input) {
    if (input == null) return null;
    if (input is num) {
      final d = input.toDouble();
      return (d.isNaN || d.isInfinite) ? null : d;
    }
    if (input is! String) return null;

    String cleaned = input
        .replaceAll(_cleanCurrencyRegex, '')
        .trim();

    if (cleaned.isEmpty) return null;

    final hasDot = cleaned.contains('.');
    final hasComma = cleaned.contains(',');

    if (hasDot && hasComma) {
      final lastDot = cleaned.lastIndexOf('.');
      final lastComma = cleaned.lastIndexOf(',');
      if (lastComma > lastDot) {
        // Türkçe format: 43.315,09 -> noktalar binlik, virgül ondalık
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Uluslararası format: 43,315.09 -> virgüller binlik, nokta ondalık
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (hasComma) {
      final parts = cleaned.split(',');
      if (parts.length == 2) {
        // 43315,09 veya 75,5
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        // Çoklu virgül: 1,234,567
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (hasDot) {
      final parts = cleaned.split('.');
      if (parts.length == 2) {
        // Örn: 48.020 (3 basamaklı binlik) -> 48020
        // Ancak 48.5 veya 48.50 (1 veya 2 basamaklı) -> ondalık (48.5)
        if (parts[1].length == 3 && parts[0].isNotEmpty && parts[0].length <= 3) {
          cleaned = cleaned.replaceAll('.', '');
        } else {
          // Normal ondalık nokta (örn: 48.50 veya 43315.09)
        }
      } else if (parts.length > 2) {
        // Çoklu nokta: 1.234.567 -> 1234567
        cleaned = cleaned.replaceAll('.', '');
      }
    }

    final val = double.tryParse(cleaned);
    if (val == null || val.isNaN || val.isInfinite) return null;
    return val;
  }

  /// İki fiyat arasındaki indirim oranını tam sayı yüzde olarak hesaplar (örn: %9).
  static int? calculateDiscountRate(num? originalPrice, num? currentPrice) {
    if (originalPrice == null || currentPrice == null) return null;
    final orig = originalPrice.toDouble();
    final curr = currentPrice.toDouble();
    if (orig.isNaN || curr.isNaN || orig.isInfinite || curr.isInfinite) return null;
    if (orig <= 0 || curr <= 0 || orig <= curr) return null;

    final rate = (((orig - curr) / orig) * 100).round();
    return rate > 0 ? rate : null;
  }
}

/// Kullanıcı fiyat yazarken (TextFormField) binlik ayırıcıları (.) ve kuruş virgülünü (,)
/// gerçek zamanlı biçimlendiren, imleç konumunu kusursuz koruyan profesyonel formatter.
/// Tüm felaket senaryolarına (yapıştırma, silme, numpad noktası, backspace) dayanıklıdır.
class TurkishCurrencyInputFormatter extends TextInputFormatter {
  final int maxDecimals;
  final int maxIntegerDigits;

  TurkishCurrencyInputFormatter({
    this.maxDecimals = 2,
    this.maxIntegerDigits = 12, // 999 Milyar TL tavanı (performans ve taşma koruması)
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String rawText = newValue.text;

    // 0. Akıllı Backspace: Kullanıcı binlik noktasının ardındayken backspace bastıysa,
    // noktanın solundaki rakamı da silerek kullanıcının takılmasını önle.
    if (oldValue.text.length == rawText.length + 1 &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.end > 1 &&
        oldValue.text[oldValue.selection.end - 1] == '.') {
      final deleteIdx = oldValue.selection.end - 2;
      if (deleteIdx >= 0 && deleteIdx < rawText.length) {
        rawText = rawText.substring(0, deleteIdx) + rawText.substring(deleteIdx + 1);
      }
    }

    // Yalnızca rakam, virgül ve nokta karakterlerine izin verilir
    String text = rawText.replaceAll(PriceFormatUtil._nonDigitsOrSeparators, '');
    if (text.isEmpty) {
      return const TextEditingValue();
    }

    // 1. Nokta ve Virgül Analizi (Yapıştırma ve Numpad Desteği):
    final hasComma = text.contains(',');
    final hasDot = text.contains('.');

    if (!hasComma && hasDot) {
      // A) Zaten binlik noktalı yapıştırılmış metin (Örn: 48.020 veya 1.250.000):
      if (PriceFormatUtil._thousandPattern.hasMatch(text)) {
        // Noktalar binlik ayırıcıdır, virgüle dönüştürme; noktaları koru.
      } else if (text.endsWith('.')) {
        // B) Kullanıcı numpad noktası tuşladı (kuruş tetikleyici):
        text = '${text.substring(0, text.length - 1)},';
      } else {
        // C) Uluslararası ondalık nokta (Örn: 48.50 veya 43315.09):
        final lastDotIdx = text.lastIndexOf('.');
        final afterDot = text.substring(lastDotIdx + 1);
        if (afterDot.length <= maxDecimals && text.indexOf('.') == lastDotIdx) {
          text = '${text.substring(0, lastDotIdx)},$afterDot';
        }
      }
    }

    // 2. İlk karakter virgül ise otomatik 0 ekle (Örn: ,5 -> 0,5 veya , -> 0,)
    if (text.startsWith(',')) {
      text = '0$text';
    }

    // 3. Tam ve Ondalık Bölümleri Ayır
    String wholePart = '';
    String? decimalPart;

    if (text.contains(',')) {
      final parts = text.split(',');
      wholePart = parts[0].replaceAll('.', '');
      // Sadece tek virgül kabul edilir, sonrakiler yutulur
      decimalPart = parts.sublist(1).join('').replaceAll(PriceFormatUtil._onlyDigits, '');
      if (decimalPart.length > maxDecimals) {
        decimalPart = decimalPart.substring(0, maxDecimals);
      }
    } else {
      wholePart = text.replaceAll('.', '');
    }

    // Taşma ve DoS Koruması: Tavan basamak sınırlandırması
    if (wholePart.length > maxIntegerDigits) {
      wholePart = wholePart.substring(0, maxIntegerDigits);
    }

    // Baştaki anlamsız sıfırları temizle (tek sıfır hariç)
    if (wholePart.length > 1 && wholePart.startsWith('0')) {
      wholePart = wholePart.replaceFirst(PriceFormatUtil._leadingZeros, '');
      if (wholePart.isEmpty) wholePart = '0';
    }

    // 4. Tam Bölümü Binlik Noktalarla Formatla
    final formattedWhole = wholePart.replaceAllMapped(
      PriceFormatUtil._thousandRegex,
      (Match m) => '${m[1]}.',
    );

    // 5. Sonuç Metnini Oluştur
    String formattedResult;
    if (decimalPart != null) {
      formattedResult = '$formattedWhole,$decimalPart';
    } else {
      formattedResult = formattedWhole;
    }

    // 6. İmleç Konumunu Kusursuz Hesapla
    // Kullanıcının imleçten önce kaç adet "anlamlı karakter" (rakam veya virgül) yazdığını sayarız.
    int meaningfulCharsBeforeCursor = 0;
    final cursorIndex = newValue.selection.end.clamp(0, newValue.text.length);
    for (int i = 0; i < cursorIndex; i++) {
      final char = newValue.text[i];
      if (char != '.') {
        meaningfulCharsBeforeCursor++;
      }
    }

    // Yeni biçimlendirilmiş metinde bu kadar anlamlı karakterin denk geldiği konumu buluruz.
    int newCursorIndex = 0;
    int meaningfulSeen = 0;
    for (int i = 0; i < formattedResult.length; i++) {
      if (meaningfulSeen >= meaningfulCharsBeforeCursor) {
        break;
      }
      final char = formattedResult[i];
      if (char != '.') {
        meaningfulSeen++;
      }
      newCursorIndex = i + 1;
    }

    newCursorIndex = newCursorIndex.clamp(0, formattedResult.length);

    return TextEditingValue(
      text: formattedResult,
      selection: TextSelection.collapsed(offset: newCursorIndex),
    );
  }
}

/// Türk Lirası fiyat gösterimi için tüm uygulama genelinde ortak ve tutarlı widget.
/// ₺ Simgesi rakamın solunda, rakamdan %10 daha zarif boyutta render edilir.
/// Binlik ayırıcı olarak nokta (.), kuruş varsa virgül (,) kullanılır.
class FormattedPriceText extends StatelessWidget {
  final num? value;
  final TextStyle style;
  final String symbol;
  final TextOverflow overflow;
  final int maxLines;

  const FormattedPriceText({
    super.key,
    required this.value,
    required this.style,
    this.symbol = '₺',
    this.overflow = TextOverflow.ellipsis,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();

    final priceStr = PriceFormatUtil.format(value, includeSymbol: false);

    final double baseFontSize = style.fontSize ?? 14.0;
    final double symbolFontSize = baseFontSize * 0.90; // %10 daha zarif

    return Text.rich(
      TextSpan(
        children: [
          if (symbol.isNotEmpty)
            TextSpan(
              text: symbol,
              style: style.copyWith(
                fontSize: symbolFontSize,
              ),
            ),
          TextSpan(
            text: priceStr,
            style: style,
          ),
        ],
      ),
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
