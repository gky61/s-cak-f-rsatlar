/**
 * MediaMarkt Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class MediaMarktScraper extends BaseProductScraper {
  get domain() { return 'mediamarkt.com.tr'; }

  scrapeImage($, url) {
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) { const r = this.resolveImageUrl(img, url); if (r) return r; }
    }
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) { const r = this.resolveImageUrl(ogImg, url); if (r) return r; }
    for (const sel of ['img[data-testid="product-image"]', '#product-image img', 'img.product-image']) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !src.startsWith('data:') && !this.isLogoUrl(src)) { const r = this.resolveImageUrl(src, url); if (r) return r; }
    }
    return null;
  }

  scrapeTitle($) {
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    const el = $('h1').first();
    if (el.length) return el.text().trim();
    const og = $('meta[property="og:title"]').attr('content');
    return og ? og.trim() : null;
  }

  scrapePrice($) {
    const product = this.findProductJsonLd($);
    if (product) { const p = this.extractPriceFromProductJson(product); if (p && p > 0) return p; }
    for (const sel of ['[data-test="branded-price-whole-value"]', 'meta[property="product:price:amount"]']) {
      const el = $(sel).first();
      if (el.length) {
        const text = el.is('meta') ? el.attr('content') : el.text();
        const val = this.parsePriceText(text || '');
        if (val && val > 0) return val;
      }
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    return this.extractBreadcrumbsFromJsonLd($, title, 'mediamarkt');
  }
}

module.exports = MediaMarktScraper;
