import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class _N11ApiPriceResult {
  final double? discountedPrice;
  final double? originalPrice;

  _N11ApiPriceResult({
    this.discountedPrice,
    this.originalPrice,
  });
}

class N11Scraper extends BaseProductScraper {
  _N11ApiPriceResult? _lastApiResult;

  @override
  String get domain => 'n11.com';

  Map<String, dynamic>? _getN11Model(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('window.model =')) {
        final modelIndex = text.indexOf('window.model =');
        if (modelIndex != -1) {
          final startJson = text.indexOf('{', modelIndex);
          final endJson = text.lastIndexOf('}');
          if (startJson != -1 && endJson != -1 && endJson > startJson) {
            try {
              final jsonStr = text.substring(startJson, endJson + 1);
              return jsonDecode(jsonStr);
            } catch (_) {}
          }
        }
      }
    }
    return null;
  }

  dynamic _findValueRecursive(dynamic json, String targetKey) {
    if (json is Map) {
      if (json.containsKey(targetKey)) {
        return json[targetKey];
      }
      for (final value in json.values) {
        if (value is Map || value is List) {
          final res = _findValueRecursive(value, targetKey);
          if (res != null) return res;
        }
      }
    } else if (json is List) {
      for (final item in json) {
        final res = _findValueRecursive(item, targetKey);
        if (res != null) return res;
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
    // 1. window.model JSON'ından görseli çekmeyi dene (Öncelikli)
    final model = _getN11Model(document);
    if (model != null) {
      final images = model['product']?['images'];
      if (images is List && images.isNotEmpty) {
        final firstImgPath = images[0]['path']?.toString();
        if (firstImgPath != null && firstImgPath.isNotEmpty) {
          // {0} boyut belirtecini standart 400_570 boyutuyla değiştir
          final resolvedPath = firstImgPath.replaceAll('{0}', '400_570');
          final resolved = resolveImageUrl(resolvedPath, url);
          if (resolved != null && !isLogoUrl(resolved)) {
            log('✅ N11 görseli window.model ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final n11Selectors = [
      '.big-image-wrapper img',
      'img.swiper-image',
      'img.swiper-lazy',
      'img[class*="swiper"]',
      '#product-image img',
      '.product-images img',
    ];
    for (final selector in n11Selectors) {
      final elements = document.querySelectorAll(selector);
      for (final element in elements) {
        final src = element.attributes['src'] ?? element.attributes['data-src'] ?? element.attributes['data-lazy-src'];
        if (src != null && src.isNotEmpty && !src.startsWith('data:') && !isLogoUrl(src)) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null) {
            log('✅ N11 özel görseli DOM ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }
    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. window.model JSON'ından başlığı çekmeyi dene (Öncelikli)
    final model = _getN11Model(document);
    if (model != null) {
      final p = model['product'];
      final title = p is Map ? (p['title'] ?? p['name'] ?? p['proName']) : null;
      final seoTitle = model['seoMetaData']?['title'];
      final candidate = title ?? seoTitle;
      if (candidate != null && candidate.toString().trim().isNotEmpty) {
        return candidate.toString().trim();
      }
    }

    // 2. DOM Başlık Seçicileri (h1.title, .titleArea h1.title, h1.proName)
    final titleEl = document.querySelector('.titleArea h1.title') ??
                    document.querySelector('h1.title') ??
                    document.querySelector('h1.proName') ??
                    document.querySelector('h1.product-name') ??
                    document.querySelector('h1[class*="title"]') ??
                    document.querySelector('.proName') ??
                    document.querySelector('meta[property="og:title"]');
    if (titleEl != null) {
      if (titleEl.localName == 'meta') {
        final content = titleEl.attributes['content']?.trim();
        if (content != null && content.isNotEmpty) return content;
      } else {
        final text = titleEl.text.trim();
        if (text.isNotEmpty) return text;
      }
    }

    // 3. JSON-LD Şeması Fallback
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['name'] != null) {
      final name = productJson['name'].toString().trim();
      if (name.isNotEmpty) {
        return name
            .replaceAll(RegExp(r'\s*Fiyatları ve Özellikleri.*$', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*-\s*n11\.com$', caseSensitive: false), '')
            .trim();
      }
    }

    // 4. window.model product JSON bloğundan regex ile çekmeyi dene
    final html = document.outerHtml;
    final productTitleReg = RegExp(r'"product"\s*:\s*\{[^}]*"title"\s*:\s*"([^"]+)"');
    final productTitleMatch = productTitleReg.firstMatch(html);
    if (productTitleMatch != null) {
      final matched = productTitleMatch.group(1);
      if (matched != null && matched.trim().isNotEmpty) {
        return matched.trim();
      }
    }

    final proNameReg = RegExp(r'"proName"\s*:\s*"([^"]+)"');
    final proNameMatch = proNameReg.firstMatch(html);
    if (proNameMatch != null) {
      final matched = proNameMatch.group(1);
      if (matched != null && matched.trim().isNotEmpty) {
        return matched.trim();
      }
    }

    return null;
  }

  // --- Private Helper Methods for N11 Personalized Detail API ---

  Future<_N11ApiPriceResult?> _fetchPersonalizedDetailPrice(dom.Document document) async {
    try {
      final model = _getN11Model(document);
      final p = model?['product'];
      final dynamic rawProductId = model?['productId'] ?? p?['id'];
      if (rawProductId == null) return null;

      final productId = rawProductId is int ? rawProductId : int.tryParse(rawProductId.toString());
      if (productId == null || productId <= 0) return null;

      final categoryId = p?['category']?['id'] as int?;

      String slug = '';
      final canonical = model?['seoMetaData']?['canonical']?.toString() ??
                        document.querySelector('link[rel="canonical"]')?.attributes['href'] ??
                        document.querySelector('meta[property="og:url"]')?.attributes['content'] ??
                        p?['url']?.toString();
      if (canonical != null && canonical.contains('/urun/')) {
        try {
          final uri = Uri.parse(canonical);
          final path = uri.path;
          if (path.contains('/urun/')) {
            slug = path.substring(path.indexOf('/urun/') + 6);
            if (slug.contains('?')) slug = slug.substring(0, slug.indexOf('?'));
          }
        } catch (_) {}
      }

      final body = jsonEncode({
        'productId': productId,
        'categoryId': categoryId,
        'productSlug': slug,
        'vue': true,
      });

      final response = await http.post(
        Uri.parse('https://www.n11.com/rest/v1/personalizedDetail'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/plain, */*',
          'User-Agent': 'WhatsApp/2.23.4.15 A',
          'Accept-Language': 'tr-TR,tr;q=0.9',
        },
        body: body,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final resp = data['response'];
        if (resp is Map) {
          final prod = resp['product'] is Map ? resp['product'] as Map : null;

          final instantDiscountStr = resp['instantDiscountedPrice']?.toString();
          final finalPriceStr = prod?['finalPrice']?.toString();
          final oldPriceStr = prod?['oldPrice']?.toString();
          final displayPriceStr = prod?['displayPrice']?.toString();
          final badge = prod?['finalPriceBadge']?.toString() ?? resp['instantDiscountMessage']?.toString();

          final instantDiscount = instantDiscountStr != null ? parsePriceText(instantDiscountStr) : null;
          final finalPrice = finalPriceStr != null ? parsePriceText(finalPriceStr) : null;
          final oldPrice = oldPriceStr != null ? parsePriceText(oldPriceStr) : null;
          final displayPrice = displayPriceStr != null ? parsePriceText(displayPriceStr) : null;

          // 1. İndirimli Satış Fiyatı
          double? discPrice = instantDiscount ?? finalPrice;
          if (discPrice == null && displayPrice != null && oldPrice != null && displayPrice < oldPrice) {
            discPrice = displayPrice;
          }

          // 2. İndirimsiz Liste / Piyasa Fiyatı
          double? origPrice;
          if (oldPrice != null && discPrice != null && oldPrice > discPrice) {
            origPrice = oldPrice;
          } else if (displayPrice != null && discPrice != null && displayPrice > discPrice) {
            origPrice = displayPrice;
          }

          if (discPrice != null && discPrice > 0) {
            final result = _N11ApiPriceResult(
              discountedPrice: discPrice,
              originalPrice: origPrice,
            );
            _lastApiResult = result;
            return result;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. Canlı API Çağrısı (Öncelikli)
    final apiResult = await _fetchPersonalizedDetailPrice(document);
    if (apiResult?.discountedPrice != null && apiResult!.discountedPrice! > 0) {
      return apiResult.discountedPrice;
    }

    // 2. window.model JSON'ından fiyatı çekmeyi dene (Öncelikli Statik Fallback)
    final model = _getN11Model(document);
    if (model != null) {
      final p = model['product'];
      final pers = p is Map ? p['personalizedData'] : null;

      // Eğer personalizedData zaten model içinde varsa (nadir durumlar)
      final instantPrice = pers is Map ? pers['instantDiscountedPrice'] : null;
      if (instantPrice != null) {
        final parsed = instantPrice is num ? instantPrice.toDouble() : parsePriceText(instantPrice.toString());
        if (parsed != null && parsed > 0) return parsed;
      }

      final finalPrice = (pers is Map && pers['product'] is Map)
          ? pers['product']['finalPrice']
          : (p is Map ? p['finalPriceFloat'] ?? p['finalPrice'] : null);
      if (finalPrice != null) {
        final parsed = finalPrice is num ? finalPrice.toDouble() : parsePriceText(finalPrice.toString());
        if (parsed != null && parsed > 0) return parsed;
      }

      // price ve displayPrice alanlarını parse et ve karşılaştır!
      double? priceVal;
      double? displayVal;
      if (p is Map) {
        final rawPrice = p['priceFloat'] ?? p['price'];
        if (rawPrice != null) {
          priceVal = rawPrice is num ? rawPrice.toDouble() : parsePriceText(rawPrice.toString());
        }
        final rawDisplay = p['displayPriceFloat'] ?? p['displayPrice'];
        if (rawDisplay != null) {
          displayVal = rawDisplay is num ? rawDisplay.toDouble() : parsePriceText(rawDisplay.toString());
        }
      }

      if (priceVal != null && displayVal != null && priceVal > 0 && displayVal > 0) {
        // İki fiyat da mevcutsa DÜŞÜK OLAN satış fiyatıdır (indirimli fiyattır)!
        return priceVal < displayVal ? priceVal : displayVal;
      } else if (priceVal != null && priceVal > 0) {
        return priceVal;
      } else if (displayVal != null && displayVal > 0) {
        return displayVal;
      }
    }

    // 3. window.model içinden regex ile fiyat çekmeyi dene (Fallback 1)
    final html = document.outerHtml;
    final finalPriceReg = RegExp(r'"finalPrice"\s*:\s*"([^"]+)"');
    final finalPriceMatch = finalPriceReg.firstMatch(html);
    if (finalPriceMatch != null) {
      final val = parsePriceText(finalPriceMatch.group(1)!);
      if (val != null && val > 0) return val;
    }
    
    final priceReg = RegExp(r'"price"\s*:\s*"([^"]+)"');
    final priceMatch = priceReg.firstMatch(html);
    if (priceMatch != null) {
      final val = parsePriceText(priceMatch.group(1)!);
      if (val != null && val > 0) return val;
    }

    // 4. DOM Seçicileri (Fallback 2)
    final priceEl = document.querySelector('.newPrice ins') ??
                    document.querySelector('ins') ??
                    document.querySelector('.newPrice') ??
                    document.querySelector('meta[property="product:price:amount"]');
                    
    if (priceEl != null) {
      if (priceEl.localName == 'meta') {
        return parsePriceText(priceEl.attributes['content'] ?? '');
      }
      return parsePriceText(priceEl.text);
    }
    return null;
  }

  @override
  double? scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice == null || currentPrice <= 0) return null;

    // 1. Canlı API Sonucu Önceliği (_lastApiResult)
    if (_lastApiResult?.originalPrice != null && _lastApiResult!.originalPrice! > currentPrice) {
      return _lastApiResult!.originalPrice;
    }

    final candidates = <double>[];

    // 2. window.model JSON'ından eski / liste fiyatlarını çek
    final model = _getN11Model(document);
    if (model != null) {
      final p = model['product'];
      final pers = p is Map ? p['personalizedData'] : null;

      final modelCandidates = [
        if (pers is Map && pers['product'] is Map) pers['product']['oldPrice'],
        if (pers is Map && pers['product'] is Map) pers['product']['displayPrice'],
        if (p is Map) p['displayPriceFloat'],
        if (p is Map) p['displayPrice'],
        if (p is Map) p['oldPriceFloat'],
        if (p is Map) p['oldPrice'],
        if (p is Map) p['priceFloat'],
        if (p is Map) p['price'],
      ];

      for (final val in modelCandidates) {
        if (val != null) {
          final parsed = val is num ? val.toDouble() : parsePriceText(val.toString());
          if (parsed != null && parsed > currentPrice) {
            candidates.add(parsed);
          }
        }
      }
    }

    // 3. DOM selectors for old / strikethrough / original prices
    final selectors = [
      '.oldPrice',
      '.old-price',
      '[class*="oldPrice"]',
      '[class*="old-price"]',
      'del',
      's',
    ];

    for (final selector in selectors) {
      for (final el in document.querySelectorAll(selector)) {
        final parsed = parsePriceText(el.text);
        if (parsed != null && parsed > currentPrice) {
          candidates.add(parsed);
        }
      }
    }

    if (candidates.isEmpty) return null;

    final valid = candidates.where((c) => c > currentPrice && c <= currentPrice * 5).toList();
    if (valid.isEmpty) return null;

    valid.sort();
    return valid.first;
  }


  @override
  String? scrapeDescription(dom.Document document) {
    // 1. window.model JSON'ından açıklamayı çekmeyi dene (Öncelikli)
    final model = _getN11Model(document);
    if (model != null) {
      final desc = model['seoMetaData']?['description'];
      if (desc != null && desc.toString().isNotEmpty) {
        return desc.toString().trim();
      }
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
    final productTitle = scrapeTitle(document) ?? '';

    // window.model JSON'ından aramayı dene
    final model = _getN11Model(document);
    if (model != null) {
      final categoryField = model['category'] ?? model['categories'];
      if (categoryField is String && categoryField.isNotEmpty) {
        final parts = categoryField
            .split(RegExp(r'\s*>\s*|\s*/\s*'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .where((e) {
              final lower = e.toLowerCase();
              return lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('n11') && lower != productTitle.toLowerCase().trim() && e.length < 50;
            })
            .toList();
        if (parts.isNotEmpty) return parts;
      } else if (categoryField is List) {
        final List<String> list = [];
        for (final cat in categoryField) {
          if (cat is Map && cat['name'] != null) {
            final name = cat['name'].toString().trim();
            final lower = name.toLowerCase();
            if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('n11') && lower != productTitle.toLowerCase().trim() && name.length < 50) {
              list.add(name);
            }
          } else if (cat is String) {
            final name = cat.trim();
            final lower = name.toLowerCase();
            if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('n11') && lower != productTitle.toLowerCase().trim() && name.length < 50) {
              list.add(name);
            }
          }
        }
        if (list.isNotEmpty) return list;
      }
    }

    // DOM Fallback
    final breadcrumbElements = document.querySelectorAll('.breadcrumb-item a, .breadcrumb a, .breadcrumb-group a');
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty) {
          final lower = text.toLowerCase();
          if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('n11') && lower != productTitle.toLowerCase().trim() && text.length < 50) {
            list.add(text);
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    return [];
  }

  @override
  double? scrapeRatingValue(dom.Document document) {
    print('[aggregateRating] N11Scraper: ratingValue aranıyor...');

    // 1. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingValue'] != null) {
        final val = (rating!['ratingValue'] as num).toDouble();
        print('[aggregateRating] N11Scraper: JSON-LD ile ratingValue bulundu: $val');
        return val;
      }
    }

    // 2. window.model Fallback
    final model = _getN11Model(document);
    if (model != null) {
      final ratingScore = _findValueRecursive(model, 'ratingScore') ??
                          _findValueRecursive(model, 'ratingValue') ??
                          _findValueRecursive(model, 'averageRating');
      if (ratingScore != null) {
        final parsed = double.tryParse(ratingScore.toString().replaceAll(',', '.'));
        if (parsed != null && parsed > 0 && parsed <= 5.0) {
          print('[aggregateRating] N11Scraper: window.model ile ratingValue bulundu: $parsed');
          return parsed;
        }
      }
    }

    // 3. DOM Fallback
    final ratingEl = document.querySelector('.ratingScore') ??
                     document.querySelector('[itemprop="ratingValue"]') ??
                     document.querySelector('.rating-score') ??
                     document.querySelector('.rating-cont .rating-text');
    if (ratingEl != null) {
      final text = ratingEl.text.trim();
      final match = RegExp(r'([0-5][.,]\d)').firstMatch(text);
      if (match != null) {
        final parsed = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        if (parsed != null && parsed > 0 && parsed <= 5.0) {
          print('[aggregateRating] N11Scraper: DOM ile ratingValue bulundu: $parsed');
          return parsed;
        }
      }
    }

    print('[aggregateRating] N11Scraper: ratingValue bulunamadı (null)');
    return null;
  }

  @override
  int? scrapeRatingCount(dom.Document document) {
    print('[aggregateRating] N11Scraper: ratingCount/reviewCount aranıyor...');

    // 1. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingCount'] != null) {
        final cnt = (rating!['ratingCount'] as num).toInt();
        print('[aggregateRating] N11Scraper: JSON-LD ile ratingCount/reviewCount bulundu: $cnt');
        return cnt;
      }
    }

    // 2. window.model Fallback
    final model = _getN11Model(document);
    if (model != null) {
      final reviewCount = _findValueRecursive(model, 'reviewCount') ??
                          _findValueRecursive(model, 'ratingCount') ??
                          _findValueRecursive(model, 'commentCount');
      if (reviewCount != null) {
        final parsed = int.tryParse(reviewCount.toString());
        if (parsed != null && parsed > 0) {
          print('[aggregateRating] N11Scraper: window.model ile ratingCount bulundu: $parsed');
          return parsed;
        }
      }
    }

    // 3. DOM Fallback
    final countEl = document.querySelector('.ratingCount') ??
                    document.querySelector('[itemprop="reviewCount"]') ??
                    document.querySelector('[itemprop="ratingCount"]') ??
                    document.querySelector('.review-count');
    if (countEl != null) {
      final text = countEl.text.trim();
      final match = RegExp(r'(\d+)').firstMatch(text);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null && parsed > 0) {
          print('[aggregateRating] N11Scraper: DOM ile ratingCount bulundu: $parsed');
          return parsed;
        }
      }
    }

    print('[aggregateRating] N11Scraper: ratingCount bulunamadı (null)');
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    print('[aggregateRating] N11Scraper: brand (marka) aranıyor...');

    // 1. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) {
        print('[aggregateRating] N11Scraper: JSON-LD ile brand bulundu: $brand');
        return brand;
      }
    }

    // 2. window.model Fallback
    final model = _getN11Model(document);
    if (model != null) {
      final brand = model['product']?['brand']?['name'] ??
                    model['product']?['brandName'] ??
                    _findValueRecursive(model, 'brandName');
      if (brand != null && brand.toString().trim().isNotEmpty) {
        final text = brand.toString().trim();
        print('[aggregateRating] N11Scraper: window.model ile brand bulundu: $text');
        return text;
      }
    }

    // 3. DOM Fallback
    final brandEl = document.querySelector('.brand-name') ??
                    document.querySelector('[itemprop="brand"]') ??
                    document.querySelector('.unf-p-detail-brand');
    if (brandEl != null) {
      final text = brandEl.text.trim();
      if (text.isNotEmpty) {
        print('[aggregateRating] N11Scraper: DOM ile brand bulundu: $text');
        return text;
      }
    }

    print('[aggregateRating] N11Scraper: brand bulunamadı (null)');
    return null;
  }
}
