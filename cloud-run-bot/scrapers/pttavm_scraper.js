/**
 * PttAVM Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class PttavmScraper extends BaseProductScraper {
  get domain() { return 'pttavm.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('pttavm.com');
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
      '.product-detail-images img',
      '.product-images img',
      'img[class*="product"]',
      '#product-image'
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
    const el = $('h1.product-title, .product-name').first();
    if (el.length) return el.text().trim();
    const og = $('meta[property="og:title"]').attr('content');
    return og ? og.trim() : null;
  }

  scrapePrice($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    // 2. DOM
    const priceSelectors = [
      '.product-price',
      '.price-box',
      '.discount-price',
      '.current-price'
    ];
    for (const sel of priceSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const v = this.parsePriceText(el.text());
        if (v && v > 0) return v;
      }
    }
    return null;
  }

  scrapeDescription($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['description']) {
      const desc = product['description'].toString().trim();
      if (desc && desc.toLowerCase() !== 'null') return desc;
    }
    // 2. meta data-rh="true"
    const rhDesc = $('meta[data-rh="true"][name="description"]').first();
    if (rhDesc.length) {
      const content = rhDesc.attr('content')?.trim();
      if (content && content.toLowerCase() !== 'null') return content;
    }
    // 3. standard meta
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    if (descEl.length) {
      const content = descEl.attr('content')?.trim();
      if (content && content.toLowerCase() !== 'null') return content;
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'pttavm');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('ul.breadcrumb a, .breadcrumb a, .breadcrumbs a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && !lower.includes('pttavm') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = PttavmScraper;
