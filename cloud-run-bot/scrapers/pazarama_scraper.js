/**
 * Pazarama Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class PazaramaScraper extends BaseProductScraper {
  get domain() { return 'pazarama.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('pazarama.com');
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
    // 2. DOM Selectors
    const pazaramaSelectors = [
      '.product-detail-slider img',
      '.product-image img',
      'picture img',
      'img[class*="object-contain"]',
      'img[src*="pzrmcdn.com"]',
      'img[src*="asset/"][src*="images/"]',
      'img[src*="product"]',
      'main img',
      '#product-image-gallery img'
    ];
    for (const sel of pazaramaSelectors) {
      const elements = $(sel);
      for (let i = 0; i < elements.length; i++) {
        const src = $(elements[i]).attr('src') || $(elements[i]).attr('data-src') || $(elements[i]).attr('data-lazy-src') || $(elements[i]).attr('data-old-hires');
        if (src && !src.startsWith('data:') && !this.isLogoUrl(src)) {
          const resolved = this.resolveImageUrl(src, url);
          if (resolved) return resolved;
        }
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    // 2. DOM
    const titleEl = $('h1.text-huge.text-gray-600.font-bold, h1.text-huge, h1').first();
    if (titleEl.length) return titleEl.text().trim();
    const og = $('meta[property="og:title"]').attr('content');
    if (og) return og.trim();
    return null;
  }

  scrapePrice($) {
    // 1. Pazarama Plus Fiyat Kontrolü
    let plusPrice = null;
    $('img[alt="plus-icon"], img[src*="pz-plus-icon"]').each((_, plusImg) => {
      let parent = $(plusImg).parent();
      while (parent.length && parent.prop('tagName') !== 'DIV') {
        parent = parent.parent();
      }
      if (parent.length) {
        parent.find('span').each((_, span) => {
          const text = $(span).text().trim();
          if (text.includes('TL') && !text.includes('ile')) {
            const val = this.parsePriceText(text);
            if (val && val > 0) {
              plusPrice = val;
            }
          }
        });
      }
    });
    if (plusPrice && plusPrice > 0) return plusPrice;

    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 3. DOM
    const selectors = [
      'div[class*="text-4xl"][class*="text-black"][class*="font-bold"]',
      'div.text-4xl.text-black.font-bold',
      'div.text-4xl.text-black',
      'span[class*="text-lg"][class*="font-bold"][class*="text-red-600"]',
      'span.text-lg.font-bold.text-red-600',
      'meta[property="product:price:amount"]'
    ];
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

  scrapeDescription($) {
    const metaDesc = $('meta[name="description"], meta[data-hid="description"], meta[property="og:description"]').first();
    if (metaDesc.length) {
      const desc = metaDesc.attr('content')?.trim();
      if (desc && desc.toLowerCase() !== 'null') return desc;
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'pazarama');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, .breadcrumb-list a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && !lower.includes('pazarama') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = PazaramaScraper;
