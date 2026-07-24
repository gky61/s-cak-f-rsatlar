import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/defacto_scraper.dart';

void main() {
  test('DeFacto Original Price Scraper Test (All 3 Links)', () async {
    final scraper = DefactoScraper();

    final testCases = [
      {
        'name': 'Link 1 (Pamuklu Regular Fit Polo Tişört)',
        'url': 'https://www.defacto.com.tr/pamuklu-regular-fit-kisa-kollu-polo-tisort-3429279',
        'expectedDiscounted': 399.99,
        'expectedOriginal': 799.99,
      },
      {
        'name': 'Link 2 (Regular Fit Pamuklu Smart Casual Pantolon)',
        'url': 'https://www.defacto.com.tr/regular-fit-pamuklu-smart-casual-pantolon-3376806',
        'expectedDiscounted': 499.99,
        'expectedOriginal': 999.99,
      },
      {
        'name': 'Link 3 (Erkek Ürün)',
        'url': 'https://www.defacto.com.tr/erkek-3414636',
        'expectedDiscounted': 209.99,
        'expectedOriginal': 349.99,
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
