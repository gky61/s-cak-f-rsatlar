import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/zara_scraper.dart';

void main() {
  test('Zara Original Price Scraper Test (All 3 Links)', () async {
    final scraper = ZaraScraper();

    final testCases = [
      {
        'name': 'Link 1 (Cepli İnterlok Sweatshirt)',
        'url': 'https://www.zara.com/tr/tr/cepli-interlok-sweatshirt-p00761409.html?v1=498899772&v2=2537962',
        'expectedDiscounted': 590.0,
        'expectedOriginal': 750.0,
      },
      {
        'name': 'Link 2 (Yün Karışımlı Yama Cepli Blazer)',
        'url': 'https://www.zara.com/tr/tr/yun-karisimli-yama-cepli-blazer-p04422136.html?v1=513992488&v2=2724459',
        'expectedDiscounted': 1290.0,
        'expectedOriginal': 1690.0,
      },
      {
        'name': 'Link 3 (Deri Makosen)',
        'url': 'https://www.zara.com/tr/tr/deri-makosen-p12653720.html?v1=508357135&v2=2721511',
        'expectedDiscounted': 3390.0,
        'expectedOriginal': 3990.0,
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
