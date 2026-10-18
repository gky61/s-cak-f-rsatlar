import 'dart:async';
import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

/// CarrefourSA (carrefoursa.com) için özel ürün kazıma sınıfı.
/// JSON-LD Product/BreadcrumbList şemaları, PDP kampanya/kart fiyat kartları ve
/// `campaignList` script değişkenlerini destekler.
class CarrefoursaScraper extends BaseProductScraper {
  @override
  String get domain => 'carrefoursa.com';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('carrefoursa.com');
  }

  @override
  String? scrape({
    required dom.Document document,
    required String url,
    required bool Function(String urlString) isLogoUrl,
    required String? Function(String? imageUrl, String pageUrl) resolveImageUrl,
    required void Function(String message) log,
  }) {
    // 1. JSON-LD Product şeması görseli (yüksek çözünürlüklü mnresize/600/600/)
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['image'] != null) {
      final imgLd = extractImageFromProductJson(productJson['image']);
      if (imgLd != null && imgLd.isNotEmpty) {
        final resolved = resolveImageUrl(imgLd, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ CarrefourSA görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph og:image
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ CarrefourSA görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. csfour.com veya carrefoursa ürün görseli selector'ları
    final imgSelectors = [
      'img[src*="images.csfour.com/mnresize/600/600"]',
      'img[src*="images.csfour.com/mnresize"]',
      'img[src*="images.csfour.com"]',
      '.product-detail-slider img',
      '.product-image img',
      '.pdp-image-container img',
    ];

    for (final sel in imgSelectors) {
      final elements = document.querySelectorAll(sel);
      for (final el in elements) {
        final src = el.attributes['data-src'] ?? el.attributes['src'];
        if (src != null && src.isNotEmpty && !src.contains('banner') && !src.contains('icon')) {
          final resolved = resolveImageUrl(src, url);
          if (resolved != null && !isLogoUrl(resolved)) {
            log('✅ CarrefourSA görseli DOM selector ile bulundu: $resolved');
            return resolved;
          }
        }
      }
    }

    return null;
  }

  @override
  String? scrapeTitle(dom.Document document) {
    // 1. JSON-LD Product şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['name'] != null) {
      final name = productJson['name'].toString().trim();
      if (name.isNotEmpty) return name;
    }

    // 2. h1 etiketi
    final h1El = document.querySelector('h1');
    if (h1El != null && h1El.text.trim().isNotEmpty) {
      return h1El.text.trim();
    }

    // 3. Open Graph og:title
    final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'];
    if (ogTitle != null && ogTitle.trim().isNotEmpty) {
      return ogTitle.trim().replaceAll(RegExp(r'\s*\|\s*CarrefourSA.*$', caseSensitive: false), '').trim();
    }

    // 4. data-item_name attribute
    final dataNameEl = document.querySelector('[data-item_name]');
    final dataName = dataNameEl?.attributes['data-item_name']?.trim();
    if (dataName != null && dataName.isNotEmpty) {
      return dataName;
    }

    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    // 1. JSON-LD Product şeması
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brand = extractBrandFromProductJson(productJson);
      if (brand != null && brand.isNotEmpty && brand.toUpperCase() != 'MARKASIZ' && !brand.startsWith('BRN-')) {
        return brand;
      }
    }

    // 2. data-item_brand attribute
    final dataBrandEl = document.querySelector('[data-item_brand]');
    final dataBrand = dataBrandEl?.attributes['data-item_brand']?.trim();
    if (dataBrand != null && dataBrand.isNotEmpty && dataBrand.toUpperCase() != 'MARKASIZ' && !dataBrand.startsWith('BRN-')) {
      return dataBrand;
    }

    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. PDP kampanya / indirimli fiyat kartı (CarrefourSA Kart ile)
    final campaignPriceEl = document.querySelector('.pdp-price-card-campaign .item-price, .pdp-price-card-campaign [itemprop="price"]');
    if (campaignPriceEl != null) {
      final contentVal = campaignPriceEl.attributes['content'];
      if (contentVal != null && contentVal.trim().isNotEmpty) {
        final p = double.tryParse(contentVal.trim());
        if (p != null && p > 0) {
          return ((p * 100).roundToDouble()) / 100;
        }
      }
      final parsedText = parsePriceText(campaignPriceEl.text);
      if (parsedText != null && parsedText > 0) {
        return parsedText;
      }
    }

    // 2. JSON-LD Product offers.price
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final p = extractPriceFromProductJson(productJson);
      if (p != null && p > 0) {
        return ((p * 100).roundToDouble()) / 100;
      }
    }

    // 3. Genel .item-price-contain veya .item-price
    final itemPriceEl = document.querySelector('.item-price-contain .item-price, .item-price[itemprop="price"]');
    if (itemPriceEl != null) {
      final contentVal = itemPriceEl.attributes['content'];
      if (contentVal != null && contentVal.trim().isNotEmpty) {
        final p = double.tryParse(contentVal.trim());
        if (p != null && p > 0) {
          return ((p * 100).roundToDouble()) / 100;
        }
      }
      final parsedText = parsePriceText(itemPriceEl.text);
      if (parsedText != null && parsedText > 0) {
        return parsedText;
      }
    }

    // 4. data-price attribute
    final dataPriceEl = document.querySelector('[data-price]');
    final dataPrice = dataPriceEl?.attributes['data-price'];
    if (dataPrice != null && dataPrice.isNotEmpty) {
      final p = double.tryParse(dataPrice);
      if (p != null && p > 0) {
        return ((p * 100).roundToDouble()) / 100;
      }
    }

    return null;
  }

  @override
  FutureOr<double?> scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice != null && currentPrice <= 0) return null;

    // PDP standart / indirimsiz fiyat kartı: .pdp-price-card-regular
    // Not: Alttaki "Benzer Ürünler" / tavsiye slider'larındaki (.hover-box) üzeri çizili fiyatlarla
    // karışmaması için doğrudan .pdp-price-card-regular seçicisi kullanılır.
    final regularPriceEl = document.querySelector('.pdp-price-card-regular .js-variant-price, .pdp-price-card-regular .priceLineThrough, .pdp-price-card-regular .item-price');
    if (regularPriceEl != null) {
      final contentVal = regularPriceEl.attributes['content'];
      if (contentVal != null && contentVal.trim().isNotEmpty) {
        final p = double.tryParse(contentVal.trim());
        if (p != null && (currentPrice == null || p > currentPrice)) {
          return ((p * 100).roundToDouble()) / 100;
        }
      }
      final parsedText = parsePriceText(regularPriceEl.text);
      if (parsedText != null && (currentPrice == null || parsedText > currentPrice)) {
        return parsedText;
      }
    }

    return null;
  }

  @override
  FutureOr<String?> scrapePriceLabel(dom.Document document) {
    // 1. HTML içerisindeki `var campaignList = "CarrefourSA Kart ile 2 Al 1 Öde";` script değişkeni
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (text.contains('campaignList')) {
        final match = RegExp(r'var\s+campaignList\s*=\s*["\x27]([^"\x27]+)["\x27]').firstMatch(text);
        if (match != null) {
          final val = match.group(1)?.trim();
          if (val != null && val.isNotEmpty && !val.toLowerCase().contains('at sepete')) {
            return val;
          }
        }
      }
    }

    // 2. data-campaign_type attribute (örn: data-campaign_type="CarrefourSA Kart ile 2 Al 1 Öde")
    final dataCampEl = document.querySelector('[data-campaign_type]');
    final dataCamp = dataCampEl?.attributes['data-campaign_type']?.trim();
    if (dataCamp != null && dataCamp.isNotEmpty && !dataCamp.toLowerCase().contains('at sepete')) {
      return dataCamp;
    }

    // 3. Kampanya rozeti: .product-detail-badge-position (örn: "CarrefourSA Kart ile 2 Al 1 Öde")
    // DİKKAT: "at sepete", "sepete ekle" gibi genel e-ticaret aksiyon etiketleri kampanya rozeti sanılmamalıdır!
    final campBadgeEl = document.querySelector('.product-detail-badge-position');
    if (campBadgeEl != null) {
      final txt = campBadgeEl.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      final lower = txt.toLowerCase();
      if (txt.isNotEmpty &&
          !lower.contains('at sepete') &&
          !lower.contains('sepete at') &&
          !lower.contains('sepete ekle') &&
          (lower.contains('kart') || lower.contains('al') || lower.contains('öde') || lower.contains('%') || lower.contains('indirim'))) {
        return txt;
      }
    }

    // 4. PDP kart kampanyası veya indirim rozeti: .pdp-price-card-campaign veya .pd-price-cont .disc-badge-new
    if (document.querySelector('.pdp-price-card-campaign') != null || document.querySelector('.pd-price-cont .disc-badge-new') != null) {
      final campaignLabelEl = document.querySelector('.pdp-price-card-campaign .pdp-price-card-label');
      if (campaignLabelEl != null) {
        final txt = campaignLabelEl.text.trim();
        if (txt.isNotEmpty) {
          return txt;
        }
      }
      return 'CarrefourSA Kart ile';
    }

    return null;
  }

  @override
  FutureOr<double?> scrapeRatingValue(dom.Document document) {
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final r = extractRatingFromProductJson(productJson);
      if (r != null && r['ratingValue'] != null) {
        return (r['ratingValue'] as num).toDouble();
      }
    }
    return null;
  }

  @override
  FutureOr<int?> scrapeRatingCount(dom.Document document) {
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final r = extractRatingFromProductJson(productJson);
      if (r != null && r['ratingCount'] != null) {
        return (r['ratingCount'] as num).toInt();
      }
    }
    return null;
  }

  @override
  FutureOr<String?> scrapeDescription(dom.Document document) {
    // 1. JSON-LD Product description
    final productJson = findProductJsonLd(document);
    if (productJson != null && productJson['description'] != null) {
      final desc = productJson['description'].toString().trim();
      if (desc.isNotEmpty) return desc;
    }

    // 2. Open Graph og:description
    final ogDesc = document.querySelector('meta[property="og:description"]')?.attributes['content'];
    if (ogDesc != null && ogDesc.trim().isNotEmpty) return ogDesc.trim();

    // 3. Meta name="description"
    final metaDesc = document.querySelector('meta[name="description"]')?.attributes['content'];
    if (metaDesc != null && metaDesc.trim().isNotEmpty) return metaDesc.trim();

    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final productTitle = scrapeTitle(document) ?? '';
    
    // 1. JSON-LD BreadcrumbList
    final scripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
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
                  if (lower != 'ana sayfa' && lower != 'home' && !lower.contains('carrefoursa') && str != productTitle) {
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

    // 2. data-item_category fallback
    final dataEl = document.querySelector('[data-item_category]');
    if (dataEl != null) {
      final List<String> cats = [];
      for (int i = 1; i <= 5; i++) {
        final attr = i == 1 ? 'data-item_category' : 'data-item_category$i';
        final val = dataEl.attributes[attr]?.trim();
        if (val != null && val.isNotEmpty && val != productTitle) {
          cats.add(val);
        }
      }
      if (cats.isNotEmpty) return cats;
    }

    return [];
  }
}
