/** Zara Scraper (Node.js port) */
const BaseProductScraper = require('./base_scraper');
class ZaraScraper extends BaseProductScraper {
  get domain() { return 'zara.com'; }
  scrapeImage($, url) {
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) { const r = this.resolveImageUrl(ogImg, url); if (r) return r; }
    const product = this.findProductJsonLd($);
    if (product && product['image']) { const img = this.extractImageFromProductJson(product['image']); if (img && !this.isLogoUrl(img)) { const r = this.resolveImageUrl(img, url); if (r) return r; } }
    return null;
  }
  scrapeTitle($) {
    // analyticsData'dan
    const html = $.html();
    const match = html.match(/zara\.analyticsData\s*=\s*({[^;]+})/);
    if (match) { try { const d = JSON.parse(match[1]); if (d.productName) return d.productName; } catch (_) {} }
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    const el = $('h1, .product-detail-info__header-name').first();
    return el.length ? el.text().trim() : null;
  }
  scrapePrice($) {
    const product = this.findProductJsonLd($);
    if (product) { const p = this.extractPriceFromProductJson(product); if (p && p > 0) return p; }
    const el = $('meta[property="product:price:amount"]').first();
    if (el.length) { const v = this.parsePriceText(el.attr('content') || ''); if (v && v > 0) return v; }
    return null;
  }
  scrapeBreadcrumbs($) { return this.extractBreadcrumbsFromJsonLd($, this.scrapeTitle($) || '', 'zara'); }
}
module.exports = ZaraScraper;
