import 'dart:async';
import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class TrendyolScraper extends BaseProductScraper {
  @override
  String get domain => 'trendyol.com';

  @override
  bool canHandle(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('trendyol.com') || lowerUrl.contains('ty.gl');
  }

  @override
  FutureOr<String?> scrapePriceLabel(dom.Document document) {
    // 1. DOM Seçicileri: Trendyol Plus gerçek fiyat & banner elemanları
    const plusSelectors = [
      '.ty-plus-price-header',
      '.ty-plus-price-discounted-price',
      '.ty-plus-price',
      '.ty-plus-banner-desktop',
    ];

    for (final sel in plusSelectors) {
      final el = document.querySelector(sel);
      if (el != null) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          return "Plus'a Özel";
        }
      }
    }

    // 2. Metin bazlı DOM araması (Plus'a Özel / Trendyol Plus'a Özel)
    final plusRegex = RegExp(r"^(?:trendyol\s*)?plus['’]?\s*(?:a\s*özel|la\s*daha\s*az\s*öde|ile)", caseSensitive: false);
    final elements = document.querySelectorAll('span, div, p, b, strong, a, label, h1, h2, h3');
    for (final el in elements) {
      final text = el.text.trim();
      if (text.isNotEmpty && text.length <= 60 && plusRegex.hasMatch(text)) {
        return "Plus'a Özel";
      }
    }

    // 3. Script etiketleri: SADECE açık boolean TRUE koşulları (window condition=true veya JSON true)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.isNotEmpty) {
        if (RegExp(r'''__envoy_ty-plus-banner__CONDITION["']?\s*\]?\s*=\s*true''', caseSensitive: false).hasMatch(text)) {
          return "Plus'a Özel";
        }
        if (RegExp(r'''"hasPlusPromotion"\s*:\s*true|"isPlusExclusive"\s*:\s*true''', caseSensitive: false).hasMatch(text)) {
          return "Plus'a Özel";
        }
      }
    }

    return null;
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
          log('✅ Trendyol görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Trendyol görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. Main Product Image (Fallback 2)
    final imgElements = document.querySelectorAll('.product-image-container img, .detail-main-img img, img.main-img');
    for (final img in imgElements) {
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src != null && src.isNotEmpty) {
        final resolved = resolveImageUrl(src, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Trendyol görseli img etiketiyle bulundu: $resolved');
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
    final titleEl = document.querySelector('[data-testid="product-title"]') ??
                    document.querySelector('.product-title') ??
                    document.querySelector('h1.product-title');
    if (titleEl != null) {
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. Plus indirimli fiyat DOM kontrolü (En spesifik güncel fiyat)
    final plusPriceEl = document.querySelector('.ty-plus-price-discounted-price') ??
                        document.querySelector('.ty-plus-price .ty-plus-price-discounted-price') ??
                        document.querySelector('[class*="ty-plus-price-discounted-price"]');
    if (plusPriceEl != null) {
      final val = parsePriceText(plusPriceEl.text);
      if (val != null && val > 0) return val;
    }

    // 2. JSON-LD şemasından (Öncelikli)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) {
        return priceLd;
      }
    }

    // 3. DOM Seçicileri (Fallback)
    final priceEl = document.querySelector('.discounted') ??
                    document.querySelector('.prc-dsc') ??
                    document.querySelector('.price-container span');
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

    // 1. DOM Seçicileri (Öncelikli)
    final domSelectors = [
      '.old-price',
      '.prc-org',
      '.ty-plus-price-original-price',
      '[class*="price-original"]',
      '[class*="original-price"]',
      '[class*="prc-org"]',
      '[class*="old-price"]',
      'del',
      's',
    ];

    for (final selector in domSelectors) {
      for (final el in document.querySelectorAll(selector)) {
        final parsed = parsePriceText(el.text);
        if (parsed != null && parsed > currentPrice) {
          candidates.add(parsed);
        }
      }
    }

    if (candidates.isNotEmpty) {
      final valid = candidates.where((c) => c > currentPrice && c <= currentPrice * 5).toList();
      if (valid.isNotEmpty) {
        valid.sort();
        return valid.first;
      }
    }

    // 2. Initial State Script Search (Fallback)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('__PRODUCT_DETAIL_APP_INITIAL_STATE__') || text.contains('product":{')) {
        try {
          final matches = RegExp(r'"(?:originalPrice|sellingPrice|marketPrice)"\s*:\s*\{[^\}]*?"value"\s*:\s*([\d.]+)').allMatches(text);
          for (final m in matches) {
            final raw = m.group(1);
            if (raw != null) {
              final val = double.tryParse(raw);
              if (val != null && val > currentPrice) {
                candidates.add(val);
              }
            }
          }
        } catch (_) {}
      }
    }

    if (candidates.isEmpty) return null;

    final valid = candidates.where((c) => c > currentPrice && c <= currentPrice * 5).toList();
    if (valid.isEmpty) return null;

    valid.sort();
    return valid.first;
  }

  @override
  double? scrapeRatingValue(dom.Document document) {
    print('[aggregateRating] TrendyolScraper: ratingValue aranıyor...');
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingValue'] != null) {
        final val = (rating!['ratingValue'] as num).toDouble();
        print('[aggregateRating] TrendyolScraper: JSON-LD ile ratingValue bulundu: $val');
        return val;
      }
    }

    // Fallback: Raw Script Regex Arama
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('aggregateRating') || text.contains('ratingValue')) {
        final match = RegExp(r'"ratingValue"\s*:\s*"?([\d.,]+)"?').firstMatch(text);
        if (match != null) {
          final raw = match.group(1)?.replaceAll(',', '.');
          final parsed = raw != null ? double.tryParse(raw) : null;
          if (parsed != null) {
            print('[aggregateRating] TrendyolScraper: Regex fallback ile ratingValue bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] TrendyolScraper: ratingValue bulunamadı (null)');
    return null;
  }

  @override
  int? scrapeRatingCount(dom.Document document) {
    print('[aggregateRating] TrendyolScraper: ratingCount/reviewCount aranıyor...');
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingCount'] != null) {
        final cnt = (rating!['ratingCount'] as num).toInt();
        print('[aggregateRating] TrendyolScraper: JSON-LD ile ratingCount/reviewCount bulundu: $cnt');
        return cnt;
      }
    }

    // Fallback: Raw Script Regex Arama
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('aggregateRating') || text.contains('reviewCount') || text.contains('ratingCount')) {
        final match = RegExp(r'"(?:ratingCount|reviewCount)"\s*:\s*"?(\d+)"?').firstMatch(text);
        if (match != null) {
          final parsed = int.tryParse(match.group(1) ?? '');
          if (parsed != null) {
            print('[aggregateRating] TrendyolScraper: Regex fallback ile ratingCount/reviewCount bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] TrendyolScraper: ratingCount bulunamadı (null)');
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    print('[aggregateRating] TrendyolScraper: brand (marka) aranıyor...');
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) {
        print('[aggregateRating] TrendyolScraper: JSON-LD ile brand bulundu: $brand');
        return brand;
      }
    }

    // Fallback: Raw Script Regex Arama
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('"brand"') || text.contains('"Brand"')) {
        final match = RegExp(r'"brand"\s*:\s*\{\s*"@type"\s*:\s*"Brand"\s*,\s*"name"\s*:\s*"([^"]+)"').firstMatch(text) ??
                      RegExp(r'"brand"\s*:\s*"([^"]+)"').firstMatch(text);
        if (match != null) {
          final bName = match.group(1)?.trim();
          if (bName != null && bName.isNotEmpty && !bName.contains('{')) {
            print('[aggregateRating] TrendyolScraper: Regex fallback ile brand bulundu: $bName');
            return bName;
          }
        }
      }
    }

    print('[aggregateRating] TrendyolScraper: brand bulunamadı (null)');
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
    final breadcrumbElements = document.querySelectorAll('.product-detail-breadcrumb a, .breadcrumb a, .breadcrumbs a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'trendyol' && text != productTitle && text.length < 50) {
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
                if (lowerName != 'anasayfa' && lowerName != 'trendyol') {
                  // Ürün başlığının kendisini veya çok uzun ürün isimlerini breadcrumb olarak ekleme
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
              .split(RegExp(r'\s*>\s*'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .where((e) {
                final lower = e.toLowerCase();
                return lower != 'anasayfa' && lower != 'trendyol' && e != productTitle && e.length < 50;
              })
              .toList();
          if (parts.isNotEmpty) return parts;
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
}
