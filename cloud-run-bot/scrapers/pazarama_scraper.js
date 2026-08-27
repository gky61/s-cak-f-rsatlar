/**
 * Pazarama Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class PazaramaScraper extends BaseProductScraper {
  get domain() { return 'pazarama.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('pazarama.com');
  }

  scrapePriceLabel($) {
    // 1. DOM: Plus ikonu veya Plus banner/linki
    const hasPlusImg = $('img[alt*="plus-icon"], img[src*="pz-plus-icon"], img[src*="plus-icon"]').length > 0;
    if (hasPlusImg) return "Plus ile";

    const hasPlusLink = $('a[href*="pazarama-plus"]').length > 0;
    if (hasPlusLink) return "Plus ile";

    // 2. Metin bazlı DOM araması
    let foundText = false;
    const plusRegex = /(?:pazarama\s*)?plus['’]?\s*(?:ile|a özel|fırsat)|şimdi\s*plus['’]l[ıi]\s*ol/i;
    $('span, div, p, b, strong, a, label').each((_, el) => {
      const text = $(el).clone().children().remove().end().text().trim();
      if (plusRegex.test(text)) {
        foundText = true;
        return false;
      }
    });
    if (foundText) return "Plus ile";

    // 3. Script kontrolü
    let scriptFound = false;
    const scriptPlusRegex = /pz-plus-icon|pazarama-plus|CART_BASKET_PLUS_PROMO|CMS_PLUS_ADVANTAGES|PLUS_USER_SUBSCRIPTION_STATUS/i;
    $('script').each((_, el) => {
      const text = $(el).text();
      if (text && scriptPlusRegex.test(text)) {
        scriptFound = true;
        return false;
      }
    });
    if (scriptFound) return "Plus ile";

    return null;
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
    // 2. DOM Selectors
    const pazaramaSelectors = [
      '.product-detail-slider img',
      '.product-image img',
      'picture img',
      'img[class*="object-contain"]',
      'img[src*="pzrmcdn.com"]',
      'img[src*="asset/"][src*="images/"]',
      'img[src*="product"]',
      'main img',
      '#product-image-gallery img'
    ];
    for (const sel of pazaramaSelectors) {
      const elements = $(sel);
      for (let i = 0; i < elements.length; i++) {
        const src = $(elements[i]).attr('src') || $(elements[i]).attr('data-src') || $(elements[i]).attr('data-lazy-src') || $(elements[i]).attr('data-old-hires');
        if (src && !src.startsWith('data:') && !this.isLogoUrl(src)) {
          const resolved = this.resolveImageUrl(src, url);
          if (resolved) return resolved;
        }
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    // 2. DOM
    const titleEl = $('h1.text-huge.text-gray-600.font-bold, h1.text-huge, h1').first();
    if (titleEl.length) return titleEl.text().trim();
    const og = $('meta[property="og:title"]').attr('content');
    if (og) return og.trim();
    return null;
  }

  scrapePrice($) {
    // 1. Pazarama Plus / Sepet / Mavi indirimli özel fiyat
    let bluePrice = null;
    $('span.text-blue-500.font-bold, span[class*="text-blue-500"], img[alt="plus-icon"], img[src*="pz-plus-icon"]').each((_, el) => {
      let targetSpan = $(el);
      if ($(el).is('img')) {
        let parent = $(el).parent();
        while (parent.length && parent.prop('tagName') !== 'DIV') {
          parent = parent.parent();
        }
        targetSpan = parent.find('span');
      }
      targetSpan.each((_, s) => {
        const text = $(s).text().trim();
        if (text.includes('TL') && !text.includes('ile')) {
          const val = this.parsePriceText(text);
          if (val && val > 0) {
            bluePrice = val;
          }
        }
      });
    });
    if (bluePrice && bluePrice > 0) return bluePrice;

    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 3. DOM
    const selectors = [
      'div[class*="text-4xl"][class*="text-black"][class*="font-bold"]',
      'p.text-4xl.font-bold',
      'div.text-4xl.text-black.font-bold',
      'div.text-4xl.text-black',
      'span[class*="text-lg"][class*="font-bold"][class*="text-red-600"]',
      'span.text-lg.font-bold.text-red-600',
      'meta[property="product:price:amount"]'
    ];
    for (const sel of selectors) {
      const el = $(sel).first();
      if (el.length) {
        const text = el.is('meta') ? el.attr('content') : el.text();
        const val = this.parsePriceText(text || '');
        if (val && val > 0) return val;
      }
    }
    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    let candidates = [];

    const selectors = [
      '.line-through',
      'span.text-gray-400.line-through',
      'p.text-base.font-normal.text-gray-400.line-through',
      'p.text-lg.font-bold.text-red-600',
      'p.text-gray-400',
      '[class*="text-gray-400"]',
      'del',
      's'
    ];

    for (const selector of selectors) {
      $(selector).each((_, el) => {
        const txt = $(el).text().trim();
        if (txt.includes('TL')) {
          const parsed = this.parsePriceText(txt);
          if (parsed !== null && parsed > currentPrice) {
            candidates.push(parsed);
          }
        }
      });
    }

    if (candidates.length === 0) return null;

    candidates = candidates.filter(c => c > currentPrice && c <= currentPrice * 5);
    if (candidates.length === 0) return null;

    candidates.sort((a, b) => b - a);
    return candidates[0];
  }

  scrapeDescription($) {
    const metaDesc = $('meta[name="description"], meta[data-hid="description"], meta[property="og:description"]').first();
    if (metaDesc.length) {
      const desc = metaDesc.attr('content')?.trim();
      if (desc && desc.toLowerCase() !== 'null') return desc;
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'pazarama');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, .breadcrumb-list a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && !lower.includes('pazarama') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }

  scrapeRating($) {
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }
    return { ratingValue: null, ratingCount: null };
  }

  scrapeBrand($) {
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand) return brand;
    }
    return null;
  }
}

module.exports = PazaramaScraper;
