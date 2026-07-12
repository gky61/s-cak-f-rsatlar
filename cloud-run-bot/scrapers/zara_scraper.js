/**
 * Zara Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class ZaraScraper extends BaseProductScraper {
  get domain() { return 'zara.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('zara.com');
  }

  scrapeImage($, url) {
    // 1. og:image / twitter:image / image_src
    const ogImg = $('meta[property="og:image"]').attr('content') ||
                  $('meta[name="twitter:image"]').attr('content') ||
                  $('link[rel="image_src"]').attr('href');
    if (ogImg && ogImg.toLowerCase() !== 'null') {
      const resolved = this.resolveImageUrl(ogImg, url);
      if (resolved && !this.isLogoUrl(resolved)) return resolved;
    }

    // 2. Script regex matching
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('image') || text.includes('contentUrl')) {
        const match = text.match(/"image"\s*:\s*\[\s*"([^"]+)"/) ||
                      text.match(/"contentUrl"\s*:\s*"([^"]+)"/);
        if (match) {
          const resolved = this.resolveImageUrl(match[1], url);
          if (resolved && !this.isLogoUrl(resolved)) return resolved;
        }
      }
    }

    // 3. DOM selectors
    const imgSelectors = [
      '.media-image__image',
      '.product-detail-images img',
      'img[class*="product"]',
      'main img'
    ];
    for (const sel of imgSelectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const resolved = this.resolveImageUrl(src, url);
        if (resolved) return resolved;
      }
    }

    // 4. JSON-LD fallback
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const resolved = this.resolveImageUrl(img, url);
        if (resolved) return resolved;
      }
    }

    return null;
  }

  scrapeTitle($, url) {
    // 1. DOM
    const titleEl = $('h1.product-detail-info__header-name, .product-name, h1').first();
    if (titleEl.length) {
      const text = titleEl.text().trim();
      if (text && text.toLowerCase() !== 'null') return text;
    }

    // 2. og:title
    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle && ogTitle.toLowerCase() !== 'null') return ogTitle.trim();

    // 3. Script regex matching
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('productName') || text.includes('name')) {
        const match = text.match(/"productName"\s*:\s*"([^"]+)"/) ||
                      text.match(/"name"\s*:\s*"([^"]+)"/);
        if (match) {
          const val = match[1];
          if (val && val.toLowerCase() !== 'null') return val.trim();
        }
      }
    }

    // 4. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();

    return null;
  }

  scrapePrice($) {
    // 1. Script regex matching
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      // A) mainPrice
      const m1 = text.match(/"mainPrice"\s*:\s*([0-9.]+)/);
      if (m1) {
        const val = parseFloat(m1[1]);
        if (!isNaN(val) && val > 0) return val;
      }
      // B) price
      const m2 = text.match(/"price"\s*:\s*"([0-9.]+)"/) ||
                 text.match(/"price"\s*:\s*([0-9.]+)/);
      if (m2) {
        const val = parseFloat(m2[1]);
        if (!isNaN(val) && val > 0) return val;
      }
    }

    // 2. DOM selectors
    const priceSelectors = [
      '.price-current__amount',
      '.price__amount',
      '.price',
      'span[class*="price"]'
    ];
    for (const sel of priceSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const val = this.parsePriceText(el.text());
        if (val && val > 0) return val;
      }
    }

    // 3. JSON-LD / Meta tags
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    const metaPrice = $('meta[property="product:price:amount"]').first();
    if (metaPrice.length) {
      const val = this.parsePriceText(metaPrice.attr('content') || '');
      if (val && val > 0) return val;
    }

    return null;
  }

  scrapeDescription($) {
    // 1. DOM meta description
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    if (descEl.length) {
      const content = descEl.attr('content')?.trim();
      if (content && content.toLowerCase() !== 'null') return content;
    }
    // 2. Script matching
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('description')) {
        const match = text.match(/"description"\s*:\s*"([^"]+)"/);
        if (match) {
          const val = match[1];
          if (val && val.toLowerCase() !== 'null') return val.replace(/\\n/g, '\n').trim();
        }
      }
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';

    // 1. Microdata / Schema.org BreadcrumbList
    const els = $('[itemprop="itemListElement"] [itemprop="name"], ol[itemtype*="BreadcrumbList"] span[itemprop="name"], ol[itemtype*="BreadcrumbList"] [itemprop="name"], [itemtype*="BreadcrumbList"] [itemprop="name"], .layout-footer-breadcrumbs__items [itemprop="name"]');
    if (els.length) {
      const list = [];
      els.each((_, el) => {
        const text = $(el).text().trim();
        if (text) {
          const lower = text.toLowerCase();
          if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('zara') && lower !== title.toLowerCase().trim() && text.length < 50) {
            list.push(text);
          }
        }
      });
      if (list.length > 0) return list;
    }

    // 2. DOM Fallback
    const fallbackList = [];
    $('.breadcrumb a, .breadcrumbs a, .breadcrumb-item a, nav a, ol li a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('zara') && lower !== title.toLowerCase().trim() && text.length < 50) {
          fallbackList.push(text);
        }
      }
    });
    if (fallbackList.length > 0) return fallbackList;

    return this.extractBreadcrumbsFromJsonLd($, title, 'zara');
  }
}

module.exports = ZaraScraper;
