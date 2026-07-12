/**
 * Idefix Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class IdefixScraper extends BaseProductScraper {
  get domain() { return 'idefix.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('idefix.com');
  }

  scrapeImage($, url) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      let img = this.extractImageFromProductJson(product['image']);
      if (img) {
        if (img.includes('{size}')) {
          img = img.replace('{size}', '500/0/');
        }
        if (!this.isLogoUrl(img)) {
          const r = this.resolveImageUrl(img, url);
          if (r) return r;
        }
      }
    }
    // 2. og:image
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r) return r;
    }
    // 3. DOM selectors
    const imgElements = $('img[class*="product"], img.product-image, .product-detail img');
    for (let i = 0; i < imgElements.length; i++) {
      const src = $(imgElements[i]).attr('src') || $(imgElements[i]).attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const r = this.resolveImageUrl(src, url);
        if (r) return r;
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    // 2. DOM
    const el = $('h1.text-title-lg, h1').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    // 2. DOM
    const el = $('meta[property="og:price:sale_price"], meta[property="product:price:amount"]').first();
    if (el.length) {
      const v = this.parsePriceText(el.attr('content') || '');
      if (v && v > 0) return v;
    }
    return null;
  }

  scrapeDescription($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['description']) return product['description'].toString().trim();
    // 2. DOM
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? descEl.attr('content')?.trim() : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'idefix');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, .idefix-breadcrumb a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('idefix') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = IdefixScraper;
