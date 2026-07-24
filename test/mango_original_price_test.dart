import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/mango_scraper.dart';

void main() {
  test('Mango Original Price Scraper Test (All 2 Links)', () async {
    final scraper = MangoScraper();

    final testCases = [
      {
        'name': 'Link 1 (Erkek Süet Ayakkabı)',
        'url': 'https://shop.mango.com/tr/tr/p/erkek/ayakkab%C4%B1/deri/suet-ayakkab%C4%B1/37091356/CG/00',
        'expectedDiscounted': 2499.99,
        'expectedOriginal': 3699.99,
      },
      {
        'name': 'Link 2 (Erkek Gabardin Trençkot / Parka)',
        'url': 'https://shop.mango.com/tr/tr/p/erkek/gabardin-trenckotlar/su-gecirmez-parka--c%C4%B1kar%C4%B1labilir-kapusonlu/27034409/56/00',
        'expectedDiscounted': 2399.99,
        'expectedOriginal': 7999.99,
      },
    ];

    const whatsappUA = 'WhatsApp/2.23.4.15 A';

    for (final tc in testCases) {
      final url = tc['url'] as String;
      final processRes = await Process.run('curl', [
        '-sL',
        '--compressed',
        '-H', 'User-Agent: $whatsappUA',
        '-H', 'Accept-Language: tr-TR,tr;q=0.9',
        url,
      ]);

      expect(processRes.exitCode, equals(0));
      final doc = html_parser.parse(processRes.stdout as String);

      final price = await scraper.scrapePrice(doc);
      final originalPrice = scraper.scrapeOriginalPrice(doc, price);

      print('--- ${tc['name']} ---');
      print('Discounted Price: $price (Expected: ${tc['expectedDiscounted']})');
      print('Original Price:   $originalPrice (Expected: ${tc['expectedOriginal']})');

      expect((price! - (tc['expectedDiscounted'] as double)).abs() < 0.01, isTrue);
      expect((originalPrice! - (tc['expectedOriginal'] as double)).abs() < 0.01, isTrue);

      if (originalPrice > price) {
        final discountPercent = (((originalPrice - price) / originalPrice) * 100).round();
        print('Discount Percentage: %$discountPercent');
      }
      print('✅ PASSED: ${tc['name']}\n');
    }
  });
}
