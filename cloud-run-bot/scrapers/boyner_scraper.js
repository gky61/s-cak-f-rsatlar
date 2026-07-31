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
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }
    return { ratingValue: null, ratingCount: null };
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
