/**
 * Incehesap Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class IncehesapScraper extends BaseProductScraper {
  get domain() { return 'incehesap.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('incehesap.com');
  }

  _findDataLayerEcommerce($) {
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).html() || '';
      if (text.includes('window.dataLayer.push(') && text.includes('ecommerce') && text.includes('items')) {
        try {
          const match = text.match(/window\.dataLayer\.push\(([\s\S]*?)\);/);
          if (match) {
            const jsonStr = match[1].trim();
            const decoded = JSON.parse(jsonStr);
            if (decoded && decoded.ecommerce) {
              return decoded.ecommerce;
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  scrapeImage($, url) {
    // 1. dataLayer
    const ecommerce = this._findDataLayerEcommerce($);
    if (ecommerce && Array.isArray(ecommerce.items) && ecommerce.items.length > 0) {
      const imgUrl = ecommerce.items[0].image?.toString();
      if (imgUrl && !this.isLogoUrl(imgUrl)) {
        const resolved = this.resolveImageUrl(imgUrl, url);
        if (resolved) return resolved;
      }
    }
    // 2. og:image
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const resolved = this.resolveImageUrl(ogImg, url);
      if (resolved) return resolved;
    }
    // 3. DOM selectors
    const imgSelectors = [
      '.product-image img',
      '.product-detail img',
      '#product-gallery img',
      'img[class*="product"]'
    ];
    for (const sel of imgSelectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const resolved = this.resolveImageUrl(src, url);
        if (resolved) return resolved;
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. dataLayer
    const ecommerce = this._findDataLayerEcommerce($);
    if (ecommerce && Array.isArray(ecommerce.items) && ecommerce.items.length > 0) {
      const name = ecommerce.items[0].item_name?.toString();
      if (name) return name.trim();
    }
    // 2. DOM
    const el = $('h1.product-title, .product-name, h1').first();
    if (el.length) return el.text().trim();
    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle) return ogTitle.trim();
    return null;
  }

  scrapePrice($) {
    // Sepette indirim etiket kontrolü
    const hasBasketDiscount = $('.basketdiscount-label-detail').length > 0;
    if (hasBasketDiscount) {
      const priceEl = $('div.price, .price, [class*="price"]').first();
      if (priceEl.length) {
        const val = this.parsePriceText(priceEl.text());
        if (val && val > 0) return val;
      }
    }

    // dataLayer
    const ecommerce = this._findDataLayerEcommerce($);
    if (ecommerce) {
      if (Array.isArray(ecommerce.items) && ecommerce.items.length > 0) {
        const price = ecommerce.items[0].price;
        if (price != null) {
          const parsed = parseFloat(price.toString());
          if (!isNaN(parsed) && parsed > 0) return parsed;
        }
      }
      const valueVal = ecommerce.value;
      if (valueVal != null) {
        const parsed = parseFloat(valueVal.toString());
        if (!isNaN(parsed) && parsed > 0) return parsed;
      }
    }

    // JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // Fallback DOM
    const priceEl = $('div.price, .price, [class*="price"]').first();
    if (priceEl.length) {
      const val = this.parsePriceText(priceEl.text());
      if (val && val > 0) return val;
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    // 1. Önce ana fiyat elementinin parent/container'ında strikethrough fiyatı ara
    const priceEl = $('div.price, p.price, .price, [class*="price"]').first();
    if (priceEl.length) {
      const containers = [
        priceEl.parent(),
        priceEl.parent().parent(),
        priceEl.closest('div[class*="flex"]'),
        priceEl.closest('div[class*="price"]'),
        priceEl.closest('.product-detail')
      ];

      for (const container of containers) {
        if (container.length) {
          const strikeEl = container.find('.line-through, [class*="line-through"], del, s').first();
          if (strikeEl.length) {
            const parsed = this.parsePriceText(strikeEl.text());
            if (parsed && parsed > currentPrice && parsed <= currentPrice * 5) {
              return parsed;
            }
          }
        }
      }
    }

    // 2. Global fallback
    let candidates = [];
    $('.line-through, [class*="line-through"], del, s').each((_, el) => {
      const txt = $(el).text().trim();
      if (txt.includes('TL') || txt.includes('₺')) {
        const parsed = this.parsePriceText(txt);
        if (parsed !== null && parsed > currentPrice && parsed <= currentPrice * 5) {
          candidates.push(parsed);
        }
      }
    });

    if (candidates.length === 0) return null;

    // İlgisiz önerilen ürün fiyatlarını seçmemek için currentPrice'a en yakın olan aday tercih edilir
    candidates.sort((a, b) => a - b);
    return candidates[0];
  }

  scrapeDescription($) {
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? descEl.attr('content')?.trim() : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'incehesap');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // 1. Schema.org BreadcrumbList
    const els = $('[itemprop="itemListElement"] [itemprop="name"], nav[itemtype*="BreadcrumbList"] span[itemprop="name"], nav[itemtype*="BreadcrumbList"] [itemprop="name"]');
    if (els.length) {
      const list = [];
      els.each((_, el) => {
        const text = $(el).text().trim();
        if (text) {
          const lower = text.toLowerCase();
          if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('incehesap') && lower !== title.toLowerCase().trim() && text.length < 50) {
            list.push(text);
          }
        }
      });
      if (list.length > 0) return list;
    }

    // 2. DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, .breadcrumb-item a, nav a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('incehesap') && lower !== title.toLowerCase().trim() && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }

  scrapeRating($) {
    // 1. DOM Microdata (Öncelikli - İncehesap'ta rating JSON-LD'de yok)
    const ratingEl = $('[itemprop="ratingValue"], meta[property="product:rating:value"], .rating-score, .pdp-rating-value').first();
    let ratingValue = null;
    let ratingCount = null;

    if (ratingEl.length) {
      const txt = ratingEl.is('meta') ? ratingEl.attr('content') : ratingEl.text();
      if (txt) {
        const p = parseFloat(txt.trim().replace(',', '.'));
        if (!isNaN(p) && p > 0 && p <= 5.0) ratingValue = p;
      }
    }

    const countEl = $('[itemprop="reviewCount"], [itemprop="ratingCount"], .review-count, .rating-count').first();
    if (countEl.length) {
      const txt = countEl.is('meta') ? countEl.attr('content') : countEl.text();
      if (txt) {
        const m = /(\d+)/.exec(txt);
        if (m) {
          const c = parseInt(m[1]);
          if (!isNaN(c) && c > 0) ratingCount = c;
        }
      }
    }

    if (ratingValue || ratingCount) {
      return { ratingValue, ratingCount };
    }

    // 2. JSON-LD Fallback
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }

    return { ratingValue: null, ratingCount: null };
  }

  scrapeBrand($) {
    // 1. DOM Microdata (Öncelikli - itemprop="brand" > meta[itemprop="name"])
    const brandDiv = $('[itemprop="brand"]').first();
    if (brandDiv.length) {
      const metaName = brandDiv.find('meta[itemprop="name"]');
      if (metaName.length) {
        const content = metaName.attr('content');
        if (content && content.trim()) return content.trim();
      }
      const txt = brandDiv.text().trim();
      if (txt) return txt;
    }

    // 2. JSON-LD Fallback
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand) return brand;
    }

    // 3. Diğer DOM / Meta Tag
    const metaBrand = $('meta[property="product:brand"], meta[name="brand"], .product-brand, [data-brand]').first();
    if (metaBrand.length) {
      const txt = metaBrand.is('meta') ? metaBrand.attr('content') : (metaBrand.attr('data-brand') || metaBrand.text());
      if (txt && txt.trim()) return txt.trim();
    }
    return null;
  }
}

module.exports = IncehesapScraper;
