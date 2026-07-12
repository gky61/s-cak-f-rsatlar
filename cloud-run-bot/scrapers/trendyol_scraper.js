/**
 * Trendyol Scraper (Node.js port)
 * Dart karşılığı: lib/services/scrapers/trendyol_scraper.dart
 */
const BaseProductScraper = require('./base_scraper');

class TrendyolScraper extends BaseProductScraper {
  get domain() { return 'trendyol.com'; }

  canHandle(url) {
    const lower = url.toLowerCase();
    return lower.includes('trendyol.com') || lower.includes('ty.gl');
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
    const selectors = ['.product-image-container img', '.detail-main-img img', 'img.main-img'];
    for (const sel of selectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const resolved = this.resolveImageUrl(src, url);
        if (resolved) return resolved;
      }
    }
    return null;
  }

  scrapeTitle($) {
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    const el = $('[data-testid="product-title"], .product-title, h1.product-title').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    const el = $('.discounted, .prc-dsc, .price-container span').first();
    if (el.length) {
      const val = this.parsePriceText(el.text());
      if (val && val > 0) return val;
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    return this.extractBreadcrumbsFromJsonLd($, title, 'trendyol');
  }
}

module.exports = TrendyolScraper;
