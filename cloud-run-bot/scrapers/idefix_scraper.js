/**
 * Idefix Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');
const https = require('https');

class IdefixScraper extends BaseProductScraper {
  get domain() { return 'idefix.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('idefix.com');
  }

  scrapeImage($, url) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      let img = this.extractImageFromProductJson(product['image']);
      if (img) {
        if (img.includes('{size}')) {
          img = img.replace('{size}', '500/0/');
        }
        if (!this.isLogoUrl(img)) {
          const r = this.resolveImageUrl(img, url);
          if (r) return r;
        }
      }
    }
    // 2. og:image
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r) return r;
    }
    // 3. DOM selectors
    const imgElements = $('img[class*="product"], img.product-image, .product-detail img');
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
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    // 2. DOM
    const el = $('h1.text-title-lg, h1').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. __NEXT_DATA__
    const nextScript = $('#__NEXT_DATA__').html();
    if (nextScript) {
      try {
        const json = JSON.parse(nextScript);
        const cp = json.props?.pageProps?.productDetail?.currentPrice;
        if (cp) {
          const eff = cp.effectivePrice || cp.discountedPrice;
          if (eff && eff > 0) return parseFloat(eff);
        }
      } catch (_) {}
    }

    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 3. DOM
    const el = $('span.text-title-2xl.text-secondary-600, meta[property="og:price:sale_price"], meta[property="product:price:amount"]').first();
    if (el.length) {
      const v = this.parsePriceText(el.is('meta') ? el.attr('content') : el.text());
      if (v && v > 0) return v;
    }
    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    let candidates = [];

    // 1. __NEXT_DATA__
    const nextScript = $('#__NEXT_DATA__').html();
    if (nextScript) {
      try {
        const json = JSON.parse(nextScript);
        const cp = json.props?.pageProps?.productDetail?.currentPrice;
        if (cp) {
          if (cp.price != null) {
            const val = parseFloat(cp.price);
            if (val > currentPrice) candidates.push(val);
          }
          if (cp.comparePrice != null) {
            const val = parseFloat(cp.comparePrice);
            if (val > currentPrice) candidates.push(val);
          }
        }
      } catch (_) {}
    }

    // 2. DOM selectors for strikethrough price
    const selectors = [
      'span.line-through',
      'span.text-title-md.text-neutral-500',
      'span.text-neutral-500',
      '.line-through',
      'del',
      's'
    ];

    for (const selector of selectors) {
      $(selector).each((_, el) => {
        const txt = $(el).text().trim();
        if (txt.includes('TL')) {
          const parsed = this.parsePriceText(txt);
          if (parsed !== null && parsed > currentPrice) {
            candidates.push(parsed);
          }
        }
      });
    }

    if (candidates.length === 0) return null;

    candidates = candidates.filter(c => c > currentPrice && c <= currentPrice * 5);
    if (candidates.length === 0) return null;

    candidates.sort((a, b) => a - b);
    return candidates[0];
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
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'idefix');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, .idefix-breadcrumb a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('idefix') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }

  async scrapeRating($, url) {
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }

    // Live ecomapi API Fallback using native https
    try {
      let productId = null;
      const match = /p-(\d+)/.exec(url || '') || /p-(\d+)/.exec($('link[rel="canonical"]').attr('href') || '');
      if (match) productId = match[1];

      if (productId) {
        const data = await new Promise((resolve) => {
          const req = https.get(`https://ecomapi.idefix.com/api/product/${productId}/detail/review`, {
            headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36' },
            timeout: 5000,
          }, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
              try { resolve(JSON.parse(body)); } catch (_) { resolve(null); }
            });
          });
          req.on('error', () => resolve(null));
          req.on('timeout', () => { req.destroy(); resolve(null); });
        });

        if (data) {
          const ratingValue = data.averageRating != null ? parseFloat(data.averageRating) : null;
          const ratingCount = data.reviewCount != null ? parseInt(data.reviewCount) : null;
          if (ratingValue || ratingCount) {
            return { ratingValue: !isNaN(ratingValue) ? ratingValue : null, ratingCount: !isNaN(ratingCount) ? ratingCount : null };
          }
        }
      }
    } catch (_) {}

    return { ratingValue: null, ratingCount: null };
  }

  scrapeBrand($) {
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand) return brand;
    }
    return null;
  }
}

module.exports = IdefixScraper;
