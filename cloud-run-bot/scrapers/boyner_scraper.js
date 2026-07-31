/**
 * Boyner Product Scraper (Boyner.com.tr)
 * Node.js portu
 * Dart karşılığı: lib/services/scrapers/boyner_scraper.dart
 */

const BaseProductScraper = require('./base_scraper');

class BoynerScraper extends BaseProductScraper {
  get domain() {
    return 'boyner.com.tr';
  }

  scrapeTitle($) {
    const product = this.findProductJsonLd($);
    if (product && product.name) {
      return this.unescapeHtml(product.name.trim());
    }
    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle) return this.unescapeHtml(ogTitle.trim());
    const h1 = $('h1').first().text();
    if (h1) return this.unescapeHtml(h1.trim());
    return null;
  }

  scrapeBrand($) {
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand) return brand;
    }
    const metaBrand = $('meta[property="product:brand"]').attr('content');
    if (metaBrand) return metaBrand.trim();
    return null;
  }

  scrapePrice($) {
    // 1. DOM selector for main price (e.g. [class*="priceMain"])
    let mainPriceText = '';
    $('[class*="priceMain"]').each((_, el) => {
      const txt = $(el).text().trim();
      if (txt && !mainPriceText) {
        mainPriceText = txt;
      }
    });

    if (mainPriceText) {
      const p = this.parsePriceText(mainPriceText);
      if (p != null && p > 0) return p;
    }

    // 2. Script/JSON regex scan for CampaignPrice > 0
    const html = $.html();
    const matches = html.matchAll(/"CampaignPrice":\s*(\d+(?:\.\d+)?)/gi);
    for (const m of matches) {
      const val = parseFloat(m[1]);
      if (!isNaN(val) && val > 0) {
        return val;
      }
    }

    // 3. Fallback to JSON-LD price
    const product = this.findProductJsonLd($);
    if (product) {
      const price = this.extractPriceFromProductJson(product);
      if (price != null && price > 0) return price;
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    // 1. DOM selector for old price (e.g. [class*="priceOldPrice"])
    let oldPriceText = '';
    $('[class*="priceOldPrice"]').each((_, el) => {
      const txt = $(el).text().trim();
      if (txt && !oldPriceText) {
        oldPriceText = txt;
      }
    });

    if (oldPriceText) {
      const oldPrice = this.parsePriceText(oldPriceText);
      if (oldPrice != null && currentPrice != null && oldPrice > currentPrice) {
        return oldPrice;
      }
    }

    // 2. Script/JSON regex scan for StrikeThrough / ActualPrice > currentPrice
    const html = $.html();
    const matches = html.matchAll(/"(?:StrikeThroughPriceToShowOnScreen|ActualPriceToShowOnScreen)":\s*(\d+(?:\.\d+)?)/gi);
    for (const m of matches) {
      const val = parseFloat(m[1]);
      if (!isNaN(val) && currentPrice != null && val > currentPrice) {
        return val;
      }
    }

    return null;
  }

  scrapeRating($) {
    // 1. Check JSON-LD blocks recursively for aggregateRating
    const jsonLdRating = this.findRatingFromJsonLd($);
    if (jsonLdRating && (jsonLdRating.ratingValue != null || jsonLdRating.ratingCount != null)) {
      return jsonLdRating;
    }

    // 2. Script/JSON payload regex search (ProductRating, TotalReviewCount, ReviewCount)
    const html = $.html();
    const ratingValueMatch = html.match(/"ProductRating"\s*:\s*(\d+(?:\.\d+)?)/i) ||
                             html.match(/"ratingValue"\s*:\s*(\d+(?:\.\d+)?)/i);
    const ratingCountMatch = html.match(/"TotalReviewCount"\s*:\s*(\d+)/i) ||
                             html.match(/"ReviewCount"\s*:\s*(\d+)/i) ||
                             html.match(/"ratingCount"\s*:\s*(\d+)/i);

    const ratingValue = ratingValueMatch ? parseFloat(ratingValueMatch[1]) : null;
    const ratingCount = ratingCountMatch ? parseInt(ratingCountMatch[1]) : null;

    if (!isNaN(ratingValue) || !isNaN(ratingCount)) {
      return {
        ratingValue: !isNaN(ratingValue) ? ratingValue : null,
        ratingCount: !isNaN(ratingCount) ? ratingCount : null,
      };
    }

    return { ratingValue: null, ratingCount: null };
  }

  findRatingFromJsonLd($) {
    const scripts = $('script[type="application/ld+json"]');
    for (let i = 0; i < scripts.length; i++) {
      try {
        const text = $(scripts[i]).text() || '';
        const sanitized = text.replace(/\r\n/g, ' ').replace(/\n/g, ' ').replace(/\r/g, ' ');
        const data = JSON.parse(sanitized);
        const rating = this._searchRatingInJson(data);
        if (rating) return rating;
      } catch (_) {}
    }
    return null;
  }

  _searchRatingInJson(json) {
    if (json && typeof json === 'object' && !Array.isArray(json)) {
      if (json['aggregateRating'] && typeof json['aggregateRating'] === 'object') {
        const r = this.extractRatingFromProductJson(json);
        if (r && (r.ratingValue != null || r.ratingCount != null)) return r;
      }
      if (Array.isArray(json['@graph'])) {
        for (const item of json['@graph']) {
          const res = this._searchRatingInJson(item);
          if (res) return res;
        }
      }
      for (const val of Object.values(json)) {
        if (val && typeof val === 'object') {
          const res = this._searchRatingInJson(val);
          if (res) return res;
        }
      }
    } else if (Array.isArray(json)) {
      for (const item of json) {
        const res = this._searchRatingInJson(item);
        if (res) return res;
      }
    }
    return null;
  }

  scrapeImage($, url) {
    const product = this.findProductJsonLd($);
    if (product && product.image) {
      const img = this.extractImageFromProductJson(product.image);
      if (img && !this.isLogoUrl(img)) {
        return this.resolveImageUrl(img, url);
      }
    }

    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      return this.resolveImageUrl(ogImg, url);
    }

    return null;
  }

  scrapeDescription($) {
    const ogDesc = $('meta[property="og:description"]').attr('content');
    if (ogDesc) return this.unescapeHtml(ogDesc.trim());
    const metaDesc = $('meta[name="description"]').attr('content');
    if (metaDesc) return this.unescapeHtml(metaDesc.trim());
    return null;
  }

  scrapeBreadcrumbs($) {
    return this.extractBreadcrumbsFromJsonLd($, this.scrapeTitle($), 'boyner');
  }
}

module.exports = BoynerScraper;
