/**
 * Hepsiburada Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class HepsiburadaScraper extends BaseProductScraper {
  get domain() { return 'hepsiburada.com'; }

  canHandle(url) {
    const lower = url.toLowerCase();
    return lower.includes('hepsiburada.com') || lower.includes('hb.biz');
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
    const selectors = ['img[class*="hb-HbImage-view__image"]', '.hb-HbImage-view img', 'img[alt*="ürün"]', 'img[alt*="Ürün"]'];
    for (const sel of selectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const resolved = this.resolveImageUrl(src, url);
        if (resolved) return resolved;
      }
    }
    // 4. data-image attributes
    $('[data-image], [data-srcset], [data-original-src]').each((_, el) => {
      const imgUrl = $(el).attr('data-image') || ($(el).attr('data-srcset') || '').split(',')[0]?.trim() || $(el).attr('data-original-src');
      if (imgUrl && !imgUrl.startsWith('data:') && !this.isLogoUrl(imgUrl)) {
        const resolved = this.resolveImageUrl(imgUrl, url);
        if (resolved) return resolved; // won't break early in cheerio each, but attempts
      }
    });
    return null;
  }

  scrapeTitle($) {
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    const el = $('h1[data-test-id="title"], h1.xeL9CQ3JILmYoQPCgDcl').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. Premium fiyat
    const premiumContainer = $('div[class*="hb-premium-price"], [class*="premium-price"]').first();
    if (premiumContainer.length) {
      const priceSpan = premiumContainer.find('span').first();
      if (priceSpan.length) {
        const val = this.parsePriceText(priceSpan.text());
        if (val && val > 0) return val;
      }
    }
    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    // 3. DOM
    const selectors = ['.price-value', '.offering-price', 'meta[property="product:price:amount"]'];
    for (const sel of selectors) {
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
    return this.extractBreadcrumbsFromJsonLd($, title, 'hepsiburada');
  }
}

module.exports = HepsiburadaScraper;
