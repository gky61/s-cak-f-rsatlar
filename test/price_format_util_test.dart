import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/utils/price_format_util.dart';

void main() {
  group('PriceFormatUtil.format Tests', () {
    test('Tam sayı fiyatları binlik noktalı ve sembollü formatlar', () {
      expect(PriceFormatUtil.format(0), '₺0');
      expect(PriceFormatUtil.format(75), '₺75');
      expect(PriceFormatUtil.format(1500), '₺1.500');
      expect(PriceFormatUtil.format(48020), '₺48.020');
      expect(PriceFormatUtil.format(1250000), '₺1.250.000');
    });

    test('Kuruşlu fiyatları binlik noktalı, virgüllü ve sembollü formatlar', () {
      expect(PriceFormatUtil.format(75.50), '₺75,50');
      expect(PriceFormatUtil.format(1999.90), '₺1.999,90');
      expect(PriceFormatUtil.format(43315.09), '₺43.315,09');
      expect(PriceFormatUtil.format(12.99), '₺12,99');
    });

    test('Sembolsüz biçimlendirme', () {
      expect(PriceFormatUtil.format(48020, includeSymbol: false), '48.020');
      expect(PriceFormatUtil.format(43315.09, includeSymbol: false), '43.315,09');
      expect(PriceFormatUtil.format(1500, includeSymbol: false), '1.500');
    });

    test('null / NaN / Infinity değerleri için boş string döner', () {
      expect(PriceFormatUtil.format(null), '');
      expect(PriceFormatUtil.format(double.nan), '');
      expect(PriceFormatUtil.format(double.infinity), '');
      expect(PriceFormatUtil.format(null, includeSymbol: false), '');
    });

    test('forceDecimals: true olduğunda tam sayılara da ,00 ekler', () {
      expect(PriceFormatUtil.format(1500, forceDecimals: true), '₺1.500,00');
      expect(PriceFormatUtil.format(48020, forceDecimals: true, includeSymbol: false), '48.020,00');
    });
  });

  group('PriceFormatUtil.formatForInput Tests', () {
    test('Input alanları için sembolsüz ve Türk Lirası standart format döner', () {
      expect(PriceFormatUtil.formatForInput(48020), '48.020');
      expect(PriceFormatUtil.formatForInput(43315.09), '43.315,09');
      expect(PriceFormatUtil.formatForInput(1500), '1.500');
      expect(PriceFormatUtil.formatForInput(75.5), '75,50');
      expect(PriceFormatUtil.formatForInput(null), '');
      expect(PriceFormatUtil.formatForInput(double.nan), '');
    });
  });

  group('PriceFormatUtil.parse Tests', () {
    test('Türkçe formatlı binlik noktalı sayıları doğru parse eder', () {
      expect(PriceFormatUtil.parse('48.020'), 48020.0);
      expect(PriceFormatUtil.parse('1.500'), 1500.0);
      expect(PriceFormatUtil.parse('1.250.000'), 1250000.0);
    });

    test('Türkçe formatlı kuruşlu ve noktalı sayıları doğru parse eder', () {
      expect(PriceFormatUtil.parse('43.315,09'), 43315.09);
      expect(PriceFormatUtil.parse('1.999,90'), 1999.90);
      expect(PriceFormatUtil.parse('75,50'), 75.50);
      expect(PriceFormatUtil.parse('12,99'), 12.99);
    });

    test('Para birimi simgesi veya TL eki içeren metinleri temizleyip parse eder', () {
      expect(PriceFormatUtil.parse('₺48.020'), 48020.0);
      expect(PriceFormatUtil.parse('₺ 43.315,09'), 43315.09);
      expect(PriceFormatUtil.parse('48.020 TL'), 48020.0);
      expect(PriceFormatUtil.parse('43.315,09 TL'), 43315.09);
      expect(PriceFormatUtil.parse('1.500 tl'), 1500.0);
    });

    test('Uluslararası formatları da güvenle destekler', () {
      expect(PriceFormatUtil.parse('43315.09'), 43315.09);
      expect(PriceFormatUtil.parse('43,315.09'), 43315.09);
      expect(PriceFormatUtil.parse('1500'), 1500.0);
    });

    test('Sayısal (num) girdileri olduğu gibi double yapar', () {
      expect(PriceFormatUtil.parse(48020), 48020.0);
      expect(PriceFormatUtil.parse(43315.09), 43315.09);
    });

    test('Geçersiz veya boş değerler için null döner', () {
      expect(PriceFormatUtil.parse(null), isNull);
      expect(PriceFormatUtil.parse(''), isNull);
      expect(PriceFormatUtil.parse('   '), isNull);
      expect(PriceFormatUtil.parse('abc'), isNull);
      expect(PriceFormatUtil.parse(double.nan), isNull);
      expect(PriceFormatUtil.parse(double.infinity), isNull);
    });
  });

  group('PriceFormatUtil.calculateDiscountRate Tests', () {
    test('İdefix örnek ürünlerindeki indirim oranlarını doğru hesaplar', () {
      // Örnek 1: Profilo Buzdolabı (47.599 -> 43.315,09) -> ~%9
      final rate1 = PriceFormatUtil.calculateDiscountRate(47599, 43315.09);
      expect(rate1, 9);

      // Örnek 2: Bosch Buzdolabı (49.000 -> 48.020) -> ~%2
      final rate2 = PriceFormatUtil.calculateDiscountRate(49000, 48020);
      expect(rate2, 2);
    });

    test('Geçersiz veya indirimsiz durumlarda null döner', () {
      expect(PriceFormatUtil.calculateDiscountRate(null, 100), isNull);
      expect(PriceFormatUtil.calculateDiscountRate(100, null), isNull);
      expect(PriceFormatUtil.calculateDiscountRate(100, 100), isNull);
      expect(PriceFormatUtil.calculateDiscountRate(100, 120), isNull); // Fiyat artmış
      expect(PriceFormatUtil.calculateDiscountRate(0, 50), isNull);
      expect(PriceFormatUtil.calculateDiscountRate(double.nan, 50), isNull);
    });
  });

  group('TurkishCurrencyInputFormatter Tests', () {
    final formatter = TurkishCurrencyInputFormatter();

    test('Basamaklar yazıldıkça binlik noktaları otomatik ekler', () {
      final val1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '48020', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(val1.text, '48.020');
      expect(val1.selection.baseOffset, 6);

      final val2 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1250000', selection: TextSelection.collapsed(offset: 7)),
      );
      expect(val2.text, '1.250.000');
    });

    test('Kullanıcı virgülle ondalık yazdığında kuruşu korur', () {
      final val = formatter.formatEditUpdate(
        const TextEditingValue(text: '43315'),
        const TextEditingValue(text: '43315,09', selection: TextSelection.collapsed(offset: 8)),
      );
      expect(val.text, '43.315,09');
    });

    test('Kullanıcı numpad noktasını tuşladığında virgüle dönüştürür', () {
      final val = formatter.formatEditUpdate(
        const TextEditingValue(text: '48020'),
        const TextEditingValue(text: '48020.', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(val.text, '48.020,');
    });

    test('FELAKET SENARYOSU: Binlik noktalı metin yapıştırıldığında (örn: 48.020) noktayı kuruş yapmaz', () {
      final val1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '48.020', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(val1.text, '48.020');

      final val2 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1.500', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(val2.text, '1.500');

      final val3 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1.250.000', selection: TextSelection.collapsed(offset: 9)),
      );
      expect(val3.text, '1.250.000');
    });

    test('FELAKET SENARYOSU: Para birimi simgeli yapıştırma (₺ 48.020,50)', () {
      final val = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '₺ 48.020,50', selection: TextSelection.collapsed(offset: 11)),
      );
      expect(val.text, '48.020,50');
    });

    test('İlk karakter olarak virgül girildiğinde 0 ekler (örn: ,5 -> 0,5)', () {
      final val1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: ',', selection: TextSelection.collapsed(offset: 1)),
      );
      expect(val1.text, '0,');

      final val2 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: ',5', selection: TextSelection.collapsed(offset: 2)),
      );
      expect(val2.text, '0,5');
    });

    test('Akıllı Backspace: Noktadan hemen sonra silme tuşuna basıldığında takılmayı önler', () {
      // 1.500 metninde imleç '.' karakterinden hemen sonra (offset 2) iken backspace basıldı:
      final val = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.500', selection: TextSelection.collapsed(offset: 2)),
        const TextEditingValue(text: '1500', selection: TextSelection.collapsed(offset: 1)),
      );
      // '1' silindi ve geriye '500' kaldı
      expect(val.text, '500');
    });

    test('Aşırı uzun giriş (DoS/Taşma Koruması) 12 basamakla sınırlandırılır', () {
      final val = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12345678901234567890', selection: TextSelection.collapsed(offset: 20)),
      );
      // 12 basamak: 123.456.789.012
      expect(val.text, '123.456.789.012');
    });
  });

  group('FormattedPriceText Widget Tests', () {
    testWidgets('₺ simgesini ve formatlanmış fiyatı doğru render eder', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FormattedPriceText(
            value: 48020,
            style: TextStyle(fontSize: 20, color: Colors.black),
          ),
        ),
      );

      final textFinder = find.descendant(
        of: find.byType(FormattedPriceText),
        matching: find.byType(Text),
      );
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      final textSpan = textWidget.textSpan as TextSpan;

      expect(textSpan.toPlainText(), '₺48.020');
      expect((textSpan.children![0] as TextSpan).text, '₺');
      expect((textSpan.children![0] as TextSpan).style!.fontSize, 18.0);
      expect((textSpan.children![1] as TextSpan).text, '48.020');
      expect((textSpan.children![1] as TextSpan).style!.fontSize, 20.0);
    });

    testWidgets('Kuruşlu fiyatı doğru render eder', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FormattedPriceText(
            value: 43315.09,
            style: TextStyle(fontSize: 20, color: Colors.black),
          ),
        ),
      );

      final textFinder = find.descendant(
        of: find.byType(FormattedPriceText),
        matching: find.byType(Text),
      );
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      final textSpan = textWidget.textSpan as TextSpan;
      expect(textSpan.toPlainText(), '₺43.315,09');
      expect((textSpan.children![1] as TextSpan).text, '43.315,09');
    });
  });
}
