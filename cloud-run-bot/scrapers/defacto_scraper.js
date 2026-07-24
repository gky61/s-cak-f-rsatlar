/**
 * DeFacto Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class DefactoScraper extends BaseProductScraper {
  get domain() { return 'defacto.com.tr'; }

  canHandle(url) {
    return url.toLowerCase().includes('defacto.com.tr');
  }

  _decodeUnicode(str) {
    try {
      return str.replace(/\\u([\dA-Fa-f]{4})/g, (_, grp) => String.fromCharCode(parseInt(grp, 16)));
    } catch (_) {
      return str;
    }
  }

  scrapeImage($, url) {
    // 1. og:image
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r) return r;
    }
    // 2. DOM
    const imgSelectors = [
      '.product-card__image img',
      '.product-image img',
      'img[class*="product"]',
      'main img'
    ];
    for (const sel of imgSelectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const r = this.resolveImageUrl(src, url);
        if (r) return r;
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. Script
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('PRODUCT_DETAIL_LASTVISITED') || text.includes('PRODUCT_DETAIL_INFO')) {
        const match = text.match(/"?ProductVariantMiniProductName"?\s*:\s*"([^"]+)"/) ||
                      text.match(/"?Name"?\s*:\s*"([^"]+)"/) ||
                      text.match(/"?name"?\s*:\s*"([^"]+)"/);
        if (match) {
          return this.unescapeHtml(this._decodeUnicode(match[1]));
        }
      }
    }
    // 2. DOM
    const el = $('h1.product-card__title, .product-title, h1').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. DOM campaing-base-price (Sepette / Kampanyalı indirimli fiyat)
    const campaingEl = $('[class*="campaing-base-price"], .campaing-base-price, .product-price__discount').first();
    if (campaingEl.length) {
      const val = this.parsePriceText(campaingEl.text());
      if (val && val > 0) return val;
    }

    // 2. Script bloğundan
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('PRODUCT_DETAIL_LASTVISITED') || text.includes('CampaignBadge')) {
        // A) DiscountPrice
        const m1 = text.match(/"?DiscountPrice"?\s*:\s*([0-9.]+)/);
        if (m1) {
          const val = parseFloat(m1[1]);
          if (!isNaN(val) && val > 0) return val;
        }
        // B) CampaignDiscountedPrice
        const m2 = text.match(/"?CampaignDiscountedPrice"?\s*:\s*([0-9.]+)/);
        if (m2) {
          const val = parseFloat(m2[1]);
          if (!isNaN(val) && val > 0) return val;
        }
        // C) ProductVariantMiniDiscountedPriceInclTax
        const m3 = text.match(/"?ProductVariantMiniDiscountedPriceInclTax"?\s*:\s*"([0-9.]+)"/);
        if (m3) {
          const val = parseFloat(m3[1]);
          if (!isNaN(val) && val > 0) return val;
        }
      }
    }

    // 3. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 4. DOM fallback
    const priceSelectors = [
      '.product-price',
      '.product-info__price--new',
      'span[class*="price"]'
    ];
    for (const sel of priceSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const val = this.parsePriceText(el.text());
        if (val && val > 0) return val;
      }
    }
    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    // 1. DOM lined-base-price (İndirimsiz çizili fiyat)
    const linedEl = $('[class*="lined-base-price"], .lined-base-price').first();
    if (linedEl.length) {
      const txt = linedEl.text().trim();
      const val = this.parsePriceText(txt);
      if (val && val > currentPrice) return val;
    }

    // 2. JSON-LD price (DeFacto JSON-LD genellikle indirim öncesi liste fiyatını verir)
    const product = this.findProductJsonLd($);
    if (product && product.offers && product.offers.price != null) {
      const p = parseFloat(product.offers.price);
      if (!isNaN(p) && p > currentPrice) return p;
    }

    // 3. Fallback selectors
    let candidates = [];
    const selectors = [
      '[class*="lined-base-price"]',
      '.lined-base-price',
      'del',
      's',
      '.old-price',
      '.original-price'
    ];
    for (const selector of selectors) {
      $(selector).each((_, el) => {
        const txt = $(el).text().trim();
        if (txt.includes('TL') || txt.includes('₺')) {
          const parsed = this.parsePriceText(txt);
          if (parsed !== null && parsed > currentPrice && parsed <= currentPrice * 5) {
            candidates.push(parsed);
          }
        }
      });
    }

    if (candidates.length === 0) return null;

    candidates.sort((a, b) => b - a);
    return candidates[0];
  }

  scrapeDescription($) {
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? descEl.attr('content')?.trim() : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'defacto');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, .defacto-breadcrumb a, .breadcrumb-list a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('defacto') && lower !== title.toLowerCase().trim() && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }

  scrapeRating($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }

    // 2. DOM
    const ratingEl = $('[itemprop="ratingValue"], meta[property="product:rating:value"], .rating-score, .pdp-rating-value').first();
    let ratingValue = null;
    let ratingCount = null;

    if (ratingEl.length) {
      const txt = ratingEl.is('meta') ? ratingEl.attr('content') : ratingEl.text();
      if (txt) {
        const p = parseFloat(txt.trim().replace(',', '.'));
        if (!isNaN(p) && p > 0 && p <= 5.0) ratingValue = p;
      }
    }

    const countEl = $('[itemprop="reviewCount"], [itemprop="ratingCount"], .review-count, .rating-count').first();
    if (countEl.length) {
      const txt = countEl.is('meta') ? countEl.attr('content') : countEl.text();
      if (txt) {
        const m = /(\d+)/.exec(txt);
        if (m) {
          const c = parseInt(m[1]);
          if (!isNaN(c) && c > 0) ratingCount = c;
        }
      }
    }

    if (ratingValue || ratingCount) {
      return { ratingValue, ratingCount };
    }

    return { ratingValue: null, ratingCount: null };
  }

  scrapeBrand($) {
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand) return brand;
    }
    const metaBrand = $('meta[property="product:brand"], meta[name="brand"], .product-brand, [data-brand]').first();
    if (metaBrand.length) {
      const txt = metaBrand.is('meta') ? metaBrand.attr('content') : (metaBrand.attr('data-brand') || metaBrand.text());
      if (txt && txt.trim()) return txt.trim();
    }
    return null;
  }
}

module.exports = DefactoScraper;
