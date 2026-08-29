/**
 * Hepsiburada Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class HepsiburadaScraper extends BaseProductScraper {
  get domain() { return 'hepsiburada.com'; }

  canHandle(url) {
    const lower = url.toLowerCase();
    return lower.includes('hepsiburada.com') || lower.includes('hb.biz');
  }

  scrapeImage($, url) {
    // 1. JSON-LD şemasından görsel çekmeyi dene (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const resolved = this.resolveImageUrl(img, url);
        if (resolved) return resolved;
      }
    }
    // 2. Open Graph meta tag'i dene (Fallback 1)
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const resolved = this.resolveImageUrl(ogImg, url);
      if (resolved) return resolved;
    }
    // 3. reduxStore'dan media alanından görsel çek (Fallback 2)
    // Microlink prerender HTML'inde JSON-LD ve og:image yok ama reduxStore.productState.product.media var.
    // URL formatı: https://productimages.hepsiburada.net/s/777/{size}/110000671504006.jpg
    // {size} parametresini 500 ile değiştiriyoruz.
    const reduxScript = $('#reduxStore');
    if (reduxScript.length) {
      try {
        const reduxData = JSON.parse(reduxScript.text());
        const reduxProduct = reduxData?.productState?.product;
        if (reduxProduct?.media && Array.isArray(reduxProduct.media) && reduxProduct.media.length > 0) {
          const mediaUrl = reduxProduct.media[0].url;
          if (mediaUrl && typeof mediaUrl === 'string') {
            const resolvedMediaUrl = mediaUrl.replace('{size}', '500');
            if (resolvedMediaUrl && !this.isLogoUrl(resolvedMediaUrl)) {
              console.log(`[HepsiburadaScraper] ✅ reduxStore media'dan görsel bulundu: ${resolvedMediaUrl}`);
              return resolvedMediaUrl;
            }
          }
        }
      } catch (_) {}
    }
    // 4. Klasik img etiketlerinden ürün görsellerini ara (Fallback 3)
    const productImg = $('img[class*="hb-HbImage-view__image"], .hb-HbImage-view img, img[alt*="ürün"], img[alt*="Ürün"]').first();
    if (productImg.length) {
      const src = productImg.attr('src') || productImg.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const resolved = this.resolveImageUrl(src, url);
        if (resolved) return resolved;
      }
    }
    // 5. data-image attribute'larını dene (Eski akış fallback)
    // Not: .each() callback'ten return döngüyü kırmaz; Dart'taki for döngüsüyle birebir eşit for...of kullanıyoruz
    const dataImgEls = $('[data-image], [data-srcset], [data-original-src]').toArray();
    for (const el of dataImgEls) {
      const imgUrl = $(el).attr('data-image') || ($(el).attr('data-srcset') || '').split(',')[0]?.trim() || $(el).attr('data-original-src');
      if (imgUrl && !imgUrl.startsWith('data:') && !this.isLogoUrl(imgUrl)) {
        const resolved = this.resolveImageUrl(imgUrl, url);
        if (resolved) return resolved;
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. JSON-LD şemasından (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    // 2. DOM Seçicileri (Fallback 1)
    const el = $('h1[data-test-id="title"], h1.xeL9CQ3JILmYoQPCgDcl').first();
    if (el.length) return el.text().trim();
    // 3. reduxStore'dan başlık çek (Fallback 2)
    // Microlink prerender HTML'inde JSON-LD yok ama reduxStore.productState.product.name var.
    const reduxScript = $('#reduxStore');
    if (reduxScript.length) {
      try {
        const reduxData = JSON.parse(reduxScript.text());
        const reduxProduct = reduxData?.productState?.product;
        if (reduxProduct?.name) {
          const brand = reduxProduct.brand || '';
          const name = reduxProduct.name;
          // Dart scraper'daki gibi brand + name birleştir
          const fullTitle = brand ? `${brand} ${name}` : name;
          console.log(`[HepsiburadaScraper] ✅ reduxStore'dan başlık bulundu: ${fullTitle}`);
          return fullTitle.trim();
        }
      } catch (_) {}
    }
    return null;
  }

  async scrapePrice($) {
    // 1. Hepsiburada Premium Fiyat Kontrolü (Premium indirimli fiyat önceliklidir - DOM Eşleşmesi)
    const spans = $('span');
    for (let i = 0; i < spans.length; i++) {
      const span = $(spans[i]);
      const text = span.text().trim();
      if (text.startsWith('Premium ile') || text.startsWith('Premium\'la') || text.startsWith('Premium’la')) {
        const bElement = span.find('b').first();
        if (bElement.length) {
          const parsed = this.parsePriceText(bElement.text());
          if (parsed !== null && parsed > 0) return parsed;
        }
        const cleanText = text
            .replace('Premium ile', '')
            .replace('Premium\'la', '')
            .replace('Premium’la', '')
            .trim();
        const parsed = this.parsePriceText(cleanText);
        if (parsed !== null && parsed > 0) return parsed;
      }
    }

    // 2. Canlı API Çağrıları (Dinamik Fiyat Sorguları - DOM'da Premium fiyat bulunamadıysa)
    let bestApiResult = null;
    const script = $('#reduxStore');
    if (script.length) {
      try {
        const reduxData = JSON.parse(script.text());
        const productState = reduxData['productState'];
        const product = productState ? productState['product'] : null;
        if (productState && product) {
          const results = await Promise.all([
            this._fetchWithoutAffordabilityPrice(reduxData),
            this._fetchOtherMerchantsPrice(reduxData),
          ]);

          const withoutAffordabilityRes = results[0];
          const otherMerchantsRes = results[1];

          if (withoutAffordabilityRes && withoutAffordabilityRes.price > 0) {
            bestApiResult = withoutAffordabilityRes;
          }
          if (otherMerchantsRes && otherMerchantsRes.price > 0) {
            if (
              bestApiResult === null ||
              otherMerchantsRes.price < bestApiResult.price ||
              (otherMerchantsRes.price === bestApiResult.price && otherMerchantsRes.isPremium && !bestApiResult.isPremium)
            ) {
              bestApiResult = otherMerchantsRes;
            }
          }
        }
      } catch (_) {}
    } else {
      // reduxStore bulunamadıysa fallback olarak withoutAffordability API'sini doğrudan dene
      try {
        bestApiResult = await this._fetchWithoutAffordabilityPrice({});
      } catch (_) {}
    }

    this._lastApiResult = bestApiResult;
    if (bestApiResult && bestApiResult.price > 0) {
      return bestApiResult.price;
    }

    // 3. JSON-LD şemasından (Öncelikli normal fiyat)
    const productJson = this.findProductJsonLd($);
    if (productJson) {
      const priceVal = this.extractPriceFromProductJson(productJson);
      if (priceVal !== null && priceVal > 0) {
        return priceVal;
      }
    }

    // 4. HTML Redux Fiyatları Fallback
    if (script.length) {
      try {
        const reduxData = JSON.parse(script.text());
        const product = reduxData['productState']?.['product'];
        const pricesList = product ? product['prices'] : null;
        if (Array.isArray(pricesList) && pricesList.length > 0) {
          let minPrice = null;
          for (const priceObj of pricesList) {
            if (priceObj && typeof priceObj === 'object') {
              const val = parseFloat(priceObj['value']?.toString() || '');
              if (!isNaN(val) && val > 0) {
                if (minPrice === null || val < minPrice) {
                  minPrice = val;
                }
              }
            }
          }
          if (minPrice !== null) {
            return minPrice;
          }
        }
      } catch (_) {}
    }

    // 5. DOM Seçicileri (En son fallback)
    const priceSelectors = [
      '[data-test-id="price-current-value"]',
      '[data-test-id="price"]',
      'span[class*="price"]',
      'div[class*="price-value"]',
    ];
    for (const selector of priceSelectors) {
      const priceEl = $(selector).first();
      if (priceEl.length) {
        const parsed = this.parsePriceText(priceEl.text());
        if (parsed !== null && parsed > 0) return parsed;
      }
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    let candidates = [];

    // 1. ReduxStore product.prices (SADECE ana ürünün liste/eski fiyatları)
    // Diğer satıcıların (product.listings) yüksek fiyatlarını HARİÇ tutuyoruz.
    const script = $('#reduxStore');
    if (script.length) {
      try {
        const reduxData = JSON.parse(script.text());
        const product = reduxData?.productState?.product;
        if (product && Array.isArray(product.prices)) {
          for (const p of product.prices) {
            const val = parseFloat(p?.value?.toString() || '');
            if (!isNaN(val) && val > currentPrice) {
              candidates.push(val);
            }
          }
        }
      } catch (_) {}
    }

    // 2. DOM selectors for old / crossed out prices (Diğer satıcılar bloğu hariç)
    const domSelectors = [
      'del',
      's',
      '[data-test-id*="price-old"]',
      '[data-test-id*="old-price"]',
      '[data-test-id="variant-box-price"]',
      'span[class*="del"]',
      'span[class*="old"]',
      'span[class*="original"]'
    ];

    for (const selector of domSelectors) {
      $(selector).each((_, el) => {
        // Diğer satıcılar ("other-merchants") alanındaki fiyatları hariç tut
        const $el = $(el);
        if ($el.closest('[class*="otherMerchant"], [data-test-id*="merchant"], .other-merchants, #otherMerchants').length > 0) {
          return;
        }

        const txt = $el.text().trim();
        const parsed = this.parsePriceText(txt);
        if (parsed !== null && parsed > currentPrice) {
          candidates.push(parsed);
        }
      });
    }

    if (candidates.length === 0) return null;

    candidates = candidates.filter(c => c > currentPrice && c <= currentPrice * 5);
    if (candidates.length === 0) return null;

    candidates.sort((a, b) => a - b);
    return candidates[0];
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'hepsiburada');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumbs span[itemprop="name"], [data-test-id="breadcrumbs"] li').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa') {
          list.push(text);
        }
      }
    });
    return list;
  }

  // --- Private Helper Methods for API Calls ---

  async _fetchWithoutAffordabilityPrice(reduxData) {
    const productState = reduxData['productState'];
    if (!productState) return null;
    const product = productState['product'];
    if (!product) return null;

    const sku = (product['sku'] || '').toString();
    const productId = (product['productId'] || '').toString();
    const brand = (product['brand'] || '').toString();
    const listingId = (product['listingId'] || '').toString();
    const merchantId = (product['merchantId'] || '').toString();
    const definitionId = (product['definitionId'] || '').toString();
    const definitionName = (product['definitionName'] || '').toString();
    const taxVatRate = parseInt(product['taxVatRate']) || 20;

    let finalPrice = null;
    const pricesList = product['prices'] || [];
    if (pricesList.length > 0) {
      let minPrice = null;
      for (const priceObj of pricesList) {
        if (priceObj && typeof priceObj === 'object') {
          const val = parseFloat(priceObj['value']);
          if (!isNaN(val) && val > 0) {
            if (minPrice === null || val < minPrice) {
              minPrice = val;
            }
          }
        }
      }
      finalPrice = minPrice;
    }

    const rootCategoryList = [];
    const rawCategories = product['rootCategoryList'] || [];
    for (const item of rawCategories) {
      if (item && typeof item === 'object') {
        const catId = parseInt(item['categoryId']);
        if (!isNaN(catId) && catId > 0) rootCategoryList.push(catId);
      } else {
        const catId = parseInt(item);
        if (!isNaN(catId) && catId > 0) rootCategoryList.push(catId);
      }
    }

    const productTags = [];
    const tagList = product['tagList'] || [];
    for (const item of tagList) {
      if (item && item['tagId']) {
        productTags.push(item['tagId'].toString());
      }
    }

    const campaignIds = [];
    const rawCampaignIds = product['campaignIds'] || [];
    for (const idObj of rawCampaignIds) {
      const id = parseInt(idObj);
      if (!isNaN(id) && id > 0) campaignIds.push(id);
    }

    const campaignIdRegExp = /^(\d+)-/;
    for (const tag of productTags) {
      const match = campaignIdRegExp.exec(tag);
      if (match) {
        const id = parseInt(match[1]);
        if (!isNaN(id) && id > 0 && !campaignIds.includes(id)) {
          campaignIds.push(id);
        }
      }
    }

    const payload = {
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

    const url = 'https://www.hepsiburada.com/api/v1/withoutAffordability';
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36',
          'content-type': 'application/json',
          'accept': 'application/json, text/plain, */*',
          'origin': 'https://www.hepsiburada.com',
          'referer': 'https://www.hepsiburada.com/',
          'x-gotham_app-key': 'All',
          'x-gotham_is_enabled_evaluate_coupon': 'true',
          'x-gotham_is_enabled_next_eligible_campaign': 'true',
          'x-gotham_is_include_payment_campaigns': 'true',
          'x-gotham_is_include_premium_clubs': 'true'
        },
        body: JSON.stringify(payload)
      });

      if (response.ok) {
        const resJson = await response.json();
        const productResult = resJson['data']?.['result']?.['product'];
        if (productResult) {
          let lowestCalculatedPrice = null;
          let isPremium = false;
          let campaignName = null;

          const updateLowest = (priceVal, premium, name) => {
            if (priceVal != null) {
              const p = parseFloat(priceVal);
              if (!isNaN(p) && p > 0) {
                if (
                  lowestCalculatedPrice === null ||
                  p < lowestCalculatedPrice ||
                  (p === lowestCalculatedPrice && premium && !isPremium)
                ) {
                  lowestCalculatedPrice = p;
                  isPremium = !!premium;
                  campaignName = name || null;
                }
              }
            }
          };

          const priceData = productResult['priceData'];
          if (priceData) {
            const pPrem = priceData['isPremium'] === true;
            updateLowest(priceData['discountedPrice'], pPrem, priceData['priceText']);
            updateLowest(priceData['price'], false, null);
          }

          const promoData = productResult['promoData']?.['data'];
          if (promoData) {
            const campEval = promoData['campaignEvaluateResult'];
            if (campEval) {
              const premiumResult = campEval['evaluateAsPremiumResult'];
              if (premiumResult) {
                updateLowest(premiumResult['discountedPrice'], true, premiumResult['campaignText']);
              }
              const evalResult = campEval['evaluateResult'];
              if (evalResult) {
                updateLowest(evalResult['discountedPrice'], false, evalResult['campaignText']);
              }
              const normalPrice = campEval['discountedPrice'];
              if (normalPrice != null) {
                updateLowest(normalPrice, false, campEval['campaignText']);
              }
            }
          }

          if (lowestCalculatedPrice !== null && lowestCalculatedPrice > 0) {
            return {
              price: lowestCalculatedPrice,
              isPremium: isPremium,
              campaignName: campaignName
            };
          }
        }
      }
    } catch (_) {}
    return null;
  }

  async _fetchOtherMerchantsPrice(reduxData) {
    const productState = reduxData['productState'];
    if (!productState) return null;
    const product = productState['product'];
    if (!product) return null;

    const sku = (product['sku'] || '').toString();
    const productId = (product['productId'] || '').toString();
    const brand = (product['brand'] || '').toString();
    const definitionId = (product['definitionId'] || '').toString();
    const definitionName = (product['definitionName'] || '').toString();
    const taxVatRate = parseInt(product['taxVatRate']) || 20;

    let finalPrice = null;
    const pricesList = product['prices'] || [];
    if (pricesList.length > 0) {
      let minPrice = null;
      for (const priceObj of pricesList) {
        if (priceObj && typeof priceObj === 'object') {
          const val = parseFloat(priceObj['value']);
          if (!isNaN(val) && val > 0) {
            if (minPrice === null || val < minPrice) {
              minPrice = val;
            }
          }
        }
      }
      finalPrice = minPrice;
    }

    const rootCategoryList = [];
    const rawCategories = product['rootCategoryList'] || [];
    for (const item of rawCategories) {
      if (item && typeof item === 'object') {
        const catId = parseInt(item['categoryId']);
        if (!isNaN(catId) && catId > 0) rootCategoryList.push(catId);
      } else {
        const catId = parseInt(item);
        if (!isNaN(catId) && catId > 0) rootCategoryList.push(catId);
      }
    }

    const otherMerchantsList = [];
    const addListing = (item) => {
      if (!item) return;
      const merchantId = (item['merchantId'] || '').toString();
      const merchantName = (item['merchantName'] || '').toString();
      const listingId = (item['listingId'] || '').toString();

      let itemPrice = null;
      const itemPrices = item['prices'] || [];
      if (itemPrices.length > 0) {
        let minItemPrice = null;
        for (const pObj of itemPrices) {
          if (pObj && typeof pObj === 'object') {
            const val = parseFloat(pObj['value']);
            if (!isNaN(val) && val > 0) {
              if (minItemPrice === null || val < minItemPrice) {
                minItemPrice = val;
              }
            }
          }
        }
        itemPrice = minItemPrice;
      }

      let minimumPriceForNLastDays = null;
      if (item['minimumPriceForNLastDays'] != null) {
        minimumPriceForNLastDays = parseFloat(item['minimumPriceForNLastDays']);
      }

      const itemTags = [];
      const rawItemTags = item['productTags'] || [];
      for (const tagObj of rawItemTags) {
        if (tagObj && tagObj['tagId']) {
          itemTags.push(tagObj['tagId'].toString());
        }
      }
      if (itemTags.length === 0 && item['paymentTag']) {
        const payTagStr = item['paymentTag'].toString();
        itemTags.push(...payTagStr.split(',').map(s => s.trim()).filter(s => s.length > 0));
      }

      const itemCampaignIds = [];
      const rawItemCampaignIds = item['campaignIds'] || [];
      for (const idObj of rawItemCampaignIds) {
        const id = parseInt(idObj);
        if (!isNaN(id) && id > 0) itemCampaignIds.push(id);
      }

      const campaignIdRegExp = /^(\d+)-/;
      for (const tag of itemTags) {
        const match = campaignIdRegExp.exec(tag);
        if (match) {
          const id = parseInt(match[1]);
          if (!isNaN(id) && id > 0 && !itemCampaignIds.includes(id)) {
            itemCampaignIds.push(id);
          }
        }
      }

      otherMerchantsList.push({
        "productTags": itemTags,
        "campaignIds": itemCampaignIds,
        "finalPriceOnSale": itemPrice,
        "minimumPriceForNLastDays": minimumPriceForNLastDays,
        "merchantId": merchantId,
        "merchantName": merchantName,
        "listingId": listingId
      });
    };

    addListing(product);

    const rawListings = product['listings'] || productState['listings'] || [];
    for (const item of rawListings) {
      if (item && typeof item === 'object') {
        addListing(item);
      }
    }

    if (otherMerchantsList.length === 0) return null;

    const payload = {
      "userId": "",
      "product": {
        "productTags": [],
        "sku": sku,
        "productId": productId,
        "brand": brand,
        "rootCategoryList": rootCategoryList,
        "rootBuyingCategoryList": rootCategoryList.length > 0 ? [rootCategoryList[rootCategoryList.length - 1]] : [null],
        "campaignIds": [],
        "definitionName": definitionName,
        "definitionId": definitionId,
        "finalPriceOnSale": finalPrice,
        "taxVatRate": taxVatRate,
        "otherMerchants": otherMerchantsList
      }
    };

    const url = 'https://www.hepsiburada.com/api/v1/otherMerchants';
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36',
          'content-type': 'application/json',
          'accept': 'application/json, text/plain, */*',
          'origin': 'https://www.hepsiburada.com',
          'referer': 'https://www.hepsiburada.com/',
          'x-gotham_app-key': 'All',
          'x-gotham_is_enabled_evaluate_coupon': 'true',
          'x-gotham_is_enabled_next_eligible_campaign': 'true',
          'x-gotham_is_include_payment_campaigns': 'true',
          'x-gotham_is_include_premium_clubs': 'true'
        },
        body: JSON.stringify(payload)
      });

      if (response.ok) {
        const resJson = await response.json();
        const listingsResult = resJson['data']?.['result']?.['products']?.['otherMerchants'] || resJson['data']?.['result']?.['listings'] || [];
        
        let lowestPrice = null;
        let isPremium = false;
        let campaignName = null;

        for (const listingObj of listingsResult) {
          if (listingObj && typeof listingObj === 'object') {
            const updateListingLowest = (pVal, premium, name) => {
              if (pVal != null) {
                const p = parseFloat(pVal);
                if (!isNaN(p) && p > 0) {
                  if (
                    lowestPrice === null ||
                    p < lowestPrice ||
                    (p === lowestPrice && premium && !isPremium)
                  ) {
                    lowestPrice = p;
                    isPremium = !!premium;
                    campaignName = name || null;
                  }
                }
              }
            };

            const priceData = listingObj['priceData'];
            if (priceData) {
              const pPrem = priceData['isPremium'] === true;
              updateListingLowest(priceData['discountedPrice'], pPrem, priceData['priceText']);
              updateListingLowest(priceData['price'], false, null);
            }

            const promoData = listingObj['promoData']?.['data'];
            if (promoData) {
              const campEval = promoData['campaignEvaluateResult'];
              if (campEval) {
                const premiumResult = campEval['evaluateAsPremiumResult'];
                if (premiumResult) {
                  updateListingLowest(premiumResult['discountedPrice'], true, premiumResult['campaignText']);
                }
                const evalResult = campEval['evaluateResult'];
                if (evalResult) {
                  updateListingLowest(evalResult['discountedPrice'], false, evalResult['campaignText']);
                }
                const normalPrice = campEval['discountedPrice'];
                if (normalPrice != null) {
                  updateListingLowest(normalPrice, false, campEval['campaignText']);
                }
              }
            }
          }
        }
        if (lowestPrice !== null && lowestPrice > 0) {
          return {
            price: lowestPrice,
            isPremium: isPremium,
            campaignName: campaignName
          };
        }
      }
    } catch (_) {}
    return null;
  }

  scrapeRating($) {
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }
    const reduxScript = $('#reduxStore');
    if (reduxScript.length) {
      try {
        const reduxData = JSON.parse(reduxScript.text());
        const productData = reduxData?.productState?.product;
        const ratingVal = parseFloat(productData?.customerReview?.rating || productData?.ratingValue);
        const ratingCnt = parseInt(productData?.customerReview?.totalCount || productData?.ratingCount);
        return {
          ratingValue: !isNaN(ratingVal) && ratingVal > 0 ? ratingVal : null,
          ratingCount: !isNaN(ratingCnt) && ratingCnt > 0 ? ratingCnt : null,
        };
      } catch (_) {}
    }
    return { ratingValue: null, ratingCount: null };
  }

  scrapeBrand($) {
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand) return brand;
    }
    const reduxScript = $('#reduxStore');
    if (reduxScript.length) {
      try {
        const reduxData = JSON.parse(reduxScript.text());
        const brandVal = reduxData?.productState?.product?.brand;
        if (brandVal && typeof brandVal === 'string' && brandVal.trim().length > 0) {
          return brandVal.trim();
        }
      } catch (_) {}
    }
    return null;
  }

  scrapePriceLabel($) {
    // 1. Canlı API Sonucu Kontrolü (Birincil ve En Güvenilir Kaynak)
    if (this._lastApiResult) {
      return this._lastApiResult.isPremium ? 'Premium ile' : null;
    }

    // 2. DOM Kontrolü: Özel Premium Fiyat/Rozet Seçicileri (Statik HTML / Offline Test durumları için)
    const ignoredParents = 'header, footer, nav, [class*="TopLinks"], [class*="topLinks"], [class*="installment"], [class*="Installment"], [data-test-id*="installment"], [class*="footer"], [class*="navigation"]';
    const premiumSelectors = [
      '[data-test-id*="premium-price"]',
      '[class*="PremiumPrice"]',
      '[class*="premium-price"]',
      '[class*="premiumPrice"]',
      '[data-test-id="loyalty-discount"]',
      '[class*="loyalty-discount"]',
      '[class*="loyaltyDiscount"]'
    ];

    for (const sel of premiumSelectors) {
      const el = $(sel).first();
      if (el.length && el.closest(ignoredParents).length === 0) {
        const text = el.text().trim();
        if (text.length > 0 && !text.toLowerCase().includes('taksit')) {
          return 'Premium ile';
        }
      }
    }

    // 3. DOM Metin Taraması: SADECE doğrudan fiyat içeren açık Premium etiketleri
    let domFound = false;
    $('span, div, p, b, strong, label, a').each((_, el) => {
      const $el = $(el);
      if ($el.closest(ignoredParents).length > 0) return;

      const directText = $el.clone().children().remove().end().text().trim();
      const fullText = $el.text().trim();

      const strictRegex = /^(?:hepsiburada\s*)?premium['’]?\s*(?:ile|la|’la|'la|a\s*özel\s*fiyat|üyelerine\s*özel)\s*[\d.,]+\s*(?:tl|₺)?$/i;
      const priceWithPremiumRegex = /premium['’]?\s*(?:ile|la|’la|'la)\s*[\d.,]+\s*(?:tl|₺)/i;

      if (strictRegex.test(directText) || priceWithPremiumRegex.test(directText)) {
        domFound = true;
        return false;
      }

      if (fullText.length <= 50 && (strictRegex.test(fullText) || priceWithPremiumRegex.test(fullText))) {
        domFound = true;
        return false;
      }
    });

    if (domFound) return 'Premium ile';

    return null;
  }
}

module.exports = HepsiburadaScraper;

