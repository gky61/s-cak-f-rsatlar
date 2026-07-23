/**
 * Havit Store Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class HavitScraper extends BaseProductScraper {
  get domain() { return 'havitstore.com.tr'; }

  canHandle(url) {
    return url.toLowerCase().includes('havitstore.com.tr');
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
      '.sub-image img',
      '#product-image img',
      '.product-details img',
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
    const el = $('h1.product-title, h1').first();
    if (el.length) return el.text().trim();
    return null;
  }

  scrapePrice($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    // 2. DOM Fallback
    const el = $('#fiyat2 .spanFiyat, .indirimliFiyat .spanFiyat').first();
    if (el.length) {
      const v = this.parsePriceText(el.text());
      if (v && v > 0) return v;
    }
    return null;
  }

  cleanDescription(desc) {
    if (!desc) return '';
    let cleaned = desc.replace(/@import\s+url\([^)]+\);?/gi, '');
    cleaned = cleaned.replace(/@import\s+[^;]+;/gi, '');
    cleaned = cleaned.replace(/[^{]+{[^}]+}/g, '');
    cleaned = cleaned.replace(/<[^>]*>/g, ' ');
    cleaned = cleaned.replace(/[\w-]+\s*:\s*[^;]+;/g, '');
    cleaned = cleaned.replace(/\s+/g, ' ');
    return cleaned.trim();
  }

  scrapeDescription($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['description']) {
      return this.cleanDescription(product['description'].toString());
    }
    // 2. DOM
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? this.cleanDescription(descEl.attr('content')) : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'havitstore');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, ul.breadcrumb li a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('havit') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }

  async fetchYgDigitalRating($) {
    try {
      let barcode = $('#divBarkod #spnBarkod, #spnBarkod').text().trim();
      if (!barcode) {
        $('script').each((_, el) => {
          const text = $(el).html() || '';
          const m = text.match(/"stockCode"\s*:\s*"([^"]+)"/);
          if (m) {
            barcode = m[1].trim();
            return false;
          }
        });
      }
      const hddnVal = $('#hddnUrunID').attr('value');
      const code = barcode || hddnVal;
      if (!code) return null;

      const https = require('https');
      const payload = JSON.stringify({
        barcode: code,
        productUrl: '',
        page: 0,
        rateFilter: 0,
        photoFilter: 0,
        sortOrder: 'DESC',
        searchText: ''
      });

      return new Promise((resolve) => {
        const req = https.request({
          hostname: 'api.yg.digital',
          port: 443,
          path: '/trendyol_api/api/commentDetail.php',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload),
            'Origin': 'https://www.havitstore.com.tr',
            'Referer': 'https://www.havitstore.com.tr/',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          },
          timeout: 4000
        }, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => {
            try {
              const json = JSON.parse(data);
              if (json && json.product) {
                const avgRate = parseFloat(json.product.avg_rate);
                const rateCount = parseInt(json.product.rate_count);
                resolve({
                  ratingValue: (!isNaN(avgRate) && avgRate > 0) ? avgRate : null,
                  ratingCount: (!isNaN(rateCount) && rateCount > 0) ? rateCount : null
                });
              } else {
                resolve(null);
              }
            } catch (_) {
              resolve(null);
            }
          });
        });
        req.on('error', () => resolve(null));
        req.on('timeout', () => { req.destroy(); resolve(null); });
        req.write(payload);
        req.end();
      });
    } catch (_) {
      return null;
    }
  }

  async scrapeRating($) {
    let ratingValue = null;
    let ratingCount = null;

    // 1. Havit/Ticimax Özel DOM Seçicileri (.ctgry-avg, .comment-count.ctgry-avg, .right-stars .comment-count)
    const ratingSelectors = [
      '.comment-count.ctgry-avg',
      '.ctgry-avg',
      '.right-stars .comment-count',
      '.comment-stars-container .comment-count',
      '.yg-comment-rating-score',
    ];

    for (const sel of ratingSelectors) {
      const el = $(sel).first();
      if (el.length) {
        const txt = el.text().trim().replace(',', '.');
        if (!txt.startsWith('(')) {
          const p = parseFloat(txt);
          if (!isNaN(p) && p > 0 && p <= 5.0) {
            ratingValue = p;
            break;
          }
        }
      }
    }

    if (!ratingValue) {
      $('.comment-count').each((_, el) => {
        const txt = $(el).text().trim().replace(',', '.');
        if (!txt.startsWith('(') && !txt.endsWith(')')) {
          const p = parseFloat(txt);
          if (!isNaN(p) && p > 0 && p <= 5.0) {
            ratingValue = p;
            return false;
          }
        }
      });
    }

    // 2. Ticimax Script Model
    if (!ratingValue) {
      $('script').each((_, el) => {
        const text = $(el).html() || '';
        if (text.includes('productDetailModel') && text.includes('rating')) {
          const match = text.match(/"rating"\s*:\s*([\d]+(?:[.,]\d+)?)/);
          if (match) {
            const p = parseFloat(match[1].replace(',', '.'));
            if (!isNaN(p) && p > 0 && p <= 5.0) ratingValue = p;
          }
        }
      });
    }

    // DOM Fallback (itemprop)
    if (!ratingValue) {
      const ratingEl = $('[itemprop="ratingValue"], meta[property="product:rating:value"], .rating-score, .pdp-rating-value').first();
      if (ratingEl.length) {
        const txt = ratingEl.is('meta') ? ratingEl.attr('content') : ratingEl.text();
        if (txt) {
          const p = parseFloat(txt.trim().replace(',', '.'));
          if (!isNaN(p) && p > 0 && p <= 5.0) ratingValue = p;
        }
      }
    }

    // ratingCount DOM Seçicileri (.comment-count-left, #divYorumSayisi)
    const countEl = $('.comment-count-left, #divYorumSayisi, [itemprop="reviewCount"], [itemprop="ratingCount"], .review-count, .rating-count').first();
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

    if (!ratingCount) {
      $('.comment-count').each((_, el) => {
        const txt = $(el).text().trim();
        if (txt.includes('(') || txt.includes(')')) {
          const m = /(\d+)/.exec(txt);
          if (m) {
            const c = parseInt(m[1]);
            if (!isNaN(c) && c > 0) {
              ratingCount = c;
              return false;
            }
          }
        }
      });
    }

    if (!ratingCount) {
      const reviews = $('.yg-comment-review');
      if (reviews.length) {
        ratingCount = reviews.length;
      }
    }

    // 3. YG Digital API Fallback (Ham HTTP isteklerinde DOM unrendered ise)
    if (!ratingValue || !ratingCount) {
      const ygData = await this.fetchYgDigitalRating($);
      if (ygData) {
        if (!ratingValue && ygData.ratingValue) ratingValue = ygData.ratingValue;
        if (!ratingCount && ygData.ratingCount) ratingCount = ygData.ratingCount;
      }
    }

    if (ratingValue || ratingCount) {
      return { ratingValue, ratingCount };
    }

    // 4. JSON-LD Fallback
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
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand) return brand;
    }
    // 2. Ticimax Script Model
    let scriptBrand = null;
    $('script').each((_, el) => {
      const text = $(el).html() || '';
      if (text.includes('brandName')) {
        const match = text.match(/"brandName"\s*:\s*"([^"]+)"/);
        if (match && match[1].trim()) {
          scriptBrand = match[1].trim();
        }
      }
    });
    if (scriptBrand) return scriptBrand;

    // 3. DOM Microdata
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
    // 4. Meta Tag
    const metaBrand = $('meta[property="product:brand"], meta[name="brand"], .product-brand, [data-brand]').first();
    if (metaBrand.length) {
      const txt = metaBrand.is('meta') ? metaBrand.attr('content') : (metaBrand.attr('data-brand') || metaBrand.text());
      if (txt && txt.trim()) return txt.trim();
    }
    return null;
  }
}

module.exports = HavitScraper;
