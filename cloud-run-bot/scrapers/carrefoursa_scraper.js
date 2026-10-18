/**
 * CarrefourSA Product Scraper (carrefoursa.com)
 * Node.js portu
 * Dart karşılığı: lib/services/scrapers/carrefoursa_scraper.dart
 */

const BaseProductScraper = require('./base_scraper');

class CarrefoursaScraper extends BaseProductScraper {
  get domain() {
    return 'carrefoursa.com';
  }

  canHandle(url) {
    return url.toLowerCase().includes('carrefoursa.com');
  }

  scrapeImage($, url) {
    // 1. JSON-LD Product şeması görseli (yüksek çözünürlüklü mnresize/600/600/)
    const product = this.findProductJsonLd($);
    if (product && product.image) {
      const img = this.extractImageFromProductJson(product.image);
      if (img && !this.isLogoUrl(img)) {
        return this.resolveImageUrl(img, url);
      }
    }

    // 2. Open Graph og:image
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      return this.resolveImageUrl(ogImg, url);
    }

    // 3. csfour.com veya carrefoursa ürün görseli selector'ları
    const imgSelectors = [
      'img[src*="images.csfour.com/mnresize/600/600"]',
      'img[src*="images.csfour.com/mnresize"]',
      'img[src*="images.csfour.com"]',
      '.product-detail-slider img',
      '.product-image img',
      '.pdp-image-container img',
    ];

    for (const sel of imgSelectors) {
      let found = null;
      $(sel).each((_, el) => {
        if (found) return;
        const src = $(el).attr('data-src') || $(el).attr('src');
        if (src && !src.includes('banner') && !src.includes('icon')) {
          const resolved = this.resolveImageUrl(src, url);
          if (resolved && !this.isLogoUrl(resolved)) {
            found = resolved;
          }
        }
      });
      if (found) return found;
    }

    return null;
  }

  scrapeTitle($) {
    // 1. JSON-LD Product şeması
    const product = this.findProductJsonLd($);
    if (product && product.name) {
      const name = this.unescapeHtml(product.name.trim());
      if (name) return name;
    }

    // 2. h1 etiketi
    const h1 = $('h1').first().text().trim();
    if (h1) return this.unescapeHtml(h1);

    // 3. Open Graph og:title
    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle) {
      return this.unescapeHtml(ogTitle.replace(/\s*\|\s*CarrefourSA.*$/i, '').trim());
    }

    // 4. data-item_name attribute
    const dataName = $('[data-item_name]').first().attr('data-item_name');
    if (dataName && dataName.trim()) {
      return this.unescapeHtml(dataName.trim());
    }

    return null;
  }

  scrapeBrand($) {
    // 1. JSON-LD Product şeması
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand && brand.trim() && brand.toUpperCase() !== 'MARKASIZ' && !brand.startsWith('BRN-')) {
        return this.unescapeHtml(brand.trim());
      }
    }

    // 2. data-item_brand attribute
    const dataBrand = $('[data-item_brand]').first().attr('data-item_brand');
    if (dataBrand && dataBrand.trim() && dataBrand.toUpperCase() !== 'MARKASIZ' && !dataBrand.startsWith('BRN-')) {
      return this.unescapeHtml(dataBrand.trim());
    }

    return null;
  }

  scrapePrice($) {
    // 1. PDP kampanya / indirimli fiyat kartı: .pdp-price-card-campaign .item-price
    const campaignPriceEl = $('.pdp-price-card-campaign .item-price, .pdp-price-card-campaign [itemprop="price"]').first();
    if (campaignPriceEl.length > 0) {
      const contentVal = campaignPriceEl.attr('content');
      if (contentVal && contentVal.trim()) {
        const p = parseFloat(contentVal.trim());
        if (!isNaN(p) && p > 0) {
          return Math.round(p * 100) / 100;
        }
      }
      const parsedText = this.parsePriceText(campaignPriceEl.text());
      if (parsedText != null && parsedText > 0) {
        return parsedText;
      }
    }

    // 2. JSON-LD Product offers.price
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p != null && p > 0) {
        return Math.round(p * 100) / 100;
      }
    }

    // 3. Genel .item-price-contain veya .item-price
    const itemPriceEl = $('.item-price-contain .item-price, .item-price[itemprop="price"]').first();
    if (itemPriceEl.length > 0) {
      const contentVal = itemPriceEl.attr('content');
      if (contentVal && contentVal.trim()) {
        const p = parseFloat(contentVal.trim());
        if (!isNaN(p) && p > 0) {
          return Math.round(p * 100) / 100;
        }
      }
      const parsedText = this.parsePriceText(itemPriceEl.text());
      if (parsedText != null && parsedText > 0) {
        return parsedText;
      }
    }

    // 4. data-price attribute
    const dataPrice = $('[data-price]').first().attr('data-price');
    if (dataPrice && dataPrice.trim()) {
      const p = parseFloat(dataPrice.trim());
      if (!isNaN(p) && p > 0) {
        return Math.round(p * 100) / 100;
      }
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (currentPrice != null && currentPrice <= 0) return null;

    // PDP standart / indirimsiz fiyat kartı: .pdp-price-card-regular
    // Not: Alttaki "Benzer Ürünler" / tavsiye slider'larındaki (.hover-box) üzeri çizili fiyatlarla
    // karışmaması için doğrudan .pdp-price-card-regular seçicisi kullanılır.
    const regularPriceEl = $('.pdp-price-card-regular .js-variant-price, .pdp-price-card-regular .priceLineThrough, .pdp-price-card-regular .item-price').first();
    if (regularPriceEl.length > 0) {
      const contentVal = regularPriceEl.attr('content');
      if (contentVal && contentVal.trim()) {
        const p = parseFloat(contentVal.trim());
        if (!isNaN(p) && (currentPrice == null || p > currentPrice)) {
          return Math.round(p * 100) / 100;
        }
      }
      const parsedText = this.parsePriceText(regularPriceEl.text());
      if (parsedText != null && (currentPrice == null || parsedText > currentPrice)) {
        return parsedText;
      }
    }

    return null;
  }

  scrapePriceLabel($) {
    // 1. HTML script içerisindeki `var campaignList = "...";` (örn: "CarrefourSA Kart ile 2 Al 1 Öde")
    const html = $.html();
    const scriptMatch = html.match(/var\s+campaignList\s*=\s*["']([^"']+)["']/i);
    if (scriptMatch && scriptMatch[1] && scriptMatch[1].trim() && !scriptMatch[1].toLowerCase().includes('at sepete')) {
      return this.unescapeHtml(scriptMatch[1].trim());
    }

    // 2. data-campaign_type attribute (örn: data-campaign_type="CarrefourSA Kart ile 2 Al 1 Öde")
    const dataCamp = $('[data-campaign_type]').first().attr('data-campaign_type');
    if (dataCamp && dataCamp.trim() && !dataCamp.toLowerCase().includes('at sepete')) {
      return this.unescapeHtml(dataCamp.trim());
    }

    // 3. Kampanya rozeti: .product-detail-badge-position (örn: "CarrefourSA Kart ile 2 Al 1 Öde")
    // DİKKAT: "at sepete", "sepete ekle" gibi genel e-ticaret aksiyon etiketleri kampanya rozeti sanılmamalıdır!
    const campBadgeEl = $('.product-detail-badge-position').first();
    if (campBadgeEl.length > 0) {
      const txt = campBadgeEl.text().replace(/\s+/g, ' ').trim();
      const lower = txt.toLowerCase();
      if (txt &&
          !lower.includes('at sepete') &&
          !lower.includes('sepete at') &&
          !lower.includes('sepete ekle') &&
          (lower.includes('kart') || lower.includes('al') || lower.includes('öde') || lower.includes('%') || lower.includes('indirim'))) {
        return this.unescapeHtml(txt);
      }
    }

    // 4. PDP kart kampanyası veya indirim rozeti: .pdp-price-card-campaign veya .pd-price-cont .disc-badge-new
    if ($('.pdp-price-card-campaign').length > 0 || $('.pd-price-cont .disc-badge-new').length > 0) {
      const campaignLabelEl = $('.pdp-price-card-campaign .pdp-price-card-label').first();
      if (campaignLabelEl.length > 0) {
        const txt = campaignLabelEl.text().trim();
        if (txt) {
          return this.unescapeHtml(txt);
        }
      }
      return 'CarrefourSA Kart ile';
    }

    return null;
  }

  scrapeRating($) {
    const product = this.findProductJsonLd($);
    if (product) {
      const r = this.extractRatingFromProductJson(product);
      if (r && (r.ratingValue != null || r.ratingCount != null)) {
        return r;
      }
    }
    return { ratingValue: null, ratingCount: null };
  }

  scrapeDescription($) {
    // 1. JSON-LD Product description
    const product = this.findProductJsonLd($);
    if (product && product.description) {
      const desc = this.unescapeHtml(product.description.trim());
      if (desc) return desc;
    }

    // 2. Open Graph og:description
    const ogDesc = $('meta[property="og:description"]').attr('content');
    if (ogDesc && ogDesc.trim()) return this.unescapeHtml(ogDesc.trim());

    // 3. Meta name="description"
    const metaDesc = $('meta[name="description"]').attr('content');
    if (metaDesc && metaDesc.trim()) return this.unescapeHtml(metaDesc.trim());

    return null;
  }

  scrapeBreadcrumbs($) {
    const productTitle = this.scrapeTitle($) || '';
    
    // 1. JSON-LD BreadcrumbList
    const scripts = $('script[type="application/ld+json"]');
    for (let i = 0; i < scripts.length; i++) {
      try {
        const text = $(scripts[i]).text() || '';
        const sanitized = text.replace(/\r\n/g, ' ').replace(/\n/g, ' ').replace(/\r/g, ' ');
        const data = JSON.parse(sanitized);
        if (data && data['@type'] === 'BreadcrumbList' && Array.isArray(data.itemListElement)) {
          const result = [];
          for (const item of data.itemListElement) {
            const name = item.name || item.item?.name;
            if (name && typeof name === 'string' && name.trim()) {
              const str = name.trim();
              const lower = str.toLowerCase();
              if (lower !== 'ana sayfa' && lower !== 'home' && !lower.includes('carrefoursa') && str !== productTitle) {
                result.push(str);
              }
            }
          }
          if (result.length > 0) return result;
        }
      } catch (_) {}
    }

    // 2. data-item_category fallback
    const dataEl = $('[data-item_category]').first();
    if (dataEl.length > 0) {
      const cats = [];
      for (let i = 1; i <= 5; i++) {
        const attr = i === 1 ? 'data-item_category' : `data-item_category${i}`;
        const val = dataEl.attr(attr);
        if (val && val.trim() && val.trim() !== productTitle) {
          cats.push(val.trim());
        }
      }
      if (cats.length > 0) return cats;
    }

    return [];
  }
}

module.exports = CarrefoursaScraper;
