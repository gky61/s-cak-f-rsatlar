/**
 * Itopya Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class ItopyaScraper extends BaseProductScraper {
  get domain() { return 'itopya.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('itopya.com');
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
      '.product-details-img img',
      '#product-image img',
      'img[class*="product"]'
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

  scrapeTitle($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();
    // 2. DOM
    const el = $('h1.product-details-title, h1').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. DOM Sepette indirimli fiyat (.product-price-warning-detail span)
    const sepetteEl = $('.product-price-warning-detail span').first();
    if (sepetteEl.length) {
      const val = this.parsePriceText(sepetteEl.text());
      if (val && val > 0) return val;
    }

    // 2. DOM newprice
    const newPriceEl = $('.product-details__sidebar_newprice').first();
    if (newPriceEl.length) {
      const val = this.parsePriceText(newPriceEl.text());
      if (val && val > 0) return val;
    }

    // 3. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 4. Fallback DOM
    const el = $('.product-price-warning-detail, .amount').first();
    if (el.length) {
      const v = this.parsePriceText(el.text());
      if (v && v > 0) return v;
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    // 1. DOM .product-details__sidebar_oldprice (Çizili eski fiyat)
    const oldPriceEl = $('.product-details__sidebar_oldprice').first();
    if (oldPriceEl.length) {
      const val = this.parsePriceText(oldPriceEl.text());
      if (val && val > currentPrice) return val;
    }

    // 2. DOM .product-details__sidebar_newprice (Eğer sepette indirim varsa, liste fiyatı bu alandadır)
    const newPriceEl = $('.product-details__sidebar_newprice').first();
    if (newPriceEl.length) {
      const val = this.parsePriceText(newPriceEl.text());
      if (val && val > currentPrice) return val;
    }

    // 3. Fallback selectors
    let candidates = [];
    const selectors = [
      '.product-details__sidebar_oldprice',
      '.product-details__sidebar_newprice',
      'del',
      's',
      '.old-price',
      '.original-price'
    ];
    for (const selector of selectors) {
      $(selector).each((_, el) => {
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

    candidates.sort((a, b) => b - a);
    return candidates[0];
  }

  scrapeBrand($) {
    const product = this.findProductJsonLd($);
    if (product && product.brand) {
      if (typeof product.brand === 'string') return product.brand.trim();
      if (typeof product.brand === 'object' && product.brand.name) return product.brand.name.trim();
    }

    const brandEl = $('.product-details-brand, [itemprop="brand"]').first();
    if (brandEl.length) return brandEl.text().trim();

    return null;
  }

  scrapeRating($, url, html) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }

    // 2. DOM ratingValue (data-rateyo-rating)
    let ratingValue = null;
    let ratingCount = null;

    $('[data-rateyo-rating]').each((_, el) => {
      const attr = $(el).attr('data-rateyo-rating');
      if (attr && attr !== 'undefined') {
        const val = parseFloat(attr);
        if (!isNaN(val) && val > 0 && ratingValue === null) ratingValue = val;
      }
    });

    // 3. DOM ratingCount (a.seeAll e.g. "(4)")
    const seeAllEl = $('a.seeAll, a[onclick*="FocusYorum"], .count').first();
    if (seeAllEl.length) {
      const match = seeAllEl.text().match(/\((\d+)\)/);
      if (match) {
        const count = parseInt(match[1], 10);
        if (!isNaN(count)) ratingCount = count;
      }
    }

    if (ratingValue !== null || ratingCount !== null) {
      return { ratingValue, ratingCount };
    }

    // 4. Fallback: API Call to /Urun/UrunYorum?id={urunId} (Cloudflare Bypass via Google Translate Proxy)
    try {
      const canonical = $('link[rel="canonical"]').attr('href') || $('meta[property="og:url"]').attr('content') || '';
      const matchCanonical = canonical.match(/_u(\d+)/i);
      const matchUrl = (url || '').match(/_u(\d+)/i);
      const htmlText = $.html ? $.html() : (html || '');
      const matchHtml = typeof htmlText === 'string' ? htmlText.match(/urunId\s*[:=]\s*['"]?(\d+)['"]?/i) : null;
      const urunId = matchCanonical ? matchCanonical[1] : (matchUrl ? matchUrl[1] : (matchHtml ? matchHtml[1] : null));

      if (urunId) {
        const { execSync } = require('child_process');
        const proxyApiUrl = `https://www-itopya-com.translate.goog/Urun/UrunYorum?id=${urunId}&_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;
        const directApiUrl = `https://www.itopya.com/Urun/UrunYorum?id=${urunId}`;

        let raw = null;
        try {
          raw = execSync(`curl -sL --compressed -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "${proxyApiUrl}"`, { timeout: 4000 }).toString();
        } catch (_) {}

        if (!raw || !raw.trim().startsWith('[')) {
          try {
            raw = execSync(`curl -sL --compressed -H "User-Agent: WhatsApp/2.23.4.15 A" "${directApiUrl}"`, { timeout: 4000 }).toString();
          } catch (_) {}
        }

        if (raw && raw.trim().startsWith('[')) {
          const data = JSON.parse(raw);
          if (Array.isArray(data) && data.length > 0) {
            let totalPuan = 0;
            let count = 0;
            for (const item of data) {
              if (item.puan !== undefined && item.puan !== null) {
                const p = parseFloat(item.puan);
                if (!isNaN(p)) {
                  totalPuan += p;
                  count++;
                }
              }
            }
            if (count > 0) {
              return {
                ratingValue: Math.round((totalPuan / count) * 10) / 10,
                ratingCount: data.length
              };
            }
          }
        }
      }
    } catch (_) {}

    return null;
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
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'itopya');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, ul.breadcrumb li a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('itopya') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = ItopyaScraper;
