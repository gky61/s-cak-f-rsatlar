/**
 * Gamer Gen Product Scraper (Gamer.gen.tr)
 * Dart karşılığı: lib/services/scrapers/gamer_gen_scraper.dart
 */

const BaseProductScraper = require('./base_scraper');

class GamerGenScraper extends BaseProductScraper {
  get domain() {
    return 'gamer.gen.tr';
  }

  canHandle(url) {
    return url.toLowerCase().includes('gamer.gen.tr');
  }

  scrapeImage($, url, html) {
    // 1. JSON-LD şemasından görsel çekmeyi dene (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product && product.image) {
      const img = this.extractImageFromProductJson(product.image);
      if (img && !this.isLogoUrl(img)) {
        const r = this.resolveImageUrl(img, url);
        if (r) return r;
      }
    }

    // 2. Open Graph meta tag'i dene (Eğer logo değilse)
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r) return r;
    }

    // 3. DOM Seçicileri (Fallback)
    const imgSelectors = [
      '.product-details-img img',
      '#product-image img',
      'img[class*="product"]',
      '.system-image img'
    ];
    for (const sel of imgSelectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const r = this.resolveImageUrl(src, url);
        if (r) return r;
      }
    }

    // 4. Hazır sistem veya genel sayfa için CDN regex fallback'i
    const rawHtml = $.html ? $.html() : (html || '');
    const cdnMatches = rawHtml.match(/https:\/\/img\.yenieera22\.com\/cdn\/(?:1000|250)\/[a-zA-Z0-9_\.\-]+(?:\.png|\.jpg|\.webp)/gi);
    if (cdnMatches && cdnMatches.length > 0) {
      for (const matchedUrl of cdnMatches) {
        if (!this.isLogoUrl(matchedUrl)) {
          const highRes = matchedUrl.replace('/cdn/250/', '/cdn/1000/');
          const r = this.resolveImageUrl(highRes, url);
          if (r) return r;
        }
      }
    }

    return null;
  }

  scrapeTitle($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product.name) {
      const name = product.name.toString().trim();
      if (name.length > 0) return name;
    }

    // 2. DOM
    const el = $('h1.product-details-title, h1').first();
    if (el.length) {
      let title = el.clone().children().remove().end().text().trim();
      if (!title) title = el.text().trim();
      title = title.replace(/\s*Paylaş\s*$/i, '').trim();
      if (title.length > 0) return title;
    }

    // 3. og:title
    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle && ogTitle.trim().length > 0) {
      let clean = ogTitle.trim();
      clean = clean.replace(/\s*\|\s*(?:ITOPYA|GAMER\.GEN\.TR|Gamer Gen).*$/i, '').trim();
      if (clean.length > 0) return clean;
    }

    return null;
  }

  scrapePrice($, html) {
    // 1. DOM Sepette indirimli fiyat (.text-price: ör. "Sepette 18.999,00 TL")
    const textPriceEl = $('.text-price').first();
    if (textPriceEl.length) {
      const clean = textPriceEl.text().replace(/sepette/gi, '');
      const val = this.parsePriceText(clean);
      if (val && val > 0) return val;
    }

    // 2. DOM normal satış fiyatı (.product-price: ör. "23.158,63 TL" veya "10.899,00 TL")
    const productPriceEl = $('.product-price').first();
    if (productPriceEl.length) {
      const val = this.parsePriceText(productPriceEl.text());
      if (val && val > 0) return val;
    }

    // 3. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 4. Hazır sistem (_h...) ve script fallback'leri
    const rawHtml = $.html ? $.html() : (html || '');
    const toplamFiyatMatch = rawHtml.match(/var\s+toplamFiyat\s*=\s*['"]?([0-9.,]+)['"]?/i);
    if (toplamFiyatMatch) {
      const val = this.parsePriceText(toplamFiyatMatch[1]);
      if (val && val > 0) return val;
    }

    const gtagMatch = rawHtml.match(/gtag\("event",\s*"view_item"[\s\S]*?price\s*:\s*([0-9.]+)/i);
    if (gtagMatch) {
      const val = parseFloat(gtagMatch[1]);
      if (!isNaN(val) && val > 0) return val;
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    // 1. Eğer sepet indirimi varsa (.text-price), liste fiyatı .product-price içindedir
    const textPriceEl = $('.text-price').first();
    if (textPriceEl.length && textPriceEl.text().trim().length > 0) {
      const clean = textPriceEl.text().replace(/sepette/gi, '');
      const sepetPrice = this.parsePriceText(clean);
      if (sepetPrice && currentPrice <= sepetPrice) {
        const productPriceEl = $('.product-price').first();
        if (productPriceEl.length) {
          const val = this.parsePriceText(productPriceEl.text());
          if (val && val > currentPrice) return val;
        }
      }
    }

    // 2. Normal indirimli ürünlerde eski fiyat .product-old-price içindedir
    const oldPriceEl = $('.product-old-price').first();
    if (oldPriceEl.length) {
      const val = this.parsePriceText(oldPriceEl.text());
      if (val && val > currentPrice) return val;
    }

    // 3. Fallback aday seçicileri
    const candidates = [];
    const selectors = [
      '.product-old-price',
      '.product-price',
      '.detail-price-div',
      'del',
      's',
      '.old-price',
      '.original-price'
    ];

    for (const sel of selectors) {
      $(sel).each((_, el) => {
        const txt = $(el).text().trim();
        if (txt.includes('TL') || txt.includes('₺') || /\d/.test(txt)) {
          const parsed = this.parsePriceText(txt);
          if (parsed !== null && parsed > currentPrice && parsed <= currentPrice * 5) {
            candidates.push(parsed);
          }
        }
      });
    }

    if (candidates.length === 0) return null;

    candidates.sort((a, b) => a - b);
    return candidates[0];
  }

  scrapeBrand($, html) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product.brand) {
      if (typeof product.brand === 'string') return product.brand.trim();
      if (typeof product.brand === 'object' && product.brand.name) return product.brand.name.trim();
    }

    // 2. DOM
    const brandEl = $('.product-details-brand, [itemprop="brand"]').first();
    if (brandEl.length && brandEl.text().trim().length > 0) {
      return brandEl.text().trim();
    }

    // 3. Script / regex
    const rawHtml = $.html ? $.html() : (html || '');
    const brandMatch = rawHtml.match(/"brand"\s*:\s*\{\s*"@type"\s*:\s*"Brand"\s*,\s*"name"\s*:\s*"([^"]+)"/i) ||
                       rawHtml.match(/item_brand\s*:\s*"([^"]+)"/i);
    if (brandMatch) {
      return brandMatch[1].trim();
    }

    return null;
  }

  scrapeDescription($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product.description) return product.description.toString().trim();

    // 2. DOM
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? descEl.attr('content')?.trim() : null;
  }

  scrapeBreadcrumbs($, html) {
    const title = this.scrapeTitle($) || '';

    // 1. JSON-LD BreadcrumbList
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'gamer');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // 2. JSON-LD regex fallback
    const rawHtml = $.html ? $.html() : (html || '');
    const bcBlock = rawHtml.match(/"itemListElement"\s*:\s*\[([\s\S]*?)\]/i);
    if (bcBlock) {
      const itemNames = [...bcBlock[1].matchAll(/"name"\s*:\s*"([^"]+)"/g)].map(m => m[1]);
      const list = [];
      for (const name of itemNames) {
        const lower = name.toLowerCase();
        if (lower !== 'ana sayfa' && lower !== 'anasayfa' && !lower.includes('gamer') && !lower.includes('itopya') && name !== title && name.length < 50) {
          list.push(name);
        }
      }
      if (list.length > 0) return list;
    }

    // 3. DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, ul.breadcrumb li a, .breadcrumb-item a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('gamer') && !lower.includes('itopya') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }

  scrapePriceLabel($) {
    return null;
  }

  scrapeRating($) {
    return { ratingValue: null, ratingCount: null };
  }
}

module.exports = GamerGenScraper;
