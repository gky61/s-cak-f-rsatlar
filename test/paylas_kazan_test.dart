// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/domain_allowlist_service.dart';
import 'package:sicak_firsatlar/services/link_preview_service.dart';

void main() {
  HttpOverrides.global = null;

  group('Teknosa Paylaş Kazan Tests', () {
    const paylasKazanUrl = 'https://paylaskazan.teknosa.com/teknosa-F8NSB38NC3';

    test('validateUrl should validate Paylaş Kazan URL end-to-end via shortlink resolution', () async {
      final validationResult = await DomainAllowlistService.validateUrl(paylasKazanUrl);
      expect(validationResult, equals(UrlValidationResult.valid));
    });

    test('Allowlist and Domain validation tests for resolved canonical URL', () async {
      final linkService = LinkPreviewService();
      final resolved = await linkService.resolveUrlRedirects(paylasKazanUrl);

      expect(DomainAllowlistService.isDomainAllowed(resolved), isTrue);
      expect(DomainAllowlistService.isProductUrl(resolved), isTrue);
      expect(DomainAllowlistService.getStoreNameForUrl(resolved), equals('teknosa'));
    });

    test('resolveTeknosaPaylasKazan should extract canonical product URL with shopId', () async {
      final linkService = LinkPreviewService();
      final resolved = await linkService.resolveTeknosaPaylasKazan(paylasKazanUrl);

      print('Resolved Paylaş Kazan URL: $resolved');
      expect(resolved, contains('teknosa.com'));
      expect(resolved, contains('-p-790182989'));
      expect(resolved, contains('shopId=2442'));
    });

    test('resolveUrlRedirects should route and resolve Paylaş Kazan link', () async {
      final linkService = LinkPreviewService();
      final resolved = await linkService.resolveUrlRedirects(paylasKazanUrl);

      print('Resolved through resolveUrlRedirects: $resolved');
      expect(resolved, contains('teknosa.com'));
      expect(resolved, contains('-p-790182989'));
      expect(resolved, contains('shopId=2442'));
    });

    test('validateUrl should validate Paylaş Kazan URL end-to-end', () async {
      final validationResult = await DomainAllowlistService.validateUrl(paylasKazanUrl);
      expect(validationResult, equals(UrlValidationResult.valid));
    });

    test('fetchMetadata should scrape product details from Paylaş Kazan link', () async {
      final linkService = LinkPreviewService();
      final result = await linkService.fetchMetadata(paylasKazanUrl);

      expect(result, isNotNull);
      print('Scraped Title:         ${result!.title}');
      print('Scraped Price:         ${result.price}');
      print('Scraped OriginalPrice: ${result.originalPrice}');
      print('Scraped Image:         ${result.imageUrl}');
      print('Scraped Brand:         ${result.brand}');

      expect(result.title, contains('iPhone XR'));
      if (result.price != null) {
        expect(result.price, isPositive);
      }
      expect(result.brand, equals('Apple'));
    });
  });
}
