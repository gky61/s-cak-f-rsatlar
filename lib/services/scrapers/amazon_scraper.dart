import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class AmazonScraper extends BaseProductScraper {
  @override
  String get domain => 'amazon.'; // Hem amazon.com hem amazon.com.tr hem de amzn.eu için canHandle ezilecek

  @override
  bool canHandle(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('amazon.') || lowerUrl.contains('amzn.');
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

    // 2. Birinci öncelik: .a-price içindeki .a-offscreen (Genelde en temiz fiyattır: "₺39.972,00")
    final offscreenEl = document.querySelector('.a-price .a-offscreen');
    if (offscreenEl != null) {
      final val = parsePriceText(offscreenEl.text);
      if (val != null && val > 0) {
        return val;
      }
    }

    // 3. İkinci öncelik: Klasik .a-price-whole
    final priceEl = document.querySelector('.a-price-whole');
    if (priceEl != null) {
      final decimalEl = priceEl.querySelector('.a-price-decimal');
      String text = priceEl.text;
      if (decimalEl != null) {
        text = text.replaceAll(decimalEl.text, '');
      }
      final val = parsePriceText(text);
      if (val != null && val > 0) {
        return val;
      }
    }

    // 4. Üçüncü öncelik: Buybox veya diğer bilinen fiyat kimlikleri
    final alternativeSelectors = [
      '#price_inside_buybox',
      '#priceBlock_ourPrice',
      '#priceBlock_dealPrice',
      '.apexPriceToPay',
    ];
    for (final selector in alternativeSelectors) {
      final el = document.querySelector(selector);
      if (el != null) {
        final val = parsePriceText(el.text);
        if (val != null && val > 0) {
          return val;
        }
      }
    }

    return null;
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
}
