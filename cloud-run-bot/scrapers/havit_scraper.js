/**
 * Havit Store Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class HavitScraper extends BaseProductScraper {
  get domain() { return 'havitstore.com.tr'; }

  canHandle(url) {
    return url.toLowerCase().includes('havitstore.com.tr');
  }

  scrapeImage($, url) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const r = this.resolveImageUrl(img, url);
        if (r) return r;
      }
    }
    // 2. og:image
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r) return r;
    }
    // 3. DOM selectors
    const imgSelectors = [
      '.sub-image img',
      '#product-image img',
      '.product-details img',
      'img[class*="product"]'
    ];
    for (const sel of imgSelectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
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
    const el = $('h1.product-title, h1').first();
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
    // 2. DOM Fallback
    const el = $('#fiyat2 .spanFiyat, .indirimliFiyat .spanFiyat').first();
    if (el.length) {
      const v = this.parsePriceText(el.text());
      if (v && v > 0) return v;
    }
    return null;
  }

  cleanDescription(desc) {
    if (!desc) return '';
    let cleaned = desc.replace(/@import\s+url\([^)]+\);?/gi, '');
    cleaned = cleaned.replace(/@import\s+[^;]+;/gi, '');
    cleaned = cleaned.replace(/[^{]+{[^}]+}/g, '');
    cleaned = cleaned.replace(/<[^>]*>/g, ' ');
    cleaned = cleaned.replace(/[\w-]+\s*:\s*[^;]+;/g, '');
    cleaned = cleaned.replace(/\s+/g, ' ');
    return cleaned.trim();
  }

  scrapeDescription($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['description']) {
      return this.cleanDescription(product['description'].toString());
    }
    // 2. DOM
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? this.cleanDescription(descEl.attr('content')) : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'havitstore');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, ul.breadcrumb li a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('havit') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = HavitScraper;
