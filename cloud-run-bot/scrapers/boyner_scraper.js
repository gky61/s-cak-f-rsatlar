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

  _extractBoynerPriceInfo($) {
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text();
      if (!text || !text.includes('"PriceInfo"')) continue;

      const match = text.match(/"PriceInfo"\s*:\s*\{([^}]+)\}/);
      if (match && match[1]) {
        const content = match[1];
        const priceMatch = content.match(/"Price"\s*:\s*(?:"([^"]+)"|(\d+(?:\.\d+)?))/);
        const oldPriceMatch = content.match(/"OldPrice"\s*:\s*(?:"([^"]+)"|(\d+(?:\.\d+)?))/);
        const campaignMatch = content.match(/"CampaignInfo"\s*:\s*"([^"]+)"/);

        const rawPrice = priceMatch ? (priceMatch[1] || priceMatch[2]) : null;
        const rawOldPrice = oldPriceMatch ? (oldPriceMatch[1] || oldPriceMatch[2]) : null;
        const rawCampaign = campaignMatch ? campaignMatch[1] : null;

        const parsedPrice = rawPrice ? this.parsePriceText(rawPrice) : null;
        const parsedOldPrice = rawOldPrice ? this.parsePriceText(rawOldPrice) : null;

        if (parsedPrice != null && parsedPrice > 0) {
          return {
            price: parsedPrice,
            originalPrice: parsedOldPrice,
            campaignInfo: rawCampaign ? rawCampaign.trim() : null,
          };
        }
      }
    }
    return null;
  }

  scrapePrice($) {
    // 1. En güvenilir kaynak: Next.js script verisindeki PriceInfo
    const priceInfo = this._extractBoynerPriceInfo($);
    if (priceInfo && priceInfo.price) {
      return priceInfo.price;
    }

    // 2. DOM selector for main price: [class*="priceMain"]
    let domPrice = null;
    $('[class*="priceMain"]').each((_, el) => {
      if (domPrice) return;
      const clone = $(el).clone();
      clone.find('[class*="priceMainText"], [class*="price_priceMainText"]').remove();
      let cleanText = clone.text().trim();
      if (cleanText) {
        cleanText = cleanText.replace(/^(?:Sepette(?:\s*İndirim)?|Özel\s*Fiyat)\s*/i, '').trim();
        const p = this.parsePriceText(cleanText);
        if (p != null && p > 0) {
          // 2.1 Sanity Check: Eğer bulunan fiyat 100 TL altıysa ama JSON-LD fiyatı 100 TL üzerindeyse
          if (p < 100) {
            const product = this.findProductJsonLd($);
            if (product) {
              const priceLd = this.extractPriceFromProductJson(product);
              if (priceLd != null && priceLd > 100 && (priceLd / p) > 50) {
                domPrice = priceLd;
                return;
              }
            }
          }
          domPrice = p;
        }
      }
    });

    if (domPrice) return domPrice;

    // 3. Fallback to JSON-LD price
    const product = this.findProductJsonLd($);
    if (product) {
      const price = this.extractPriceFromProductJson(product);
      if (price != null && price > 0) return price;
    }

    // 4. Legacy Script/JSON regex scan for CampaignPrice > 0
    const html = $.html();
    const matches = html.matchAll(/"CampaignPrice":\s*(\d+(?:\.\d+)?)/gi);
    for (const m of matches) {
      const val = parseFloat(m[1]);
      if (!isNaN(val) && val > 0) {
        return val;
      }
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (currentPrice != null && currentPrice <= 0) return null;

    // 1. En güvenilir kaynak: Next.js script verisindeki PriceInfo.OldPrice
    const priceInfo = this._extractBoynerPriceInfo($);
    if (priceInfo && priceInfo.originalPrice != null && (currentPrice == null || priceInfo.originalPrice > currentPrice)) {
      return priceInfo.originalPrice;
    }

    // 2. DOM selector for old price (e.g. [class*="priceOldPrice"])
    let oldPriceText = '';
    $('[class*="priceOldPrice"]').each((_, el) => {
      const txt = $(el).text().trim();
      if (txt && !oldPriceText) {
        oldPriceText = txt;
      }
    });

    if (oldPriceText) {
      const oldPrice = this.parsePriceText(oldPriceText);
      if (oldPrice != null && (currentPrice == null || oldPrice > currentPrice)) {
        return oldPrice;
      }
    }

    // 3. Script/JSON regex scan for StrikeThrough / ActualPrice > currentPrice
    const html = $.html();
    const matches = html.matchAll(/"(?:StrikeThroughPriceToShowOnScreen|ActualPriceToShowOnScreen)":\s*(\d+(?:\.\d+)?)/gi);
    for (const m of matches) {
      const val = parseFloat(m[1]);
      if (!isNaN(val) && (currentPrice == null || val > currentPrice)) {
        return val;
      }
    }

    return null;
  }

  scrapePriceLabel($) {
    // 1. PriceInfo.CampaignInfo ("Sepette %28 İndirim", "%48 İndirim" vb.)
    const priceInfo = this._extractBoynerPriceInfo($);
    if (priceInfo && priceInfo.campaignInfo) {
      return priceInfo.campaignInfo;
    }

    // 2. DOM selector [class*="priceMainText"]
    const badgeEl = $('[class*="priceMainText"], [class*="price_priceMainText"]').first();
    if (badgeEl.length > 0) {
      const txt = badgeEl.text().trim();
      if (txt) {
        if (txt.toLowerCase() === 'sepette') return 'Sepette İndirim';
        return txt;
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
