/**
 * Teknosa Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class TeknosaScraper extends BaseProductScraper {
  get domain() { return 'teknosa.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('teknosa.com');
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
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r) return r;
    }
    // 3. DOM Selectors
    const imgSelectors = [
      '.product-images img',
      '#product-detail-gallery img',
      'img[class*="product"]'
    ];
    for (const sel of imgSelectors) {
      const elements = $(sel);
      for (let i = 0; i < elements.length; i++) {
        const el = $(elements[i]);
        const src = el.attr('src') || el.attr('data-src');
        if (src && !this.isLogoUrl(src)) {
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
    const el = $('span.replaceName, h1.product-title, h1').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. DOM Seçicileri - Öncelikli: span.prc-third (Hem indirimli hem indirimsiz doğru fiyatı içerir)
    const priceThirdEl = $('span.prc-third').first();
    if (priceThirdEl.length) {
      const v = this.parsePriceText(priceThirdEl.text());
      if (v && v > 0) return v;
    }

    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 3. Diğer DOM Seçicileri (Yedek)
    const el = $('span.prc, .price, .product-price').first();
    if (el.length) {
      const v = this.parsePriceText(el.text());
      if (v && v > 0) return v;
    }
    return null;
  }

  scrapeDescription($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['description']) return product['description'].toString().trim();
    // 2. DOM
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? descEl.attr('content')?.trim() : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'teknosa');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, .breadcrumb-list a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && !lower.includes('teknosa') && text !== title && text.length < 50) {
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

    // 2. DOM (itemprop="ratingValue")
    const ratingEl = $('[itemprop="ratingValue"], meta[property="product:rating:value"], .pdp-rating-value, .rating-score').first();
    let ratingValue = null;
    let ratingCount = null;

    if (ratingEl.length) {
      const txt = ratingEl.is('meta') ? ratingEl.attr('content') : ratingEl.text();
      if (txt) {
        const p = parseFloat(txt.trim().replace(',', '.'));
        if (!isNaN(p) && p > 0 && p <= 5.0) ratingValue = p;
      }
    }

    const countEl = $('[itemprop="reviewCount"], [itemprop="ratingCount"], .pdp-review-count, .rating-count').first();
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

module.exports = TeknosaScraper;
