/**
 * Vatan Bilgisayar Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class VatanScraper extends BaseProductScraper {
  get domain() { return 'vatanbilgisayar.com'; }

  _parseUpdateProductDetayItem($) {
    const scripts = $('script');
    const regex = /UpdateProductDetayItem\s*\(\s*({.*?})\s*\)/;
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      const match = regex.exec(text);
      if (match) {
        try { return JSON.parse(match[1]); } catch (_) {}
      }
    }
    return null;
  }

  scrapeImage($, url) {
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const resolved = this.resolveImageUrl(img, url);
        if (resolved) return resolved;
      }
    }
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const resolved = this.resolveImageUrl(ogImg, url);
      if (resolved) return resolved;
    }
    const selectors = ['#main-img', 'img.swiper-lazy', 'a[data-fancybox="images"]', 'a[data-fancybox]', '.product-details-img img'];
    for (const sel of selectors) {
      const el = $(sel).first();
      const src = el.attr('data-zoom-image') || el.attr('data-srcset') || el.attr('data-src') || el.attr('href') || el.attr('src');
      if (src && !src.startsWith('data:') && !src.includes('placeholder') && !this.isLogoUrl(src)) {
        const resolved = this.resolveImageUrl(src, url);
        if (resolved) return resolved;
      }
    }
    return null;
  }

  scrapeTitle($) {
    const detay = this._parseUpdateProductDetayItem($);
    if (detay && detay['ProductName']) return detay['ProductName'].toString().trim();
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    const el = $('h1.product_title, #product-title h2, h1').first();
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
    const el = $('.product-list__price').first();
    if (el.length) return this.parsePriceText(el.text());
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    return this.extractBreadcrumbsFromJsonLd($, title, 'vatan');
  }
}

module.exports = VatanScraper;
