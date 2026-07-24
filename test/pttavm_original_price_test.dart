import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/pttavm_scraper.dart';

void main() {
  test('PttAVM Original Price Scraper Test (All 2 Links)', () async {
    final scraper = PttavmScraper();

    final testCases = [
      {
        'name': 'Link 1 (Cata CT-1156 Dolunay LED Ampul)',
        'url': 'https://www.pttavm.com/cata-ct-1156-dolunay-72w-fanli-kumandali-led-ampul-3-renk-p-1456659184',
        'expectedDiscounted': 1722.62,
        'expectedOriginal': 1980.02,
      },
      {
        'name': 'Link 2 (Rivaistanbul Ahşap Lambader)',
        'url': 'https://www.pttavm.com/rivaistanbul-hasir-dokulu-silindir-baslik-ahsap-uc-ayakli-lambader-p-846468199',
        'expectedDiscounted': 799.72,
        'expectedOriginal': 929.90,
      },
    ];

    const chromeUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

    for (final tc in testCases) {
      final url = tc['url'] as String;
      final processRes = await Process.run('curl', [
        '-sL',
        '--compressed',
        '-H', 'User-Agent: $chromeUA',
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
