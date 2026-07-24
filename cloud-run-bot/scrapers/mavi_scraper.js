/**
 * Mavi Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class MaviScraper extends BaseProductScraper {
  get domain() { return 'mavi.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('mavi.com');
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
    // 3. DOM selectors
    const imgSelectors = [
      '.product-detail-images img',
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
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    // 2. DOM
    const el = $('h1.product-title, .product-name, h1').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. DOM .price inside .product__pricing-info
    const pricingInfo = $('.product__pricing-info, .js-product-price').first();
    if (pricingInfo.length) {
      const priceEl = pricingInfo.find('.price, ins.price').first();
      if (priceEl.length) {
        const val = this.parsePriceText(priceEl.text());
        if (val && val > 0) return val;
      }
    }

    // 2. DOM fallback
    const priceSelectors = [
      'ins.price',
      '.product-price',
      '.price-value',
      '.price',
      'span[class*="price"]'
    ];
    for (const sel of priceSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const text = el.is('meta') ? el.attr('content') : el.text();
        const v = this.parsePriceText(text || '');
        if (v && v > 0) return v;
      }
    }

    // 3. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    // 1. DOM .nodiscount-price
    const nodiscountEl = $('.nodiscount-price, .product__pricing-info .nodiscount-price, del.nodiscount-price').first();
    if (nodiscountEl.length) {
      const txt = nodiscountEl.text().trim();
      const val = this.parsePriceText(txt);
      if (val && val > currentPrice) return val;
    }

    // 2. Fallback selectors
    let candidates = [];
    const selectors = [
      '.nodiscount-price',
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
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['description']) return product['description'].toString().trim();
    // 2. DOM
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? descEl.attr('content')?.trim() : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'mavi');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, .breadcrumb-item a, nav a, ol li a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('mavi') && lower !== title.toLowerCase().trim() && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }

  scrapeRating($) {
    // 1. DOM Seçicileri (Öncelikli - Mavi'ye özel)
    const ratingEl = $('.average-rate__number, [itemprop="ratingValue"], meta[property="product:rating:value"], .rating-score, .pdp-rating-value').first();
    let ratingValue = null;
    let ratingCount = null;

    if (ratingEl.length) {
      const txt = ratingEl.is('meta') ? ratingEl.attr('content') : ratingEl.text();
      if (txt) {
        const p = parseFloat(txt.trim().replace(',', '.'));
        if (!isNaN(p) && p > 0 && p <= 5.0) ratingValue = p;
      }
    }

    // .rate-info içinden "5 Değerlendirme" gibi metinden sayıyı çeker
    const rateInfoEl = $('.rate-info').first();
    if (rateInfoEl.length) {
      const txt = rateInfoEl.text();
      if (txt) {
        const m = /(\d+)/.exec(txt);
        if (m) {
          const c = parseInt(m[1]);
          if (!isNaN(c) && c > 0) ratingCount = c;
        }
      }
    }

    if (!ratingCount) {
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
    }

    if (ratingValue || ratingCount) {
      return { ratingValue, ratingCount };
    }

    // 2. JSON-LD (Fallback)
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
    const metaBrand = $('meta[property="product:brand"], meta[name="brand"], .product-brand, [data-brand]').first();
    if (metaBrand.length) {
      const txt = metaBrand.is('meta') ? metaBrand.attr('content') : (metaBrand.attr('data-brand') || metaBrand.text());
      if (txt && txt.trim()) return txt.trim();
    }
    return null;
  }
}

module.exports = MaviScraper;
