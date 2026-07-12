/** Teknosa Scraper (Node.js port) */
const BaseProductScraper = require('./base_scraper');
class TeknosaScraper extends BaseProductScraper {
  get domain() { return 'teknosa.com'; }
  scrapeImage($, url) {
    const product = this.findProductJsonLd($);
    if (product && product['image']) { const img = this.extractImageFromProductJson(product['image']); if (img && !this.isLogoUrl(img)) { const r = this.resolveImageUrl(img, url); if (r) return r; } }
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) { const r = this.resolveImageUrl(ogImg, url); if (r) return r; }
    for (const sel of ['.product-images img', '#product-detail-gallery img', 'img[class*="product"]']) {
      const el = $(sel).first(); const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) { const r = this.resolveImageUrl(src, url); if (r) return r; }
    }
    return null;
  }
  scrapeTitle($) {
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    const el = $('span.replaceName, h1.product-title, h1').first();
    return el.length ? el.text().trim() : null;
  }
  scrapePrice($) {
    const product = this.findProductJsonLd($);
    if (product) { const p = this.extractPriceFromProductJson(product); if (p && p > 0) return p; }
    const el = $('span.prc, span.prc-third, .price, .product-price').first();
    if (el.length) { const v = this.parsePriceText(el.text()); if (v && v > 0) return v; }
    return null;
  }
  scrapeBreadcrumbs($) { return this.extractBreadcrumbsFromJsonLd($, this.scrapeTitle($) || '', 'teknosa'); }
}
module.exports = TeknosaScraper;
