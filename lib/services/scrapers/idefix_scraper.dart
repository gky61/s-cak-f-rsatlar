import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'base_scraper.dart';

class IdefixScraper extends BaseProductScraper {
  @override
  String get domain => 'idefix.com';

  Future<Map<String, dynamic>?> _fetchEcomApiReview(dom.Document document) async {
    try {
      String? productId;

      // 1. Canonical / OG URL veya Link Href
      final canonicalUrl = document.querySelector('link[rel="canonical"]')?.attributes['href'] ??
                           document.querySelector('meta[property="og:url"]')?.attributes['content'];
      if (canonicalUrl != null) {
        final match = RegExp(r'p-(\d+)').firstMatch(canonicalUrl);
        if (match != null) productId = match.group(1);
      }

      // 2. DOM etiketlerinden veya scriptlerden arama
      if (productId == null) {
        final scripts = document.querySelectorAll('script');
        for (final script in scripts) {
          final match = RegExp(r'p-(\d+)').firstMatch(script.text) ?? RegExp(r'"productId"\s*:\s*"?(\d+)"?').firstMatch(script.text);
          if (match != null) {
            productId = match.group(1);
            break;
          }
        }
      }

      // 3. __NEXT_DATA__ sayfa özellikleri
      if (productId == null) {
        final nextScript = document.querySelector('script#__NEXT_DATA__');
        if (nextScript != null) {
          try {
            final jsonMap = jsonDecode(nextScript.text);
            final pId = jsonMap['props']?['pageProps']?['productDetail']?['id'];
            if (pId != null) productId = pId.toString();
          } catch (_) {}
        }
      }

      if (productId == null || productId.isEmpty) return null;

      final apiUrl = 'https://ecomapi.idefix.com/api/product/$productId/detail/review';
      final res = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        return data;
      }
    } catch (_) {}
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
      var imgLd = extractImageFromProductJson(productJson['image']);
      if (imgLd != null && imgLd.isNotEmpty) {
        // İdefix'in boyut placeholder'ını çözümlüyoruz
        if (imgLd.contains('{size}')) {
          imgLd = imgLd.replaceAll('{size}', '500/0/');
        }
        final resolved = resolveImageUrl(imgLd, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ İdefix görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ İdefix görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. DOM Seçicileri (Fallback 2)
    final imgElements = document.querySelectorAll('img[class*="product"], img.product-image, .product-detail img');
    for (final img in imgElements) {
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src != null && src.isNotEmpty) {
        final resolved = resolveImageUrl(src, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ İdefix görseli img etiketiyle bulundu: $resolved');
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
    final titleEl = document.querySelector('h1.text-title-lg') ??
                    document.querySelector('h1');
    if (titleEl != null) {
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
    final salePriceMeta = document.querySelector('meta[property="og:price:sale_price"]') ??
                          document.querySelector('meta[property="product:price:amount"]');
    if (salePriceMeta != null) {
      final val = parsePriceText(salePriceMeta.attributes['content'] ?? '');
      if (val != null && val > 0) {
        return val;
      }
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
  Future<double?> scrapeRatingValue(dom.Document document) async {
    print('[aggregateRating] IdefixScraper: ratingValue aranıyor...');
    
    // 1. Tüm JSON-LD Script bloklarında arama yap
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json') {
        try {
          final sanitizedText = script.text
              .replaceAll('\r\n', ' ')
              .replaceAll('\n', ' ')
              .replaceAll('\r', ' ')
              .replaceAll('\t', ' ');
          final data = jsonDecode(sanitizedText);
          final product = findProductInJson(data);
          if (product != null) {
            final rating = extractRatingFromProductJson(product);
            if (rating?['ratingValue'] != null) {
              final val = (rating!['ratingValue'] as num).toDouble();
              print('[aggregateRating] IdefixScraper: JSON-LD ile ratingValue bulundu: $val');
              return val;
            }
          }
        } catch (_) {}
      }
    }

    // 2. Next.js __NEXT_DATA__ Script Tag Arama
    final nextDataScript = document.querySelector('script#__NEXT_DATA__');
    if (nextDataScript != null) {
      try {
        final Map<String, dynamic> nextData = jsonDecode(nextDataScript.text);
        final pageProps = nextData['props']?['pageProps'];
        final product = pageProps?['product'] ?? pageProps?['initialState']?['product'];
        if (product != null) {
          final ratingVal = product['ratingScore'] ?? product['ratingValue'] ?? product['rating'] ?? product['averageRating'];
          if (ratingVal != null) {
            final parsed = double.tryParse(ratingVal.toString());
            if (parsed != null && parsed > 0) {
              print('[aggregateRating] IdefixScraper: __NEXT_DATA__ ile ratingValue bulundu: $parsed');
              return parsed;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: Raw Script Regex Arama
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('aggregateRating') || text.contains('ratingValue')) {
        final match = RegExp(r'"ratingValue"\s*:\s*"?([\d.,]+)"?').firstMatch(text);
        if (match != null) {
          final raw = match.group(1)?.replaceAll(',', '.');
          final parsed = raw != null ? double.tryParse(raw) : null;
          if (parsed != null && parsed > 0) {
            print('[aggregateRating] IdefixScraper: Regex fallback ile ratingValue bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    // 4. Fallback: Microdata & DOM Seçicileri
    final metaRating = document.querySelector('meta[itemprop="ratingValue"]') ??
                       document.querySelector('[itemprop="ratingValue"]') ??
                       document.querySelector('.product-rating-point') ??
                       document.querySelector('.rating-value') ??
                       document.querySelector('.rating-score');
    if (metaRating != null) {
      final text = metaRating.localName == 'meta' 
          ? (metaRating.attributes['content'] ?? '') 
          : metaRating.text;
      final raw = text.trim().replaceAll(',', '.');
      final parsed = double.tryParse(raw) ?? parsePriceText(raw);
      if (parsed != null && parsed > 0 && parsed <= 5.0) {
        print('[aggregateRating] IdefixScraper: DOM fallback ile ratingValue bulundu: $parsed');
        return parsed;
      }
    }

    // 5. Live EcomAPI Fallback (Canlı İdefix Değerlendirme Servisi)
    final apiData = await _fetchEcomApiReview(document);
    if (apiData != null && apiData['averageRating'] != null) {
      final val = double.tryParse(apiData['averageRating'].toString());
      if (val != null && val > 0) {
        print('[aggregateRating] IdefixScraper: ecomapi API ile ratingValue bulundu: $val');
        return val;
      }
    }

    print('[aggregateRating] IdefixScraper: ratingValue bulunamadı (null)');
    return null;
  }

  @override
  Future<int?> scrapeRatingCount(dom.Document document) async {
    print('[aggregateRating] IdefixScraper: ratingCount/reviewCount aranıyor...');
    
    // 1. Tüm JSON-LD Script bloklarında arama yap
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json') {
        try {
          final sanitizedText = script.text
              .replaceAll('\r\n', ' ')
              .replaceAll('\n', ' ')
              .replaceAll('\r', ' ')
              .replaceAll('\t', ' ');
          final data = jsonDecode(sanitizedText);
          final product = findProductInJson(data);
          if (product != null) {
            final rating = extractRatingFromProductJson(product);
            if (rating?['ratingCount'] != null) {
              final cnt = (rating!['ratingCount'] as num).toInt();
              print('[aggregateRating] IdefixScraper: JSON-LD ile ratingCount/reviewCount bulundu: $cnt');
              return cnt;
            }
          }
        } catch (_) {}
      }
    }

    // 2. Next.js __NEXT_DATA__ Script Tag Arama
    final nextDataScript = document.querySelector('script#__NEXT_DATA__');
    if (nextDataScript != null) {
      try {
        final Map<String, dynamic> nextData = jsonDecode(nextDataScript.text);
        final pageProps = nextData['props']?['pageProps'];
        final product = pageProps?['product'] ?? pageProps?['initialState']?['product'];
        if (product != null) {
          final reviewCnt = product['commentCount'] ?? product['reviewCount'] ?? product['ratingCount'] ?? product['totalCommentCount'];
          if (reviewCnt != null) {
            final parsed = int.tryParse(reviewCnt.toString());
            if (parsed != null && parsed > 0) {
              print('[aggregateRating] IdefixScraper: __NEXT_DATA__ ile ratingCount bulundu: $parsed');
              return parsed;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: Raw Script Regex Arama
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('aggregateRating') || text.contains('reviewCount') || text.contains('ratingCount')) {
        final match = RegExp(r'"(?:reviewCount|ratingCount)"\s*:\s*"?(\d+)"?').firstMatch(text);
        if (match != null) {
          final parsed = int.tryParse(match.group(1) ?? '');
          if (parsed != null) {
            print('[aggregateRating] IdefixScraper: Regex fallback ile ratingCount/reviewCount bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    // 4. Fallback: Microdata & DOM Seçicileri
    final metaCount = document.querySelector('meta[itemprop="reviewCount"]') ??
                      document.querySelector('meta[itemprop="ratingCount"]') ??
                      document.querySelector('[itemprop="reviewCount"]') ??
                      document.querySelector('[itemprop="ratingCount"]') ??
                      document.querySelector('.product-review-count') ??
                      document.querySelector('.comment-count');
    if (metaCount != null) {
      final text = metaCount.localName == 'meta'
          ? (metaCount.attributes['content'] ?? '')
          : metaCount.text;
      final cleanText = RegExp(r'\d+').firstMatch(text.trim())?.group(0);
      if (cleanText != null) {
        final parsed = int.tryParse(cleanText);
        if (parsed != null && parsed > 0) {
          print('[aggregateRating] IdefixScraper: DOM fallback ile ratingCount bulundu: $parsed');
          return parsed;
        }
      }
    }

    // 5. Live EcomAPI Fallback (Canlı İdefix Değerlendirme Servisi)
    final apiData = await _fetchEcomApiReview(document);
    if (apiData != null && apiData['reviewCount'] != null) {
      final cnt = int.tryParse(apiData['reviewCount'].toString());
      if (cnt != null && cnt > 0) {
        print('[aggregateRating] IdefixScraper: ecomapi API ile ratingCount bulundu: $cnt');
        return cnt;
      }
    }

    print('[aggregateRating] IdefixScraper: ratingCount bulunamadı (null)');
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    print('[aggregateRating] IdefixScraper: brand (marka) aranıyor...');
    
    // 1. Tüm JSON-LD Script bloklarında arama yap
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json') {
        try {
          final sanitizedText = script.text
              .replaceAll('\r\n', ' ')
              .replaceAll('\n', ' ')
              .replaceAll('\r', ' ')
              .replaceAll('\t', ' ');
          final data = jsonDecode(sanitizedText);
          final product = findProductInJson(data);
          if (product != null) {
            final brand = extractBrandFromProductJson(product);
            if (brand != null && brand.isNotEmpty) {
              print('[aggregateRating] IdefixScraper: JSON-LD ile brand bulundu: $brand');
              return brand;
            }
          }
        } catch (_) {}
      }
    }

    // 2. Fallback: Raw Script Regex Arama
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('"brand"') || text.contains('"Brand"')) {
        final match = RegExp(r'"brand"\s*:\s*\{\s*"@type"\s*:\s*"(?:Organization|Brand)"\s*,\s*"name"\s*:\s*"([^"]+)"').firstMatch(text) ??
                      RegExp(r'"brand"\s*:\s*"([^"]+)"').firstMatch(text);
        if (match != null) {
          final bName = match.group(1)?.trim();
          if (bName != null && bName.isNotEmpty && !bName.contains('{')) {
            print('[aggregateRating] IdefixScraper: Regex fallback ile brand bulundu: $bName');
            return bName;
          }
        }
      }
    }

    // 3. Fallback: Microdata & DOM Selectors
    final metaBrand = document.querySelector('meta[itemprop="brand"]') ??
                      document.querySelector('[itemprop="brand"]') ??
                      document.querySelector('.product-brand-name') ??
                      document.querySelector('a.brand-name');
    if (metaBrand != null) {
      final text = metaBrand.localName == 'meta'
          ? (metaBrand.attributes['content'] ?? '')
          : metaBrand.text;
      final clean = text.trim();
      if (clean.isNotEmpty) {
        print('[aggregateRating] IdefixScraper: DOM fallback ile brand bulundu: $clean');
        return clean;
      }
    }

    print('[aggregateRating] IdefixScraper: brand bulunamadı (null)');
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
    final breadcrumbElements = document.querySelectorAll('.breadcrumb a, .breadcrumbs a, .idefix-breadcrumb a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('idefix') && text != productTitle && text.length < 50) {
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
                if (lowerName != 'anasayfa' && lowerName != 'ana sayfa' && !lowerName.contains('idefix')) {
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
                return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('idefix') && e != productTitle && e.length < 50;
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
                  return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('idefix') && e != productTitle && e.length < 50;
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
