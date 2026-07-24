import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/pazarama_scraper.dart';

void main() {
  test('Pazarama Original Price Scraper Test (All 5 Links)', () async {
    final scraper = PazaramaScraper();

    final testCases = [
      {
        'name': 'Link 1 (LG 65QNED TV)',
        'url': 'https://www.pazarama.com/lg-65qned70b6c-4k-uhd-qned-mini-led-tv-165-cm-8806096774205-p-8806096774205?magaza=mediamarkt',
        'expectedDiscounted': 49882.00,
        'expectedOriginal': 50900.00,
      },
      {
        'name': 'Link 2 (Einhell Akülü Çivi Zımba)',
        'url': 'https://www.pazarama.com/einhell-te-cn-18-li-akulu-civi-ve-zimba-tabancasi-seti-25-ah-aku-ve-sarj-cihazi-dahildir-p-8694301331219?magaza=pazarama',
        'expectedDiscounted': 5140.00,
        'expectedOriginal': 5440.00,
      },
      {
        'name': 'Link 3 (Peros Sıvı Sabun)',
        'url': 'https://www.pazarama.com/peros-sivi-sabun-3-kg-aqua-deniz-esintisi-p-8697713838895',
        'expectedDiscounted': 104.41,
        'expectedOriginal': 149.90,
      },
      {
        'name': 'Link 4 (Philips Vantilatör)',
        'url': 'https://www.pazarama.com/philips-cx-553500-kule-tipi-vantilator-beyaz-p-8720389036972',
        'expectedDiscounted': 5758.00,
        'expectedOriginal': 7200.00,
      },
      {
        'name': 'Link 5 (Flormar Fondöten Kapatıcı)',
        'url': 'https://www.pazarama.com/yogun-kapaticilik-sunan-2li-fondotenkapatici-seti-acik-tensoguk-alt-ton-p-SET137?magaza=flormar',
        'expectedDiscounted': 617.50,
        'expectedOriginal': 899.99,
      },
    ];

    for (final tc in testCases) {
      final url = tc['url'] as String;
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'WhatsApp/2.23.4.15 A',
          'Accept-Language': 'tr-TR,tr;q=0.9',
        },
      );

      expect(response.statusCode, equals(200));
      final doc = html_parser.parse(response.body);

      final price = await scraper.scrapePrice(doc);
      final originalPrice = scraper.scrapeOriginalPrice(doc, price);

      print('--- ${tc['name']} ---');
      print('Discounted Price: $price (Expected: ${tc['expectedDiscounted']})');
      print('Original Price:   $originalPrice (Expected: ${tc['expectedOriginal']})');

      expect(price, equals(tc['expectedDiscounted']));
      expect(originalPrice, equals(tc['expectedOriginal']));

      if (originalPrice != null && price != null && originalPrice > price) {
        final discountPercent = (((originalPrice - price) / originalPrice) * 100).round();
        print('Discount Percentage: %$discountPercent');
      }
      print('✅ PASSED: ${tc['name']}\n');
    }
  });
}
