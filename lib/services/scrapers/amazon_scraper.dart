import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class AmazonScraper extends BaseProductScraper {
  @override
  String get domain => 'amazon.'; // Hem amazon.com hem amazon.com.tr hem de amzn.eu için canHandle ezilecek

  @override
  bool canHandle(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('amazon.') || 
           lowerUrl.contains('amzn.') || 
           lowerUrl.contains('link.amazon');
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. Amazon dynamicImage data attribute'larını parse et
    final dynamicImages = document.querySelectorAll('[data-a-dynamic-image]');
    for (final element in dynamicImages) {
      try {
        final attr = element.attributes['data-a-dynamic-image'];
        if (attr != null && attr.isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(attr);
          if (data.isNotEmpty) {
            final firstKey = data.keys.first;
            if (firstKey.isNotEmpty && !firstKey.startsWith('data:') && !isLogoUrl(firstKey)) {
              final resolved = resolveImageUrl(firstKey, url);
              if (resolved != null) {
                log('✅ Amazon dynamic image bulundu: $resolved');
                return resolved;
              }
            }
          }
        }
      } catch (e) {
        log('⚠️ Amazon dynamic image parse hatası: $e');
      }
    }
    
    // 2. Amazon'un ürün görseli için özel selector'lar
    final amazonSelectors = [
      '#landingImage',
      '#imgBlkFront',
      '#main-image',
      '#imageBlock_feature_div img',
      '#imageBlock img',
      '#altImages img',
      '.a-dynamic-image',
      '[id*="landingImage"]',
      '[id*="main-image"]',
    ];
    
    for (final selector in amazonSelectors) {
      final images = document.querySelectorAll(selector);
      for (final img in images) {
        String? imageUrl = img.attributes['src'] ?? 
                         img.attributes['data-src'] ?? 
                         img.attributes['data-a-dynamic-image'] ??
                         img.attributes['data-old-src'];
        
        if (imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('data:')) {
          // Amazon'un placeholder görsellerini atla
          if (imageUrl.contains('pixel') || 
              imageUrl.contains('placeholder') ||
              imageUrl.contains('spinner') ||
              imageUrl.contains('loading')) {
            continue;
          }
          
          // Amazon CDN görsellerini tercih et
          if (imageUrl.contains('images-na.ssl-images-amazon.com') ||
              imageUrl.contains('images-eu.ssl-images-amazon.com') ||
              imageUrl.contains('images-amazon.com')) {
            final resolved = resolveImageUrl(imageUrl, url);
            if (resolved != null && !isLogoUrl(resolved)) {
              log('✅ Amazon görsel bulundu: $resolved');
              return resolved;
            }
          }
        }
      }
    }
    
    // 3. Amazon JSON-LD schema'dan görsel çek
    final amazonJsonLd = document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in amazonJsonLd) {
      try {
        final jsonContent = script.text;
        if (jsonContent.contains('Product') || jsonContent.contains('image')) {
          final jsonData = jsonDecode(jsonContent);
          final imageUrl = _extractImageFromJson(jsonData);
          if (imageUrl != null && imageUrl.isNotEmpty && !isLogoUrl(imageUrl)) {
            final resolved = resolveImageUrl(imageUrl, url);
            if (resolved != null) {
              log('✅ Amazon JSON-LD görsel bulundu: $resolved');
              return resolved;
            }
          }
        }
      } catch (e) {
        // JSON parse hatası, devam et
      }
    }
    
    return null;
  }

  String? _extractImageFromJson(dynamic jsonData) {
    if (jsonData is Map) {
      if (jsonData['image'] != null) {
        if (jsonData['image'] is String) {
          return jsonData['image'] as String;
        } else if (jsonData['image'] is Map && jsonData['image']['url'] != null) {
          return jsonData['image']['url'] as String;
        } else if (jsonData['image'] is List && jsonData['image'].isNotEmpty) {
          final firstImage = jsonData['image'][0];
          if (firstImage is String) {
            return firstImage;
          } else if (firstImage is Map && firstImage['url'] != null) {
            return firstImage['url'] as String;
          }
        }
      }

      if (jsonData['@graph'] != null && jsonData['@graph'] is List) {
        for (final item in jsonData['@graph'] as List) {
          final image = _extractImageFromJson(item);
          if (image != null) return image;
        }
      }

      if (jsonData['itemListElement'] != null && jsonData['itemListElement'] is List) {
        for (final item in jsonData['itemListElement'] as List) {
          final image = _extractImageFromJson(item);
          if (image != null) return image;
        }
      }

      for (final value in jsonData.values) {
        final image = _extractImageFromJson(value);
        if (image != null) return image;
      }
    }
    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    final titleEl = document.querySelector('#productTitle') ??
                    document.querySelector('#title') ??
                    document.querySelector('.a-size-large.product-title-word-break');
    if (titleEl != null) {
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. En öncelikli yeni yapı: twister-plus-buying-options-price-data JSON kutusunu çöz
    final twisterEl = document.querySelector('.twister-plus-buying-options-price-data');
    if (twisterEl != null) {
      try {
        final jsonStr = twisterEl.text.trim();
        final data = jsonDecode(jsonStr);
        if (data is Map) {
          for (final key in data.keys) {
            final list = data[key];
            if (list is List && list.isNotEmpty) {
              final firstObj = list[0];
              if (firstObj is Map) {
                final priceAmount = firstObj['priceAmount'];
                if (priceAmount != null) {
                  final parsed = double.tryParse(priceAmount.toString());
                  if (parsed != null && parsed > 0) {
                    return parsed;
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Depo / İkinci El / Yenilenmiş Özel Seçiciler
    final depoSelectors = [
      '#apex-pricetopay-accessibility-label',
      '.apex-pricetopay-value',
      '#usedBuySection .offer-price',
      '#usedAccordionRow .offer-price',
      '#usedBuyBoxContainer .offer-price',
      '.rbbHeader .offer-price',
      '#usedBuySection .a-color-price',
      '#usedAccordionRow .a-color-price',
      '#usedBuySection .a-price',
      '#usedAccordionRow .a-price'
    ];

    for (final selector in depoSelectors) {
      final el = document.querySelector(selector);
      if (el != null) {
        final val = parsePriceText(el.text);
        if (val != null && val > 0) {
          return val;
        }
      }
    }

    // 3. Birincil Satış Fiyatı Seçicileri
    final primarySelectors = [
      '#rightCol #tp_price_block_total_price_ww .a-offscreen',
      '#rightCol #tp_price_block_total_price_ww .aok-offscreen',
      '#corePrice_feature_div .a-price .a-offscreen',
      '#corePrice_feature_div .a-price .aok-offscreen',
      '#corePriceDisplay_desktop_feature_div .a-price .a-offscreen',
      '#corePriceDisplay_desktop_feature_div .a-price .aok-offscreen',
      '#corePriceDisplay_desktop_feature_div .a-price',
      '#rightCol .priceToPay .a-offscreen',
      '#rightCol .priceToPay .aok-offscreen',
      '#centerCol .priceToPay .a-offscreen',
      '#centerCol .priceToPay .aok-offscreen',
      '#rightCol .apexPriceToPay .a-offscreen',
      '#rightCol .apexPriceToPay .aok-offscreen',
      '#centerCol .apexPriceToPay .a-offscreen',
      '#centerCol .apexPriceToPay .aok-offscreen',
      '#rightCol #aod-ingress-link .a-price .a-offscreen',
      '#price_inside_buybox',
      '#priceBlock_dealPrice',
      '#priceBlock_ourPrice',
      '.priceToPay',
      '.apexPriceToPay'
    ];

    for (final selector in primarySelectors) {
      final el = document.querySelector(selector);
      if (el != null) {
        if (!_hasAncestorWithClass(el, 'a-text-price')) { // Üstü çizili değilse
          final val = parsePriceText(el.text);
          if (val != null && val > 0) {
            return val;
          }
        }
      }
    }

    // 4. Genel .a-price, .a-offscreen, .aok-offscreen ve .offer-price etiketlerinden üstü çizili olmayan en düşük fiyatı seç
    final offscreenEls = document.querySelectorAll(
      '.a-price .a-offscreen, '
      '.a-price .aok-offscreen, '
      '.offer-price, '
      '.a-price'
    );
    double? bestPrice;
    for (final el in offscreenEls) {
      if (_hasAncestorWithClass(el, 'a-text-price')) {
        continue; // Üstü çizili liste fiyatını atla
      }
      final val = parsePriceText(el.text);
      if (val != null && val > 0) {
        if (bestPrice == null || val < bestPrice) {
          bestPrice = val;
        }
      }
    }
    if (bestPrice != null) return bestPrice;

    // 5. Fallback: Eğer yukarıdakiler bulunamadıysa, sayfa genelindeki ilk geçerli fiyatı dön
    final allOffscreenEls = document.querySelectorAll('.a-price .a-offscreen, .a-price .aok-offscreen, .offer-price');
    for (final el in allOffscreenEls) {
      final val = parsePriceText(el.text);
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
      '#corePrice_desktop .a-text-price span.a-offscreen',
      '#corePrice_feature_div .a-text-price span.a-offscreen',
      '#corePriceDisplay_desktop_feature_div .a-text-price span.a-offscreen',
      '#apex_desktop .a-text-price span.a-offscreen',
      '.basisPrice .a-text-price span.a-offscreen',
      '.listPrice .a-text-price span.a-offscreen',
      'span.a-price[data-a-strike="true"] span.a-offscreen',
      'span.a-text-price[data-a-strike="true"] span.a-offscreen',
      '.a-text-strike',
      '#priceBlock_listPrice',
      '#listPrice',
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
    // meta[name="description"] veya og:description içerisinden çek
    final descEl = document.querySelector('meta[name="description"]') ??
                   document.querySelector('meta[property="og:description"]') ??
                   document.querySelector('meta[property="twitter:description"]');
    if (descEl != null) {
      return descEl.attributes['content']?.trim();
    }
    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final List<String> list = [];
    final productTitle = scrapeTitle(document) ?? '';

    // 1. Standart Amazon Breadcrumb Seçicileri (En güvenilir olandır)
    final breadcrumbElements = document.querySelectorAll(
      '#wayfinding-breadcrumbs_feature_div ul li a, '
      '#wayfinding-breadcrumbs_container ul li a, '
      '.a-breadcrumb a, '
      '#wayfinding-breadcrumbs_feature_div li a, '
      '#wayfinding-breadcrumbs_container li a'
    );

    for (final el in breadcrumbElements) {
      final text = el.text.trim();
      if (text.isNotEmpty) {
        final lower = text.toLowerCase();
        if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('amazon') && text != productTitle && text.length < 50) {
          list.add(text);
        }
      }
    }

    if (list.isNotEmpty) return list;

    // 2. Alt Menü Altındaki Aktif Öğe (#nav-subnav a.nav-b)
    final activeSubnav = document.querySelector('#nav-subnav a.nav-b, #nav-subnav .nav-b, #nav-subnav a[class*="nav-b"]');
    if (activeSubnav != null) {
      final text = activeSubnav.text.trim();
      if (text.isNotEmpty) {
        final lower = text.toLowerCase();
        if (lower != 'anasayfa' && lower != 'ana sayfa' && !lower.contains('amazon') && text != productTitle && text.length < 50) {
          return [text];
        }
      }
    }

    // 3. Alt Menü data-category Değeri veya İlk Öğe
    final navSubnav = document.querySelector('#nav-subnav');
    if (navSubnav != null) {
      final dataCat = navSubnav.attributes['data-category'];
      if (dataCat != null && dataCat.isNotEmpty) {
        var friendlyName = dataCat.trim();
        if (friendlyName.toLowerCase() == 'electronics') friendlyName = 'Elektronik';
        else if (friendlyName.toLowerCase() == 'books') friendlyName = 'Kitap';
        else if (friendlyName.toLowerCase() == 'fashion') friendlyName = 'Moda';
        else if (friendlyName.toLowerCase() == 'home') friendlyName = 'Ev ve Yaşam';
        
        return [friendlyName];
      }
    }

    return [];
  }

  @override
  double? scrapeRatingValue(dom.Document document) {
    print('[aggregateRating] AmazonScraper: ratingValue aranıyor...');
    
    // 1. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingValue'] != null) {
        final val = (rating!['ratingValue'] as num).toDouble();
        print('[aggregateRating] AmazonScraper: JSON-LD ile ratingValue bulundu: $val');
        return val;
      }
    }

    // 2. DOM Seçicileri
    final popover = document.querySelector('#averageCustomerReviews .a-icon-alt') ??
                    document.querySelector('#acrPopover .a-icon-alt') ??
                    document.querySelector('span.a-icon-alt');
    if (popover != null) {
      final text = popover.text.trim();
      final match = RegExp(r'([0-5][.,]\d)').firstMatch(text);
      if (match != null) {
        final parsed = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        if (parsed != null && parsed > 0 && parsed <= 5.0) {
          print('[aggregateRating] AmazonScraper: DOM (.a-icon-alt) ile ratingValue bulundu: $parsed');
          return parsed;
        }
      }
    }

    final ratingTextEl = document.querySelector('span[data-hook="rating-out-of-text"]');
    if (ratingTextEl != null) {
      final text = ratingTextEl.text.trim();
      final match = RegExp(r'([0-5][.,]\d)').firstMatch(text);
      if (match != null) {
        final parsed = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        if (parsed != null && parsed > 0 && parsed <= 5.0) {
          print('[aggregateRating] AmazonScraper: DOM (rating-out-of-text) ile ratingValue bulundu: $parsed');
          return parsed;
        }
      }
    }

    final starIcon = document.querySelector('i[class*="a-star-"]');
    if (starIcon != null) {
      final cls = starIcon.attributes['class'] ?? '';
      final match = RegExp(r'a-star-(\d+)(?:-(\d+))?').firstMatch(cls);
      if (match != null) {
        final major = match.group(1);
        final minor = match.group(2) ?? '0';
        final parsed = double.tryParse('$major.$minor');
        if (parsed != null && parsed > 0 && parsed <= 5.0) {
          print('[aggregateRating] AmazonScraper: DOM (a-star class) ile ratingValue bulundu: $parsed');
          return parsed;
        }
      }
    }

    print('[aggregateRating] AmazonScraper: ratingValue bulunamadı (null)');
    return null;
  }

  @override
  int? scrapeRatingCount(dom.Document document) {
    print('[aggregateRating] AmazonScraper: ratingCount/reviewCount aranıyor...');

    // 1. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final rating = extractRatingFromProductJson(productJson);
      if (rating?['ratingCount'] != null) {
        final cnt = (rating!['ratingCount'] as num).toInt();
        print('[aggregateRating] AmazonScraper: JSON-LD ile ratingCount/reviewCount bulundu: $cnt');
        return cnt;
      }
    }

    // 2. DOM Seçicileri
    final selectors = [
      '#acrCustomerReviewText',
      '#acrCustomerReviewLink',
      'span[data-hook="total-review-count"]',
      '#totalReviewCount',
      '[itemprop="reviewCount"]',
      '[itemprop="ratingCount"]',
    ];

    for (final selector in selectors) {
      final el = document.querySelector(selector);
      if (el != null) {
        final text = el.text.trim();
        final match = RegExp(r'(\d[\d.,]*)').firstMatch(text);
        if (match != null) {
          final clean = match.group(1)!.replaceAll('.', '').replaceAll(',', '');
          final parsed = int.tryParse(clean);
          if (parsed != null && parsed > 0) {
            print('[aggregateRating] AmazonScraper: DOM ($selector) ile ratingCount bulundu: $parsed');
            return parsed;
          }
        }
      }
    }

    print('[aggregateRating] AmazonScraper: ratingCount bulunamadı (null)');
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    print('[aggregateRating] AmazonScraper: brand (marka) aranıyor...');

    // 1. JSON-LD Şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty) {
        print('[aggregateRating] AmazonScraper: JSON-LD ile brand bulundu: $brand');
        return brand;
      }
    }

    // 2. DOM Seçicileri
    final poBrand = document.querySelector('tr.po-brand td.po-break-word') ??
                    document.querySelector('tr.po-brand span.a-size-base');
    if (poBrand != null) {
      final text = poBrand.text.trim();
      if (text.isNotEmpty && text != 'Marka') {
        print('[aggregateRating] AmazonScraper: DOM (tr.po-brand) ile brand bulundu: $text');
        return text;
      }
    }

    final byline = document.querySelector('#bylineInfo') ?? document.querySelector('a#bylineInfo');
    if (byline != null) {
      var text = byline.text.trim();
      text = text
        .replaceAll(RegExp(r'Marka:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'Brand:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'Store’u ziyaret edin', caseSensitive: false), '')
        .replaceAll(RegExp(r"Store'u ziyaret edin", caseSensitive: false), '')
        .replaceAll(RegExp(r'Visit the\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Store', caseSensitive: false), '')
        .trim();
      if (text.isNotEmpty) {
        print('[aggregateRating] AmazonScraper: DOM (#bylineInfo) ile brand bulundu: $text');
        return text;
      }
    }

    print('[aggregateRating] AmazonScraper: brand bulunamadı (null)');
    return null;
  }

  bool _hasAncestorWithClass(dom.Element element, String className) {
    dom.Element? current = element.parent;
    while (current != null) {
      if (current.classes.contains(className)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}
