import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class _HbApiPriceResult {
  final double? price;
  final bool isPremium;
  final String? campaignName;

  _HbApiPriceResult({
    this.price,
    this.isPremium = false,
    this.campaignName,
  });
}

class HepsiburadaScraper extends BaseProductScraper {
  _HbApiPriceResult? _lastApiResult;

  @override
  String get domain => 'hepsiburada.com';

  @override
  bool canHandle(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('hepsiburada.com') || lowerUrl.contains('hb.biz');
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
          log('✅ Hepsiburada görseli JSON-LD ile bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 2. Open Graph meta tag'i dene (Fallback 1)
    final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (ogImage != null && ogImage.isNotEmpty) {
      final resolved = resolveImageUrl(ogImage, url);
      if (resolved != null && !isLogoUrl(resolved)) {
        log('✅ Hepsiburada görseli og:image ile bulundu: $resolved');
        return resolved;
      }
    }

    // 3. reduxStore'dan media alanından görsel çek (Fallback 2)
    // Microlink prerender HTML'inde JSON-LD ve og:image yok ama reduxStore.productState.product.media var.
    // URL formatı: https://productimages.hepsiburada.net/s/777/{size}/110000671504006.jpg
    // {size} parametresini 500 ile değiştiriyoruz.
    final reduxScript = document.getElementById('reduxStore');
    if (reduxScript != null) {
      try {
        final Map<String, dynamic> reduxData = jsonDecode(reduxScript.text);
        final reduxProduct = reduxData['productState']?['product'];
        final media = reduxProduct?['media'];
        if (media is List && media.isNotEmpty) {
          final mediaUrl = media[0]['url']?.toString();
          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            final resolvedMediaUrl = mediaUrl.replaceAll('{size}', '500');
            if (!isLogoUrl(resolvedMediaUrl)) {
              log('✅ Hepsiburada görseli reduxStore media ile bulundu: $resolvedMediaUrl');
              return resolvedMediaUrl;
            }
          }
        }
      } catch (_) {}
    }

    // 4. Klasik img etiketlerinden ürün görsellerini ara (Fallback 3)
    final productImg = document.querySelector('img[class*="hb-HbImage-view__image"]') ??
                       document.querySelector('.hb-HbImage-view img') ??
                       document.querySelector('img[alt*="ürün"]') ??
                       document.querySelector('img[alt*="Ürün"]');
    if (productImg != null) {
      final src = productImg.attributes['src'] ?? productImg.attributes['data-src'];
      if (src != null && src.isNotEmpty) {
        final resolved = resolveImageUrl(src, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Hepsiburada görseli img etiketiyle bulundu: $resolved');
          return resolved;
        }
      }
    }

    // 5. data-image attribute'larını dene (Eski akış fallback)
    final hepsiburadaImages = document.querySelectorAll('[data-image], [data-srcset], [data-original-src]');
    for (final element in hepsiburadaImages) {
      final imageUrl = element.attributes['data-image'] ?? 
                      element.attributes['data-srcset']?.split(',').first.trim() ??
                      element.attributes['data-original-src'];
      if (imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('data:')) {
        final resolved = resolveImageUrl(imageUrl, url);
        if (resolved != null && !isLogoUrl(resolved)) {
          log('✅ Hepsiburada görsel attribute ile bulundu: $resolved');
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
    final titleEl = document.querySelector('h1[data-test-id="title"]') ?? 
                    document.querySelector('h1.xeL9CQ3JILmYoQPCgDcl');
    if (titleEl != null) {
      return titleEl.text.trim();
    }
    return null;
  }

  @override
  Future<double?> scrapePrice(dom.Document document) async {
    // 1. Hepsiburada Premium Fiyat Kontrolü (Premium indirimli fiyat önceliklidir - DOM Eşleşmesi)
    final spans = document.querySelectorAll('span');
    for (final span in spans) {
      final text = span.text.trim();
      if (text.startsWith('Premium ile') || text.startsWith('Premium\'la') || text.startsWith('Premium’la')) {
        final bElement = span.querySelector('b');
        if (bElement != null) {
          final parsed = parsePriceText(bElement.text);
          if (parsed != null && parsed > 0) return parsed;
        }
        final cleanText = text
            .replaceAll('Premium ile', '')
            .replaceAll('Premium\'la', '')
            .replaceAll('Premium’la', '')
            .trim();
        final parsed = parsePriceText(cleanText);
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    // 2. Canlı API Çağrıları (Dinamik Fiyat Sorguları - DOM'da Premium fiyat bulunamadıysa)
    // Hepsiburada canlı bot istekleri için Premium fiyatını HTML'e gömmediğinden
    // backend API'lerini (withoutAffordability & otherMerchants) paralel sorgularız.
    _HbApiPriceResult? bestApiResult;
    final script = document.getElementById('reduxStore');
    if (script != null) {
      try {
        final Map<String, dynamic> reduxData = jsonDecode(script.text);
        final productState = reduxData['productState'];
        final product = productState?['product'];
        if (productState != null && product != null) {
          final results = await Future.wait([
            _fetchWithoutAffordabilityPrice(document),
            _fetchOtherMerchantsPrice(document, productState, product),
          ]);

          final withoutAffordabilityRes = results[0];
          final otherMerchantsRes = results[1];

          if (withoutAffordabilityRes != null && withoutAffordabilityRes.price != null && withoutAffordabilityRes.price! > 0) {
            bestApiResult = withoutAffordabilityRes;
          }
          if (otherMerchantsRes != null && otherMerchantsRes.price != null && otherMerchantsRes.price! > 0) {
            if (bestApiResult == null ||
                otherMerchantsRes.price! < bestApiResult.price! ||
                (otherMerchantsRes.price! == bestApiResult.price! && otherMerchantsRes.isPremium && !bestApiResult.isPremium)) {
              bestApiResult = otherMerchantsRes;
            }
          }
        }
      } catch (_) {}
    } else {
      // reduxStore bulunamadıysa fallback olarak withoutAffordability API'sini doğrudan dene
      bestApiResult = await _fetchWithoutAffordabilityPrice(document);
    }

    _lastApiResult = bestApiResult;
    if (bestApiResult != null && bestApiResult.price != null && bestApiResult.price! > 0) {
      return bestApiResult.price;
    }

    // 3. JSON-LD şemasından (Öncelikli normal fiyat)
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final priceVal = extractPriceFromProductJson(productJson);
      if (priceVal != null && priceVal > 0) {
        return priceVal;
      }
    }

    // 4. HTML Redux Fiyatları Fallback
    if (script != null) {
      try {
        final Map<String, dynamic> reduxData = jsonDecode(script.text);
        final product = reduxData['productState']?['product'];
        final pricesList = product?['prices'] as List?;
        if (pricesList != null && pricesList.isNotEmpty) {
          double? minPrice;
          for (final priceObj in pricesList) {
            if (priceObj is Map) {
              final val = double.tryParse(priceObj['value']?.toString() ?? '');
              if (val != null && val > 0) {
                if (minPrice == null || val < minPrice) {
                  minPrice = val;
                }
              }
            }
          }
          if (minPrice != null) {
            return minPrice;
          }
        }
      } catch (_) {}
    }

    // 5. DOM Seçicileri (En son fallback)
    final priceSelectors = [
      '[data-test-id="price-current-value"]',
      '[data-test-id="price"]',
      'span[class*="price"]',
      'div[class*="price-value"]',
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
  double? scrapeOriginalPrice(dom.Document document, double? currentPrice) {
    if (currentPrice == null || currentPrice <= 0) return null;

    final candidates = <double>[];

    // 1. ReduxStore product.prices (SADECE ana ürünün liste/eski fiyatları)
    // Diğer satıcıların (product.listings) yüksek fiyatlarını HARİÇ tutuyoruz.
    final script = document.getElementById('reduxStore');
    if (script != null) {
      try {
        final Map<String, dynamic> reduxData = jsonDecode(script.text);
        final product = reduxData['productState']?['product'];
        if (product != null) {
          final pricesList = product['prices'];
          if (pricesList is List) {
            for (final p in pricesList) {
              if (p is Map) {
                final val = double.tryParse(p['value']?.toString() ?? '');
                if (val != null && val > currentPrice) {
                  candidates.add(val);
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. DOM selectors for old / crossed out prices (Diğer satıcılar bloğu hariç)
    final domSelectors = [
      'del',
      's',
      '[data-test-id*="price-old"]',
      '[data-test-id*="old-price"]',
      '[data-test-id="variant-box-price"]',
      'span[class*="del"]',
      'span[class*="old"]',
      'span[class*="original"]'
    ];

    for (final selector in domSelectors) {
      for (final el in document.querySelectorAll(selector)) {
        // Diğer satıcılar ("other-merchants") alanındaki fiyatları hariç tut
        bool isOtherMerchant = false;
        dom.Element? current = el.parent;
        while (current != null) {
          final className = current.className.toLowerCase();
          final testId = (current.attributes['data-test-id'] ?? '').toLowerCase();
          final id = current.id.toLowerCase();
          if (className.contains('othermerchant') ||
              className.contains('other-merchants') ||
              testId.contains('merchant') ||
              id.contains('othermerchant')) {
            isOtherMerchant = true;
            break;
          }
          current = current.parent;
        }
        if (isOtherMerchant) continue;

        final parsed = parsePriceText(el.text);
        if (parsed != null && parsed > currentPrice) {
          candidates.add(parsed);
        }
      }
    }

    if (candidates.isEmpty) return null;

    final filtered = candidates.where((c) => c > currentPrice && c <= currentPrice * 5).toList();
    if (filtered.isEmpty) return null;

    filtered.sort();
    return filtered.first;
  }

  // --- Private Helper Methods for API Calls ---

  Future<_HbApiPriceResult?> _fetchWithoutAffordabilityPrice(dom.Document document) async {
    final script = document.getElementById('reduxStore');
    if (script == null) return null;

    Map<String, dynamic> reduxData;
    try {
      reduxData = jsonDecode(script.text);
    } catch (_) {
      return null;
    }

    final productState = reduxData['productState'];
    if (productState == null) return null;

    final product = productState['product'];
    if (product == null) return null;

    final sku = product['sku']?.toString() ?? '';
    final productId = product['productId']?.toString() ?? '';
    final brand = product['brand']?.toString() ?? '';
    final listingId = product['listingId']?.toString() ?? '';
    final merchantId = product['merchantId']?.toString() ?? '';
    final definitionId = product['definitionId']?.toString() ?? '';
    final definitionName = product['definitionName']?.toString() ?? '';
    final taxVatRate = product['taxVatRate'] as int? ?? 20;

    double? finalPriceDouble;
    final pricesList = product['prices'] as List?;
    if (pricesList != null && pricesList.isNotEmpty) {
      double? minPrice;
      for (final priceObj in pricesList) {
        if (priceObj is Map) {
          final val = double.tryParse(priceObj['value']?.toString() ?? '');
          if (val != null && val > 0) {
            if (minPrice == null || val < minPrice) {
              minPrice = val;
            }
          }
        }
      }
      finalPriceDouble = minPrice;
    }
    final finalPrice = finalPriceDouble;

    final List<int> rootCategoryList = [];
    final rawCategories = product['rootCategoryList'] as List?;
    if (rawCategories != null) {
      for (final item in rawCategories) {
        if (item is Map) {
          final catIdStr = item['categoryId']?.toString();
          if (catIdStr != null) {
            final catId = int.tryParse(catIdStr);
            if (catId != null && catId > 0) {
              rootCategoryList.add(catId);
            }
          }
        } else if (item is int) {
          rootCategoryList.add(item);
        }
      }
    }

    final List<String> productTags = [];
    final tagList = product['tagList'] as List?;
    if (tagList != null) {
      for (final item in tagList) {
        final tagId = item['tagId']?.toString();
        if (tagId != null && tagId.isNotEmpty) {
          productTags.add(tagId);
        }
      }
    }

    final List<int> campaignIds = [];
    final rawCampaignIds = product['campaignIds'] as List?;
    if (rawCampaignIds != null) {
      for (final idObj in rawCampaignIds) {
        final id = int.tryParse(idObj?.toString() ?? '');
        if (id != null && id > 0) {
          campaignIds.add(id);
        }
      }
    }

    final campaignIdRegExp = RegExp(r'^(\d+)-');
    for (final tag in productTags) {
      final match = campaignIdRegExp.firstMatch(tag);
      if (match != null) {
        final id = int.tryParse(match.group(1)!);
        if (id != null && id > 0 && !campaignIds.contains(id)) {
          campaignIds.add(id);
        }
      }
    }

    final payload = {
      "userId": "",
      "product": {
        "productTags": productTags,
        "finalPrice": finalPrice,
        "sku": sku,
        "listingId": listingId,
        "productId": productId,
        "brand": brand,
        "merchantId": merchantId,
        "rootCategoryList": rootCategoryList,
        "rootBuyingCategoryList": [null],
        "campaignIds": campaignIds,
        "definitionName": definitionName,
        "definitionId": definitionId,
        "finalPriceOnSale": finalPrice,
        "taxVatRate": taxVatRate
      }
    };

    final client = HttpClient();
    client.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36';

    const url = 'https://www.hepsiburada.com/api/v1/withoutAffordability';
    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('content-type', 'application/json');
      request.headers.set('accept', 'application/json, text/plain, */*');
      request.headers.set('origin', 'https://www.hepsiburada.com');
      request.headers.set('referer', 'https://www.hepsiburada.com/');
      request.headers.set('x-gotham_app-key', 'All');
      request.headers.set('x-gotham_is_enabled_evaluate_coupon', 'true');
      request.headers.set('x-gotham_is_enabled_next_eligible_campaign', 'true');
      request.headers.set('x-gotham_is_include_payment_campaigns', 'true');
      request.headers.set('x-gotham_is_include_premium_clubs', 'true');
      
      request.add(utf8.encode(jsonEncode(payload)));
      
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final resJson = jsonDecode(body);
        
        final productResult = resJson['data']?['result']?['product'];
        if (productResult != null) {
          double? lowestCalculatedPrice;
          bool isPremium = false;
          String? campName;

          void updateLowest(double? priceVal, bool premium, String? name) {
            if (priceVal != null) {
              final double p = priceVal;
              if (p > 0) {
                if (lowestCalculatedPrice == null ||
                    p < lowestCalculatedPrice! ||
                    (p == lowestCalculatedPrice! && premium && !isPremium)) {
                  lowestCalculatedPrice = p;
                  isPremium = premium;
                  campName = name;
                }
              }
            }
          }

          final priceData = productResult['priceData'];
          if (priceData != null) {
            final discountedPrice = double.tryParse(priceData['discountedPrice']?.toString() ?? '');
            final bool pPrem = priceData['isPremium'] == true;
            updateLowest(discountedPrice, pPrem, priceData['priceText']?.toString());
            
            final price = double.tryParse(priceData['price']?.toString() ?? '');
            updateLowest(price, false, null);
          }

          final promoData = productResult['promoData']?['data'];
          if (promoData != null) {
            final campEval = promoData['campaignEvaluateResult'];
            if (campEval != null) {
              final premiumResult = campEval['evaluateAsPremiumResult'];
              if (premiumResult != null) {
                final premiumPrice = double.tryParse(premiumResult['discountedPrice']?.toString() ?? '');
                final cText = premiumResult['campaignText']?.toString();
                updateLowest(premiumPrice, true, cText);
              }
              
              final evalResult = campEval['evaluateResult'];
              if (evalResult != null) {
                final evalPrice = double.tryParse(evalResult['discountedPrice']?.toString() ?? '');
                final cText = evalResult['campaignText']?.toString();
                updateLowest(evalPrice, false, cText);
              }

              final normalPrice = double.tryParse(campEval['discountedPrice']?.toString() ?? '');
              if (normalPrice != null) {
                updateLowest(normalPrice, false, campEval['campaignText']?.toString());
              }
            }
          }

          if (lowestCalculatedPrice != null && lowestCalculatedPrice! > 0) {
            return _HbApiPriceResult(
              price: lowestCalculatedPrice,
              isPremium: isPremium,
              campaignName: campName,
            );
          }
        }
      }
    } catch (_) {
      // Fallback silently
    } finally {
      client.close();
    }

    return null;
  }

  Future<_HbApiPriceResult?> _fetchOtherMerchantsPrice(dom.Document document, Map<String, dynamic> productState, Map<String, dynamic> product) async {
    final sku = product['sku']?.toString() ?? '';
    final productId = product['productId']?.toString() ?? '';
    final brand = product['brand']?.toString() ?? '';
    final definitionId = product['definitionId']?.toString() ?? '';
    final definitionName = product['definitionName']?.toString() ?? '';
    final taxVatRate = product['taxVatRate'] as int? ?? 20;

    double? finalPriceDouble;
    final pricesList = product['prices'] as List?;
    if (pricesList != null && pricesList.isNotEmpty) {
      double? minPrice;
      for (final priceObj in pricesList) {
        if (priceObj is Map) {
          final val = double.tryParse(priceObj['value']?.toString() ?? '');
          if (val != null && val > 0) {
            if (minPrice == null || val < minPrice) {
              minPrice = val;
            }
          }
        }
      }
      finalPriceDouble = minPrice;
    }
    final finalPrice = finalPriceDouble;

    final List<int> rootCategoryList = [];
    final rawCategories = product['rootCategoryList'] as List?;
    if (rawCategories != null) {
      for (final item in rawCategories) {
        if (item is Map) {
          final catIdStr = item['categoryId']?.toString();
          if (catIdStr != null) {
            final catId = int.tryParse(catIdStr);
            if (catId != null && catId > 0) {
              rootCategoryList.add(catId);
            }
          }
        } else if (item is int) {
          rootCategoryList.add(item);
        }
      }
    }

    final List<Map<String, dynamic>> otherMerchantsList = [];

    void addListing(Map<String, dynamic> item) {
      final merchantId = item['merchantId']?.toString() ?? '';
      final merchantName = item['merchantName']?.toString() ?? '';
      final listingId = item['listingId']?.toString() ?? '';

      double? itemPriceDouble;
      final itemPrices = item['prices'] as List?;
      if (itemPrices != null && itemPrices.isNotEmpty) {
        double? minItemPrice;
        for (final pObj in itemPrices) {
          if (pObj is Map) {
            final val = double.tryParse(pObj['value']?.toString() ?? '');
            if (val != null && val > 0) {
              if (minItemPrice == null || val < minItemPrice) {
                minItemPrice = val;
              }
            }
          }
        }
        itemPriceDouble = minItemPrice;
      }
      final itemPrice = itemPriceDouble;

      double? minimumPriceForNLastDays;
      final rawMinPrice = item['minimumPriceForNLastDays'];
      if (rawMinPrice != null) {
        minimumPriceForNLastDays = double.tryParse(rawMinPrice.toString());
      }

      final List<String> itemTags = [];
      final rawItemTags = item['productTags'] as List?;
      if (rawItemTags != null) {
        for (final tagObj in rawItemTags) {
          if (tagObj is Map) {
            final tagId = tagObj['tagId']?.toString();
            if (tagId != null && tagId.isNotEmpty) {
              itemTags.add(tagId);
            }
          }
        }
      }
      if (itemTags.isEmpty && item['paymentTag'] != null) {
        final String payTagStr = item['paymentTag'].toString();
        itemTags.addAll(payTagStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
      }

      final List<int> itemCampaignIds = [];
      final rawItemCampaignIds = item['campaignIds'] as List?;
      if (rawItemCampaignIds != null) {
        for (final idObj in rawItemCampaignIds) {
          final id = int.tryParse(idObj?.toString() ?? '');
          if (id != null && id > 0) {
            itemCampaignIds.add(id);
          }
        }
      }

      final campaignIdRegExp = RegExp(r'^(\d+)-');
      for (final tag in itemTags) {
        final match = campaignIdRegExp.firstMatch(tag);
        if (match != null) {
          final id = int.tryParse(match.group(1)!);
          if (id != null && id > 0 && !itemCampaignIds.contains(id)) {
            itemCampaignIds.add(id);
          }
        }
      }

      otherMerchantsList.add({
        "productTags": itemTags,
        "campaignIds": itemCampaignIds,
        "finalPriceOnSale": itemPrice,
        "minimumPriceForNLastDays": minimumPriceForNLastDays,
        "merchantId": merchantId,
        "merchantName": merchantName,
        "listingId": listingId
      });
    }

    addListing(product);

    final rawListings = (product['listings'] ?? productState['listings']) as List?;
    if (rawListings != null) {
      for (final item in rawListings) {
        if (item is Map) {
          addListing(Map<String, dynamic>.from(item));
        }
      }
    }

    if (otherMerchantsList.isEmpty) return null;

    final payload = {
      "userId": "",
      "product": {
        "productTags": [],
        "sku": sku,
        "productId": productId,
        "brand": brand,
        "rootCategoryList": rootCategoryList,
        "rootBuyingCategoryList": rootCategoryList.isNotEmpty ? [rootCategoryList.last] : [null],
        "campaignIds": [],
        "definitionName": definitionName,
        "definitionId": definitionId,
        "finalPriceOnSale": finalPrice,
        "taxVatRate": taxVatRate,
        "otherMerchants": otherMerchantsList
      }
    };

    final client = HttpClient();
    client.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36';

    const url = 'https://www.hepsiburada.com/api/v1/otherMerchants';
    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('content-type', 'application/json');
      request.headers.set('accept', 'application/json, text/plain, */*');
      request.headers.set('origin', 'https://www.hepsiburada.com');
      request.headers.set('referer', 'https://www.hepsiburada.com/');
      request.headers.set('x-gotham_app-key', 'All');
      request.headers.set('x-gotham_is_enabled_evaluate_coupon', 'true');
      request.headers.set('x-gotham_is_enabled_next_eligible_campaign', 'true');
      request.headers.set('x-gotham_is_include_payment_campaigns', 'true');
      request.headers.set('x-gotham_is_include_premium_clubs', 'true');
      
      request.add(utf8.encode(jsonEncode(payload)));
      
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final resJson = jsonDecode(body);
        
        final listingsResult = (resJson['data']?['result']?['products']?['otherMerchants'] ?? resJson['data']?['result']?['listings']) as List?;
        if (listingsResult != null) {
          double? lowestPrice;
          bool isPremium = false;
          String? campName;

          void updateLowest(double? p, bool premium, String? name) {
            if (p != null && p > 0) {
              if (lowestPrice == null ||
                  p < lowestPrice! ||
                  (p == lowestPrice! && premium && !isPremium)) {
                lowestPrice = p;
                isPremium = premium;
                campName = name;
              }
            }
          }

          for (final listingObj in listingsResult) {
            if (listingObj is Map) {
              final priceData = listingObj['priceData'];
              if (priceData != null) {
                final discountedPrice = double.tryParse(priceData['discountedPrice']?.toString() ?? '');
                final bool pPrem = priceData['isPremium'] == true;
                updateLowest(discountedPrice, pPrem, priceData['priceText']?.toString());
                
                final price = double.tryParse(priceData['price']?.toString() ?? '');
                updateLowest(price, false, null);
              }

              final promoData = listingObj['promoData']?['data'];
              if (promoData != null) {
                final campEval = promoData['campaignEvaluateResult'];
                if (campEval != null) {
                  final premiumResult = campEval['evaluateAsPremiumResult'];
                  if (premiumResult != null) {
                    final premiumPrice = double.tryParse(premiumResult['discountedPrice']?.toString() ?? '');
                    final cText = premiumResult['campaignText']?.toString();
                    updateLowest(premiumPrice, true, cText);
                  }
                  
                  final evalResult = campEval['evaluateResult'];
                  if (evalResult != null) {
                    final evalPrice = double.tryParse(evalResult['discountedPrice']?.toString() ?? '');
                    final cText = evalResult['campaignText']?.toString();
                    updateLowest(evalPrice, false, cText);
                  }

                  final normalResult = promoData['campaignEvaluateResult'];
                  if (normalResult != null) {
                    final normalPrice = double.tryParse(normalResult['discountedPrice']?.toString() ?? '');
                    updateLowest(normalPrice, false, campEval['campaignText']?.toString());
                  }
                }
              }
            }
          }

          if (lowestPrice != null && lowestPrice! > 0) {
            return _HbApiPriceResult(
              price: lowestPrice,
              isPremium: isPremium,
              campaignName: campName,
            );
          }
        }
      }
    } catch (_) {
      // Fallback silently
    } finally {
      client.close();
    }

    return null;
  }

  @override
  List<String> scrapeBreadcrumbs(dom.Document document) {
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type == 'application/ld+json') {
        try {
          final sanitizedText = script.text.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
          final data = jsonDecode(sanitizedText);
          final breadcrumbs = _extractBreadcrumbsFromJson(data);
          if (breadcrumbs.isNotEmpty) {
            return breadcrumbs;
          }
        } catch (_) {}
      }
    }

    // DOM Fallback
    var breadcrumbElements = document.querySelectorAll('.breadcrumbs span[itemprop="name"]');
    if (breadcrumbElements.isEmpty) {
      breadcrumbElements = document.querySelectorAll('[data-test-id="breadcrumbs"] li');
    }
    if (breadcrumbElements.isNotEmpty) {
      final List<String> list = [];
      for (final el in breadcrumbElements) {
        final text = el.text.trim();
        if (text.isNotEmpty && text.toLowerCase() != 'anasayfa') {
          list.add(text);
        }
      }
      if (list.isNotEmpty) return list;
    }

    return [];
  }

  List<String> _extractBreadcrumbsFromJson(dynamic json) {
    if (json is Map) {
      // 1. BreadcrumbList kontrolü
      if (json['@type'] == 'BreadcrumbList' || json['@type'] == 'http://schema.org/BreadcrumbList') {
        final items = json['itemListElement'];
        if (items is List) {
          final List<String> breadcrumbs = [];
          for (final item in items) {
            if (item is Map && item['name'] != null) {
              final name = item['name'].toString().trim();
              if (name.isNotEmpty && name.toLowerCase() != 'anasayfa') {
                breadcrumbs.add(name);
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
              .where((e) => e.isNotEmpty && e.toLowerCase() != 'anasayfa')
              .toList();
          if (parts.isNotEmpty) return parts;
        }
      }

      // Recursive arama
      for (final value in json.values) {
        if (value is Map || value is List) {
          final res = _extractBreadcrumbsFromJson(value);
          if (res.isNotEmpty) return res;
        }
      }
    } else if (json is List) {
      for (final item in json) {
        final res = _extractBreadcrumbsFromJson(item);
        if (res.isNotEmpty) return res;
      }
    }
    return [];
  }

  @override
  double? scrapeRatingValue(dom.Document document) {
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final ratingData = extractRatingFromProductJson(productJson);
      if (ratingData != null && ratingData['ratingValue'] != null) {
        return (ratingData['ratingValue'] as num).toDouble();
      }
    }
    final script = document.getElementById('reduxStore');
    if (script != null) {
      try {
        final Map<String, dynamic> reduxData = jsonDecode(script.text);
        final product = reduxData['productState']?['product'];
        final ratingVal = product?['customerReview']?['rating'] ?? product?['ratingValue'];
        if (ratingVal != null) {
          final parsed = double.tryParse(ratingVal.toString());
          if (parsed != null && parsed > 0) return parsed;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  int? scrapeRatingCount(dom.Document document) {
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final ratingData = extractRatingFromProductJson(productJson);
      if (ratingData != null && ratingData['ratingCount'] != null) {
        return (ratingData['ratingCount'] as num).toInt();
      }
    }
    final script = document.getElementById('reduxStore');
    if (script != null) {
      try {
        final Map<String, dynamic> reduxData = jsonDecode(script.text);
        final product = reduxData['productState']?['product'];
        final reviewCount = product?['customerReview']?['totalCount'] ?? product?['ratingCount'];
        if (reviewCount != null) {
          final parsed = int.tryParse(reviewCount.toString());
          if (parsed != null && parsed > 0) return parsed;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  String? scrapeBrand(dom.Document document) {
    final productJson = findProductJsonLd(document);
    if (productJson != null) {
      final brandVal = extractBrandFromProductJson(productJson);
      if (brandVal != null && brandVal.isNotEmpty) return brandVal;
    }
    final script = document.getElementById('reduxStore');
    if (script != null) {
      try {
        final Map<String, dynamic> reduxData = jsonDecode(script.text);
        final product = reduxData['productState']?['product'];
        final brandVal = product?['brand']?.toString().trim();
        if (brandVal != null && brandVal.isNotEmpty) return brandVal;
      } catch (_) {}
    }
    return null;
  }

  @override
  FutureOr<String?> scrapePriceLabel(dom.Document document) async {
    // 1. Canlı API Sonucu Kontrolü (Birincil ve En Güvenilir Kaynak)
    if (_lastApiResult != null) {
      return _lastApiResult!.isPremium ? 'Premium ile' : null;
    }

    // 2. DOM Kontrolü: Özel Premium Fiyat/Rozet Seçicileri (Statik HTML / Offline Test durumları için)
    final ignoredParents = RegExp(r'header|footer|nav|toplinks|installment', caseSensitive: false);

    const premiumSelectors = [
      '[data-test-id*="premium-price"]',
      '[class*="PremiumPrice"]',
      '[class*="premium-price"]',
      '[class*="premiumPrice"]',
      '[data-test-id="loyalty-discount"]',
      '[class*="loyalty-discount"]',
      '[class*="loyaltyDiscount"]',
    ];

    for (final sel in premiumSelectors) {
      final el = document.querySelector(sel);
      if (el != null) {
        final text = el.text.trim();
        if (text.isNotEmpty && !text.toLowerCase().contains('taksit')) {
          return 'Premium ile';
        }
      }
    }

    // 3. DOM Metin Taraması: SADECE doğrudan fiyat içeren açık Premium etiketleri
    final strictRegex = RegExp(r"^(?:hepsiburada\s*)?premium['’]?\s*(?:ile|la|’la|'la|a\s*özel\s*fiyat|üyelerine\s*özel)\s*[\d.,]+\s*(?:tl|₺)?$", caseSensitive: false);
    final priceWithPremiumRegex = RegExp(r"premium['’]?\s*(?:ile|la|’la|'la)\s*[\d.,]+\s*(?:tl|₺)", caseSensitive: false);

    final elements = document.querySelectorAll('span, b, strong, p, label');
    for (final el in elements) {
      final parentClass = (el.parent?.attributes['class'] ?? '').toLowerCase();
      final selfClass = (el.attributes['class'] ?? '').toLowerCase();
      if (ignoredParents.hasMatch(parentClass) || ignoredParents.hasMatch(selfClass)) {
        continue;
      }

      final text = el.text.trim();
      if (text.isEmpty || text.length > 50) continue;

      if (strictRegex.hasMatch(text) || priceWithPremiumRegex.hasMatch(text)) {
        return 'Premium ile';
      }
    }

    return null;
  }
}


