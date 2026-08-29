import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:sicak_firsatlar/services/scrapers/hepsiburada_scraper.dart';

void main() {
  group('Hepsiburada Live URL Premium Detection Tests (7 User Cases)', () {
    final scraper = HepsiburadaScraper();

    Future<String> resolveHbBiz(String url) async {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url))..followRedirects = false;
        final response = await client.send(request);
        final location = response.headers['location'];
        if (location != null) {
          final uri = Uri.parse(location);
          final fallback = uri.queryParameters['adjust_fallback'] ?? uri.queryParameters['adj_fallback'];
          if (fallback != null) {
            return Uri.decodeComponent(fallback);
          }
          return location;
        }
      } catch (e) {
        // Fallback
      } finally {
        client.close();
      }
      return url;
    }

    test('Case 1: Le Petit Marseillais Duş Jeli (False Positive Prevention -> null)', () async {
      final shortUrl = 'https://app.hb.biz/IJkBneLO0EMd';
      final resolvedUrl = await resolveHbBiz(shortUrl);
      final res = await http.get(
        Uri.parse(resolvedUrl),
        headers: {'User-Agent': 'WhatsApp/2.23.4.15 A', 'Accept': 'text/html'},
      );
      final doc = html_parser.parse(res.body);

      final price = await scraper.scrapePrice(doc);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(price, isNotNull);
      expect(priceLabel, isNull);
    });

    test('Case 2: Isana Men Duş Jeli (False Negative Prevention -> Premium ile)', () async {
      final shortUrl = 'https://app.hb.biz/557ruKNKje27';
      final resolvedUrl = await resolveHbBiz(shortUrl);
      final res = await http.get(
        Uri.parse(resolvedUrl),
        headers: {'User-Agent': 'WhatsApp/2.23.4.15 A', 'Accept': 'text/html'},
      );
      final doc = html_parser.parse(res.body);

      final price = await scraper.scrapePrice(doc);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(price, equals(71.1));
      expect(priceLabel, equals('Premium ile'));
    });

    test('Case 3: Tudors Polo T-Shirt (False Positive Prevention -> null)', () async {
      final shortUrl = 'https://app.hb.biz/FLn8axWk18kf';
      final resolvedUrl = await resolveHbBiz(shortUrl);
      final res = await http.get(
        Uri.parse(resolvedUrl),
        headers: {'User-Agent': 'WhatsApp/2.23.4.15 A', 'Accept': 'text/html'},
      );
      final doc = html_parser.parse(res.body);

      final price = await scraper.scrapePrice(doc);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(price, equals(399.98));
      expect(priceLabel, isNull);
    });

    test('Case 4: L\'Oréal Men Expert Duş Jeli (False Positive Prevention -> null)', () async {
      final shortUrl = 'https://app.hb.biz/82purTtw8lCz';
      final resolvedUrl = await resolveHbBiz(shortUrl);
      final res = await http.get(
        Uri.parse(resolvedUrl),
        headers: {'User-Agent': 'WhatsApp/2.23.4.15 A', 'Accept': 'text/html'},
      );
      final doc = html_parser.parse(res.body);

      final price = await scraper.scrapePrice(doc);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(price, isNotNull);
      expect(priceLabel, isNull);
    });

    test('Case 5: L\'Oréal Barber Club Duş Jeli (False Positive Prevention -> null)', () async {
      final shortUrl = 'https://app.hb.biz/1NtpRgwjkbVb';
      final resolvedUrl = await resolveHbBiz(shortUrl);
      final res = await http.get(
        Uri.parse(resolvedUrl),
        headers: {'User-Agent': 'WhatsApp/2.23.4.15 A', 'Accept': 'text/html'},
      );
      final doc = html_parser.parse(res.body);

      final price = await scraper.scrapePrice(doc);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(price, isNotNull);
      expect(priceLabel, isNull);
    });

    test('Case 6: Mirissa Lab Kepek Şampuanı (False Negative Prevention -> Premium ile)', () async {
      final shortUrl = 'https://app.hb.biz/fmLh1PwftM9s';
      final resolvedUrl = await resolveHbBiz(shortUrl);
      final res = await http.get(
        Uri.parse(resolvedUrl),
        headers: {'User-Agent': 'WhatsApp/2.23.4.15 A', 'Accept': 'text/html'},
      );
      final doc = html_parser.parse(res.body);

      final price = await scraper.scrapePrice(doc);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(price, equals(494.99));
      expect(priceLabel, equals('Premium ile'));
    });

    test('Case 7: Baren Coss Biberiye Şampuanı (False Negative Prevention -> Premium ile)', () async {
      final shortUrl = 'https://app.hb.biz/MTfmiMR9EWpo';
      final resolvedUrl = await resolveHbBiz(shortUrl);
      final res = await http.get(
        Uri.parse(resolvedUrl),
        headers: {'User-Agent': 'WhatsApp/2.23.4.15 A', 'Accept': 'text/html'},
      );
      final doc = html_parser.parse(res.body);

      final price = await scraper.scrapePrice(doc);
      final priceLabel = await scraper.scrapePriceLabel(doc);

      expect(price, equals(406.08));
      expect(priceLabel, equals('Premium ile'));
    });
  });
}
