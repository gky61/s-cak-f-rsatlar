/**
 * Migros Store Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class MigrosScraper extends BaseProductScraper {
  get domain() { return 'migros.com.tr'; }

  canHandle(url) {
    return url.toLowerCase().includes('migros.com.tr');
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
      'img[class*="product-image"]',
      'img.product-image',
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

  extractProductId($, url) {
    const matchHex = (url || '').match(/-p-([a-fA-F0-9]+)/i);
    if (matchHex) {
      const dec = parseInt(matchHex[1], 16);
      if (!isNaN(dec) && dec > 0) return dec.toString();
    }
    const ogImg = $('meta[property="og:image"]').attr('content') || '';
    const matchImg = ogImg.match(/product\/(\d+)/);
    if (matchImg) return matchImg[1];
    return null;
  }

  async fetchScreensApi(productId) {
    if (!productId) return null;
    const endpoints = [
      `https://www.migros.com.tr/rest/hemen/products/screens/${productId}`,
      `https://www.migros.com.tr/rest/sanalmarket/products/screens/${productId}`,
      `https://www.migros.com.tr/rest/products/screens/${productId}`
    ];
    for (const ep of endpoints) {
      try {
        const res = await fetch(ep, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
          },
          signal: AbortSignal.timeout(3000)
        });
        if (res.ok) {
          const json = await res.json();
          if (json.data?.storeProductInfoDTO) {
            return json.data.storeProductInfoDTO;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  async scrapePrice($, url) {
    // 1. Screens API
    const productId = this.extractProductId($, url);
    if (productId) {
      const dto = await this.fetchScreensApi(productId);
      if (dto) {
        const p = (dto.shownPrice || dto.loyaltyPrice || dto.salePrice);
        if (p && p > 0) return p / 100;
      }
    }

    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 3. DOM Fallback
    const el = $('#new-amount, .amount').first();
    if (el.length) {
      const v = this.parsePriceText(el.text());
      if (v && v > 0) return v;
    }
    return null;
  }

  async scrapeOriginalPrice($, currentPrice, url) {
    if (!currentPrice || currentPrice <= 0) return null;

    const candidates = [];

    // 1. Screens API (Primary for Migros SPA)
    const productId = this.extractProductId($, url);
    if (productId) {
      const dto = await this.fetchScreensApi(productId);
      if (dto) {
        if (dto.regularPrice) {
          const reg = dto.regularPrice / 100;
          if (reg > currentPrice) candidates.push(reg);
        }
        if (Array.isArray(dto.badges)) {
          const promotedBadge = dto.badges.find(b => b.name === 'PRICE_PROMOTED' && b.value);
          if (promotedBadge) {
            const val = this.parsePriceText(promotedBadge.value);
            if (val && val > currentPrice) candidates.push(val);
          }
        }
      }
    }

    // 2. DOM: .single-price-amount (Migros specific non-Money price)
    $('.single-price-amount, [class*="single-price-amount"]').each((_, el) => {
      const txt = $(el).text().trim();
      const val = this.parsePriceText(txt);
      if (val && val > currentPrice) {
        candidates.push(val);
      }
    });

    // 3. DOM: Standard strikethrough / old price selectors
    const strikeSelectors = [
      '.old-price',
      '[class*="old-price"]',
      '[class*="original-price"]',
      '[class*="crossed-price"]',
      'del',
      's'
    ];
    for (const sel of strikeSelectors) {
      $(sel).each((_, el) => {
        const txt = $(el).text().trim();
        const val = this.parsePriceText(txt);
        if (val && val > currentPrice) {
          candidates.push(val);
        }
      });
    }

    // 4. JSON-LD highPrice or priceSpecification
    const product = this.findProductJsonLd($);
    if (product && product.offers) {
      const offers = Array.isArray(product.offers) ? product.offers[0] : product.offers;
      if (offers) {
        if (offers.highPrice) {
          const hp = parseFloat(offers.highPrice);
          if (!isNaN(hp) && hp > currentPrice) candidates.push(hp);
        }
        if (Array.isArray(offers.priceSpecification)) {
          for (const spec of offers.priceSpecification) {
            if (spec.priceType && spec.priceType.includes('Strikethrough') && spec.price) {
              const sp = parseFloat(spec.price);
              if (!isNaN(sp) && sp > currentPrice) candidates.push(sp);
            }
          }
        }
      }
    }

    if (candidates.length === 0) return null;
    candidates.sort((a, b) => a - b);
    return candidates[0];
  }


  cleanDescription(desc) {
    if (!desc) return '';
    let cleaned = desc.replace(/<[^>]*>/g, ' ');
    cleaned = cleaned.replace(/\s+/g, ' ');
    return cleaned.trim();
  }

  async scrapeDescription($) {
    let crmPrefix = '';

    // 1. Check DOM (for SSR or local test cases)
    const crmEl = $('.product-label.crm').first();
    if (crmEl.length) {
      const crmText = crmEl.text().trim().toLocaleUpperCase('tr-TR');
      if (crmText) {
        crmPrefix = crmText;
      }
    }

    // 2. If not found in DOM, fetch from Screens API
    if (!crmPrefix) {
      try {
        let imageUrl = '';
        const product = this.findProductJsonLd($);
        if (product && product['image']) {
          imageUrl = this.extractImageFromProductJson(product['image']) || '';
        }
        if (!imageUrl) {
          imageUrl = $('meta[property="og:image"]').attr('content') || '';
        }

        if (imageUrl) {
          const match = imageUrl.match(/product\/(\d+)/);
          if (match) {
            const productId = match[1];
            console.log(`[MigrosScraper] CRM label fetches from Screens API for product ID: ${productId}`);
            const apiRes = await fetch(`https://www.migros.com.tr/rest/hemen/products/screens/${productId}`, {
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
              }
            });
            if (apiRes.ok) {
              const json = await apiRes.json();
              const crmTags = json.data?.storeProductInfoDTO?.crmDiscountTags;
              if (Array.isArray(crmTags) && crmTags.length > 0) {
                const crmText = crmTags[0].tag;
                if (crmTags[0].tag) {
                  crmPrefix = crmTags[0].tag.trim().toLocaleUpperCase('tr-TR');
                  console.log(`[MigrosScraper] CRM tag found from API: "${crmTags[0].tag}"`);
                }
              }
            }
          }
        }
      } catch (err) {
        console.warn(`[MigrosScraper] CRM tag API fetch failed: ${err.message}`);
      }
    }

    let baseDesc = '';

    // 1. JSON-LD Product
    const product = this.findProductJsonLd($);
    if (product && product['description']) {
      baseDesc = this.cleanDescription(product['description'].toString());
    } else {
      // 2. JSON-LD Root
      const scripts = $('script[type="application/ld+json"]');
      for (let i = 0; i < scripts.length; i++) {
        try {
          const text = $(scripts[i]).text() || '';
          const sanitized = text.replace(/\r\n/g, ' ').replace(/\n/g, ' ').replace(/\r/g, ' ');
          const data = JSON.parse(sanitized);
          if (data && data.description) {
            baseDesc = this.cleanDescription(data.description.toString());
            break;
          }
        } catch (_) {}
      }
    }

    // 3. DOM Fallback if still empty
    if (!baseDesc) {
      const descEl = $('meta[name="description"], meta[property="og:description"]').first();
      if (descEl.length) {
        baseDesc = this.cleanDescription(descEl.attr('content'));
      }
    }

    if (crmPrefix) {
      return baseDesc ? `${crmPrefix}\n\n${baseDesc}` : crmPrefix;
    }
    return baseDesc || null;
  }

  async scrapePriceLabel($) {
    // 1. Check DOM
    const crmEl = $('.product-label.crm').first();
    if (crmEl.length) {
      const crmText = crmEl.text().trim().toLocaleUpperCase('tr-TR');
      if (crmText) return crmText;
    }

    // 2. API fallback
    try {
      let imageUrl = '';
      const product = this.findProductJsonLd($);
      if (product && product['image']) {
        imageUrl = this.extractImageFromProductJson(product['image']) || '';
      }
      if (!imageUrl) {
        imageUrl = $('meta[property="og:image"]').attr('content') || '';
      }

      if (imageUrl) {
        const match = imageUrl.match(/product\/(\d+)/);
        if (match) {
          const productId = match[1];
          const apiRes = await fetch(`https://www.migros.com.tr/rest/hemen/products/screens/${productId}`, {
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
            }
          });
          if (apiRes.ok) {
            const json = await apiRes.json();
            const crmTags = json.data?.storeProductInfoDTO?.crmDiscountTags;
            if (Array.isArray(crmTags) && crmTags.length > 0) {
              if (crmTags[0].tag) {
                return crmTags[0].tag.trim().toLocaleUpperCase('tr-TR');
              }
            }
          }
        }
      }
    } catch (err) {
      console.warn(`[MigrosScraper] CRM tag API fetch failed: ${err.message}`);
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'migros');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, ul.breadcrumb li a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('migros') && text !== title && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = MigrosScraper;
