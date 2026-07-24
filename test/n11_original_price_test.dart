import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/n11_scraper.dart';

void main() {
  test('N11 Original Price Scraper Test (All 6 Links)', () async {
    final scraper = N11Scraper();

    final testCases = [
      {
        'name': 'Link 1 (LG 65QNED TV)',
        'url': 'https://www.n11.com/urun/lg-65qned70b6c-65-165-ekran-uydu-alicili-4k-ultra-hd-smart-webos-miniled-tv-128133247?magaza=tekno11',
        'expectedDiscounted': 46409.09,
        'expectedOriginal': 50999.00,
      },
      {
        'name': 'Link 2 (Samsung Mikrodalga)',
        'url': 'https://www.n11.com/urun/samsung-ms23k3614awtr-23-lt-solo-mikrodalga-firin-61161984?magaza=samsungturkiye',
        'expectedDiscounted': 4912.20,
        'expectedOriginal': 5167.80,
      },
      {
        'name': 'Link 3 (Tefal Tencere Seti)',
        'url': 'https://www.n11.com/urun/tefal-optispace-6-parca-tencere-seti-16784781?magaza=tefal',
        'expectedDiscounted': 3999.00,
        'expectedOriginal': 5499.00,
      },
      {
        'name': 'Link 4 (Samsung Galaxy A17)',
        'url': 'https://www.n11.com/urun/samsung-galaxy-a17-5g-8-gb-256-gb-samsung-turkiye-garantili-98196396?renk=gri&magaza=n11',
        'expectedDiscounted': 16399.00,
        'expectedOriginal': 19399.00,
      },
      {
        'name': 'Link 5 (Yunuşoğlu Plaj Çantası)',
        'url': 'https://www.n11.com/urun/yunusoglu-home-genis-hacimli-ham-bez-plaj-cantasi-ic-cepli-sik-tasarim-bordo-35-cm-x-45-cm-128529494?magaza=yunusogluhome',
        'expectedDiscounted': 275.91,
        'expectedOriginal': 299.90,
      },
      {
        'name': 'Link 6 (Karaca Barbekü Mangal Seti)',
        'url': 'https://www.n11.com/urun/onluklu-7-parca-ahsap-sapli-barbekumangal-seti-94403175?magaza=karaca',
        'expectedDiscounted': 819.98,
        'expectedOriginal': 919.98,
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
