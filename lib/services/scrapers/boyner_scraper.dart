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

  Map<String, dynamic>? _extractBoynerPriceInfo(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (!text.contains('"PriceInfo"')) continue;

      final match = RegExp(r'"PriceInfo"\s*:\s*\{([^}]+)\}').firstMatch(text);
      if (match != null) {
        final content = match.group(1);
        if (content != null) {
          final priceMatch = RegExp(r'"Price"\s*:\s*(?:"([^"]+)"|(\d+(?:\.\d+)?))').firstMatch(content);
          final oldPriceMatch = RegExp(r'"OldPrice"\s*:\s*(?:"([^"]+)"|(\d+(?:\.\d+)?))').firstMatch(content);
          final campaignMatch = RegExp(r'"CampaignInfo"\s*:\s*"([^"]+)"').firstMatch(content);

          final rawPrice = priceMatch?.group(1) ?? priceMatch?.group(2);
          final rawOldPrice = oldPriceMatch?.group(1) ?? oldPriceMatch?.group(2);
          final rawCampaign = campaignMatch?.group(1);

          final parsedPrice = rawPrice != null ? parsePriceText(rawPrice) : null;
          final parsedOldPrice = rawOldPrice != null ? parsePriceText(rawOldPrice) : null;

          if (parsedPrice != null && parsedPrice > 0) {
            return {
              'price': parsedPrice,
              'originalPrice': parsedOldPrice,
              'campaignInfo': rawCampaign?.trim(),
            };
          }
        }
      }
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. En güvenilir kaynak: Next.js script verisindeki PriceInfo
    final priceInfo = _extractBoynerPriceInfo(document);
    if (priceInfo != null && priceInfo['price'] != null) {
      return priceInfo['price'] as double;
    }

    // 2. DOM selector for main price: [class*="priceMain"]
    final mainPriceElements = document.querySelectorAll('[class*="priceMain"]');
    for (final el in mainPriceElements) {
      // DOM elemanının kopyasını alıp içindeki "Sepette" rozetini fiyattan ayıklıyoruz
      final clone = el.clone(true);
      final badgeElements = clone.querySelectorAll('[class*="priceMainText"], [class*="price_priceMainText"]');
      for (final badge in badgeElements) {
        badge.remove();
      }

      String cleanText = clone.text.trim();
      if (cleanText.isNotEmpty) {
        cleanText = cleanText.replaceAll(RegExp(r'^(?:Sepette(?:\s*İndirim)?|Özel\s*Fiyat)\s*', caseSensitive: false), '').trim();
        final parsed = parsePriceText(cleanText);
        if (parsed != null && parsed > 0) {
          // 2.1 Sanity Check: Eğer bulunan fiyat 100 TL altıysa ama JSON-LD fiyatı 100 TL üzerindeyse
          // (örn. 11.999 TL'nin 11.99 olarak kırpılması anomalisi), JSON-LD teyit edilir
          if (parsed < 100) {
            final productJson = findProductJsonLd(document);
            if (productJson != null) {
              final priceLd = extractPriceFromProductJson(productJson);
              if (priceLd != null && priceLd > 100 && (priceLd / parsed) > 50) {
                return priceLd;
              }
            }
          }
          return parsed;
        }
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

    // 4. Legacy Script regex scan for CampaignPrice > 0
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      final matches = RegExp(r'"CampaignPrice"\s*:\s*(\d+(?:\.\d+)?)', caseSensitive: false).allMatches(text);
      for (final m in matches) {
        final val = double.tryParse(m.group(1)!);
        if (val != null && val > 0) return val;
      }
    }

    return null;
  }

  @override
  FutureOr<double?> scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice != null && currentPrice <= 0) return null;

    // 1. En güvenilir kaynak: Next.js script verisindeki PriceInfo.OldPrice
    final priceInfo = _extractBoynerPriceInfo(document);
    final infoOldPrice = priceInfo?['originalPrice'] as double?;
    if (infoOldPrice != null && (currentPrice == null || infoOldPrice > currentPrice)) {
      return infoOldPrice;
    }

    // 2. DOM selector for old price: [class*="priceOldPrice"]
    final oldPriceElements = document.querySelectorAll('[class*="priceOldPrice"]');
    for (final el in oldPriceElements) {
      final text = el.text.trim();
      if (text.isNotEmpty) {
        final parsed = parsePriceText(text);
        if (parsed != null && (currentPrice == null || parsed > currentPrice)) return parsed;
      }
    }

    // 3. Script/JSON regex scan for StrikeThrough / ActualPrice > currentPrice
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      final matches = RegExp(
        r'"(?:StrikeThroughPriceToShowOnScreen|ActualPriceToShowOnScreen)"\s*:\s*(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ).allMatches(text);
      for (final m in matches) {
        final val = double.tryParse(m.group(1)!);
        if (val != null && (currentPrice == null || val > currentPrice)) return val;
      }
    }

    return null;
  }

  @override
  FutureOr<String?> scrapePriceLabel(dom.Document document) {
    // 1. PriceInfo.CampaignInfo ("Sepette %28 İndirim", "%48 İndirim" vb.)
    final priceInfo = _extractBoynerPriceInfo(document);
    final campaign = priceInfo?['campaignInfo'] as String?;
    if (campaign != null && campaign.isNotEmpty) {
      return campaign;
    }

    // 2. DOM selector [class*="priceMainText"]
    final badgeEl = document.querySelector('[class*="priceMainText"], [class*="price_priceMainText"]');
    if (badgeEl != null) {
      final txt = badgeEl.text.trim();
      if (txt.isNotEmpty) {
        if (txt.toLowerCase() == 'sepette') return 'Sepette İndirim';
        return txt;
      }
    }

    return null;
  }

  @override
  FutureOr<double?> scrapeRatingValue(dom.Document document) {
    // 1. Check all JSON-LD blocks for aggregateRating
    final jsonLdRating = _findRatingFromJsonLd(document);
    if (jsonLdRating != null && jsonLdRating['ratingValue'] != null) {
      return (jsonLdRating['ratingValue'] as num).toDouble();
    }

    // 2. Script/JSON payload regex search
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      final match = RegExp(r'"ProductRating"\s*:\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(text) ??
                    RegExp(r'"ratingValue"\s*:\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(text);
      if (match != null) {
        final val = double.tryParse(match.group(1)!);
        if (val != null && val > 0) return val;
      }
    }

    return null;
  }

  @override
  FutureOr<int?> scrapeRatingCount(dom.Document document) {
    // 1. Check all JSON-LD blocks for aggregateRating
    final jsonLdRating = _findRatingFromJsonLd(document);
    if (jsonLdRating != null && jsonLdRating['ratingCount'] != null) {
      return (jsonLdRating['ratingCount'] as num).toInt();
    }

    // 2. Script/JSON payload regex search
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      final match = RegExp(r'"TotalReviewCount"\s*:\s*(\d+)', caseSensitive: false).firstMatch(text) ??
                    RegExp(r'"ReviewCount"\s*:\s*(\d+)', caseSensitive: false).firstMatch(text) ??
                    RegExp(r'"ratingCount"\s*:\s*(\d+)', caseSensitive: false).firstMatch(text);
      if (match != null) {
        final val = int.tryParse(match.group(1)!);
        if (val != null && val > 0) return val;
      }
    }

    return null;
  }

  Map<String, dynamic>? _findRatingFromJsonLd(dom.Document document) {
    final scripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      try {
        final sanitizedText = script.text
            .replaceAll('\r\n', ' ')
            .replaceAll('\n', ' ')
            .replaceAll('\r', ' ')
            .replaceAll('\t', ' ');
        final data = jsonDecode(sanitizedText);
        final rating = _searchRatingInJson(data);
        if (rating != null) return rating;
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic>? _searchRatingInJson(dynamic json) {
    if (json is Map) {
      if (json['aggregateRating'] is Map) {
        final r = extractRatingFromProductJson(Map<String, dynamic>.from(json));
        if (r != null && (r['ratingValue'] != null || r['ratingCount'] != null)) {
          return r;
        }
      }
      if (json['@graph'] is List) {
        for (final item in json['@graph'] as List) {
          final res = _searchRatingInJson(item);
          if (res != null) return res;
        }
      }
      for (final value in json.values) {
        if (value is Map || value is List) {
          final res = _searchRatingInJson(value);
          if (res != null) return res;
        }
      }
    } else if (json is List) {
      for (final item in json) {
        final res = _searchRatingInJson(item);
        if (res != null) return res;
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
