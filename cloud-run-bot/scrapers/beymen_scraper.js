/**
 * Beymen Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class BeymenScraper extends BaseProductScraper {
  get domain() { return 'beymen.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('beymen.com');
  }

  scrapeImage($, url) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const r = this.resolveImageUrl(img, url);
        if (r) return r;
      }
    }
    // 2. og:image
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r) return r;
    }
    // 3. DOM selectors
    const imgElements = $('.product-detail-images img, img[class*="product"]');
    for (let i = 0; i < imgElements.length; i++) {
      const src = $(imgElements[i]).attr('src') || $(imgElements[i]).attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const r = this.resolveImageUrl(src, url);
        if (r) return r;
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. DOM o-productDetail__description
    const titleEl = $('.o-productDetail__description').first();
    if (titleEl.length) {
      const text = titleEl.text().trim();
      if (text) return text;
    }

    // 2. Script displayName
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('BEYMEN.productMain')) {
        const match = text.match(/"displayName"\s*:\s*"((?:[^"\\]|\\.)*)"/);
        if (match) {
          return match[1].replace(/\\"/g, '"').trim();
        }
      }
    }

    // 3. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();

    // 4. DOM H1
    const h1El = $('h1.o-productDetail__title, h1').first();
    if (h1El.length) return h1El.text().trim();

    return null;
  }

  scrapePrice($) {
    // 1. DOM Campaign / Sepette price (Öncelikli)
    const campaignPriceEl = $('.m-price__campaignPrice, [id="priceCampaign"]').first();
    if (campaignPriceEl.length) {
      const val = this.parsePriceText(campaignPriceEl.text());
      if (val && val > 0) return val;
    }

    // 2. DOM Last Price (Son İndirimli / Ek İndirimli Fiyat - Örn: Dolce & Gabbana 44.195 TL)
    const lastPriceEl = $('.m-price__lastPrice').first();
    if (lastPriceEl.length) {
      const val = this.parsePriceText(lastPriceEl.text());
      if (val && val > 0) return val;
    }

    // 3. DOM New price
    const newPriceEl = $('ins.m-price__new, .m-price__new, [id="priceNew"]').first();
    if (newPriceEl.length) {
      const val = this.parsePriceText(newPriceEl.text());
      if (val && val > 0) return val;
    }

    // 4. Script BEYMEN.productMain promotedOrActualPrice
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('BEYMEN.productMain')) {
        const match = text.match(/"promotedOrActualPrice"\s*:\s*([0-9.]+)/) ||
                      text.match(/"actualPrice"\s*:\s*([0-9.]+)/);
        if (match) {
          const val = parseFloat(match[1]);
          if (!isNaN(val) && val > 0) return val;
        }
      }
    }

    // 5. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 6. DOM campaign/discount/Visa prices fallback
    const priceSelectors = [
      '.m-price__campaignPrice',
      '.m-price__lastPrice',
      'ins.m-price__new',
      '.m-price__new',
      '.m-productDetail__newPrice',
      '.o-productDetail__price'
    ];
    let lowestPrice = null;
    for (const sel of priceSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const val = this.parsePriceText(el.text());
        if (val && val > 0) {
          if (lowestPrice === null || val < lowestPrice) {
            lowestPrice = val;
          }
        }
      }
    }

    return lowestPrice;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    // 1. DOM old strikethrough price (.m-price__old, del.m-price__old)
    const oldPriceEl = $('.m-price__old, del.m-price__old, [id="priceOld"]').first();
    if (oldPriceEl.length) {
      const val = this.parsePriceText(oldPriceEl.text());
      if (val && val > currentPrice) return val;
    }

    // 2. DOM .m-price__new (Eğer kampanya veya lastPrice varsa, normal satış fiyatı .m-price__new üzerindedir)
    const newPriceEl = $('ins.m-price__new, .m-price__new, [id="priceNew"]').first();
    if (newPriceEl.length) {
      const val = this.parsePriceText(newPriceEl.text());
      if (val && val > currentPrice) return val;
    }

    // 3. DOM .m-price__lastPrice (Eğer kampanya fiyatı varsa, ara indirimli fiyat .m-price__lastPrice üzerindedir)
    const lastPriceEl = $('.m-price__lastPrice').first();
    if (lastPriceEl.length) {
      const val = this.parsePriceText(lastPriceEl.text());
      if (val && val > currentPrice) return val;
    }

    // 4. Script BEYMEN.productMain strikeThroughPrice veya actualPrice
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('BEYMEN.productMain')) {
        const strikeMatch = text.match(/"strikeThroughPriceText"\s*:\s*"([^"]+)"/);
        if (strikeMatch) {
          const val = this.parsePriceText(strikeMatch[1]);
          if (val && val > currentPrice) return val;
        }

        const actualMatch = text.match(/"actualPriceText"\s*:\s*"([^"]+)"/);
        if (actualMatch) {
          const val = this.parsePriceText(actualMatch[1]);
          if (val && val > currentPrice) return val;
        }
      }
    }

    // 5. Fallback selectors
    let candidates = [];
    const selectors = [
      '.m-price__old',
      '.m-price__new',
      '.m-price__lastPrice',
      'del',
      's',
      '.old-price',
      '.original-price'
    ];
    for (const selector of selectors) {
      $(selector).each((_, el) => {
        const txt = $(el).text().trim();
        if (txt.includes('TL') || txt.includes('₺')) {
          const parsed = this.parsePriceText(txt);
          if (parsed !== null && parsed > currentPrice && parsed <= currentPrice * 5) {
            candidates.push(parsed);
          }
        }
      });
    }

    if (candidates.length === 0) return null;

    candidates.sort((a, b) => b - a);
    return candidates[0];
  }

  scrapeDescription($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['description']) return product['description'].toString().trim();
    // 2. DOM
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    if (descEl.length) {
      const content = descEl.attr('content')?.trim();
      if (content && content.toLowerCase() !== 'null') return content;
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'beymen');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // 1. Microdata / Schema.org BreadcrumbList
    const els = $('[itemprop="itemListElement"] [itemprop="name"], ol[itemtype*="BreadcrumbList"] span[itemprop="name"], ol[itemtype*="BreadcrumbList"] [itemprop="name"], [itemtype*="BreadcrumbList"] [itemprop="name"], #breadcrumb [itemprop="name"], .m-breadcrumb [itemprop="name"]');
    if (els.length) {
      const list = [];
      els.each((_, el) => {
        const text = $(el).text().trim();
        if (text) {
          const lower = text.toLowerCase();
          if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('beymen') && lower !== title.toLowerCase().trim() && text.length < 50) {
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
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('beymen') && lower !== title.toLowerCase().trim() && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = BeymenScraper;
