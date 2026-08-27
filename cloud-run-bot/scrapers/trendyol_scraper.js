/**
 * Trendyol Scraper (Node.js port)
 * Enhanced for full compatibility & robust extraction
 */
const BaseProductScraper = require('./base_scraper');

class TrendyolScraper extends BaseProductScraper {
  get domain() { return 'trendyol.com'; }

  canHandle(url) {
    const lower = url.toLowerCase();
    return lower.includes('trendyol.com') || lower.includes('ty.gl');
  }

  scrapeImage($, url) {
    // 1. JSON-LD şemasından (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const resolved = this.resolveImageUrl(img, url);
        if (resolved) return resolved;
      }
    }

    // 2. Open Graph / Meta Tags
    const metaImages = [
      $('meta[property="og:image"]').attr('content'),
      $('meta[name="twitter:image"]').attr('content')
    ];
    for (const ogImg of metaImages) {
      if (ogImg && !this.isLogoUrl(ogImg)) {
        const resolved = this.resolveImageUrl(ogImg, url);
        if (resolved) return resolved;
      }
    }

    // 3. DOM Seçicileri
    const imgSelectors = [
      '.product-image-container img',
      '.detail-main-img img',
      'img.main-img',
      '.gallery-container img',
      '.base-product-image img',
      '[data-testid="product-image"] img'
    ];
    for (const sel of imgSelectors) {
      const imgElements = $(sel);
      for (let i = 0; i < imgElements.length; i++) {
        const el = $(imgElements[i]);
        const src = el.attr('src') || el.attr('data-src') || el.attr('data-original');
        if (src && !this.isLogoUrl(src)) {
          const resolved = this.resolveImageUrl(src, url);
          if (resolved) return resolved;
        }
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. JSON-LD şemasından (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product && product['name']) {
      const name = product['name'].toString().trim();
      if (name.length > 0) return name;
    }

    // 2. DOM Seçicileri
    const titleSelectors = [
      '[data-testid="product-title"]',
      'h1.pr-new-br',
      '.product-title',
      'h1.product-title',
      'h1'
    ];
    for (const sel of titleSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const txt = el.text().trim();
        if (txt.length > 0) return txt;
      }
    }

    // 3. Meta Tags
    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle && ogTitle.trim()) return ogTitle.trim();

    return null;
  }

  scrapePriceLabel($) {
    // 1. DOM Seçicileri: Trendyol Plus fiyat/başlık öğeleri
    const plusSelectors = [
      '.ty-plus-price-header',
      '.ty-plus-price',
      '[class*="ty-plus-price"]',
      '[class*="ty-plus"]',
      '[class*="plus-price"]',
      '.ty-plus-banner-desktop'
    ];

    for (const sel of plusSelectors) {
      const el = $(sel).first();
      if (el.length > 0) {
        const text = el.text().trim();
        if (/plus/i.test(text) || sel.includes('ty-plus')) {
          return "Plus'a Özel";
        }
      }
    }

    // 2. Metin bazlı DOM araması (Plus'a Özel)
    let foundText = false;
    $('span, div, p, b, strong, a, label, h1, h2, h3').each((_, el) => {
      const text = $(el).clone().children().remove().end().text().trim();
      if (/(?:trendyol\s*)?plus['’]?\s*a\s*özel/i.test(text)) {
        foundText = true;
        return false;
      }
    });
    if (foundText) return "Plus'a Özel";

    // 3. Script etiketleri & initial state kontrolü
    let scriptFound = false;
    const scriptPlusRegex = /ty-plus|hasPlusPromotion|isPlusExclusive|plusPromotion|(?:trendyol\s*)?plus(?:\\u0027|['’])\s*a\s*özel/i;
    $('script').each((_, el) => {
      const text = $(el).text();
      if (text && scriptPlusRegex.test(text)) {
        scriptFound = true;
        return false;
      }
    });
    if (scriptFound) return "Plus'a Özel";

    return null;
  }

  scrapePrice($) {
    // 1. Plus indirimli fiyat DOM kontrolü (En spesifik güncel fiyat)
    const plusPriceEl = $('.ty-plus-price-discounted-price, .ty-plus-price .ty-plus-price-discounted-price, [class*="ty-plus-price-discounted-price"]').first();
    if (plusPriceEl.length) {
      const val = this.parsePriceText(plusPriceEl.text());
      if (val !== null && val > 0) return val;
    }

    // 2. JSON-LD şemasından (Öncelikli)
    const productJson = this.findProductJsonLd($);
    if (productJson) {
      const priceLd = this.extractPriceFromProductJson(productJson);
      if (priceLd && priceLd > 0) {
        return priceLd;
      }
    }

    // 3. DOM Seçicileri (Fallback 1)
    const priceSelectors = [
      '.discounted',
      '.prc-dsc',
      '.price-container span',
      '.prc-slg',
      '.pr-bx-w .prc-dsc',
      '.product-price-container span',
      '.prc-box-dsc',
      '.prc-box-sll',
      '[class*="price-discounted"]',
      '[class*="prc-dsc"]',
      '[class*="selling-price"]'
    ];
    for (const sel of priceSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const val = this.parsePriceText(el.text());
        if (val !== null && val > 0) return val;
      }
    }

    // 4. Script Search (Fallback 2: Initial State / Next Data)
    let foundPrice = null;
    $('script').each((_, el) => {
      const text = $(el).text();
      if (text && (text.includes('__PRODUCT_DETAIL_APP_INITIAL_STATE__') || text.includes('product":{') || text.includes('__NEXT_DATA__'))) {
        try {
          const m = text.match(/"(?:discountedPrice|sellingPrice|price|salePrice)"\s*:\s*\{[^\}]*?"value"\s*:\s*([\d.]+)/);
          if (m) {
            const val = parseFloat(m[1]);
            if (!isNaN(val) && val > 0) {
              foundPrice = val;
              return false;
            }
          }
        } catch (_) {}
      }
    });

    return foundPrice;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    let candidates = [];

    // 1. DOM selectors for old / strikethrough / original prices (Öncelikli)
    const domSelectors = [
      '.old-price',
      '.prc-org',
      '.ty-plus-price-original-price',
      '[class*="price-original"]',
      '[class*="original-price"]',
      '[class*="prc-org"]',
      '[class*="old-price"]',
      '.prc-box-org',
      'del',
      's'
    ];

    for (const selector of domSelectors) {
      $(selector).each((_, el) => {
        const txt = $(el).text().trim();
        const parsed = this.parsePriceText(txt);
        if (parsed !== null && parsed > currentPrice) {
          candidates.push(parsed);
        }
      });
    }

    if (candidates.length > 0) {
      candidates = candidates.filter(c => c > currentPrice && c <= currentPrice * 5);
      if (candidates.length > 0) {
        candidates.sort((a, b) => a - b);
        return candidates[0];
      }
    }

    // 2. JSON-LD High Price (Fallback 1)
    const productJson = this.findProductJsonLd($);
    if (productJson && productJson['offers']) {
      const offers = Array.isArray(productJson['offers']) ? productJson['offers'] : [productJson['offers']];
      for (const offer of offers) {
        if (offer['highPrice']) {
          const hp = parseFloat(offer['highPrice']);
          if (!isNaN(hp) && hp > currentPrice) candidates.push(hp);
        }
      }
    }

    // 3. Initial State Script Search (Fallback 2)
    $('script').each((_, el) => {
      const text = $(el).text();
      if (text && (text.includes('__PRODUCT_DETAIL_APP_INITIAL_STATE__') || text.includes('product":{') || text.includes('__NEXT_DATA__'))) {
        try {
          const matches = text.match(/"(?:originalPrice|marketPrice|crossedOutPrices)"\s*:\s*\{[^\}]*?"value"\s*:\s*([\d.]+)/g);
          if (matches) {
            for (const m of matches) {
              const valMatch = m.match(/"value"\s*:\s*([\d.]+)/);
              if (valMatch) {
                const val = parseFloat(valMatch[1]);
                if (!isNaN(val) && val > currentPrice) {
                  candidates.push(val);
                }
              }
            }
          }
        } catch (_) {}
      }
    });

    if (candidates.length === 0) return null;

    candidates = candidates.filter(c => c > currentPrice && c <= currentPrice * 5);
    if (candidates.length === 0) return null;

    candidates.sort((a, b) => a - b);
    return candidates[0];
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

  scrapeRating($) {
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }

    let ratingValue = null;
    let ratingCount = null;

    $('script').each((_, el) => {
      const text = $(el).text();
      if (text && (text.includes('ratingValue') || text.includes('averageRating'))) {
        if (!ratingValue) {
          const vm = text.match(/"(?:ratingValue|averageRating)"\s*:\s*"?([\d.,]+)"?/);
          if (vm) {
            const parsed = parseFloat(vm[1].replace(',', '.'));
            if (!isNaN(parsed) && parsed > 0 && parsed <= 5) ratingValue = parsed;
          }
        }
        if (!ratingCount) {
          const cm = text.match(/"(?:ratingCount|totalRatingCount|reviewCount)"\s*:\s*"?(\d+)"?/);
          if (cm) {
            const parsed = parseInt(cm[1]);
            if (!isNaN(parsed) && parsed > 0) ratingCount = parsed;
          }
        }
      }
    });

    return { ratingValue, ratingCount };
  }

  scrapeBrand($) {
    // 1. JSON-LD (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand && brand.trim()) return brand.trim();
    }

    // 2. DOM Seçicileri
    const brandSelectors = [
      'h1.pr-new-br a',
      'a.product-brand',
      'span.pr-new-br',
      '.brand-name',
      '[data-testid="brand-name"]'
    ];
    for (const sel of brandSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const txt = el.text().trim();
        if (txt.length > 0) return txt;
      }
    }

    return null;
  }
}

module.exports = TrendyolScraper;
