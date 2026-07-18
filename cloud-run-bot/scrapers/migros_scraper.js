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

  scrapePrice($) {
    // 1. JSON-LD
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }
    // 2. DOM Fallback
    const el = $('#new-amount, .amount').first();
    if (el.length) {
      const v = this.parsePriceText(el.text());
      if (v && v > 0) return v;
    }
    return null;
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
