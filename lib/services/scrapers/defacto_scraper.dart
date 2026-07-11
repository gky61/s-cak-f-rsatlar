import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class DefactoScraper extends BaseProductScraper {
  @override
  String get domain => 'defacto.com.tr';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('defacto.com.tr');
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. og:image tag'i dene (Defacto için son derece güvenlidir)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Defacto görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final imgSelectors = [
      '.product-card__image img',
      '.product-image img',
      'img[class*="product"]',
      'main img',
    ];
    for (final selector in imgSelectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final src = element.attributes['src'] ?? element.attributes['data-src'];
        if (src != null && src.isNotEmpty && !isLogoUrl(src)) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null) {
            log('✅ Defacto görseli DOM ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. Script bloğundan çekmeyi dene (Öncelikli)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('PRODUCT_DETAIL_LASTVISITED') || text.contains('PRODUCT_DETAIL_INFO')) {
        final match = RegExp(r'"?ProductVariantMiniProductName"?\s*:\s*"([^"]+)"').firstMatch(text) ??
                      RegExp(r'"?Name"?\s*:\s*"([^"]+)"').firstMatch(text) ??
                      RegExp(r'"?name"?\s*:\s*"([^"]+)"').firstMatch(text);
        if (match != null) {
          final title = match.group(1);
          if (title != null && title.isNotEmpty) {
            return _decodeUnicode(title);
          }
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final titleEl = document.querySelector('h1.product-card__title') ?? 
                    document.querySelector('.product-title') ?? 
                    document.querySelector('h1');
    if (titleEl != null) {
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. Script bloğundan (Öncelikli)
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('PRODUCT_DETAIL_LASTVISITED') || text.contains('CampaignBadge')) {
        // Fiyat belirleme algoritması:
        // A) Sepette indirimli fiyat (DiscountPrice) varsa bunu kullan
        final discountPriceMatch = RegExp(r'"?DiscountPrice"?\s*:\s*([0-9.]+)').firstMatch(text);
        if (discountPriceMatch != null) {
          final val = double.tryParse(discountPriceMatch.group(1)!);
          if (val != null && val > 0) return val;
        }

        // B) DataLayer altındaki CampaignDiscountedPrice varsa bunu kullan
        final campaignDiscountMatch = RegExp(r'"?CampaignDiscountedPrice"?\s*:\s*([0-9.]+)').firstMatch(text);
        if (campaignDiscountMatch != null) {
          final val = double.tryParse(campaignDiscountMatch.group(1)!);
          if (val != null && val > 0) return val;
        }

        // C) Ürünün standart indirimli fiyatı (ProductVariantMiniDiscountedPriceInclTax)
        final miniDiscountMatch = RegExp(r'"?ProductVariantMiniDiscountedPriceInclTax"?\s*:\s*"([0-9.]+)"').firstMatch(text);
        if (miniDiscountMatch != null) {
          final val = double.tryParse(miniDiscountMatch.group(1)!);
          if (val != null && val > 0) return val;
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    final priceSelectors = [
      '.product-price__discount',
      '.product-price',
      'span[class*="price"]',
    ];
    for (final selector in priceSelectors) {
      final priceEl = document.querySelector(selector);
      if (priceEl != null) {
        final parsed = parsePriceText(priceEl.text);
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    return null;
  }

  @override
  String? scrapeDescription(dom.Document document) {
    // 1. DOM meta description
    final descEl = document.querySelector('meta[name="description"]') ?? 
                   document.querySelector('meta[property="og:description"]');
    if (descEl != null) {
      final content = descEl.attributes['content']?.trim();
      if (content != null && content.isNotEmpty && content.toLowerCase() != 'null') {
        return content;
      }
    }
    return null;
  }

  String _decodeUnicode(String input) {
    var text = input;
    text = text.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
      final hexCode = match.group(1)!;
      final charCode = int.parse(hexCode, radix: 16);
      return String.fromCharCode(charCode);
    });
    text = text
      .replaceAll('&#x131;', 'ı')
      .replaceAll('&#x130;', 'İ')
      .replaceAll('&#x15F;', 'ş')
      .replaceAll('&#x15E;', 'Ş')
      .replaceAll('&#xE7;', 'ç')
      .replaceAll('&#xC7;', 'Ç')
      .replaceAll('&#xF6;', 'ö')
      .replaceAll('&#xD6;', 'Ö')
      .replaceAll('&#xFC;', 'ü')
      .replaceAll('&#xDC;', 'Ü')
      .replaceAll('&#x11F;', 'ğ')
      .replaceAll('&#x11E;', 'Ğ')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&');
    return text;
  }
}
