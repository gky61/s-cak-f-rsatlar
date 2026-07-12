/**
 * Mango Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class MangoScraper extends BaseProductScraper {
  get domain() { return 'mango.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('mango.com');
  }

  scrapeImage($, url) {
    // 1. og:image
    const ogImg = $('meta[property="og:image"]').attr('content') ||
                  $('meta[name="twitter:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r) return r;
    }

    // 2. DOM selectors
    const imgSelectors = [
      '.product-image img',
      'img[class*="product"]',
      'main img'
    ];
    for (const sel of imgSelectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const r = this.resolveImageUrl(src, url);
        if (r) return r;
      }
    }

    // 3. JSON-LD fallback
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const r = this.resolveImageUrl(img, url);
        if (r) return r;
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. og:title
    const ogTitle = $('meta[property="og:title"]').attr('content') || $('title').text();
    if (ogTitle && ogTitle.toLowerCase() !== 'null') return ogTitle.trim();

    // 2. DOM
    const el = $('h1, .product-name').first();
    if (el.length) return el.text().trim();

    // 3. JSON-LD fallback
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();

    return null;
  }

  scrapePrice($) {
    // 1. Next.js __next_f script push data regex match
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('price') || text.includes('amount')) {
        const match = text.match(/\\?"price\\?"\s*:\s*\{\s*\\?"amount\\?"\s*:\s*\\?"?([0-9.]+)\\?"?/) ||
                      text.match(/\\?"price\\?"\s*:\s*\\?"?([0-9.]+)\\?"?/);
        if (match) {
          const val = parseFloat(match[1]);
          if (!isNaN(val) && val > 0) return val;
        }
      }
    }

    // 2. JSON-LD fallback
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 3. DOM selectors
    const priceSelectors = [
      '[data-testid="pdp.productInfo.price"]',
      '.pdp-price',
      '.product-price',
      'span[class*="price"]'
    ];
    for (const sel of priceSelectors) {
      const priceEl = $(sel).first();
      if (priceEl.length) {
        const parsed = this.parsePriceText(priceEl.text());
        if (parsed && parsed > 0) return parsed;
      }
    }

    return null;
  }

  scrapeDescription($) {
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    if (descEl.length) {
      const content = descEl.attr('content')?.trim();
      if (content && content.toLowerCase() !== 'null') return content;
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'mango');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // 1. Microdata / Schema.org BreadcrumbList
    const els = $('[itemprop="itemListElement"] [itemprop="name"], ol[itemtype*="BreadcrumbList"] span[itemprop="name"], ol[itemtype*="BreadcrumbList"] [itemprop="name"], [itemtype*="BreadcrumbList"] [itemprop="name"]');
    if (els.length) {
      const list = [];
      els.each((_, el) => {
        const text = $(el).text().trim();
        if (text) {
          const lower = text.toLowerCase();
          if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('mango') && lower !== title.toLowerCase().trim() && text.length < 50) {
            list.push(text);
          }
        }
      });
      if (list.length > 0) return list;
    }

    // 2. DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, .breadcrumb-item a, nav a, ol li a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('mango') && lower !== title.toLowerCase().trim() && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = MangoScraper;
