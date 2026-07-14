/**
 * Amazon Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class AmazonScraper extends BaseProductScraper {
  get domain() { return 'amazon.'; }

  canHandle(url) {
    const lower = url.toLowerCase();
    return lower.includes('amazon.') || lower.includes('amzn.');
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

    // 2. Birincil Satış Fiyatı Seçicileri (Örn: İndirimli ana fiyat alanları)
    const primarySelectors = [
      '#corePrice_feature_div .a-price .a-offscreen',
      '.apexPriceToPay .a-offscreen',
      '.priceToPay .a-offscreen',
      '#price_inside_buybox',
      '#priceBlock_dealPrice',
      '#priceBlock_ourPrice'
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

    // 3. Genel .a-price .a-offscreen etiketlerinden üstü çizili olmayan en düşük fiyatı seç
    const offscreenEls = $('.a-price .a-offscreen');
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

    // 4. Fallback: Eğer üstü çizili olmayan bulunamadıysa, ilk geçerli fiyatı dön
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
}

module.exports = AmazonScraper;
