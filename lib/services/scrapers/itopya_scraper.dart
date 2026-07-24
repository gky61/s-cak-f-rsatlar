import 'dart:convert';
import 'dart:async';
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

class ItopyaScraper extends BaseProductScraper {
  final Map<String, Map<String, dynamic>> _apiCache = {};

  Future<Map<String, dynamic>?> _fetchRatingFromApi(dom.Document document) async {
    try {
      final canonical = document.querySelector('link[rel="canonical"]')?.attributes['href'] ??
                        document.querySelector('meta[property="og:url"]')?.attributes['content'] ?? '';
      final matchUrl = RegExp(r'_u(\d+)', caseSensitive: false).firstMatch(canonical);
      final htmlText = document.outerHtml;
      final matchHtml = RegExp(r'urunId\s*[:=]\s*["'']?(\d+)["'']?', caseSensitive: false).firstMatch(htmlText);
      final urunId = matchUrl?.group(1) ?? matchHtml?.group(1);
      if (urunId == null) return null;

      if (_apiCache.containsKey(urunId)) return _apiCache[urunId];

      final uri = Uri.parse('https://www.itopya.com/Urun/UrunYorum?id=$urunId');
      final res = await http.get(uri, headers: {
        'User-Agent': 'WhatsApp/2.23.4.15 A',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          double totalPuan = 0;
          int count = 0;
          for (final item in data) {
            if (item is Map && item['puan'] != null) {
              final p = double.tryParse(item['puan'].toString());
              if (p != null) {
                totalPuan += p;
                count++;
              }
            }
          }
          if (count > 0) {
            final cacheResult = {
              'ratingValue': double.parse((totalPuan / count).toStringAsFixed(1)),
              'ratingCount': data.length,
            };
            _apiCache[urunId] = cacheResult;
            return cacheResult;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  FutureOr<double?> scrapeRatingValue(dom.Document document) async {
    // 1. JSON-LD
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating != null && rating['ratingValue'] != null) {
        final val = double.tryParse(rating['ratingValue'].toString());
        if (val != null && val > 0) return val;
      }
    }

    // 2. DOM ratingValue (data-rateyo-rating)
    final rateyoEl = document.querySelector('[data-rateyo-rating]');
    if (rateyoEl != null) {
      final attr = rateyoEl.attributes['data-rateyo-rating'];
      if (attr != null && attr.isNotEmpty && attr != 'undefined') {
        final val = double.tryParse(attr);
        if (val != null && val > 0) return val;
      }
    }

    // 3. Fallback: API Call
    final apiData = await _fetchRatingFromApi(document);
    if (apiData != null && apiData['ratingValue'] != null) {
      return apiData['ratingValue'] as double;
    }

    return null;
  }

  @override
  FutureOr<int?> scrapeRatingCount(dom.Document document) async {
    // 1. JSON-LD
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating != null && rating['ratingCount'] != null) {
        final count = int.tryParse(rating['ratingCount'].toString());
        if (count != null) return count;
      }
    }

    // 2. DOM ratingCount (a.seeAll e.g. "(4)")
    final seeAllEl = document.querySelector('a.seeAll') ??
                     document.querySelector('a[onclick*="FocusYorum"]');
    if (seeAllEl != null) {
      final match = RegExp(r'\((\d+)\)').firstMatch(seeAllEl.text);
      if (match != null) {
        final count = int.tryParse(match.group(1)!);
        if (count != null) return count;
      }
    }

    // 3. Fallback: API Call
    final apiData = await _fetchRatingFromApi(document);
    if (apiData != null && apiData['ratingCount'] != null) {
      return apiData['ratingCount'] as int;
    }

    return null;
  }
  @override
  String get domain => 'itopya.com';

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
          log('✅ Itopya görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Itopya görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final imgElements = document.querySelectorAll('.product-details-img img, #product-image img, img[class*="product"]');
    for (final img in imgElements) {
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src != null && src.isNotEmpty) {
        final resolved = resolveImageUrl(src, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Itopya görseli img etiketiyle bulundu: $resolved');
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
    final titleEl = document.querySelector('h1.product-details-title') ??
                    document.querySelector('h1');
    if (titleEl != null) {
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. DOM Sepette indirimli fiyat (.product-price-warning-detail span)
    final sepetteEl = document.querySelector('.product-price-warning-detail span');
    if (sepetteEl != null) {
      final val = parsePriceText(sepetteEl.text);
      if (val != null && val > 0) return val;
    }

    // 2. DOM newprice
    final newPriceEl = document.querySelector('.product-details__sidebar_newprice');
    if (newPriceEl != null) {
      final val = parsePriceText(newPriceEl.text);
      if (val != null && val > 0) return val;
    }

    // 3. JSON-LD şemasından fiyat çekmeyi dene
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) {
        return priceLd;
      }
    }

    // 4. DOM Seçicileri (Fallback)
    final priceEl = document.querySelector('.product-price-warning-detail') ??
                    document.querySelector('.amount');
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

    // 1. DOM .product-details__sidebar_oldprice (Çizili eski fiyat)
    final oldPriceEl = document.querySelector('.product-details__sidebar_oldprice');
    if (oldPriceEl != null) {
      final val = parsePriceText(oldPriceEl.text);
      if (val != null && val > currentPrice) return val;
    }

    // 2. DOM .product-details__sidebar_newprice (Eğer sepette indirim varsa, liste fiyatı bu alandadır)
    final newPriceEl = document.querySelector('.product-details__sidebar_newprice');
    if (newPriceEl != null) {
      final val = parsePriceText(newPriceEl.text);
      if (val != null && val > currentPrice) return val;
    }

    // 3. Fallback selectors
    final candidates = <double>[];
    final selectors = [
      '.product-details__sidebar_oldprice',
      '.product-details__sidebar_newprice',
      'del',
      's',
      '.old-price',
      '.original-price',
    ];
    for (final selector in selectors) {
      for (final el in document.querySelectorAll(selector)) {
        final txt = el.text.trim();
        if (txt.contains('TL') || txt.contains('₺') || RegExp(r'\d').hasMatch(txt)) {
          final parsed = parsePriceText(txt);
          if (parsed != null && parsed > currentPrice && parsed <= currentPrice * 5) {
            candidates.add(parsed);
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.compareTo(a));
    return candidates.first;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['brand'] != null) {
      final b = productJson['brand'];
      if (b is String && b.trim().isNotEmpty) return b.trim();
      if (b is Map && b['name'] != null && b['name'].toString().trim().isNotEmpty) {
        return b['name'].toString().trim();
      }
    }

    final brandEl = document.querySelector('.product-details-brand') ??
                    document.querySelector('[itemprop="brand"]');
    if (brandEl != null && brandEl.text.trim().isNotEmpty) {
      return brandEl.text.trim();
    }

    return null;
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
    final breadcrumbElements = document.querySelectorAll('.breadcrumb a, .breadcrumbs a, ul.breadcrumb li a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('itopya') && text != productTitle && text.length < 50) {
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
                if (lowerName != 'anasayfa' && lowerName != 'ana sayfa' && !lowerName.contains('itopya')) {
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
                return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('itopya') && e != productTitle && e.length < 50;
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
                  return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('itopya') && e != productTitle && e.length < 50;
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
}
