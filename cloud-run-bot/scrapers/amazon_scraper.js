/**
 * Amazon Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class AmazonScraper extends BaseProductScraper {
  get domain() { return 'amazon.'; }

  canHandle(url) {
    const lower = url.toLowerCase();
    return lower.includes('amazon.') || 
           lower.includes('amzn.') || 
           lower.includes('link.amazon') || 
           lower.includes('amzlinks.');
  }

  scrapePriceLabel($) {
    // 1. Prime Özel/Fırsatı metin ve element kontrolleri
    const dealBadge = $('#dealBadgeSupportingText, .dealBadgeSupportingText, [data-badge-text*="Prime"]').text().trim();
    if (/prime\s*(?:fırsat|özel|deal)/i.test(dealBadge)) {
      return "Prime Fırsatı";
    }

    // 2. #primeExclusivePricingMessage ve upsell konteynerleri
    const primeMsg = $('#primeExclusivePricingMessage, [id*="primeExclusivePricing"], [id*="primeSavingsUpsell"]').text().trim();
    if (primeMsg && (/prime\s*(?:ile|’a|'a|\s*üyeleri)/i.test(primeMsg) || /fırsat yalnızca amazon prime/i.test(primeMsg))) {
      return "Prime Fırsatı";
    }

    // 3. Ürün ana gövdesinde Prime Fırsatı / Prime'a Özel metin kontrolü (Header/Footer hariç)
    let found = false;
    const primeRegex = /(?:amazon\s*)?prime\s*fırsatı|(?:amazon\s*)?prime['’]?\s*(?:a|’a|'a)?\s*özel|bu fırsat yalnızca amazon prime/i;
    $('#centerCol, #dp-container, #apex_desktop, #corePrice_desktop, #desktop_buybox, span, div, p, b, strong, i, a').each((_, el) => {
      const id = ($(el).attr('id') || '').toLowerCase();
      const cls = ($(el).attr('class') || '').toLowerCase();
      if (id.includes('navbar') || id.includes('navfooter') || id.includes('nav-belt') || cls.includes('nav-subnav') || cls.includes('nav-footer')) {
        return;
      }

      const txt = $(el).clone().children().remove().end().text().trim();
      if (txt.length <= 120 && primeRegex.test(txt)) {
        found = true;
        return false;
      }
    });
    if (found) return "Prime Fırsatı";

    return null;
  }

  scrapeImage($, url) {
    // 1. data-a-dynamic-image
    const dynImgs = $('[data-a-dynamic-image]');
    for (let i = 0; i < dynImgs.length; i++) {
      try {
        const attr = $(dynImgs[i]).attr('data-a-dynamic-image');
        if (attr) {
          const data = JSON.parse(attr);
          const firstKey = Object.keys(data)[0];
          if (firstKey && !firstKey.startsWith('data:') && !this.isLogoUrl(firstKey)) {
            const resolved = this.resolveImageUrl(firstKey, url);
            if (resolved) return resolved;
          }
        }
      } catch (_) {}
    }

    // 2. Amazon selectors
    const selectors = [
      '#landingImage',
      '#imgBlkFront',
      '#main-image',
      '#imageBlock_feature_div img',
      '#imageBlock img',
      '#altImages img',
      '.a-dynamic-image',
      '[id*="landingImage"]',
      '[id*="main-image"]'
    ];

    for (const sel of selectors) {
      const elements = $(sel);
      for (let i = 0; i < elements.length; i++) {
        const el = $(elements[i]);
        const src = el.attr('src') || el.attr('data-src') || el.attr('data-a-dynamic-image') || el.attr('data-old-src');
        if (src && !src.startsWith('data:')) {
          // Amazon placeholder atlama
          if (src.includes('pixel') || src.includes('placeholder') || src.includes('spinner') || src.includes('loading')) {
            continue;
          }
          // Geçerli görseli çöz ve dön
          const resolved = this.resolveImageUrl(src, url);
          if (resolved && !this.isLogoUrl(resolved)) return resolved;
        }
      }
    }

    // 3. JSON-LD — Dart'taki _extractImageFromJson ile birebir eşit özel recursive arama
    const scripts = $('script[type="application/ld+json"]');
    for (let i = 0; i < scripts.length; i++) {
      try {
        const jsonContent = $(scripts[i]).text();
        if (jsonContent.includes('Product') || jsonContent.includes('image')) {
          const jsonData = JSON.parse(jsonContent);
          const imageUrl = this._extractImageFromJson(jsonData);
          if (imageUrl && !this.isLogoUrl(imageUrl)) {
            const resolved = this.resolveImageUrl(imageUrl, url);
            if (resolved) return resolved;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  _extractImageFromJson(jsonData) {
    if (jsonData && typeof jsonData === 'object' && !Array.isArray(jsonData)) {
      if (jsonData['image'] != null) {
        if (typeof jsonData['image'] === 'string') {
          return jsonData['image'];
        } else if (typeof jsonData['image'] === 'object' && !Array.isArray(jsonData['image']) && jsonData['image']['url'] != null) {
          return jsonData['image']['url'];
        } else if (Array.isArray(jsonData['image']) && jsonData['image'].length > 0) {
          const firstImage = jsonData['image'][0];
          if (typeof firstImage === 'string') return firstImage;
          if (firstImage && typeof firstImage === 'object' && firstImage['url'] != null) return firstImage['url'];
        }
      }
      if (Array.isArray(jsonData['@graph'])) {
        for (const item of jsonData['@graph']) {
          const image = this._extractImageFromJson(item);
          if (image) return image;
        }
      }
      if (Array.isArray(jsonData['itemListElement'])) {
        for (const item of jsonData['itemListElement']) {
          const image = this._extractImageFromJson(item);
          if (image) return image;
        }
      }
      for (const value of Object.values(jsonData)) {
        const image = this._extractImageFromJson(value);
        if (image) return image;
      }
    }
    return null;
  }

  scrapeTitle($) {
    const el = $('#productTitle, #title, .a-size-large.product-title-word-break').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. En öncelikli yeni yapı: twister-plus-buying-options-price-data JSON kutusunu çöz
    const twisterEl = $('.twister-plus-buying-options-price-data').first();
    if (twisterEl.length) {
      try {
        const jsonStr = twisterEl.text().trim();
        const data = JSON.parse(jsonStr);
        if (data && typeof data === 'object') {
          for (const key of Object.keys(data)) {
            const list = data[key];
            if (Array.isArray(list) && list.length > 0) {
              const firstObj = list[0];
              if (firstObj && typeof firstObj === 'object') {
                const priceAmount = firstObj['priceAmount'];
                if (priceAmount !== undefined && priceAmount !== null) {
                  const parsed = parseFloat(priceAmount.toString());
                  if (!isNaN(parsed) && parsed > 0) {
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
    const depoSelectors = [
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

    for (const sel of depoSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const val = this.parsePriceText(el.text());
        if (val !== null && val > 0) {
          return val;
        }
      }
    }

    // 3. Birincil Satış Fiyatı Seçicileri
    const primarySelectors = [
      '#rightCol #tp_price_block_total_price_ww .a-offscreen, #rightCol #tp_price_block_total_price_ww .aok-offscreen',
      '#corePrice_feature_div .a-price .a-offscreen, #corePrice_feature_div .a-price .aok-offscreen',
      '#corePriceDisplay_desktop_feature_div .a-price .a-offscreen, #corePriceDisplay_desktop_feature_div .a-price .aok-offscreen',
      '#corePriceDisplay_desktop_feature_div .a-price',
      '#rightCol .priceToPay .a-offscreen, #rightCol .priceToPay .aok-offscreen',
      '#centerCol .priceToPay .a-offscreen, #centerCol .priceToPay .aok-offscreen',
      '#rightCol .apexPriceToPay .a-offscreen, #rightCol .apexPriceToPay .aok-offscreen',
      '#centerCol .apexPriceToPay .a-offscreen, #centerCol .apexPriceToPay .aok-offscreen',
      '#rightCol #aod-ingress-link .a-price .a-offscreen',
      '#price_inside_buybox',
      '#priceBlock_dealPrice',
      '#priceBlock_ourPrice',
      '.priceToPay',
      '.apexPriceToPay'
    ];

    for (const sel of primarySelectors) {
      const el = $(sel).first();
      if (el.length) {
        if (el.closest('.a-text-price').length === 0) { // Üstü çizili değilse
          const val = this.parsePriceText(el.text());
          if (val !== null && val > 0) {
            return val;
          }
        }
      }
    }

    // 4. Genel .a-price, .a-offscreen, .aok-offscreen ve .offer-price etiketlerinden (sadece ana alanlardaki) üstü çizili olmayan fiyatı seç
    const offscreenEls = $('.a-price .a-offscreen, .a-price .aok-offscreen, .offer-price, .a-price');
    let bestPrice = null;
    for (let i = 0; i < offscreenEls.length; i++) {
      const el = $(offscreenEls[i]);
      if (el.closest('.a-text-price').length > 0) {
        continue; // Üstü çizili liste fiyatını atla
      }
      const val = this.parsePriceText(el.text());
      if (val !== null && val > 0) {
        if (bestPrice === null || val < bestPrice) {
          bestPrice = val;
        }
      }
    }
    if (bestPrice !== null) return bestPrice;

    // 5. Fallback: Eğer yukarıdakiler bulunamadıysa, sayfa genelindeki ilk geçerli fiyatı dön
    for (let i = 0; i < offscreenEls.length; i++) {
      const el = $(offscreenEls[i]);
      const val = this.parsePriceText(el.text());
      if (val !== null && val > 0) {
        return val;
      }
    }

    return null;
  }

  scrapeDescription($) {
    const descEl = $('meta[name="description"], meta[property="og:description"], meta[property="twitter:description"]').first();
    return descEl.length ? descEl.attr('content')?.trim() : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = [];
    // 1. Standard breadcrumbs
    const els = $('#wayfinding-breadcrumbs_feature_div ul li a, #wayfinding-breadcrumbs_container ul li a, .a-breadcrumb a, #wayfinding-breadcrumbs_feature_div li a, #wayfinding-breadcrumbs_container li a');
    els.each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('amazon') && text !== title && text.length < 50) {
          breadcrumbs.push(text);
        }
      }
    });
    if (breadcrumbs.length > 0) return breadcrumbs;
    // 2. nav-subnav
    const subnav = $('#nav-subnav a.nav-b, #nav-subnav .nav-b, #nav-subnav a[class*="nav-b"]').first();
    if (subnav.length) {
      const text = subnav.text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('amazon') && text !== title && text.length < 50) {
          return [text];
        }
      }
    }
    // 3. data-category
    const navSubnav = $('#nav-subnav');
    if (navSubnav.length) {
      let dataCat = navSubnav.attr('data-category');
      if (dataCat) {
        dataCat = dataCat.trim();
        if (dataCat.toLowerCase() === 'electronics') dataCat = 'Elektronik';
        else if (dataCat.toLowerCase() === 'books') dataCat = 'Kitap';
        else if (dataCat.toLowerCase() === 'fashion') dataCat = 'Moda';
        else if (dataCat.toLowerCase() === 'home') dataCat = 'Ev ve Yaşam';
        return [dataCat];
      }
    }
    return [];
  }

  scrapeRating($) {
    let ratingValue = null;
    let ratingCount = null;

    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }

    // 2. DOM ratingValue
    const popover = $('#averageCustomerReviews .a-icon-alt, #acrPopover .a-icon-alt, span.a-icon-alt').first();
    if (popover.length) {
      const text = popover.text().trim();
      const match = text.match(/([0-5][.,]\d)/);
      if (match) {
        const val = parseFloat(match[1].replace(',', '.'));
        if (!isNaN(val) && val > 0 && val <= 5.0) ratingValue = val;
      }
    }

    if (!ratingValue) {
      const ratingText = $('span[data-hook="rating-out-of-text"]').first().text().trim();
      if (ratingText) {
        const match = ratingText.match(/([0-5][.,]\d)/);
        if (match) {
          const val = parseFloat(match[1].replace(',', '.'));
          if (!isNaN(val) && val > 0 && val <= 5.0) ratingValue = val;
        }
      }
    }

    if (!ratingValue) {
      const starIcon = $('i[class*="a-star-"]').first();
      if (starIcon.length) {
        const cls = starIcon.attr('class') || '';
        const match = cls.match(/a-star-(\d+)(?:-(\d+))?/);
        if (match) {
          const major = match[1];
          const minor = match[2] || '0';
          const val = parseFloat(`${major}.${minor}`);
          if (!isNaN(val) && val > 0 && val <= 5.0) ratingValue = val;
        }
      }
    }

    // 3. DOM ratingCount
    const countSelectors = [
      '#acrCustomerReviewText',
      '#acrCustomerReviewLink',
      'span[data-hook="total-review-count"]',
      '#totalReviewCount',
      '[itemprop="reviewCount"]',
      '[itemprop="ratingCount"]'
    ];

    for (const sel of countSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const text = el.text().trim();
        const match = text.match(/(\d[\d.,]*)/);
        if (match) {
          const clean = match[1].replace(/\./g, '').replace(/,/g, '');
          const val = parseInt(clean, 10);
          if (!isNaN(val) && val > 0) {
            ratingCount = val;
            break;
          }
        }
      }
    }

    return { ratingValue, ratingCount };
  }

  scrapeBrand($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand) return brand;
    }

    // 2. DOM Table tr.po-brand
    const poBrand = $('tr.po-brand td.po-break-word, tr.po-brand span.a-size-base').last().text().trim();
    if (poBrand && poBrand !== 'Marka') return poBrand;

    // 3. #bylineInfo
    const byline = $('#bylineInfo, a#bylineInfo').first().text().trim();
    if (byline) {
      let clean = byline
        .replace(/Marka:\s*/i, '')
        .replace(/Brand:\s*/i, '')
        .replace(/Store’u ziyaret edin/i, '')
        .replace(/Store'u ziyaret edin/i, '')
        .replace(/Visit the\s*/i, '')
        .replace(/\s*Store/i, '')
        .trim();
      if (clean) return clean;
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    let candidates = [];

    const selectors = [
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
      '#listPrice'
    ];

    for (const selector of selectors) {
      $(selector).each((_, el) => {
        const txt = $(el).text().trim();
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
}

module.exports = AmazonScraper;
