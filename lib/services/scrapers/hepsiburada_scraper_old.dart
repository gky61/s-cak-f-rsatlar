import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart' as dom;
import 'base_scraper.dart';

class HepsiburadaScraper extends BaseProductScraper {
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

    // 3. Klasik img etiketlerinden ürün görsellerini ara (Fallback 2)
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

    // 4. data-image attribute'larını dene (Eski akış fallback)
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
    double? lowestApiPrice;

    final script = document.getElementById('reduxStore');
    if (script != null) {
      try {
        final Map<String, dynamic> reduxData = jsonDecode(script.text);
        final productState = reduxData['productState'];
        final product = productState?['product'];
        if (productState != null && product != null) {
          // Parallelize the withoutAffordability and otherMerchants API requests for peak performance
          final results = await Future.wait([
            _fetchWithoutAffordabilityPrice(document),
            _fetchOtherMerchantsPrice(document, productState, product),
          ]);

          final withoutAffordabilityPrice = results[0];
          final otherMerchantsPrice = results[1];

          if (withoutAffordabilityPrice != null && withoutAffordabilityPrice > 0) {
            lowestApiPrice = withoutAffordabilityPrice;
          }
          if (otherMerchantsPrice != null && otherMerchantsPrice > 0) {
            if (lowestApiPrice == null || otherMerchantsPrice < lowestApiPrice) {
              lowestApiPrice = otherMerchantsPrice;
            }
          }
        }
      } catch (_) {}
    } else {
      // Fallback if reduxStore script is not found
      final withoutAffordabilityPrice = await _fetchWithoutAffordabilityPrice(document);
      if (withoutAffordabilityPrice != null && withoutAffordabilityPrice > 0) {
        lowestApiPrice = withoutAffordabilityPrice;
      }
    }

    if (lowestApiPrice != null && lowestApiPrice > 0) {
      return lowestApiPrice;
    }

    // C) Üçüncü öncelikli yöntem: HTML'den en ucuz fiyatı seçme (Lokasyon/API bağımsız yedek)
    double? lowestPrice;

    // 1. HTML'deki birincil/buybox ürün fiyatını oku
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
            lowestPrice = minPrice;
          }
        }
      } catch (_) {}
    }

    // 2. HTML'deki minimumPrices (Premium/Sepet indirimli) fiyatlarını oku
    final htmlText = document.outerHtml;
    final fallbackPrice = _extractPriceFromJsonState(htmlText);
    if (fallbackPrice != null && fallbackPrice > 0) {
      if (lowestPrice == null || fallbackPrice < lowestPrice) {
        lowestPrice = fallbackPrice;
      }
    }

    if (lowestPrice != null && lowestPrice > 0) {
      print('[Hepsiburada API Debug] Fallback to HTML lowest price found: $lowestPrice');
      return lowestPrice;
    }

    return null;
  }

  Future<double?> _fetchWithoutAffordabilityPrice(dom.Document document) async {
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
      finalPriceDouble = double.tryParse(pricesList[0]['value']?.toString() ?? '');
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
      
      request.add(utf8.encode(jsonEncode(payload)));
      
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final resJson = jsonDecode(body);
        
        print('[Hepsiburada API Debug] withoutAffordability payload: ${jsonEncode(payload)}');
        print('[Hepsiburada API Debug] withoutAffordability response: $body');
        
        final productResult = resJson['data']?['result']?['product'];
        if (productResult != null) {
          double? lowestCalculatedPrice;

          void updateLowest(double? priceVal, String debugLabel) {
            if (priceVal != null) {
              final double p = priceVal;
              if (p > 0) {
                print('[Hepsiburada API Debug] Candidate price ($debugLabel): $p');
                final currentLowest = lowestCalculatedPrice;
                if (currentLowest == null || p < currentLowest) {
                  lowestCalculatedPrice = p;
                }
              }
            }
          }

          // 1. Check priceData (active buybox price)
          final priceData = productResult['priceData'];
          if (priceData != null) {
            final discountedPrice = double.tryParse(priceData['discountedPrice']?.toString() ?? '');
            updateLowest(discountedPrice, 'priceData.discountedPrice');
            
            final price = double.tryParse(priceData['price']?.toString() ?? '');
            updateLowest(price, 'priceData.price');
          }

          // 2. Fallback to promoData evaluateAsPremiumResult/evaluateResult
          final promoData = productResult['promoData']?['data'];
          if (promoData != null) {
            final premiumResult = promoData['campaignEvaluateResult']?['evaluateAsPremiumResult'];
            if (premiumResult != null) {
              final premiumPrice = double.tryParse(premiumResult['discountedPrice']?.toString() ?? '');
              updateLowest(premiumPrice, 'promoData.evaluateAsPremiumResult.discountedPrice');
            }
            
            // Guest/Normal evaluateResult check
            final evalResult = promoData['campaignEvaluateResult']?['evaluateResult'];
            if (evalResult != null) {
              final evalPrice = double.tryParse(evalResult['discountedPrice']?.toString() ?? '');
              updateLowest(evalPrice, 'promoData.evaluateResult.discountedPrice');
            }

            final normalResult = promoData['campaignEvaluateResult'];
            if (normalResult != null) {
              final normalPrice = double.tryParse(normalResult['discountedPrice']?.toString() ?? '');
              updateLowest(normalPrice, 'promoData.campaignEvaluateResult.discountedPrice');
            }
          }

          if (lowestCalculatedPrice != null) {
            final double finalLowest = lowestCalculatedPrice!;
            if (finalLowest > 0) {
              print('[Hepsiburada API Debug] Selected lowest price: $finalLowest');
              return finalLowest;
            }
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

  Future<double?> _fetchOtherMerchantsPrice(dom.Document document, Map<String, dynamic> productState, Map<String, dynamic> product) async {
    final sku = product['sku']?.toString() ?? '';
    final productId = product['productId']?.toString() ?? '';
    final brand = product['brand']?.toString() ?? '';
    final definitionId = product['definitionId']?.toString() ?? '';
    final definitionName = product['definitionName']?.toString() ?? '';
    final taxVatRate = product['taxVatRate'] as int? ?? 20;

    double? finalPriceDouble;
    final pricesList = product['prices'] as List?;
    if (pricesList != null && pricesList.isNotEmpty) {
      finalPriceDouble = double.tryParse(pricesList[0]['value']?.toString() ?? '');
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

    void addListing(Map item) {
      final merchantId = item['merchantId']?.toString() ?? '';
      final listingId = item['listingId']?.toString() ?? '';
      final merchantName = item['merchantName']?.toString() ?? '';
      if (listingId.isEmpty) return;

      if (otherMerchantsList.any((l) => l['listingId'] == listingId)) return;

      double? itemPriceDouble;
      final itemPrices = item['prices'] as List?;
      if (itemPrices != null && itemPrices.isNotEmpty) {
        for (final priceObj in itemPrices) {
          if (priceObj is Map) {
            final val = double.tryParse(priceObj['value']?.toString() ?? '');
            if (val != null && val > 0) {
              if (itemPriceDouble == null || val < itemPriceDouble) {
                itemPriceDouble = val;
              }
            }
          }
        }
      }
      final itemPrice = itemPriceDouble ?? 0.0;

      double? minPriceDouble;
      if (item['price'] != null) {
        minPriceDouble = double.tryParse(item['price']['value']?.toString() ?? '');
      }
      final minimumPriceForNLastDays = minPriceDouble ?? itemPrice;

      final List<String> itemTags = [];
      final tagList = item['tagList'] as List?;
      if (tagList != null) {
        for (final tagObj in tagList) {
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

    // 1. Add primary buybox listing
    addListing(product);

    // 2. Add alternative listings from both locations
    final rawListings = (product['listings'] ?? productState['listings']) as List?;
    if (rawListings != null) {
      for (final item in rawListings) {
        if (item is Map) {
          addListing(item);
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
      
      request.add(utf8.encode(jsonEncode(payload)));
      
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final resJson = jsonDecode(body);
        print('[Hepsiburada API Debug] otherMerchants payload: ${jsonEncode(payload)}');
        print('[Hepsiburada API Debug] otherMerchants response: $body');
        
        final listingsResult = (resJson['data']?['result']?['products']?['otherMerchants'] ?? resJson['data']?['result']?['listings']) as List?;
        if (listingsResult != null) {
          double? lowestPrice;
          for (final listingObj in listingsResult) {
            if (listingObj is Map) {
              double? listingPrice;

              void updateListingLowest(double? priceVal) {
                if (priceVal != null) {
                  final double p = priceVal;
                  if (p > 0) {
                    final currentListing = listingPrice;
                    if (currentListing == null || p < currentListing) {
                      listingPrice = p;
                    }
                  }
                }
              }

              // 1. Check priceData
              final priceData = listingObj['priceData'];
              if (priceData != null) {
                final discountedPrice = double.tryParse(priceData['discountedPrice']?.toString() ?? '');
                updateListingLowest(discountedPrice);
                
                final price = double.tryParse(priceData['price']?.toString() ?? '');
                updateListingLowest(price);
              }

              // 2. Fallback to promoData
              final promoData = listingObj['promoData']?['data'];
              if (promoData != null) {
                final premiumResult = promoData['campaignEvaluateResult']?['evaluateAsPremiumResult'];
                if (premiumResult != null) {
                  final premiumPrice = double.tryParse(premiumResult['discountedPrice']?.toString() ?? '');
                  updateListingLowest(premiumPrice);
                }
                
                final evalResult = promoData['campaignEvaluateResult']?['evaluateResult'];
                if (evalResult != null) {
                  final evalPrice = double.tryParse(evalResult['discountedPrice']?.toString() ?? '');
                  updateListingLowest(evalPrice);
                }

                final normalResult = promoData['campaignEvaluateResult'];
                if (normalResult != null) {
                  final normalPrice = double.tryParse(normalResult['discountedPrice']?.toString() ?? '');
                  updateListingLowest(normalPrice);
                }
              }

              if (listingPrice != null) {
                final double lPrice = listingPrice!;
                if (lPrice > 0) {
                  final currentLowest = lowestPrice;
                  if (currentLowest == null || lPrice < currentLowest) {
                    lowestPrice = lPrice;
                  }
                }
              }
            }
          }
          if (lowestPrice != null) return lowestPrice;
        }
      }
    } catch (_) {
      // Fallback silently
    } finally {
      client.close();
    }

    return null;
  }

  double? _extractPriceFromJsonState(String html) {
    // 1. "minimumPrices" içeren JSON bloklarını bul.
    // Her bir blok için merchantName ve minimumPrices eşleştirmesini yap.
    final reg = RegExp(
      r'"merchant(?:Name|_name)"\s*:\s*"([^"]+)"[^{}]*?"minimumPrices"\s*:\s*(\[[^\]]+\])',
      caseSensitive: false,
    );

    final matches = reg.allMatches(html);
    if (matches.isEmpty) return null;

    // Hepsiburada satıcısı varsa öncelikli olarak onu seç, yoksa ilk satıcıyı al
    MapEntry<String, List>? selectedListing;
    for (final m in matches) {
      final merchantName = m.group(1)!;
      final arrayStr = m.group(2)!;
      try {
        final decoded = jsonDecode(arrayStr) as List;
        if (merchantName.toLowerCase() == 'hepsiburada') {
          selectedListing = MapEntry(merchantName, decoded);
          break; // Hepsiburada'yı bulduk, döngüden çık
        }
        selectedListing ??= MapEntry(merchantName, decoded);
      } catch (_) {}
    }

    if (selectedListing != null) {
      final decoded = selectedListing.value;
      
      // B) Sepete Özel / Normal fiyat kontrolü: non-segmented-price varsa onu al
      for (final item in decoded) {
        final name = item['name']?.toString();
        final value = double.tryParse(item['value']?.toString() ?? '');
        if (name == 'non-segmented-price' && value != null && value > 0) {
          return value;
        }
      }
    }
    return null;
  }
}
