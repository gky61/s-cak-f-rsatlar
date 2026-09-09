import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/domain_allowlist_service.dart';
import 'package:sicak_firsatlar/services/link_preview_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('İncehesap Paylaştıkça Kazan (/u/...) Unit & Integration Tests', () {
    const paylasKazanUrl = 'https://www.incehesap.com/u/TAIXbK33rm/';
    const canonicalOrganicUrl = 'https://www.incehesap.com/notorious-oem-paket-fiyati-62721/';

    test('Allowlist should accept Incehesap domain and shortlink', () {
      expect(DomainAllowlistService.isDomainAllowed(paylasKazanUrl), isTrue);
      expect(DomainAllowlistService.isDomainAllowed(canonicalOrganicUrl), isTrue);
      expect(DomainAllowlistService.getStoreNameForUrl(paylasKazanUrl), equals('incehesap'));
    });

    test('isProductUrl should accept both canonical -fiyati- and /u/ shortlinks when rules loaded', () async {
      // JSON dosyasındaki güncel kuralları simüle et
      final file = File('assets/data/domain_allowlist_extended.json');
      if (await file.exists()) {
        final jsonContent = await file.readAsString();
        final data = jsonDecode(jsonContent);
        final rules = (data['product_path_rules']['incehesap'] as List)
            .map((p) => RegExp(p.toString(), caseSensitive: false))
            .toList();

        final shortUri = Uri.parse(paylasKazanUrl);
        final canonicalUri = Uri.parse(canonicalOrganicUrl);
        final searchUri = Uri.parse('https://www.incehesap.com/arama/?q=ram');
        final categoryUri = Uri.parse('https://www.incehesap.com/kategori/gaming-kulaklik/');

        final shortMatches = rules.any((r) => r.hasMatch(shortUri.path));
        final canonicalMatches = rules.any((r) => r.hasMatch(canonicalUri.path));
        final searchMatches = rules.any((r) => r.hasMatch(searchUri.path));
        final categoryMatches = rules.any((r) => r.hasMatch(categoryUri.path));

        expect(shortMatches, isTrue, reason: '/u/TAIXbK33rm/ ürün sayfası olarak doğrulanmalı');
        expect(canonicalMatches, isTrue, reason: '-fiyati-62721/ ürün sayfası olarak doğrulanmalı');
        expect(searchMatches, isFalse, reason: 'Arama sayfası reddedilmeli');
        expect(categoryMatches, isFalse, reason: 'Kategori sayfası reddedilmeli');
      }
    });

    test('resolveUrlRedirects should follow 301 and resolve /u/ link to canonical URL', () async {
      final linkPreviewService = LinkPreviewService();
      final resolved = await linkPreviewService.resolveUrlRedirects(paylasKazanUrl);

      print('Resolved Incehesap URL: $resolved');
      expect(resolved, contains('incehesap.com'));
      expect(resolved, contains('-fiyati-62721/'));
    });

    test('validateUrl should validate Paylaştıkça Kazan URL end-to-end as valid', () async {
      final validationResult = await DomainAllowlistService.validateUrl(paylasKazanUrl);
      expect(validationResult, equals(UrlValidationResult.valid));
    });

    test('fetchMetadata should scrape product metadata directly from /u/ short link', () async {
      final linkPreviewService = LinkPreviewService();
      final result = await linkPreviewService.fetchMetadata(paylasKazanUrl);

      expect(result, isNotNull);
      print('Scraped Title:   ${result!.title}');
      print('Scraped Price:   ${result.price}');
      print('Scraped Image:   ${result.imageUrl}');
      print('Scraped Brand:   ${result.brand}');

      expect(result.title, isNotNull);
      expect(result.title!.toLowerCase(), contains('notorious'));
      expect(result.price, isNotNull);
      expect(result.price!, greaterThan(0));
      expect(result.imageUrl, isNotNull);
      expect(result.imageUrl!, startsWith('http'));
    });
  });
}
