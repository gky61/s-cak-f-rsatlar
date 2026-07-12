/** Incehesap Scraper (Node.js port) */
const BaseProductScraper = require('./base_scraper');
class IncehesapScraper extends BaseProductScraper {
  get domain() { return 'incehesap.com'; }
  canHandle(url) { return url.toLowerCase().includes('incehesap.com'); }

  _findDataLayerEcommerce($) {
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).html() || '';
      if (text.includes('window.dataLayer.push(') && text.includes('ecommerce') && text.includes('items')) {
        try {
          const match = text.match(/window\.dataLayer\.push\(([\s\S]*?)\);/);
          if (match) {
            const jsonStr = match[1].trim();
            const decoded = JSON.parse(jsonStr);
            if (decoded && decoded.ecommerce) {
              return decoded.ecommerce;
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  scrapeImage($, url) {
    const ecommerce = this._findDataLayerEcommerce($);
    if (ecommerce && Array.isArray(ecommerce.items) && ecommerce.items.length > 0) {
      const imgUrl = ecommerce.items[0].image?.toString();
      if (imgUrl && !this.isLogoUrl(imgUrl)) {
        const resolved = this.resolveImageUrl(imgUrl, url);
        if (resolved) return resolved;
      }
    }
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const resolved = this.resolveImageUrl(ogImg, url);
      if (resolved) return resolved;
    }
    for (const sel of ['.product-image img', '.product-detail img', '#product-gallery img', 'img[class*="product"]']) {
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
    const ecommerce = this._findDataLayerEcommerce($);
    if (ecommerce && Array.isArray(ecommerce.items) && ecommerce.items.length > 0) {
      const name = ecommerce.items[0].item_name?.toString();
      if (name) return name.trim();
    }
    const el = $('h1.product-title, h1').first();
    return el.length ? el.text().trim() : null;
  }

  scrapePrice($) {
    const ecommerce = this._findDataLayerEcommerce($);
    if (ecommerce && Array.isArray(ecommerce.items) && ecommerce.items.length > 0) {
      const price = ecommerce.items[0].price;
      if (price != null) {
        const parsed = parseFloat(price.toString());
        if (!isNaN(parsed) && parsed > 0) return parsed;
      }
    }
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    const el = $('.product-price, .price, meta[property="product:price:amount"]').first();
    if (el.length) {
      const text = el.is('meta') ? el.attr('content') : el.text();
      const v = this.parsePriceText(text || '');
      if (v && v > 0) return v;
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    return this.extractBreadcrumbsFromJsonLd($, title, 'incehesap');
  }
}
module.exports = IncehesapScraper;
