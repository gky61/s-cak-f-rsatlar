import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/mavi_scraper.dart';

void main() {
  test('Mavi Original Price Scraper Test (All 3 Links)', () async {
    final scraper = MaviScraper();

    final testCases = [
      {
        'name': 'Link 1 (Soft Premium Açık Mavi Polo Tişört)',
        'url': 'https://www.mavi.com/soft-premium-acik-mavi-polo-tisort/p/0613271-70802',
        'expectedDiscounted': 749.99,
        'expectedOriginal': 1499.99,
      },
      {
        'name': 'Link 2 (Road Runner Baskılı Mavi Tişört)',
        'url': 'https://www.mavi.com/road-runner-baskili-mavi-tisort/p/0613200-70758',
        'expectedDiscounted': 449.99,
        'expectedOriginal': 629.99,
      },
      {
        'name': 'Link 3 (Mini Mavi Logo Baskılı Interlok Siyah Basic Tişört)',
        'url': 'https://www.mavi.com/mini-mavi-logo-baskili-interlok-siyah-basic-tisort/p/1612122-900',
        'expectedDiscounted': 419.99,
        'expectedOriginal': 599.99,
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
