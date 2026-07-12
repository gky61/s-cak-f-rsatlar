/** Itopya Scraper (Node.js port) */
const BaseProductScraper = require('./base_scraper');
class ItopyaScraper extends BaseProductScraper {
  get domain() { return 'itopya.com'; }
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
    const el = $('h1.product-details-title, h1').first();
    return el.length ? el.text().trim() : null;
  }
  scrapePrice($) {
    const product = this.findProductJsonLd($);
    if (product) { const p = this.extractPriceFromProductJson(product); if (p && p > 0) return p; }
    const el = $('.product-price-warning-detail span, .product-price-warning-detail, .amount').first();
    if (el.length) { const v = this.parsePriceText(el.text()); if (v && v > 0) return v; }
    return null;
  }
  scrapeBreadcrumbs($) { return this.extractBreadcrumbsFromJsonLd($, this.scrapeTitle($) || '', 'itopya'); }
}
module.exports = ItopyaScraper;
