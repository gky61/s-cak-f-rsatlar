import 'dart:async';
import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class BoynerScraper extends BaseProductScraper {
  @override
  String get domain => 'boyner.com.tr';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('boyner.com.tr');
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. JSON-LD şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['image'] != null) {
      final imgLd = extractImageFromProductJson(productJson['image']);
      if (imgLd != null && imgLd.isNotEmpty) {
        final resolved = resolveImageUrl(imgLd, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Boyner görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Boyner görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. JSON-LD
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['name'] != null) {
      return productJson['name'].toString().trim();
    }

    // 2. Open Graph og:title
    final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'];
    if (ogTitle != null && ogTitle.trim().isNotEmpty) {
      return ogTitle.trim();
    }

    // 3. General H1
    final h1El = document.querySelector('h1');
    if (h1El != null && h1El.text.trim().isNotEmpty) {
      return h1El.text.trim();
    }

    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    // 1. JSON-LD
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) {
        return brand;
      }
    }

    // 2. Meta property="product:brand"
    final metaBrand = document.querySelector('meta[property="product:brand"]')?.attributes['content'];
    if (metaBrand != null && metaBrand.trim().isNotEmpty) {
      return metaBrand.trim();
    }

    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. DOM selector for main price (e.g. [class*="priceMain"])
    final mainPriceElements = document.querySelectorAll('[class*="priceMain"]');
    for (final el in mainPriceElements) {
      final text = el.text.trim();
      if (text.isNotEmpty) {
        final parsed = parsePriceText(text);
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    // 2. Script/JSON regex scan for CampaignPrice > 0
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      final matches = RegExp(r'"CampaignPrice"\s*:\s*(\d+(?:\.\d+)?)', caseSensitive: false).allMatches(text);
      for (final m in matches) {
        final val = double.tryParse(m.group(1)!);
        if (val != null && val > 0) return val;
      }
    }

    // 3. Fallback to JSON-LD price
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceLd = extractPriceFromProductJson(productJson);
      if (priceLd != null && priceLd > 0) {
        return priceLd;
      }
    }

    return null;
  }

  @override
  FutureOr<double?> scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice == null || currentPrice <= 0) return null;

    // 1. DOM selector for old price (e.g. [class*="priceOldPrice"])
    final oldPriceElements = document.querySelectorAll('[class*="priceOldPrice"]');
    for (final el in oldPriceElements) {
      final text = el.text.trim();
      if (text.isNotEmpty) {
        final parsed = parsePriceText(text);
        if (parsed != null && parsed > currentPrice) return parsed;
      }
    }

    // 2. Script/JSON regex scan for StrikeThrough / ActualPrice > currentPrice
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      final matches = RegExp(
        r'"(?:StrikeThroughPriceToShowOnScreen|ActualPriceToShowOnScreen)"\s*:\s*(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ).allMatches(text);
      for (final m in matches) {
        final val = double.tryParse(m.group(1)!);
        if (val != null && val > currentPrice) return val;
      }
    }

    return null;
  }

  @override
  FutureOr<double?> scrapeRatingValue(dom.Document document) {
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating != null && rating['ratingValue'] != null) {
        return (rating['ratingValue'] as num).toDouble();
      }
    }
    return null;
  }

  @override
  FutureOr<int?> scrapeRatingCount(dom.Document document) {
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating != null && rating['ratingCount'] != null) {
        return (rating['ratingCount'] as num).toInt();
      }
    }
    return null;
  }

  @override
  FutureOr<String?> scrapeDescription(dom.Document document) {
    final ogDesc = document.querySelector('meta[property="og:description"]')?.attributes['content'];
    if (ogDesc != null && ogDesc.trim().isNotEmpty) return ogDesc.trim();

    final metaDesc = document.querySelector('meta[name="description"]')?.attributes['content'];
    if (metaDesc != null && metaDesc.trim().isNotEmpty) return metaDesc.trim();

    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final productTitle = scrapeTitle(document) ?? '';
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final breadcrumbScripts = document.querySelectorAll('script[type="application/ld+json"]');
      for (final script in breadcrumbScripts) {
        try {
          final sanitizedText = script.text
              .replaceAll('\r\n', ' ')
              .replaceAll('\n', ' ')
              .replaceAll('\r', ' ')
              .replaceAll('\t', ' ');
          final data = jsonDecode(sanitizedText);
          if (data is Map && data['@type'] == 'BreadcrumbList') {
            final items = data['itemListElement'];
            if (items is List) {
              final List<String> result = [];
              for (final item in items) {
                if (item is Map) {
                  final name = item['name'] ?? item['item']?['name'];
                  if (name != null && name.toString().trim().isNotEmpty) {
                    final str = name.toString().trim();
                    final lower = str.toLowerCase();
                    if (lower != 'anasayfa' && lower != 'home' && !lower.contains('boyner') && str != productTitle) {
                      result.add(str);
                    }
                  }
                }
              }
              if (result.isNotEmpty) return result;
            }
          }
        } catch (_) {}
      }
    }
    return [];
  }
}
