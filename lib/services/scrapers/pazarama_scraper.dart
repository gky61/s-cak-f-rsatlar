import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class PazaramaScraper extends BaseProductScraper {
  @override
  String get domain => 'pazarama.com';

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. JSON-LD şemasından görsel çekmeyi dene (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['image'] != null) {
      final imgLd = extractImageFromProductJson(productJson['image']);
      if (imgLd != null && imgLd.isNotEmpty && !isLogoUrl(imgLd)) {
        final resolved = resolveImageUrl(imgLd, url);
        if (resolved != null) {
          log('✅ Pazarama JSON-LD görseli bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final pazaramaSelectors = [
      '.product-detail-slider img',
      '.product-image img',
      'picture img',
      'img[class*="object-contain"]',
      'img[src*="pzrmcdn.com"]',
      'img[src*="asset/"][src*="images/"]',
      'img[src*="product"]',
      'main img',
      '#product-image-gallery img',
    ];
    for (final selector in pazaramaSelectors) {
      final elements = document.querySelectorAll(selector);
      for (final element in elements) {
        final src = element.attributes['src'] ?? element.attributes['data-src'] ?? element.attributes['data-lazy-src'] ?? element.attributes['data-old-hires'];
        if (src != null && src.isNotEmpty && !src.startsWith('data:') && !isLogoUrl(src)) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null) {
            log('✅ Pazarama özel görseli bulundu: $resolved');
            return resolved;
          }
        }
      }
    }
    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. JSON-LD şemasından (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['name'] != null) {
      return productJson['name'].toString().trim();
    }

    // 2. DOM Seçicileri (Fallback)
    final titleEl = document.querySelector('h1.text-huge.text-gray-600.font-bold') ??
                    document.querySelector('h1.text-huge') ??
                    document.querySelector('h1') ??
                    document.querySelector('meta[property="og:title"]');
    if (titleEl != null) {
      if (titleEl.localName == 'meta') {
        return titleEl.attributes['content']?.trim();
      }
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. Pazarama Plus Fiyat Kontrolü (Plus'a özel indirimli fiyat önceliklidir)
    final plusImgs = document.querySelectorAll('img[alt="plus-icon"], img[src*="pz-plus-icon"]');
    for (final plusImg in plusImgs) {
      var parent = plusImg.parent;
      while (parent != null && parent.localName != 'div') {
        parent = parent.parent;
      }
      if (parent != null) {
        final spans = parent.querySelectorAll('span');
        for (final span in spans) {
          final text = span.text.trim();
          if (text.contains('TL') && !text.contains('ile')) {
            final parsedPrice = parsePriceText(text);
            if (parsedPrice != null && parsedPrice > 0) {
              return parsedPrice;
            }
          }
        }
      }
    }

    // 2. JSON-LD şemasından (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceVal = extractPriceFromProductJson(productJson);
      if (priceVal != null && priceVal > 0) {
        return priceVal;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final selectors = [
      'div[class*="text-4xl"][class*="text-black"][class*="font-bold"]',
      'div.text-4xl.text-black.font-bold',
      'div.text-4xl.text-black',
      'span[class*="text-lg"][class*="font-bold"][class*="text-red-600"]',
      'span.text-lg.font-bold.text-red-600',
      'meta[property="product:price:amount"]',
    ];
    
    for (final selector in selectors) {
      final priceEl = document.querySelector(selector);
      if (priceEl != null) {
        final text = priceEl.localName == 'meta' ? (priceEl.attributes['content'] ?? '') : priceEl.text;
        final val = parsePriceText(text);
        if (val != null && val > 0) return val;
      }
    }
    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    final metaDesc = document.querySelector('meta[name="description"]') ??
                     document.querySelector('meta[data-hid="description"]') ??
                     document.querySelector('meta[property="og:description"]');
    if (metaDesc != null) {
      final desc = metaDesc.attributes['content']?.trim();
      if (desc != null && desc.isNotEmpty && desc.toLowerCase() != 'null') {
        return desc;
      }
    }
    return null;
  }
}
