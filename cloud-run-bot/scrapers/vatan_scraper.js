/**
 * Vatan Bilgisayar Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class VatanScraper extends BaseProductScraper {
  get domain() { return 'vatanbilgisayar.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('vatanbilgisayar.com');
  }

  _parseUpdateProductDetayItem($) {
    const scripts = $('script');
    const regex = /UpdateProductDetayItem\s*\(\s*({.*?})\s*\)/;
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      const match = regex.exec(text);
      if (match) {
        try {
          return JSON.parse(match[1]);
        } catch (_) {}
      }
    }
    return null;
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
    // 2. og:image
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const resolved = this.resolveImageUrl(ogImg, url);
      if (resolved) return resolved;
    }
    // 3. DOM Selectors
    const selectors = [
      '#main-img',
      'img.swiper-lazy',
      'a[data-fancybox="images"]',
      'a[data-fancybox]',
      '.product-details-img img',
      '.gallery-image img',
      'img[id*="main-img"]',
      'img[class*="product"]'
    ];
    for (const sel of selectors) {
      const elements = $(sel);
      for (let i = 0; i < elements.length; i++) {
        const el = $(elements[i]);
        const src = el.attr('data-zoom-image') ||
                    el.attr('data-srcset') ||
                    el.attr('data-src') ||
                    el.attr('data-lazy-src') ||
                    el.attr('href') ||
                    el.attr('src');
        if (src && !src.startsWith('data:') && !src.includes('placeholder') && !this.isLogoUrl(src)) {
          const resolved = this.resolveImageUrl(src, url);
          if (resolved) return resolved;
        }
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. UpdateProductDetayItem
    const detay = this._parseUpdateProductDetayItem($);
    if (detay && detay['ProductName']) return detay['ProductName'].toString().trim();
    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    // 3. DOM
    const el = $('h1.product_title, #product-title h2, h1, h2').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 0. İndirimli özel fiyat (#priceSpecial)
    const special = $('#priceSpecial').first();
    if (special.length) {
      const val = this.parsePriceText(special.text());
      if (val && val > 0) return val;
    }
    // 1. UpdateProductDetayItem
    const detay = this._parseUpdateProductDetayItem($);
    if (detay && detay['ProductPrice']) return this.parsePriceText(detay['ProductPrice'].toString());
    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    // 3. DOM
    const priceSelectors = [
      '.product-list__price',
      '.product-detail-price-big .product-list__price'
    ];
    for (const sel of priceSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const val = this.parsePriceText(el.text());
        if (val && val > 0) return val;
      }
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
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'vatan');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('ul.breadcrumb a, .breadcrumb a, .breadcrumbs a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && !lower.includes('vatan') && text !== title && text.length < 50) {
          list.push(this.unescapeHtml(text));
        }
      }
    });
    return list;
  }
}

module.exports = VatanScraper;
