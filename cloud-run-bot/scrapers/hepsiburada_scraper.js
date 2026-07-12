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
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const resolved = this.resolveImageUrl(img, url);
        if (resolved) return resolved;
      }
    }
    // 2. og:image
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const resolved = this.resolveImageUrl(ogImg, url);
      if (resolved) return resolved;
    }
    // 3. DOM
    const selectors = ['img[class*="hb-HbImage-view__image"]', '.hb-HbImage-view img', 'img[alt*="ürün"]', 'img[alt*="Ürün"]'];
    for (const sel of selectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const resolved = this.resolveImageUrl(src, url);
        if (resolved) return resolved;
      }
    }
    // 4. data-image attributes
    $('[data-image], [data-srcset], [data-original-src]').each((_, el) => {
      const imgUrl = $(el).attr('data-image') || ($(el).attr('data-srcset') || '').split(',')[0]?.trim() || $(el).attr('data-original-src');
      if (imgUrl && !imgUrl.startsWith('data:') && !this.isLogoUrl(imgUrl)) {
        const resolved = this.resolveImageUrl(imgUrl, url);
        if (resolved) return resolved;
      }
    });
    return null;
  }

  scrapeTitle($) {
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    const el = $('h1[data-test-id="title"], h1.xeL9CQ3JILmYoQPCgDcl').first();
    if (el.length) return el.text().trim();
    return null;
  }

  async scrapePrice($) {
    // 1. Premium Fiyat (DOM Kontrolü)
    const spans = $('span');
    for (let i = 0; i < spans.length; i++) {
      const text = $(spans[i]).text().trim();
      if (text.startsWith('Premium ile') || text.startsWith("Premium'la") || text.startsWith('Premium’la')) {
        const bElement = $(spans[i]).find('b').first();
        if (bElement.length) {
          const parsed = this.parsePriceText(bElement.text());
          if (parsed && parsed > 0) return parsed;
        }
        const cleanText = text
          .replace('Premium ile', '')
          .replace("Premium'la", '')
          .replace('Premium’la', '')
          .trim();
        const parsed = this.parsePriceText(cleanText);
        if (parsed && parsed > 0) return parsed;
      }
    }

    // 2. Canlı API Çağrıları (Dinamik Fiyat Sorguları - ReduxStore üzerinden)
    const script = $('#reduxStore');
    let reduxData = null;
    if (script.length) {
      try {
        reduxData = JSON.parse(script.text());
        const productState = reduxData['productState'];
        const product = productState?.['product'];
        if (productState && product) {
          const results = await Promise.all([
            this._fetchWithoutAffordabilityPrice(reduxData),
            this._fetchOtherMerchantsPrice(reduxData)
          ]);
          const withoutAffordabilityPrice = results[0];
          const otherMerchantsPrice = results[1];

          let lowestApiPrice = null;
          if (withoutAffordabilityPrice && withoutAffordabilityPrice > 0) {
            lowestApiPrice = withoutAffordabilityPrice;
          }
          if (otherMerchantsPrice && otherMerchantsPrice > 0) {
            if (lowestApiPrice === null || otherMerchantsPrice < lowestApiPrice) {
              lowestApiPrice = otherMerchantsPrice;
            }
          }
          if (lowestApiPrice && lowestApiPrice > 0) {
            console.log(`   [HEPSIBURADA] Canlı API'lerden alınan en düşük fiyat: ${lowestApiPrice} TL`);
            return lowestApiPrice;
          }
        }
      } catch (err) {
        console.warn(`   [HEPSIBURADA] Redux store veya API sorgu hatası: ${err.message}`);
      }
    } else {
      console.log(`   [HEPSIBURADA] #reduxStore script bloğu bulunamadı.`);
    }

    // 3. JSON-LD şemasından (Normal Fiyat)
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 4. Redux Store Fiyat Listesi Fallback
    if (reduxData) {
      try {
        const product = reduxData['productState']?.['product'];
        const pricesList = product?.['prices'] || [];
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
          if (minPrice !== null) {
            console.log(`   [HEPSIBURADA] Redux store prices listesinden fiyat bulundu: ${minPrice} TL`);
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
        if (parsed && parsed > 0) return parsed;
      }
    }

    return null;
  }

  scrapeBreadcrumbs($) {
    // ReduxStore breadcrumbs kontrolü
    const script = $('#reduxStore');
    if (script.length) {
      try {
        const reduxData = JSON.parse(script.text());
        const product = reduxData['productState']?.['product'];
        if (product && product['rootCategoryList']) {
          const breadcrumbs = [];
          for (const item of product['rootCategoryList']) {
            if (item && item['name']) {
              const name = this.unescapeHtml(item['name'].toString().trim());
              if (name && name.toLowerCase() !== 'anasayfa') {
                breadcrumbs.push(name);
              }
            }
          }
          if (breadcrumbs.length > 0) return breadcrumbs;
        }
      } catch (_) {}
    }

    const title = this.scrapeTitle($) || '';
    return this.extractBreadcrumbsFromJsonLd($, title, 'hepsiburada');
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
          const updateLowest = (priceVal) => {
            if (priceVal != null) {
              const p = parseFloat(priceVal);
              if (!isNaN(p) && p > 0) {
                if (lowestCalculatedPrice === null || p < lowestCalculatedPrice) {
                  lowestCalculatedPrice = p;
                }
              }
            }
          };

          const priceData = productResult['priceData'];
          if (priceData) {
            updateLowest(priceData['discountedPrice']);
            updateLowest(priceData['price']);
          }

          const promoData = productResult['promoData']?.['data'];
          if (promoData) {
            const premiumResult = promoData['campaignEvaluateResult']?.['evaluateAsPremiumResult'];
            if (premiumResult) {
              updateLowest(premiumResult['discountedPrice']);
            }
            const evalResult = promoData['campaignEvaluateResult']?.['evaluateResult'];
            if (evalResult) {
              updateLowest(evalResult['discountedPrice']);
            }
            const normalResult = promoData['campaignEvaluateResult'];
            if (normalResult) {
              updateLowest(normalResult['discountedPrice']);
            }
          }

          if (lowestCalculatedPrice !== null && lowestCalculatedPrice > 0) {
            return lowestCalculatedPrice;
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
        for (const listingObj of listingsResult) {
          if (listingObj && typeof listingObj === 'object') {
            let listingPrice = null;
            const updateListingLowest = (priceVal) => {
              if (priceVal != null) {
                const p = parseFloat(priceVal);
                if (!isNaN(p) && p > 0) {
                  if (listingPrice === null || p < listingPrice) {
                    listingPrice = p;
                  }
                }
              }
            };

            const priceData = listingObj['priceData'];
            if (priceData) {
              updateListingLowest(priceData['discountedPrice']);
              updateListingLowest(priceData['price']);
            }

            const promoData = listingObj['promoData']?.['data'];
            if (promoData) {
              const premiumResult = promoData['campaignEvaluateResult']?.['evaluateAsPremiumResult'];
              if (premiumResult) {
                updateListingLowest(premiumResult['discountedPrice']);
              }
              const evalResult = promoData['campaignEvaluateResult']?.['evaluateResult'];
              if (evalResult) {
                updateListingLowest(evalResult['discountedPrice']);
              }
              const normalResult = promoData['campaignEvaluateResult'];
              if (normalResult) {
                updateListingLowest(normalResult['discountedPrice']);
              }
            }

            if (listingPrice !== null && listingPrice > 0) {
              if (lowestPrice === null || listingPrice < lowestPrice) {
                lowestPrice = listingPrice;
              }
            }
          }
        }
        if (lowestPrice !== null && lowestPrice > 0) {
          return lowestPrice;
        }
      }
    } catch (_) {}
    return null;
  }
}

module.exports = HepsiburadaScraper;
