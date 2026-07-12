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
          return this._decodeUnicode(match[1]);
        }
      }
    }
    // 2. DOM
    const el = $('h1.product-card__title, .product-title, h1').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. Script
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

    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 3. DOM
    const priceSelectors = [
      '.product-price__discount',
      '.product-price',
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
}

module.exports = DefactoScraper;
