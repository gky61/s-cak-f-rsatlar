/**
 * MediaMarkt Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class MediaMarktScraper extends BaseProductScraper {
  get domain() { return 'mediamarkt.com.tr'; }

  canHandle(url) {
    return url.toLowerCase().includes('mediamarkt.com.tr');
  }

  scrapeImage($, url) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const r = this.resolveImageUrl(img, url);
        if (r) return r;
      }
    }
    // 2. og:image
    const ogImg = $('meta[property="og:image"]').attr('content') ||
                  $('meta[name="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r) return r;
    }
    // 3. DOM Selectors
    const selectors = [
      'img[data-testid="product-image"]',
      '#product-image img',
      'img.product-image',
      '.product-details img'
    ];
    for (const sel of selectors) {
      const elements = $(sel);
      for (let i = 0; i < elements.length; i++) {
        const src = $(elements[i]).attr('src') || $(elements[i]).attr('data-src') || $(elements[i]).attr('data-lazy-src');
        if (src && !src.startsWith('data:') && !this.isLogoUrl(src)) {
          const r = this.resolveImageUrl(src, url);
          if (r) return r;
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
    const titleEl = $('h1[class*="mms-ui-"], h1').first();
    if (titleEl.length) return titleEl.text().trim();
    const og = $('meta[property="og:title"]').attr('content');
    return og ? og.trim() : null;
  }

  scrapePrice($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    // 2. DOM
    const priceSelectors = [
      '[data-test="branded-price-whole-value"]',
      'meta[property="product:price:amount"]',
      'meta[property="og:price:amount"]'
    ];
    for (const sel of priceSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const text = el.is('meta') ? el.attr('content') : el.text();
        const val = this.parsePriceText(text || '');
        if (val && val > 0) return val;
      }
    }
    return null;
  }

  scrapeDescription($) {
    // 1. JSON-LD şemasından açıklama çekmeyi dene (Öncelikli) — Dart ile aynı
    const product = this.findProductJsonLd($);
    if (product && product['description']) return product['description'].toString().trim();
    // 2. DOM Seçicileri (Fallback)
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? descEl.attr('content')?.trim() : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'mediamarkt');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb-list a, .breadcrumbs a, .breadcrumb a, .mms-breadcrumb a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'home' && !lower.includes('mediamarkt') && text !== title && text.length < 50) {
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

    // 2. DOM (data-test="mms-pdp-average-rating-summary")
    const ratingEl = $('[data-test="mms-pdp-average-rating-summary"], [class*="mms-pdp-average-rating"]').first();
    if (ratingEl.length) {
      const ariaLabel = ratingEl.attr('aria-label') || ratingEl.text() || '';
      let ratingValue = null;
      let ratingCount = null;

      const valMatch = /göre\s+([\d.,]+)/.exec(ariaLabel) || /([\d.,]+)\s*şeklindedir/.exec(ariaLabel) || /([\d.,]+)/.exec(ariaLabel);
      if (valMatch) {
        const p = parseFloat(valMatch[1].replace(',', '.'));
        if (!isNaN(p) && p > 0 && p <= 5.0) ratingValue = p;
      }

      const cntMatch = /(\d+)\s+(?:inceleme|yorum|oy|değerlendirme)/.exec(ariaLabel);
      if (cntMatch) {
        const c = parseInt(cntMatch[1]);
        if (!isNaN(c) && c > 0) ratingCount = c;
      }

      if (ratingValue || ratingCount) {
        return { ratingValue, ratingCount };
      }
    }

    // 3. Hydration script / Raw script regex search ("averageOverallRating", "totalReviewCount")
    let ratingValue = null;
    let ratingCount = null;

    $('script').each((_, el) => {
      const text = $(el).html() || '';
      if (!ratingValue && (text.includes('averageOverallRating') || text.includes('ratingValue') || text.includes('averageRating'))) {
        const match = /averageOverallRating["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?/.exec(text) ||
                      /ratingValue["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?/.exec(text) ||
                      /averageRating["\\]*\s*:\s*"?([\d]+(?:[.,]\d+)?)"?/.exec(text);
        if (match) {
          const p = parseFloat(match[1].replace(',', '.'));
          if (!isNaN(p) && p > 0 && p <= 5.0) {
            ratingValue = Math.round(p * 10) / 10;
          }
        }
      }

      if (!ratingCount && (text.includes('totalReviewCount') || text.includes('reviewCount') || text.includes('ratingCount'))) {
        const match = /totalReviewCount["\\]*\s*:\s*"?(\d+)"?/.exec(text) ||
                      /(?:reviewCount|ratingCount)["\\]*\s*:\s*"?(\d+)"?/.exec(text);
        if (match) {
          const c = parseInt(match[1]);
          if (!isNaN(c) && c > 0) {
            ratingCount = c;
          }
        }
      }
    });

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
    const metaBrand = $('meta[property="product:brand"], meta[name="brand"], [data-test="mms-pdp-brand-name"]').first();
    if (metaBrand.length) {
      const txt = metaBrand.is('meta') ? metaBrand.attr('content') : metaBrand.text();
      if (txt && txt.trim()) return txt.trim();
    }
    return null;
  }
}

module.exports = MediaMarktScraper;
