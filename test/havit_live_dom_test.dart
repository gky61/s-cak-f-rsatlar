import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/havit_scraper.dart';

void main() {
  group('HavitScraper Live DOM Tests', () {
    final scraper = HavitScraper();

    test('should parse ratings and reviews from user real havit-dom.md file', () async {
      final file = File('cloud-run-bot/scratch/havit-dom.md');
      if (!file.existsSync()) {
        print('Skipping test, havit-dom.md not found');
        return;
      }

      final html = file.readAsStringSync();
      final doc = html_parser.parse(html);

      final ratingVal = await scraper.scrapeRatingValue(doc);
      print('Parsed ratingValue from havit-dom.md: $ratingVal');
      expect(ratingVal, equals(5.0));

      final ratingCnt = await scraper.scrapeRatingCount(doc);
      print('Parsed ratingCount from havit-dom.md: $ratingCnt');
      expect(ratingCnt, equals(328));

      final brand = scraper.scrapeBrand(doc);
      print('Parsed brand from havit-dom.md: $brand');
      expect(brand, equals('Havit'));
    });

    test('should fallback to YG Digital API for raw HTML without rendered DOM elements', () async {
      const rawHtml = '''
      <input type="hidden" name="ctl00\$mainHolder\$UrunDetay\$hddnUrunID" id="hddnUrunID" value="397" />
      <script>
        var productDetailModel = {"productId":375,"productName":"Havit GK60 PRO","stockCode":"6939119039868"};
      </script>
      ''';
      final doc = html_parser.parse(rawHtml);

      final ratingVal = await scraper.scrapeRatingValue(doc);
      print('Parsed ratingValue via YG Digital API: $ratingVal');
      expect(ratingVal, equals(4.75));

      final ratingCnt = await scraper.scrapeRatingCount(doc);
      print('Parsed ratingCount via YG Digital API: $ratingCnt');
      expect(ratingCnt, equals(328));
    });
  });
}
