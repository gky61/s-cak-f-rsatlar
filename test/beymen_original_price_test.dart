import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/beymen_scraper.dart';

void main() {
  test('Beymen Original Price Scraper Test (All 3 Links)', () async {
    final scraper = BeymenScraper();

    final testCases = [
      {
        'name': 'Link 1 (Adidas Samba OG Koyu Kahverengi Kadın Sneaker)',
        'url': 'https://www.beymen.com/tr/p_adidas-samba-og-koyu-kahverengi-kadin-sneaker_1907622',
        'expectedDiscounted': 4076.0,
        'expectedOriginal': 7250.0,
      },
      {
        'name': 'Link 2 (Bekaliving Hills Brass Ahşap 3lü Orta Sehpa)',
        'url': 'https://www.beymen.com/tr/p_bekaliving-hills-brass-cam-detay-mushroom-ahsap-3lu-orta-sehpa-takimi_1113301',
        'expectedDiscounted': 51793.0,
        'expectedOriginal': 73990.0,
      },
      {
        'name': 'Link 3 (Beymen Club Siyah Beyaz Çizgili Sweatshirt)',
        'url': 'https://www.beymen.com/tr/p_beymen-club-siyah-beyaz-cizgili-sweatshirt_1921513',
        'expectedDiscounted': 2499.0,
        'expectedOriginal': 4999.0,
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
