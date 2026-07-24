import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class TeknosaScraper extends BaseProductScraper {
  @override
  String get domain => 'teknosa.com';

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
          log('✅ Teknosa görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Teknosa görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final imgElements = document.querySelectorAll('.product-images img, #product-detail-gallery img, img[class*="product"]');
    for (final img in imgElements) {
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src != null && src.isNotEmpty) {
        final resolved = resolveImageUrl(src, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Teknosa görseli img etiketiyle bulundu: $resolved');
          return resolved;
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
    final titleEl = document.querySelector('span.replaceName') ??
                    document.querySelector('h1.product-title') ??
                    document.querySelector('h1');
    if (titleEl != null) {
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. DOM Seçicileri - Öncelikli: span.prc-third
    final priceThirdEl = document.querySelector('.pdp-prices span.prc-third') ??
                         document.querySelector('span.prc-third');
    if (priceThirdEl != null) {
      final val = parsePriceText(priceThirdEl.text);
      if (val != null && val > 0) {
        return val;
      }
    }

    final priceLastEl = document.querySelector('.pdp-prices span.prc-last') ??
                        document.querySelector('span.prc-last');
    if (priceLastEl != null) {
      final val = parsePriceText(priceLastEl.text);
      if (val != null && val > 0) {
        return val;
      }
    }

    // 2. JSON-LD şemasından fiyat çekmeyi dene
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) {
        return priceLd;
      }
    }

    // 3. Diğer DOM Seçicileri
    final priceEl = document.querySelector('span.prc') ??
                    document.querySelector('.price') ??
                    document.querySelector('.product-price');
    if (priceEl != null) {
      final val = parsePriceText(priceEl.text);
      if (val != null && val > 0) {
        return val;
      }
    }

    return null;
  }

  @override
  double? scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice == null || currentPrice <= 0) return null;

    final candidates = <double>[];

    final selectors = [
      '.pdp-prices .pdp-prc1 span.prc',
      '.pdp-prices span.prc-first',
      '.pdp-prices span.generalPrice',
      'span.prc-first',
      'span.generalPrice',
      'span.prc.generalPrice',
      '.pdp-prc1 span',
      '.line-through',
      'del',
      's',
    ];

    for (final selector in selectors) {
      for (final el in document.querySelectorAll(selector)) {
        final txt = el.text.trim();
        if (txt.contains('TL') || txt.contains('₺')) {
          final parsed = parsePriceText(txt);
          if (parsed != null && parsed > currentPrice) {
            candidates.add(parsed);
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    final valid = candidates.where((c) => c > currentPrice && c <= currentPrice * 5).toList();
    if (valid.isEmpty) return null;

    valid.sort((a, b) => b.compareTo(a));
    return valid.first;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    // 1. JSON-LD şemasından açıklama çekmeyi dene (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['description'] != null) {
      return productJson['description'].toString().trim();
    }

    // 2. DOM Seçicileri (Fallback)
    final descEl = document.querySelector('meta[name="description"]') ??
                   document.querySelector('meta[property="og:description"]');
    if (descEl != null) {
      return descEl.attributes['content']?.trim();
    }
    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    final productTitle = scrapeTitle(document) ?? '';

    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json' || script.attributes['id'] == 'schemaJSON') {
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
    final breadcrumbElements = document.querySelectorAll('.breadcrumb a, .breadcrumbs a, .breadcrumb-list a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && !lower.contains('teknosa') && text != productTitle && text.length < 50) {
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
                if (lowerName != 'anasayfa' && !lowerName.contains('teknosa')) {
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
                return lower != 'anasayfa' && !lower.contains('teknosa') && e != productTitle && e.length < 50;
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
                  return lower != 'anasayfa' && !lower.contains('teknosa') && e != productTitle && e.length < 50;
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
    print('[aggregateRating] TeknosaScraper: ratingValue aranıyor...');
    
    // 1. JSON-LD Şeması (@type: Product)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingValue'] != null) {
        final val = (rating!['ratingValue'] as num).toDouble();
        print('[aggregateRating] TeknosaScraper: JSON-LD ile ratingValue bulundu: $val');
        return val;
      }
    }

    // 2. DOM Seçicileri / Microdata Fallback
    final ratingEl = document.querySelector('[itemprop="ratingValue"]') ??
                     document.querySelector('meta[property="product:rating:value"]') ??
                     document.querySelector('.pdp-rating-value') ??
                     document.querySelector('.rating-score');
    if (ratingEl != null) {
      final text = ratingEl.localName == 'meta'
          ? (ratingEl.attributes['content'] ?? '')
          : ratingEl.text;
      final parsed = double.tryParse(text.trim().replaceAll(',', '.'));
      if (parsed != null && parsed > 0 && parsed <= 5.0) {
        print('[aggregateRating] TeknosaScraper: DOM fallback ile ratingValue bulundu: $parsed');
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
            print('[aggregateRating] TeknosaScraper: Regex fallback ile ratingValue bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] TeknosaScraper: ratingValue bulunamadı (null)');
    return null;
  }

  @override
  int? scrapeRatingCount(dom.Document document) {
    print('[aggregateRating] TeknosaScraper: ratingCount/reviewCount aranıyor...');
    
    // 1. JSON-LD Şeması (@type: Product)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingCount'] != null) {
        final cnt = (rating!['ratingCount'] as num).toInt();
        print('[aggregateRating] TeknosaScraper: JSON-LD ile ratingCount/reviewCount bulundu: $cnt');
        return cnt;
      }
    }

    // 2. DOM Seçicileri / Microdata Fallback
    final countEl = document.querySelector('[itemprop="reviewCount"]') ??
                    document.querySelector('[itemprop="ratingCount"]') ??
                    document.querySelector('.pdp-review-count') ??
                    document.querySelector('.rating-count');
    if (countEl != null) {
      final text = countEl.localName == 'meta'
          ? (countEl.attributes['content'] ?? '')
          : countEl.text;
      final match = RegExp(r'(\d+)').firstMatch(text);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed > 0) {
          print('[aggregateRating] TeknosaScraper: DOM fallback ile ratingCount bulundu: $parsed');
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
            print('[aggregateRating] TeknosaScraper: Regex fallback ile ratingCount bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] TeknosaScraper: ratingCount bulunamadı (null)');
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    print('[aggregateRating] TeknosaScraper: brand (marka) aranıyor...');
    
    // 1. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) {
        print('[aggregateRating] TeknosaScraper: JSON-LD ile brand bulundu: $brand');
        return brand;
      }
    }

    // 2. DOM Seçicileri / Meta Tag
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
        print('[aggregateRating] TeknosaScraper: DOM fallback ile brand bulundu: $clean');
        return clean;
      }
    }

    // 3. Script Regex Fallback
    final scripts = document.getElementsByTagName('script');
    for (final script in scripts) {
      final text = script.text + ' ' + script.innerHtml;
      if (text.contains('"brand"') || text.contains('"Brand"')) {
        final match = RegExp(r'"brand"\s*:\s*\{\s*"@type"\s*:\s*"(?:Organization|Brand)"\s*,\s*"name"\s*:\s*"([^"]+)"').firstMatch(text) ??
                      RegExp(r'"brand"\s*:\s*"([^"]+)"').firstMatch(text);
        if (match != null) {
          final bName = match.group(1)?.trim();
          if (bName != null && bName.isNotEmpty && !bName.contains('{')) {
            print('[aggregateRating] TeknosaScraper: Regex fallback ile brand bulundu: $bName');
            return bName;
          }
        }
      }
    }

    print('[aggregateRating] TeknosaScraper: brand bulunamadı (null)');
    return null;
  }
}
