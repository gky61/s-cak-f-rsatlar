/**
 * Migros Store Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class MigrosScraper extends BaseProductScraper {
  get domain() { return 'migros.com.tr'; }

  canHandle(url) {
    return url.toLowerCase().includes('migros.com.tr');
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
      'img[class*="product-image"]',
      'img.product-image',
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
    const el = $('#new-amount, .amount').first();
    if (el.length) {
      const v = this.parsePriceText(el.text());
      if (v && v > 0) return v;
    }
    return null;
  }

  cleanDescription(desc) {
    if (!desc) return '';
    let cleaned = desc.replace(/<[^>]*>/g, ' ');
    cleaned = cleaned.replace(/\s+/g, ' ');
    return cleaned.trim();
  }

  scrapeDescription($) {
    // 1. JSON-LD Product
    const product = this.findProductJsonLd($);
    if (product && product['description']) {
      return this.cleanDescription(product['description'].toString());
    }
    // 2. JSON-LD Root
    const scripts = $('script[type="application/ld+json"]');
    for (let i = 0; i < scripts.length; i++) {
      try {
        const text = $(scripts[i]).text() || '';
        const sanitized = text.replace(/\r\n/g, ' ').replace(/\n/g, ' ').replace(/\r/g, ' ');
        const data = JSON.parse(sanitized);
        if (data && data.description) {
          return this.cleanDescription(data.description.toString());
        }
      } catch (_) {}
    }
    // 3. DOM
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? this.cleanDescription(descEl.attr('content')) : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'migros');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, ul.breadcrumb li a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('migros') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = MigrosScraper;
