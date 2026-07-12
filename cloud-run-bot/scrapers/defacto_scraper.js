/** DeFacto Scraper (Node.js port) */
const BaseProductScraper = require('./base_scraper');
class DefactoScraper extends BaseProductScraper {
  get domain() { return 'defacto.com.tr'; }
  canHandle(url) { return url.toLowerCase().includes('defacto.com.tr'); }

  _decodeUnicode(str) {
    try { return str.replace(/\\u([\dA-Fa-f]{4})/g, (_, grp) => String.fromCharCode(parseInt(grp, 16))); } catch (_) { return str; }
  }

  scrapeImage($, url) {
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) { const r = this.resolveImageUrl(ogImg, url); if (r) return r; }
    for (const sel of ['.product-card__image img', '.product-image img', 'img[class*="product"]']) {
      const el = $(sel).first(); const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) { const r = this.resolveImageUrl(src, url); if (r) return r; }
    }
    return null;
  }
  scrapeTitle($) {
    // Script bloğu
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).html() || '';
      if (text.includes('PRODUCT_DETAIL_LASTVISITED') || text.includes('PRODUCT_DETAIL_INFO')) {
        const match = text.match(/"?ProductVariantMiniProductName"?\s*:\s*"([^"]+)"/) ||
                      text.match(/"?Name"?\s*:\s*"([^"]+)"/) ||
                      text.match(/"?name"?\s*:\s*"([^"]+)"/);
        if (match) return this._decodeUnicode(match[1]);
      }
    }
    const el = $('h1.product-card__title, .product-title, h1').first();
    return el.length ? el.text().trim() : null;
  }
  scrapePrice($) {
    // Script bloğundan
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).html() || '';
      if (text.includes('PRODUCT_DETAIL_LASTVISITED') || text.includes('PRODUCT_DETAIL_INFO')) {
        const match = text.match(/"?DiscountedPrice"?\s*:\s*([\d.,]+)/) ||
                      text.match(/"?Price"?\s*:\s*([\d.,]+)/);
        if (match) { const v = this.parsePriceText(match[1]); if (v && v > 0) return v; }
      }
    }
    const product = this.findProductJsonLd($);
    if (product) { const p = this.extractPriceFromProductJson(product); if (p && p > 0) return p; }
    return null;
  }
  scrapeBreadcrumbs($) { return this.extractBreadcrumbsFromJsonLd($, this.scrapeTitle($) || '', 'defacto'); }
}
module.exports = DefactoScraper;
