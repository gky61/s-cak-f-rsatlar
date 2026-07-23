/**
 * PttAVM Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class PttavmScraper extends BaseProductScraper {
  get domain() { return 'pttavm.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('pttavm.com');
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
    const imgSelectors = [
      '.product-detail-images img',
      '.product-images img',
      'img[class*="product"]',
      '#product-image'
    ];
    for (const sel of imgSelectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const r = this.resolveImageUrl(src, url);
        if (r) return r;
      }
    }
    return null;
  }

  findDataLayerYmProduct($) {
    if (this._dataLayerYmCached !== undefined) {
      return this._dataLayerYmCached;
    }

    let parsed = null;
    $('script').each((_, el) => {
      const text = $(el).html();
      if (text && text.includes('dataLayerYM.push')) {
        const match = text.match(/products:\s*\[\s*(\{[\s\S]*?\})\s*\]/);
        if (match && match[1]) {
          const productObjText = match[1];
          const extractFieldValue = (fieldName) => {
            const doubleQuoteRegex = new RegExp(`${fieldName}:\\s*"((?:[^"\\\\]|\\\\.)*)"`);
            const dqMatch = productObjText.match(doubleQuoteRegex);
            if (dqMatch) return dqMatch[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');

            const singleQuoteRegex = new RegExp(`${fieldName}:\\s*'((?:[^'\\\\]|\\\\.)*)'`);
            const sqMatch = productObjText.match(singleQuoteRegex);
            if (sqMatch) return sqMatch[1].replace(/\\'/g, "'").replace(/\\\\/g, '\\');

            const unquotedRegex = new RegExp(`${fieldName}:\\s*([^,\\}\\s]+)`);
            const uMatch = productObjText.match(unquotedRegex);
            if (uMatch) return uMatch[1];

            return null;
          };

          const id = extractFieldValue('id');
          const name = extractFieldValue('name');
          const priceStr = extractFieldValue('price');
          const category = extractFieldValue('category');

          parsed = {
            id,
            name,
            price: priceStr ? parseFloat(priceStr) : null,
            category
          };
          return false; // break cheerio each loop
        }
      }
    });

    this._dataLayerYmCached = parsed;
    return parsed;
  }

  scrapeTitle($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    
    // 2. dataLayerYM fallback
    const ymData = this.findDataLayerYmProduct($);
    if (ymData && ymData.name) return ymData.name.trim();

    // 3. DOM
    const el = $('h1.product-title, .product-name').first();
    if (el.length) return el.text().trim();
    const og = $('meta[property="og:title"]').attr('content');
    return og ? og.trim() : null;
  }

  scrapePrice($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 2. dataLayerYM fallback
    const ymData = this.findDataLayerYmProduct($);
    if (ymData && ymData.price && ymData.price > 0) return ymData.price;

    // 3. DOM
    const priceSelectors = [
      '[class*="specialPriceValue__HPhRC"]',
      '.specialPriceValue__HPhRC',
      '[class*="priceValue__D5sYV"]',
      '.priceValue__D5sYV',
      '.product-price',
      '.price-box',
      '.discount-price',
      '.current-price'
    ];
    for (const sel of priceSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const v = this.parsePriceText(el.text());
        if (v && v > 0) return v;
      }
    }
    return null;
  }

  scrapeDescription($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['description']) {
      const desc = product['description'].toString().trim();
      if (desc && desc.toLowerCase() !== 'null') return desc;
    }
    // 2. meta data-rh="true"
    const rhDesc = $('meta[data-rh="true"][name="description"]').first();
    if (rhDesc.length) {
      const content = rhDesc.attr('content')?.trim();
      if (content && content.toLowerCase() !== 'null') return content;
    }
    // 3. standard meta
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    if (descEl.length) {
      const content = descEl.attr('content')?.trim();
      if (content && content.toLowerCase() !== 'null') return content;
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'pttavm');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // dataLayerYM category fallback
    const ymData = this.findDataLayerYmProduct($);
    if (ymData && ymData.category) {
      const cleanCat = ymData.category.trim();
      if (cleanCat && cleanCat.toLowerCase() !== 'null') {
        return [cleanCat];
      }
    }

    // DOM Fallback
    const list = [];
    $('ul.breadcrumb a, .breadcrumb a, .breadcrumbs a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && !lower.includes('pttavm') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }

  scrapeRating($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }

    // 2. DOM
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

    return { ratingValue: null, ratingCount: null };
  }

  scrapeBrand($) {
    // 1. additionalProperty "External Source" (Öncelikli - PttAVM'de brand alanı satıcıyı içerir)
    const product = this.findProductJsonLd($);
    if (product) {
      const additionalProps = product['additionalProperty'];
      if (Array.isArray(additionalProps) && additionalProps.length > 0) {
        const firstProp = additionalProps[0];
        if (firstProp && firstProp['name'] === 'External Source') {
          const val = firstProp['value'];
          if (val && val.toString().trim()) return val.toString().trim();
        }
      }
      // 2. brand alanı (Fallback)
      const brand = this.extractBrandFromProductJson(product);
      if (brand) return brand;
    }
    const metaBrand = $('meta[property="product:brand"], meta[name="brand"], .product-brand, [data-brand]').first();
    if (metaBrand.length) {
      const txt = metaBrand.is('meta') ? metaBrand.attr('content') : (metaBrand.attr('data-brand') || metaBrand.text());
      if (txt && txt.trim()) return txt.trim();
    }
    return null;
  }
}

module.exports = PttavmScraper;
