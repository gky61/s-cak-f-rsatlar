import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'base_scraper.dart';

class VatanScraper extends BaseProductScraper {
  @override
  String get domain => 'vatanbilgisayar.com';

  /// Vatan Bilgisayar'ın custom javascript detay scriptini parse eder
  Map<String, dynamic>? _parseUpdateProductDetayItem(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    final regex = RegExp(r'UpdateProductDetayItem\s*\(\s*({.*?})\s*\)');
    for (final script in scripts) {
      final match = regex.firstMatch(script.text);
      if (match != null) {
        try {
          final jsonStr = match.group(1);
          if (jsonStr != null) {
            return jsonDecode(jsonStr) as Map<String, dynamic>;
          }
        } catch (_) {}
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
          log('✅ Vatan Bilgisayar görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Vatan Bilgisayar görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final vatanSelectors = [
      '#main-img',
      'img.swiper-lazy',
      'a[data-fancybox="images"]',
      'a[data-fancybox]',
      '.product-details-img img',
      '.gallery-image img',
      'img[id*="main-img"]',
      'img[class*="product"]',
    ];
    for (final selector in vatanSelectors) {
      final elements = document.querySelectorAll(selector);
      for (final element in elements) {
        final src = element.attributes['data-zoom-image'] ??
                    element.attributes['data-srcset'] ??
                    element.attributes['data-src'] ??
                    element.attributes['data-lazy-src'] ??
                    element.attributes['href'] ??
                    element.attributes['src'];
        if (src != null && 
            src.isNotEmpty && 
            !src.startsWith('data:') && 
            !src.contains('placeholder') && 
            !isLogoUrl(src)) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null) {
            log('✅ Vatan Bilgisayar özel görseli bulundu: $resolved');
            return resolved;
          }
        }
      }
    }
    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. UpdateProductDetayItem scriptinden başlık çekmeyi dene (Öncelikli)
    final detay = _parseUpdateProductDetayItem(document);
    if (detay != null && detay['ProductName'] != null) {
      return detay['ProductName'].toString().trim();
    }

    // 2. JSON-LD şemasından başlık çekmeyi dene (Fallback 1)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['name'] != null) {
      return productJson['name'].toString().trim();
    }

    // 3. DOM Seçicileri (Fallback 2)
    final titleEl = document.querySelector('h1.product_title') ??
                    document.querySelector('#product-title h2') ??
                    document.querySelector('h1') ??
                    document.querySelector('h2');
    if (titleEl != null) {
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 0. İndirimli özel fiyat varsa (#priceSpecial) öncelikli olarak onu al
    final specialPriceEl = document.querySelector('#priceSpecial');
    if (specialPriceEl != null) {
      final price = parsePriceText(specialPriceEl.text);
      if (price != null && price > 0) {
        return price;
      }
    }

    // 1. UpdateProductDetayItem scriptinden fiyat çekmeyi dene (Öncelikli)
    final detay = _parseUpdateProductDetayItem(document);
    if (detay != null && detay['ProductPrice'] != null) {
      return parsePriceText(detay['ProductPrice'].toString());
    }

    // 2. JSON-LD şemasından fiyat çekmeyi dene (Fallback 1)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) {
        return priceLd;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final priceEl = document.querySelector('.product-list__price') ??
                    document.querySelector('.product-detail-price-big .product-list__price');
    if (priceEl != null) {
      return parsePriceText(priceEl.text);
    }
    return null;
  }

  @override
  double? scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice == null || currentPrice <= 0) return null;

    final candidates = <double>[];

    bool isIgnored(dom.Element el) {
      dom.Element? current = el.parent;
      while (current != null) {
        final cls = current.attributes['class'] ?? '';
        final id = current.attributes['id'] ?? '';
        if (cls.contains('fancy-modal') ||
            cls.contains('buyback-modal') ||
            cls.contains('extrawarrantyD-modal') ||
            cls.contains('garanti-price-footer') ||
            cls.contains('short-price') ||
            cls.contains('basketMobile_price') ||
            id.contains('extrawarrantyD-modal') ||
            id.contains('corporateOfferModal')) {
          return true;
        }
        current = current.parent;
      }
      return false;
    }

    final priceEls = document.querySelectorAll('.product-detail-price-big .product-list__price, .product-detail-price .product-list__price, .product-list__price');
    for (final el in priceEls) {
      if (!isIgnored(el)) {
        final parsed = parsePriceText(el.text);
        if (parsed != null && parsed > currentPrice) {
          candidates.add(parsed);
        }
      }
    }

    final detay = _parseUpdateProductDetayItem(document);
    if (detay != null && detay['ProductPrice'] != null) {
      final parsed = parsePriceText(detay['ProductPrice'].toString());
      if (parsed != null && parsed > currentPrice) {
        candidates.add(parsed);
      }
    }

    final mobileEls = document.querySelectorAll('#mobilePrice');
    for (final el in mobileEls) {
      if (!isIgnored(el)) {
        final parsed = parsePriceText(el.text);
        if (parsed != null && parsed > currentPrice) {
          candidates.add(parsed);
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

    // 2. DOM meta tag'i dene (Fallback)
    final descEl = document.querySelector('meta[name="description"]') ??
                   document.querySelector('meta[property="og:description"]');
    if (descEl != null) {
      return descEl.attributes['content']?.trim();
    }
    return null;
  }

  @override
  double? scrapeRatingValue(dom.Document document) {
    print('[aggregateRating] VatanScraper: ratingValue aranıyor...');
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingValue'] != null) {
        final val = (rating!['ratingValue'] as num).toDouble();
        print('[aggregateRating] VatanScraper: JSON-LD ile ratingValue bulundu: $val');
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
            print('[aggregateRating] VatanScraper: Regex fallback ile ratingValue bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] VatanScraper: ratingValue bulunamadı (null)');
    return null;
  }

  @override
  int? scrapeRatingCount(dom.Document document) {
    print('[aggregateRating] VatanScraper: ratingCount/reviewCount aranıyor...');
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingCount'] != null) {
        final cnt = (rating!['ratingCount'] as num).toInt();
        print('[aggregateRating] VatanScraper: JSON-LD ile ratingCount/reviewCount bulundu: $cnt');
        return cnt;
      }
    }

    // Fallback: Raw Script Regex Arama
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('aggregateRating') || text.contains('reviewCount')) {
        final match = RegExp(r'"(?:reviewCount|ratingCount)"\s*:\s*"?(\d+)"?').firstMatch(text);
        if (match != null) {
          final parsed = int.tryParse(match.group(1) ?? '');
          if (parsed != null) {
            print('[aggregateRating] VatanScraper: Regex fallback ile ratingCount/reviewCount bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] VatanScraper: ratingCount bulunamadı (null)');
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    print('[aggregateRating] VatanScraper: brand (marka) aranıyor...');
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) {
        print('[aggregateRating] VatanScraper: JSON-LD ile brand bulundu: $brand');
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
            print('[aggregateRating] VatanScraper: Regex fallback ile brand bulundu: $bName');
            return bName;
          }
        }
      }
    }

    print('[aggregateRating] VatanScraper: brand bulunamadı (null)');
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
            return breadcrumbs.map(_decodeHtmlEntities).toList();
          }
        } catch (_) {}
      }
    }

    // DOM Fallback
    final breadcrumbElements = document.querySelectorAll('ul.breadcrumb a, .breadcrumb a, .breadcrumbs a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && !lower.contains('vatan') && text != productTitle && text.length < 50) {
            list.add(_decodeHtmlEntities(text));
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    return [];
  }

  String _decodeHtmlEntities(String text) {
    try {
      return html_parser.parseFragment(text).text ?? text;
    } catch (_) {
      return text;
    }
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
                if (lowerName != 'anasayfa' && !lowerName.contains('vatan')) {
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
                return lower != 'anasayfa' && !lower.contains('vatan') && e != productTitle && e.length < 50;
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
