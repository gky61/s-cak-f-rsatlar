import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class MangoScraper extends BaseProductScraper {
  @override
  String get domain => 'mango.com';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('mango.com');
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. og:image meta tag (En güvenli ve net)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
                    document.querySelector('meta[name="twitter:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Mango görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final imgSelectors = [
      '.product-image img',
      'img[class*="product"]',
      'main img',
    ];
    for (final selector in imgSelectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final src = element.attributes['src'] ?? element.attributes['data-src'];
        if (src != null && src.isNotEmpty && !isLogoUrl(src)) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null) {
            log('✅ Mango görseli DOM ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. og:title meta tag (Next.js server-side render eder)
    final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'] ??
                    document.querySelector('title')?.text;
    if (ogTitle != null && ogTitle.isNotEmpty && ogTitle.toLowerCase() != 'null') {
      return ogTitle.trim();
    }

    // 2. DOM h1
    final titleEl = document.querySelector('h1') ?? 
                    document.querySelector('.product-name');
    if (titleEl != null) {
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. Next.js __next_f script push verisi içerisinden (Öncelikli)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('price') || text.contains('amount')) {
        // Hem kaçış karakterli (escaped) hem de kaçış karaktersiz (unescaped) tırnakları destekler.
        final match = RegExp(r'\\?"price\\?"\s*:\s*\{\s*\\?"amount\\?"\s*:\s*\\?"?([0-9.]+)\\?"?').firstMatch(text) ??
                      RegExp(r'\\?"price\\?"\s*:\s*\\?"?([0-9.]+)\\?"?').firstMatch(text);
        if (match != null) {
          final val = double.tryParse(match.group(1)!);
          if (val != null && val > 0) return val;
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final priceSelectors = [
      '[data-testid="pdp.productInfo.price"]',
      '.pdp-price',
      '.product-price',
      'span[class*="price"]',
    ];
    for (final selector in priceSelectors) {
      final priceEl = document.querySelector(selector);
      if (priceEl != null) {
        final parsed = parsePriceText(priceEl.text);
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    // 1. og:description veya description meta tag
    final descEl = document.querySelector('meta[name="description"]') ?? 
                   document.querySelector('meta[property="og:description"]');
    if (descEl != null) {
      final content = descEl.attributes['content']?.trim();
      if (content != null && content.isNotEmpty && content.toLowerCase() != 'null') {
        return content;
      }
    }
    return null;
  }
}
