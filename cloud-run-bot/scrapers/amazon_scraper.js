/**
 * Amazon Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class AmazonScraper extends BaseProductScraper {
  get domain() { return 'amazon.'; }

  canHandle(url) {
    const lower = url.toLowerCase();
    return lower.includes('amazon.') || lower.includes('amzn.');
  }

  scrapeImage($, url) {
    // 1. data-a-dynamic-image
    const dynImgs = $('[data-a-dynamic-image]');
    for (let i = 0; i < dynImgs.length; i++) {
      try {
        const attr = $(dynImgs[i]).attr('data-a-dynamic-image');
        if (attr) {
          const data = JSON.parse(attr);
          const firstKey = Object.keys(data)[0];
          if (firstKey && !firstKey.startsWith('data:') && !this.isLogoUrl(firstKey)) {
            const resolved = this.resolveImageUrl(firstKey, url);
            if (resolved) return resolved;
          }
        }
      } catch (_) {}
    }
    // 2. Amazon selectors
    const selectors = ['#landingImage', '#imgBlkFront', '#main-image', '#imageBlock_feature_div img', '#imageBlock img', '.a-dynamic-image'];
    for (const sel of selectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src') || el.attr('data-old-src');
      if (src && !src.startsWith('data:') && !src.includes('pixel') && !src.includes('placeholder') && !src.includes('spinner')) {
        if (src.includes('images-amazon.com') || src.includes('ssl-images-amazon.com')) {
          const resolved = this.resolveImageUrl(src, url);
          if (resolved && !this.isLogoUrl(resolved)) return resolved;
        }
      }
    }
    // 3. JSON-LD
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

  scrapeTitle($) {
    const el = $('#productTitle, #title, .a-size-large.product-title-word-break').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. twister-plus-buying-options-price-data
    const twister = $('.twister-plus-buying-options-price-data').first();
    if (twister.length) {
      try {
        const data = JSON.parse(twister.text().trim());
        for (const key of Object.keys(data)) {
          const list = data[key];
          if (Array.isArray(list) && list.length > 0 && list[0].priceAmount) {
            const parsed = parseFloat(list[0].priceAmount);
            if (!isNaN(parsed) && parsed > 0) return parsed;
          }
        }
      } catch (_) {}
    }
    // 2. .a-price .a-offscreen
    const offscreen = $('.a-price .a-offscreen').first();
    if (offscreen.length) {
      const val = this.parsePriceText(offscreen.text());
      if (val && val > 0) return val;
    }
    // 3. .a-price-whole
    const priceWhole = $('.a-price-whole').first();
    if (priceWhole.length) {
      const val = this.parsePriceText(priceWhole.text());
      if (val && val > 0) return val;
    }
    // 4. Alternative selectors
    const altSels = ['#price_inside_buybox', '#priceBlock_ourPrice', '#priceBlock_dealPrice', '.apexPriceToPay'];
    for (const sel of altSels) {
      const el = $(sel).first();
      if (el.length) {
        const val = this.parsePriceText(el.text());
        if (val && val > 0) return val;
      }
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = [];
    // 1. Standard breadcrumb
    const els = $('#wayfinding-breadcrumbs_feature_div ul li a, .a-breadcrumb a');
    els.each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('amazon') && text !== title && text.length < 50) {
          breadcrumbs.push(text);
        }
      }
    });
    if (breadcrumbs.length > 0) return breadcrumbs;
    // 2. nav-subnav
    const subnav = $('#nav-subnav a.nav-b, #nav-subnav .nav-b').first();
    if (subnav.length) {
      const text = subnav.text().trim();
      if (text && text.length < 50) return [text];
    }
    // 3. data-category
    const navSubnav = $('#nav-subnav');
    if (navSubnav.length) {
      let dataCat = navSubnav.attr('data-category');
      if (dataCat) {
        dataCat = dataCat.trim();
        if (dataCat.toLowerCase() === 'electronics') dataCat = 'Elektronik';
        else if (dataCat.toLowerCase() === 'books') dataCat = 'Kitap';
        else if (dataCat.toLowerCase() === 'fashion') dataCat = 'Moda';
        else if (dataCat.toLowerCase() === 'home') dataCat = 'Ev ve Yaşam';
        return [dataCat];
      }
    }
    return [];
  }
}

module.exports = AmazonScraper;
