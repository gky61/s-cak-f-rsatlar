/** Mavi Scraper (Node.js port) */
const BaseProductScraper = require('./base_scraper');
class MaviScraper extends BaseProductScraper {
  get domain() { return 'mavi.com'; }
  canHandle(url) { return url.toLowerCase().includes('mavi.com'); }
  scrapeImage($, url) {
    const product = this.findProductJsonLd($);
    if (product && product['image']) { const img = this.extractImageFromProductJson(product['image']); if (img && !this.isLogoUrl(img)) { const r = this.resolveImageUrl(img, url); if (r) return r; } }
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) { const r = this.resolveImageUrl(ogImg, url); if (r) return r; }
    return null;
  }
  scrapeTitle($) {
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    const el = $('h1.product-title, .product-name, h1').first();
    return el.length ? el.text().trim() : null;
  }
  scrapePrice($) {
    const product = this.findProductJsonLd($);
    if (product) { const p = this.extractPriceFromProductJson(product); if (p && p > 0) return p; }
    const el = $('.product-price, .price, meta[property="product:price:amount"]').first();
    if (el.length) { const text = el.is('meta') ? el.attr('content') : el.text(); const v = this.parsePriceText(text || ''); if (v && v > 0) return v; }
    return null;
  }
  scrapeBreadcrumbs($) { return this.extractBreadcrumbsFromJsonLd($, this.scrapeTitle($) || '', 'mavi'); }
}
module.exports = MaviScraper;
