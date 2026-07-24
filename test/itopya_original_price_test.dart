import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/itopya_scraper.dart';

void main() {
  test('İtopya Original Price & Brand & Rating Scraper Test (All 4 Links)', () async {
    final scraper = ItopyaScraper();

    final testCases = [
      {
        'name': 'Link 1 (Microsoft Xbox Series Wireless Gamepad)',
        'url': 'https://www.itopya.com/microsoft-xbox-series-wireless-ice-breaker-gamepad_u31675',
        'expectedDiscounted': 3846.19,
        'expectedOriginal': 6080.09,
        'expectedBrand': 'MICROSOFT',
      },
      {
        'name': 'Link 2 (ASUS ROG Strix XG27AQDMGR Monitör)',
        'url': 'https://www.itopya.com/asus-rog-strix-xg27aqdmgr-265-240hz-003ms-hdmi-dp-usb-32-adaptivesync-pivot-hdr10-woled-monitor_u31945',
        'expectedDiscounted': 28144.33,
        'expectedOriginal': 36594.98,
        'expectedBrand': 'ASUS',
      },
      {
        'name': 'Link 3 (ASUS TUF Gaming Laptop / PC)',
        'url': 'https://www.itopya.com/asus-tuf-gaming-t500mv-07240h0860-core-7-240h-16gb-ddr5-1tb-ssd-660w-80-gold-rtx-5060-dual-8gb-gddr_u33227',
        'expectedDiscounted': 67999.00,
        'expectedOriginal': 83208.24,
        'expectedBrand': 'ASUS',
      },
      {
        'name': 'Link 4 (AOC QD-OLED Monitör)',
        'url': 'https://www.itopya.com/aoc-q27g41zdf-27-240hz-003ms-hdmi-dp-adaptive-sync-hdr10-qhd-qd-oled-gaming-monitor_u32391',
        'expectedDiscounted': 21999.00,
        'expectedOriginal': 22671.82,
        'expectedBrand': 'AOC',
        'expectedRatingValue': 5.0,
        'expectedRatingCount': 4,
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
      final brand = scraper.scrapeBrand(doc);
      final ratingValue = await scraper.scrapeRatingValue(doc);
      final ratingCount = await scraper.scrapeRatingCount(doc);

      print('--- ${tc['name']} ---');
      print('Discounted Price: $price (Expected: ${tc['expectedDiscounted']})');
      print('Original Price:   $originalPrice (Expected: ${tc['expectedOriginal']})');
      print('Brand:            $brand (Expected: ${tc['expectedBrand']})');
      print('Rating Value:     $ratingValue / Count: $ratingCount');

      expect((price! - (tc['expectedDiscounted'] as double)).abs() < 0.01, isTrue);
      expect((originalPrice! - (tc['expectedOriginal'] as double)).abs() < 0.01, isTrue);
      expect(brand?.toUpperCase(), equals((tc['expectedBrand'] as String).toUpperCase()));

      if (ratingValue != null && tc.containsKey('expectedRatingValue')) {
        expect(ratingValue, equals(tc['expectedRatingValue']));
      }
      if (ratingCount != null && tc.containsKey('expectedRatingCount')) {
        expect(ratingCount, equals(tc['expectedRatingCount']));
      }

      if (originalPrice > price) {
        final discountPercent = (((originalPrice - price) / originalPrice) * 100).round();
        print('Discount Percentage: %$discountPercent');
      }
      print('✅ PASSED: ${tc['name']}\n');
    }
  });
}
