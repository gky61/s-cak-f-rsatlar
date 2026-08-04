import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/domain_allowlist_service.dart';

void main() {
  group('DomainAllowlistService Unit Tests', () {
    final validUrls = [
      'https://www.trendyol.com/brand/product-p-12345',
      'https://m.trendyol.com/item-p-999',
      'https://www.hepsiburada.com/product-p-HBV000',
      'https://www.amazon.com.tr/dp/B08N5WRWNW',
      'https://www.n11.com/urun/sample-123',
      'https://www.pazarama.com/product/123',
      'https://www.idefix.com/p-123',
      'https://www.pttavm.com/item-123',
      'https://www.teknosa.com/item-123',
      'https://www.mediamarkt.com.tr/item',
      'https://www.vatanbilgisayar.com/item',
      'https://www.itopya.com/item',
      'https://www.incehesap.com/item',
      'https://www.mavi.com/item',
      'https://www.defacto.com.tr/item',
      'https://www.zara.com/tr/item',
      'https://www.mango.com/tr/item',
      'https://www.beymen.com/item',
      'https://www.migros.com.tr/item',
      'https://getir.com/item',
      'https://www.havitstore.com.tr/item'
    ];

    test('All 20 valid store URLs should be allowed', () {
      for (final url in validUrls) {
        expect(DomainAllowlistService.isDomainAllowed(url), isTrue, reason: 'Failed for $url');
      }
    });

    final invalidUrls = [
      'https://fake-trendyol.com/item',
      'https://trendyol.com.phishing.org/item',
      'https://google.com/search?q=trendyol',
      'https://facebook.com/posts/123',
      'https://malicious-site.net/phish',
      'https://hepsiburada.fake.site',
      'https://amazon.com/dp/B000000000',
    ];

    test('Phishing and unallowed domain URLs should be rejected', () {
      for (final url in invalidUrls) {
        expect(DomainAllowlistService.isDomainAllowed(url), isFalse, reason: 'Should reject $url');
      }
    });
  });

  group('isProductUrl Tests (Fallback - product_path_rules yüklenmemiş)', () {
    // Test ortamında JSON yüklenmediğinden _productPathRules null kalır → tüm URL'ler BYPASS
    // Bu test, fallback davranışının doğru çalıştığını doğrular

    test('product_path_rules yüklenmemişse tüm allowlist URL\'leri bypass olmalı', () {
      // Fallback stores'ta olan domainler BYPASS olmalı (kural yüklenmemiş)
      expect(DomainAllowlistService.isProductUrl('https://www.trendyol.com/kampanya/xyz'), isTrue,
          reason: 'Kural yüklenmemiş → bypass');
      expect(DomainAllowlistService.isProductUrl('https://www.hepsiburada.com/magaza/xyz'), isTrue,
          reason: 'Kural yüklenmemiş → bypass');
      expect(DomainAllowlistService.isProductUrl('https://www.n11.com/arama?q=test'), isTrue,
          reason: 'Kural yüklenmemiş → bypass');
    });

    test('Allowlist dışı domain\'ler false dönmeli', () {
      expect(DomainAllowlistService.isProductUrl('https://www.google.com/search?q=trendyol'), isFalse);
      expect(DomainAllowlistService.isProductUrl('https://www.facebook.com/posts/123'), isFalse);
    });

    test('Edge cases', () {
      expect(DomainAllowlistService.isProductUrl(''), isFalse, reason: 'Boş string');
      expect(DomainAllowlistService.isProductUrl('   '), isFalse, reason: 'Sadece boşluk');
      expect(DomainAllowlistService.isProductUrl('not-a-url'), isFalse, reason: 'Geçersiz URL');
    });
  });
}
