import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/domain_allowlist_service.dart';
import 'package:sicak_firsatlar/services/link_preview_service.dart';

void main() {
  group('Amazon Short Link Resolution & Product Validation Tests', () {
    test('https://link.amazon/B0bBuCWNo should resolve to canonical Amazon product URL and pass validation', () async {
      const link = 'https://link.amazon/B0bBuCWNo';
      final linkPreviewService = LinkPreviewService();

      final resolved = await linkPreviewService.resolveUrlRedirects(link);
      expect(resolved.contains('amazon.com.tr/dp/'), isTrue,
          reason: 'link.amazon should resolve through amzlinks to canonical amazon.com.tr/dp/...');

      final validation = await DomainAllowlistService.validateUrl(link);
      expect(validation, equals(UrlValidationResult.valid),
          reason: 'link.amazon short link must be accepted as a valid product deal');
    });

    test('Direct amzlinks.in short link should also resolve and pass validation', () async {
      const link = 'https://amzlinks.in/B0bBuCWNo';
      final linkPreviewService = LinkPreviewService();

      final resolved = await linkPreviewService.resolveUrlRedirects(link);
      expect(resolved.contains('amazon.com.tr/dp/'), isTrue);

      final validation = await DomainAllowlistService.validateUrl(link);
      expect(validation, equals(UrlValidationResult.valid));
    });
  });
}
