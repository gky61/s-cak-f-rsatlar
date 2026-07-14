/**
 * Trendyol Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class TrendyolScraper extends BaseProductScraper {
  get domain() { return 'trendyol.com'; }

  canHandle(url) {
    const lower = url.toLowerCase();
    return lower.includes('trendyol.com') || lower.includes('ty.gl');
  }

  scrapeImage($, url) {
    // 1. JSON-LD şemasından görsel çekmeyi dene (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const resolved = this.resolveImageUrl(img, url);
        if (resolved) return resolved;
      }
    }
    
    // 2. Open Graph (Fallback 1)
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const resolved = this.resolveImageUrl(ogImg, url);
      if (resolved) return resolved;
    }
    
    // 3. Main Product Image (Fallback 2)
    const imgElements = $('.product-image-container img, .detail-main-img img, img.main-img');
    for (let i = 0; i < imgElements.length; i++) {
      const el = $(imgElements[i]);
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const resolved = this.resolveImageUrl(src, url);
        if (resolved) return resolved;
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. JSON-LD şemasından (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    
    // 2. DOM Seçicileri (Fallback)
    const el = $('[data-testid="product-title"], .product-title, h1.product-title').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. JSON-LD şemasından (Öncelikli)
    const productJson = this.findProductJsonLd($);
    if (productJson) {
      const priceLd = this.extractPriceFromProductJson(productJson);
      if (priceLd && priceLd > 0) {
        return priceLd;
      }
    }

    // 2. DOM Seçicileri (Fallback)
    const priceEl = $('.discounted, .prc-dsc, .price-container span').first();
    if (priceEl.length) {
      const val = this.parsePriceText(priceEl.text());
      if (val !== null && val > 0) {
        return val;
      }
    }

    return null;
  }

  scrapeDescription($) {
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? descEl.attr('content')?.trim() : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'trendyol');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.product-detail-breadcrumb a, .breadcrumb a, .breadcrumbs a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'trendyol' && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = TrendyolScraper;
