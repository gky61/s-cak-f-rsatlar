/**
 * Pazarama Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class PazaramaScraper extends BaseProductScraper {
  get domain() { return 'pazarama.com'; }

  scrapeImage($, url) {
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const resolved = this.resolveImageUrl(img, url);
        if (resolved) return resolved;
      }
    }
    const selectors = ['.product-detail-slider img', '.product-image img', 'picture img', 'img[class*="object-contain"]', 'img[src*="pzrmcdn.com"]', 'img[src*="product"]', 'main img'];
    for (const sel of selectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src') || el.attr('data-lazy-src');
      if (src && !src.startsWith('data:') && !this.isLogoUrl(src)) {
        const resolved = this.resolveImageUrl(src, url);
        if (resolved) return resolved;
      }
    }
    return null;
  }

  scrapeTitle($) {
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    const el = $('h1.text-huge, h1').first();
    if (el.length) return el.text().trim();
    const og = $('meta[property="og:title"]').attr('content');
    if (og) return og.trim();
    return null;
  }

  scrapePrice($) {
    // 1. Plus fiyat
    $('img[alt="plus-icon"], img[src*="pz-plus-icon"]').each((_, plusImg) => {
      let parent = $(plusImg).parent();
      while (parent.length && parent.prop('tagName') !== 'DIV') parent = parent.parent();
      if (parent.length) {
        parent.find('span').each((_, span) => {
          const text = $(span).text().trim();
          if (text.includes('TL') && !text.includes('ile')) {
            const val = this.parsePriceText(text);
            if (val && val > 0) return val; // won't break, but tries
          }
        });
      }
    });
    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    // 3. DOM
    const selectors = ['div.text-4xl.text-black.font-bold', 'span.text-lg.font-bold.text-red-600', 'meta[property="product:price:amount"]'];
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
    // Pazarama also has data-n-head="ssr" scripts
    const scripts = $('script[type="application/ld+json"]');
    for (let i = 0; i < scripts.length; i++) {
      try {
        const text = $(scripts[i]).html() || '';
        const sanitized = text.replace(/\r\n/g, ' ').replace(/\n/g, ' ').replace(/\r/g, ' ');
        const data = JSON.parse(sanitized);
        const bc = this._extractBreadcrumbsFromJson(data, title, 'pazarama');
        if (bc.length > 0) return bc;
      } catch (_) {}
    }
    // DOM fallback
    const breadcrumbs = [];
    $('.breadcrumb a, .breadcrumbs a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const l = text.toLowerCase();
        if (l !== 'anasayfa' && !l.includes('pazarama') && text !== title && text.length < 50) breadcrumbs.push(text);
      }
    });
    return breadcrumbs;
  }
}

module.exports = PazaramaScraper;
