import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class MediaMarktScraper extends BaseProductScraper {
  @override
  String get domain => 'mediamarkt.com.tr';

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
          log('✅ MediaMarkt JSON-LD görseli bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph görseli (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
                    document.querySelector('meta[name="og:image"]')?.attributes['content'];
                    
    if (ogImage != null && ogImage.isNotEmpty && !isLogoUrl(ogImage)) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null) {
        log('✅ MediaMarkt özel og:image görseli bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final mediaMarktSelectors = [
      'img[data-testid="product-image"]',
      '#product-image img',
      'img.product-image',
      '.product-details img',
    ];
    for (final selector in mediaMarktSelectors) {
      final elements = document.querySelectorAll(selector);
      for (final element in elements) {
        final src = element.attributes['src'] ?? element.attributes['data-src'] ?? element.attributes['data-lazy-src'];
        if (src != null && src.isNotEmpty && !src.startsWith('data:') && !isLogoUrl(src)) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null) {
            log('✅ MediaMarkt özel görseli bulundu: $resolved');
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
    final titleEl = document.querySelector('h1[class*="mms-ui-"]') ??
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
    // 1. JSON-LD şemasından (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceVal = extractPriceFromProductJson(productJson);
      if (priceVal != null && priceVal > 0) {
        return priceVal;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final priceEl = document.querySelector('[data-test="branded-price-whole-value"]') ??
                    document.querySelector('meta[property="product:price:amount"]') ??
                    document.querySelector('meta[property="og:price:amount"]');
                    
    if (priceEl != null) {
      if (priceEl.localName == 'meta') {
        return parsePriceText(priceEl.attributes['content'] ?? '');
      }
      return parsePriceText(priceEl.text);
    }
    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    final productTitle = scrapeTitle(document) ?? '';

    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json' || script.attributes['data-rh'] == 'true') {
        try {
          final sanitizedText = script.text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
          final data = jsonDecode(sanitizedText);
          final breadcrumbs = _extractBreadcrumbsFromJson(data, productTitle);
          if (breadcrumbs.isNotEmpty) {
            return breadcrumbs;
          }
        } catch (_) {}
      }
    }

    // DOM Fallback
    final breadcrumbElements = document.querySelectorAll('.breadcrumb-list a, .breadcrumbs a, .breadcrumb a, .mms-breadcrumb a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'home' && !lower.contains('mediamarkt') && text != productTitle && text.length < 50) {
            list.add(text);
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    return [];
  }

  List<String> _extractBreadcrumbsFromJson(dynamic json, String productTitle) {
    if (json is Map) {
      // 1. BreadcrumbList kontrolü
      if (json['@type'] == 'BreadcrumbList' || json['@type'] == 'http://schema.org/BreadcrumbList') {
        final items = json['itemListElement'];
        if (items is List) {
          final List<String> breadcrumbs = [];
          for (final item in items) {
            if (item is Map) {
              String? name;
              if (item['name'] != null) {
                name = item['name'].toString().trim();
              } else if (item['item'] is Map && item['item']['name'] != null) {
                name = item['item']['name'].toString().trim();
              }

              if (name != null && name.isNotEmpty) {
                final lowerName = name.toLowerCase();
                if (lowerName != 'anasayfa' && lowerName != 'home' && !lowerName.contains('mediamarkt')) {
                  if (name != productTitle && name.length < 50) {
                    breadcrumbs.add(name);
                  }
                }
              }
            }
          }
          if (breadcrumbs.isNotEmpty) return breadcrumbs;
        }
      }

      // 2. Product category kontrolü
      if (json['@type'] == 'Product' || json['@type'] == 'http://schema.org/Product' ||
          json['@type'] == 'ProductGroup' || json['@type'] == 'http://schema.org/ProductGroup') {
        final categoryField = json['category'];
        if (categoryField is String && categoryField.isNotEmpty) {
          final parts = categoryField
              .split(RegExp(r'\s*>\s*|\s*/\s*'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .where((e) {
                final lower = e.toLowerCase();
                return lower != 'anasayfa' && lower != 'home' && !lower.contains('mediamarkt') && e != productTitle && e.length < 50;
              })
              .toList();
          if (parts.isNotEmpty) return parts;
        } else if (categoryField is Map) {
          final nameVal = categoryField['name'];
          if (nameVal is String && nameVal.isNotEmpty) {
            final parts = nameVal
                .split(RegExp(r'\s*>\s*|\s*/\s*'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .where((e) {
                  final lower = e.toLowerCase();
                  return lower != 'anasayfa' && lower != 'home' && !lower.contains('mediamarkt') && e != productTitle && e.length < 50;
                })
                .toList();
            if (parts.isNotEmpty) return parts;
          }
        }
      }

      // Recursive arama
      for (final value in json.values) {
        if (value is Map || value is List) {
          final res = _extractBreadcrumbsFromJson(value, productTitle);
          if (res.isNotEmpty) return res;
        }
      }
    } else if (json is List) {
      for (final item in json) {
        final res = _extractBreadcrumbsFromJson(item, productTitle);
        if (res.isNotEmpty) return res;
      }
    }
    return [];
  }

  @override
  double? scrapeRatingValue(dom.Document document) {
    print('[aggregateRating] MediaMarktScraper: ratingValue aranıyor...');
    
    // 1. JSON-LD Şeması (@type: Product)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingValue'] != null) {
        final val = (rating!['ratingValue'] as num).toDouble();
        print('[aggregateRating] MediaMarktScraper: JSON-LD ile ratingValue bulundu: $val');
        return val;
      }
    }

    // 2. DOM / Microdata Fallback (data-test="mms-pdp-average-rating-summary")
    final ratingEl = document.querySelector('[data-test="mms-pdp-average-rating-summary"]') ??
                     document.querySelector('[class*="mms-pdp-average-rating"]');
    if (ratingEl != null) {
      final ariaLabel = ratingEl.attributes['aria-label'] ?? ratingEl.text;
      final match = RegExp(r'göre\s+([\d.,]+)').firstMatch(ariaLabel) ??
                    RegExp(r'([\d.,]+)\s*şeklindedir').firstMatch(ariaLabel) ??
                    RegExp(r'([\d.,]+)').firstMatch(ariaLabel);
      if (match != null) {
        final raw = match.group(1)?.replaceAll(',', '.');
        final parsed = raw != null ? double.tryParse(raw) : null;
        if (parsed != null && parsed > 0 && parsed <= 5.0) {
          print('[aggregateRating] MediaMarktScraper: DOM fallback (aria-label) ile ratingValue bulundu: $parsed');
          return parsed;
        }
      }
    }

    // 3. Script / Hydration Data / Document Regex Arama ("averageOverallRating", "ratingValue", "averageRating")
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final text = script.text + ' ' + script.innerHtml;
      if (text.contains('averageOverallRating') || text.contains('ratingValue') || text.contains('averageRating')) {
        final match = RegExp(r'averageOverallRating["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?').firstMatch(text) ??
                      RegExp(r'ratingValue["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?').firstMatch(text) ??
                      RegExp(r'averageRating["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?').firstMatch(text);
        if (match != null) {
          final raw = match.group(1)?.replaceAll(',', '.');
          final parsed = raw != null ? double.tryParse(raw) : null;
          if (parsed != null && parsed > 0 && parsed <= 5.0) {
            final rounded = (parsed * 10).round() / 10.0;
            print('[aggregateRating] MediaMarktScraper: Hydration Script/Regex ile ratingValue bulundu: $rounded');
            return rounded;
          }
        }
      }
    }

    // 4. Fallback: Full Document HTML Search
    final fullHtml = document.outerHtml;
    final match = RegExp(r'averageOverallRating["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?').firstMatch(fullHtml) ??
                  RegExp(r'ratingValue["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?').firstMatch(fullHtml) ??
                  RegExp(r'averageRating["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?').firstMatch(fullHtml);
    if (match != null) {
      final raw = match.group(1)?.replaceAll(',', '.');
      final parsed = raw != null ? double.tryParse(raw) : null;
      if (parsed != null && parsed > 0 && parsed <= 5.0) {
        final rounded = (parsed * 10).round() / 10.0;
        print('[aggregateRating] MediaMarktScraper: Full HTML Regex ile ratingValue bulundu: $rounded');
        return rounded;
      }
    }

    print('[aggregateRating] MediaMarktScraper: ratingValue bulunamadı (null)');
    return null;
  }

  @override
  int? scrapeRatingCount(dom.Document document) {
    print('[aggregateRating] MediaMarktScraper: ratingCount/reviewCount aranıyor...');
    
    // 1. JSON-LD Şeması (@type: Product)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingCount'] != null) {
        final cnt = (rating!['ratingCount'] as num).toInt();
        print('[aggregateRating] MediaMarktScraper: JSON-LD ile ratingCount/reviewCount bulundu: $cnt');
        return cnt;
      }
    }

    // 2. DOM / Microdata Fallback (data-test="mms-pdp-average-rating-summary")
    final ratingEl = document.querySelector('[data-test="mms-pdp-average-rating-summary"]') ??
                     document.querySelector('[class*="mms-pdp-average-rating"]');
    if (ratingEl != null) {
      final ariaLabel = ratingEl.attributes['aria-label'] ?? ratingEl.text;
      final match = RegExp(r'(\d+)\s+(?:inceleme|yorum|oy|değerlendirme)').firstMatch(ariaLabel);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed > 0) {
          print('[aggregateRating] MediaMarktScraper: DOM fallback (aria-label) ile ratingCount bulundu: $parsed');
          return parsed;
        }
      }
    }

    // 3. Script / Hydration Data Regex Arama ("totalReviewCount", "reviewCount", "ratingCount")
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final text = script.text + ' ' + script.innerHtml;
      if (text.contains('totalReviewCount') || text.contains('reviewCount') || text.contains('ratingCount')) {
        final match = RegExp(r'totalReviewCount["\\]*\s*:\s*"?(\d+)"?').firstMatch(text) ??
                      RegExp(r'(?:reviewCount|ratingCount)["\\]*\s*:\s*"?(\d+)"?').firstMatch(text);
        if (match != null) {
          final parsed = int.tryParse(match.group(1) ?? '');
          if (parsed != null && parsed > 0) {
            print('[aggregateRating] MediaMarktScraper: Hydration Script/Regex ile ratingCount bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    // 4. Fallback: Full Document HTML Search
    final fullHtml = document.outerHtml;
    final cntMatch = RegExp(r'totalReviewCount["\\]*\s*:\s*"?(\d+)"?').firstMatch(fullHtml) ??
                     RegExp(r'(?:reviewCount|ratingCount)["\\]*\s*:\s*"?(\d+)"?').firstMatch(fullHtml);
    if (cntMatch != null) {
      final parsed = int.tryParse(cntMatch.group(1) ?? '');
      if (parsed != null && parsed > 0) {
        print('[aggregateRating] MediaMarktScraper: Full HTML Regex ile ratingCount bulundu: $parsed');
        return parsed;
      }
    }

    print('[aggregateRating] MediaMarktScraper: ratingCount bulunamadı (null)');
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    print('[aggregateRating] MediaMarktScraper: brand (marka) aranıyor...');
    
    // 1. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) {
        print('[aggregateRating] MediaMarktScraper: JSON-LD ile brand bulundu: $brand');
        return brand;
      }
    }

    // 2. DOM Seçicileri / Meta Tag
    final brandMeta = document.querySelector('meta[property="product:brand"]') ??
                      document.querySelector('meta[name="brand"]') ??
                      document.querySelector('[data-test="mms-pdp-brand-name"]') ??
                      document.querySelector('[class*="brand"]');
    if (brandMeta != null) {
      final text = brandMeta.localName == 'meta'
          ? (brandMeta.attributes['content'] ?? '')
          : brandMeta.text;
      final clean = text.trim();
      if (clean.isNotEmpty) {
        print('[aggregateRating] MediaMarktScraper: DOM fallback ile brand bulundu: $clean');
        return clean;
      }
    }

    // 3. Raw Script Regex Arama
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('"brand"') || text.contains('"Brand"')) {
        final match = RegExp(r'"brand"\s*:\s*\{\s*"@type"\s*:\s*"(?:Organization|Brand)"\s*,\s*"name"\s*:\s*"([^"]+)"').firstMatch(text) ??
                      RegExp(r'"brand"\s*:\s*"([^"]+)"').firstMatch(text);
        if (match != null) {
          final bName = match.group(1)?.trim();
          if (bName != null && bName.isNotEmpty && !bName.contains('{')) {
            print('[aggregateRating] MediaMarktScraper: Regex fallback ile brand bulundu: $bName');
            return bName;
          }
        }
      }
    }

    print('[aggregateRating] MediaMarktScraper: brand bulunamadı (null)');
    return null;
  }
}
