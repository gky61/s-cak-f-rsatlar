/** PttAVM Scraper (Node.js port) */
const BaseProductScraper = require('./base_scraper');
class PttavmScraper extends BaseProductScraper {
  get domain() { return 'pttavm.com'; }
  canHandle(url) { return url.toLowerCase().includes('pttavm.com'); }
  scrapeImage($, url) {
    const product = this.findProductJsonLd($);
    if (product && product['image']) { const img = this.extractImageFromProductJson(product['image']); if (img && !this.isLogoUrl(img)) { const r = this.resolveImageUrl(img, url); if (r) return r; } }
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) { const r = this.resolveImageUrl(ogImg, url); if (r) return r; }
    for (const sel of ['.product-detail-images img', '.product-images img', 'img[class*="product"]']) {
      const el = $(sel).first(); const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) { const r = this.resolveImageUrl(src, url); if (r) return r; }
    }
    return null;
  }
  scrapeTitle($) {
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    const el = $('h1.product-title, .product-name').first();
    if (el.length) return el.text().trim();
    const og = $('meta[property="og:title"]').attr('content');
    return og ? og.trim() : null;
  }
  scrapePrice($) {
    const product = this.findProductJsonLd($);
    if (product) { const p = this.extractPriceFromProductJson(product); if (p && p > 0) return p; }
    for (const sel of ['.product-price', '.price-box', '.discount-price', '.current-price']) {
      const el = $(sel).first();
      if (el.length) { const v = this.parsePriceText(el.text()); if (v && v > 0) return v; }
    }
    return null;
  }
  scrapeBreadcrumbs($) { return this.extractBreadcrumbsFromJsonLd($, this.scrapeTitle($) || '', 'pttavm'); }
}
module.exports = PttavmScraper;
