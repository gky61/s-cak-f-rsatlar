import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/trendyol_scraper.dart';

void main() {
  test('Trendyol Original Price Scraper Test (All 5 Links)', () async {
    final scraper = TrendyolScraper();

    final testCases = [
      {
        'name': 'Link 1 (Karınca Yumurtası Yağı)',
        'url': 'https://www.trendyol.com/ornate/karinca-yumurtasi-yagli-tuy-azaltici-ve-tuy-serum-30ml-0-5-formic-acid-10-aloe-vera-p-474728905?boutiqueId=61',
        'expectedDiscounted': 249.99,
        'expectedOriginal': 259.99,
      },
      {
        'name': 'Link 2 (Mavi Kil Maskesi)',
        'url': 'https://www.trendyol.com/qremfi/sifir-gozenek-siyah-nokta-mavi-kil-maskesi-aha-bha-pha-100-ml-p-1087380299?boutiqueId=61',
        'expectedDiscounted': 272.66,
        'expectedOriginal': 279.90,
      },
      {
        'name': 'Link 3 (Çubuklu Oda Kokusu)',
        'url': 'https://www.trendyol.com/secret-of-love/cubuklu-oda-kokusu-beyaz-sabun-100ml-p-856508217?boutiqueId=61&merchantId=476096',
        'expectedDiscounted': 155.78,
        'expectedOriginal': 163.98,
      },
      {
        'name': 'Link 4 (Gürme Sütlü Çikolata)',
        'url': 'https://www.trendyol.com/swedent/gurme-serisi-sutlu-cikolata-sos-kremsi-dokusu-ile-zengin-ve-akiskan-kivam-p-1130262186?boutiqueId=61',
        'expectedDiscounted': 249.90,
        'expectedOriginal': 269.90,
      },
      {
        'name': 'Link 5 (Dyson Süpürge)',
        'url': 'https://www.trendyol.com/dyson/big-ball-absolute-2-kablolu-supurge-p-1106741113?boutiqueId=61&merchantId=117947',
        'expectedDiscounted': 16999.00,
        'expectedOriginal': 19999.00,
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
