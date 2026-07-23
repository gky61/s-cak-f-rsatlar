import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class PttavmScraper extends BaseProductScraper {
  @override
  String get domain => 'pttavm.com';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('pttavm.com');
  }

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
      if (imgLd != null && imgLd.isNotEmpty) {
        final resolved = resolveImageUrl(imgLd, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Pttavm görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Pttavm görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final imgSelectors = [
      '.product-detail-images img',
      '.product-images img',
      'img[class*="product"]',
      '#product-image',
    ];
    for (final selector in imgSelectors) {
      final imgElements = document.querySelectorAll(selector);
      for (final img in imgElements) {
        final src = img.attributes['src'] ?? img.attributes['data-src'];
        if (src != null && src.isNotEmpty) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null && !isLogoUrl(resolved)) {
            log('✅ Pttavm görseli img etiketiyle bulundu ($selector): $resolved');
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
    final titleEl = document.querySelector('h1.product-title') ??
                    document.querySelector('.product-name') ??
                    document.querySelector('meta[property="og:title"]');
    if (titleEl != null) {
      if (titleEl is dom.Element && titleEl.localName == 'meta') {
        return titleEl.attributes['content']?.trim();
      }
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. JSON-LD şemasından fiyat çekmeyi dene (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) {
        return priceLd;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final priceSelectors = [
      '.product-price',
      '.price-box',
      '.discount-price',
      '.current-price',
    ];
    for (final selector in priceSelectors) {
      final priceEl = document.querySelector(selector);
      if (priceEl != null) {
        final val = parsePriceText(priceEl.text);
        if (val != null && val > 0) {
          return val;
        }
      }
    }

    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    // 1. JSON-LD şemasından (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['description'] != null) {
      final desc = productJson['description'].toString().trim();
      if (desc.isNotEmpty && desc.toLowerCase() != 'null') {
        return desc;
      }
    }

    // 2. Özel DOM tag (data-rh="true" name="description")
    final rhDescEl = document.querySelector('meta[data-rh="true"][name="description"]');
    if (rhDescEl != null) {
      final content = rhDescEl.attributes['content']?.trim();
      if (content != null && content.isNotEmpty && content.toLowerCase() != 'null') {
        return content;
      }
    }

    // 3. Genel og:description veya description meta tag
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

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    final productTitle = scrapeTitle(document) ?? '';

    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json') {
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
    final breadcrumbElements = document.querySelectorAll('.breadcrumbs a, .breadcrumb a, ul.breadcrumbs a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && !lower.contains('pttavm') && text != productTitle && text.length < 50) {
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
                if (lowerName != 'anasayfa' && !lowerName.contains('pttavm')) {
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
                return lower != 'anasayfa' && !lower.contains('pttavm') && e != productTitle && e.length < 50;
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
                  return lower != 'anasayfa' && !lower.contains('pttavm') && e != productTitle && e.length < 50;
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
    print('[aggregateRating] PttavmScraper: ratingValue aranıyor...');
    
    // 1. JSON-LD Şeması (@type: Product)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingValue'] != null) {
        final val = (rating!['ratingValue'] as num).toDouble();
        print('[aggregateRating] PttavmScraper: JSON-LD ile ratingValue bulundu: $val');
        return val;
      }
    }

    // 2. DOM Seçicileri / Microdata Fallback
    final ratingEl = document.querySelector('[itemprop="ratingValue"]') ??
                     document.querySelector('meta[property="product:rating:value"]') ??
                     document.querySelector('.rating-score') ??
                     document.querySelector('.pdp-rating-value');
    if (ratingEl != null) {
      final text = ratingEl.localName == 'meta'
          ? (ratingEl.attributes['content'] ?? '')
          : ratingEl.text;
      final parsed = double.tryParse(text.trim().replaceAll(',', '.'));
      if (parsed != null && parsed > 0 && parsed <= 5.0) {
        print('[aggregateRating] PttavmScraper: DOM fallback ile ratingValue bulundu: $parsed');
        return parsed;
      }
    }

    // 3. Script Regex Fallback
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final text = script.text + ' ' + script.innerHtml;
      if (text.contains('aggregateRating') || text.contains('ratingValue')) {
        final match = RegExp(r'ratingValue["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?').firstMatch(text);
        if (match != null) {
          final raw = match.group(1)?.replaceAll(',', '.');
          final parsed = raw != null ? double.tryParse(raw) : null;
          if (parsed != null && parsed > 0 && parsed <= 5.0) {
            print('[aggregateRating] PttavmScraper: Regex fallback ile ratingValue bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] PttavmScraper: ratingValue bulunamadı (null)');
    return null;
  }

  @override
  int? scrapeRatingCount(dom.Document document) {
    print('[aggregateRating] PttavmScraper: ratingCount/reviewCount aranıyor...');
    
    // 1. JSON-LD Şeması (@type: Product)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingCount'] != null) {
        final cnt = (rating!['ratingCount'] as num).toInt();
        print('[aggregateRating] PttavmScraper: JSON-LD ile ratingCount/reviewCount bulundu: $cnt');
        return cnt;
      }
    }

    // 2. DOM Seçicileri / Microdata Fallback
    final countEl = document.querySelector('[itemprop="reviewCount"]') ??
                    document.querySelector('[itemprop="ratingCount"]') ??
                    document.querySelector('.review-count') ??
                    document.querySelector('.rating-count');
    if (countEl != null) {
      final text = countEl.localName == 'meta'
          ? (countEl.attributes['content'] ?? '')
          : countEl.text;
      final match = RegExp(r'(\d+)').firstMatch(text);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed > 0) {
          print('[aggregateRating] PttavmScraper: DOM fallback ile ratingCount bulundu: $parsed');
          return parsed;
        }
      }
    }

    // 3. Script Regex Fallback
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final text = script.text + ' ' + script.innerHtml;
      if (text.contains('aggregateRating') || text.contains('reviewCount') || text.contains('ratingCount')) {
        final match = RegExp(r'(?:reviewCount|ratingCount)["\\]*\s*:\s*"?(\d+)"?').firstMatch(text);
        if (match != null) {
          final parsed = int.tryParse(match.group(1) ?? '');
          if (parsed != null && parsed > 0) {
            print('[aggregateRating] PttavmScraper: Regex fallback ile ratingCount bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] PttavmScraper: ratingCount bulunamadı (null)');
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    print('[aggregateRating] PttavmScraper: brand (marka) aranıyor...');
    
    // 1. JSON-LD: additionalProperty "External Source" (Öncelikli - PttAVM'de brand alanı satıcıyı içerir)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final additionalProps = productJson['additionalProperty'];
      if (additionalProps is List && additionalProps.isNotEmpty) {
        // İlk eleman "External Source" → gerçek marka
        final firstProp = additionalProps[0];
        if (firstProp is Map && firstProp['name'] == 'External Source') {
          final val = firstProp['value']?.toString().trim();
          if (val != null && val.isNotEmpty) {
            print('[aggregateRating] PttavmScraper: JSON-LD additionalProperty ile brand bulundu: $val');
            return val;
          }
        }
      }

      // 2. JSON-LD: brand alanı (Fallback - satıcı adı olabilir)
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) {
        print('[aggregateRating] PttavmScraper: JSON-LD brand ile bulundu: $brand');
        return brand;
      }
    }

    // 3. DOM Seçicileri / Meta Tag
    final brandMeta = document.querySelector('meta[property="product:brand"]') ??
                      document.querySelector('meta[name="brand"]') ??
                      document.querySelector('.product-brand') ??
                      document.querySelector('[data-brand]');
    if (brandMeta != null) {
      final text = brandMeta.localName == 'meta'
          ? (brandMeta.attributes['content'] ?? '')
          : (brandMeta.attributes['data-brand'] ?? brandMeta.text);
      final clean = text.trim();
      if (clean.isNotEmpty) {
        print('[aggregateRating] PttavmScraper: DOM fallback ile brand bulundu: $clean');
        return clean;
      }
    }

    // 4. Script Regex Fallback
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final text = script.text + ' ' + script.innerHtml;
      if (text.contains('"brand"') || text.contains('"Brand"')) {
        final match = RegExp(r'"brand"\s*:\s*\{\s*"@type"\s*:\s*"(?:Organization|Brand)"\s*,\s*"name"\s*:\s*"([^"]+)"').firstMatch(text) ??
                      RegExp(r'"brand"\s*:\s*"([^"]+)"').firstMatch(text);
        if (match != null) {
          final bName = match.group(1)?.trim();
          if (bName != null && bName.isNotEmpty && !bName.contains('{')) {
            print('[aggregateRating] PttavmScraper: Regex fallback ile brand bulundu: $bName');
            return bName;
          }
        }
      }
    }

    print('[aggregateRating] PttavmScraper: brand bulunamadı (null)');
    return null;
  }
}
