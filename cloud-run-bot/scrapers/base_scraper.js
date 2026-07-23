/**
 * Base Product Scraper - Tüm mağaza scraperları için temel sınıf (Node.js portu)
 * Dart karşılığı: lib/services/scrapers/base_scraper.dart
 */

const cheerio = require('cheerio');

class BaseProductScraper {
  get domain() { return ''; }

  canHandle(url) {
    return url.toLowerCase().includes(this.domain);
  }

  /** HTML'den görsel URL'sini çeker */
  scrapeImage($, url) { return null; }

  /** HTML'den ürün başlığını çeker */
  scrapeTitle($) { return null; }

  /** HTML'den ürün fiyatını çeker */
  scrapePrice($) { return null; }

  /** HTML'den ürünün indirimsiz (eski/liste) fiyatını çeker */
  scrapeOriginalPrice($, currentPrice) { return null; }

  /** HTML'den ürün açıklamasını çeker */
  scrapeDescription($) { return null; }

  /** HTML'den breadcrumb listesini çeker */
  scrapeBreadcrumbs($) { return []; }

  /** HTML'den fiyatın altında gösterilecek kampanya/CRM etiketini çeker */
  scrapePriceLabel($) { return null; }

  /** HTML'den rating (puan ve değerlendirme sayısı) verisini çeker: { ratingValue, ratingCount } */
  scrapeRating($) { return { ratingValue: null, ratingCount: null }; }

  /** HTML'den ürün markasını çeker */
  scrapeBrand($) { return null; }

  // ─── Yardımcı Metotlar ───

  /** Fiyat metnini temizleyip float değere dönüştürür */
  parsePriceText(priceText) {
    if (!priceText) return null;
    // Dart birebir eşdeğeri: replaceAll case-sensitive, tüm virgüller global replace
    let cleaned = priceText
      .replace(/TL/g, '')     // Dart: replaceAll('TL', '') — case-sensitive
      .replace(/₺/g, '')
      .replace(/\$/g, '')
      .replace(/€/g, '')
      .replace(/\s+/g, '')
      .trim();

    if (!cleaned) return null;

    if (cleaned.includes('.') && cleaned.includes(',')) {
      // Dart: replaceAll('.','').replaceAll(',','.') — tüm nokta ve virgüller
      cleaned = cleaned.replace(/\./g, '').replace(/,/g, '.');
    } else if (cleaned.includes(',')) {
      // Dart: replaceAll(',','.') — tüm virgüller
      cleaned = cleaned.replace(/,/g, '.');
    } else if (cleaned.includes('.')) {
      const parts = cleaned.split('.');
      if (parts.length === 2 && parts[1].length === 3) {
        cleaned = cleaned.replace(/\./g, '');
      }
    }

    const parsed = parseFloat(cleaned);
    return isNaN(parsed) ? null : parsed;
  }

  unescapeHtml(text) {
    if (!text) return '';
    try {
      // Cheerio load unescapes HTML entities automatically
      return cheerio.load(text).text();
    } catch (_) {
      return text;
    }
  }

  /** JSON-LD şemasından Product nesnesini bulur */
  findProductJsonLd($) {
    const scripts = $('script[type="application/ld+json"]');
    console.log(`   [JSON-LD] Sayfada ${scripts.length} adet ld+json script bloğu bulundu.`);
    for (let i = 0; i < scripts.length; i++) {
      try {
        const text = $(scripts[i]).text() || '';
        console.log(`   [JSON-LD] Blok ${i + 1} uzunluğu: ${text.length} karakter.`);
        
        // Remove bad characters and parse
        const sanitized = text.replace(/\r\n/g, ' ').replace(/\n/g, ' ').replace(/\r/g, ' ');
        const data = JSON.parse(sanitized);
        
        const product = this.findProductInJson(data);
        if (product) {
          console.log(`   [JSON-LD] Başarılı! Eşleşen Product şeması bulundu: "${product.name || 'İsimsiz'}"`);
          return product;
        }
      } catch (err) {
        console.log(`   [JSON-LD] ⚠️ Blok ${i + 1} JSON parse veya arama hatası: ${err.message}`);
      }
    }
    console.log(`   [JSON-LD] Sayfadaki hiçbir blokta Product şeması bulunamadı.`);
    return null;
  }

  /** JSON içinde recursive olarak Product tipindeki nesneyi arar */
  findProductInJson(json) {
    if (json && typeof json === 'object' && !Array.isArray(json)) {
      if (json['@type'] === 'Product' || json['@type'] === 'http://schema.org/Product' ||
          json['@type'] === 'ProductGroup' || json['@type'] === 'http://schema.org/ProductGroup') {
        return json;
      }
      if (Array.isArray(json['@graph'])) {
        for (const item of json['@graph']) {
          const res = this.findProductInJson(item);
          if (res) return res;
        }
      }
      for (const value of Object.values(json)) {
        if (value && typeof value === 'object') {
          const res = this.findProductInJson(value);
          if (res) return res;
        }
      }
    } else if (Array.isArray(json)) {
      for (const item of json) {
        const res = this.findProductInJson(item);
        if (res) return res;
      }
    }
    return null;
  }

  /** Product şemasından görsel URL'sini çeker */
  extractImageFromProductJson(imageField) {
    if (typeof imageField === 'string') return imageField;
    if (Array.isArray(imageField) && imageField.length > 0) {
      return this.extractImageFromProductJson(imageField[0]);
    }
    if (imageField && typeof imageField === 'object') {
      const urlVal = imageField['url'] || imageField['contentUrl'];
      if (urlVal) return this.extractImageFromProductJson(urlVal);
    }
    return null;
  }

  /** Product şemasından fiyatı çeker */
  extractPriceFromProductJson(product) {
    const offers = product['offers'];
    if (!offers) return null;

    if (offers && typeof offers === 'object' && !Array.isArray(offers)) {
      const priceVal = offers['price'] || offers['lowPrice'] || offers['highPrice'];
      if (priceVal != null) {
        const parsed = parseFloat(priceVal.toString());
        if (!isNaN(parsed)) return parsed;
        return this.parsePriceText(priceVal.toString());
      }
    } else if (Array.isArray(offers) && offers.length > 0) {
      let lowest = null;
      for (const offer of offers) {
        if (offer && typeof offer === 'object') {
          const priceVal = offer['price'];
          if (priceVal != null) {
            const p = parseFloat(priceVal.toString()) || this.parsePriceText(priceVal.toString());
            if (p != null && (lowest === null || p < lowest)) {
              lowest = p;
            }
          }
        }
      }
      return lowest;
    }
    return null;
  }

  /** URL'nin logo olup olmadığını kontrol eder */
  isLogoUrl(urlString) {
    const lower = urlString.toLowerCase();
    if (lower.endsWith('.svg') || lower.includes('.svg')) return true;
    if (lower.includes('logo') || lower.includes('default') || lower.includes('brand') ||
        lower.includes('banner') || lower.includes('pwa') || lower.includes('favicon') ||
        lower.includes('avatar') || lower.includes('/icons/') || lower.includes('/icon/')) {
      return true;
    }
    return false;
  }

  /** Görsel URL'sini çözümler (göreceli → mutlak) */
  resolveImageUrl(imageUrl, pageUrl) {
    if (!imageUrl || imageUrl.startsWith('data:')) return null;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) return imageUrl;
    if (imageUrl.startsWith('//')) return 'https:' + imageUrl;
    try {
      const base = new URL(pageUrl);
      return new URL(imageUrl, base).toString();
    } catch (_) {
      return null;
    }
  }

  /** BreadcrumbList JSON-LD'den breadcrumb listesini çeker (ortak yardımcı) */
  extractBreadcrumbsFromJsonLd($, productTitle, storeDomain) {
    const scripts = $('script[type="application/ld+json"]');
    for (let i = 0; i < scripts.length; i++) {
      try {
        const text = $(scripts[i]).text() || '';
        const sanitized = text.replace(/\r\n/g, ' ').replace(/\n/g, ' ').replace(/\r/g, ' ');
        const data = JSON.parse(sanitized);
        const breadcrumbs = this._extractBreadcrumbsFromJson(data, productTitle, storeDomain);
        if (breadcrumbs.length > 0) return breadcrumbs;
      } catch (_) {}
    }
    return [];
  }

  _extractBreadcrumbsFromJson(json, productTitle, storeDomain) {
    if (json && typeof json === 'object' && !Array.isArray(json)) {
      // BreadcrumbList kontrolü
      if (json['@type'] === 'BreadcrumbList' || json['@type'] === 'http://schema.org/BreadcrumbList') {
        const items = json['itemListElement'];
        if (Array.isArray(items)) {
          const breadcrumbs = [];
          for (const item of items) {
            if (item && typeof item === 'object') {
              let name = null;
              if (item['name'] != null) {
                name = this.unescapeHtml(item['name'].toString().trim());
              } else if (item['item'] && typeof item['item'] === 'object' && item['item']['name'] != null) {
                name = this.unescapeHtml(item['item']['name'].toString().trim());
              }
              if (name && name.length > 0) {
                const lower = name.toLowerCase();
                if (lower !== 'anasayfa' && lower !== 'ana sayfa' && lower !== 'home' &&
                    !lower.includes(storeDomain) && name !== productTitle && name.length < 50) {
                  breadcrumbs.push(name);
                }
              }
            }
          }
          if (breadcrumbs.length > 0) return breadcrumbs;
        }
      }

      // Product category kontrolü
      if (json['@type'] === 'Product' || json['@type'] === 'http://schema.org/Product' ||
          json['@type'] === 'ProductGroup' || json['@type'] === 'http://schema.org/ProductGroup') {
        const categoryField = json['category'];
        if (typeof categoryField === 'string' && categoryField.length > 0) {
          const parts = categoryField.split(/\s*>\s*|\s*\/\s*/)
            .map(e => this.unescapeHtml(e.trim()))
            .filter(e => e.length > 0)
            .filter(e => {
              const lower = e.toLowerCase();
              return lower !== 'anasayfa' && lower !== 'home' &&
                     !lower.includes(storeDomain) && e !== productTitle && e.length < 50;
            });
          if (parts.length > 0) return parts;
        } else if (categoryField && typeof categoryField === 'object' && !Array.isArray(categoryField)) {
          const nameVal = categoryField['name'];
          if (typeof nameVal === 'string' && nameVal.length > 0) {
            const parts = nameVal.split(/\s*>\s*|\s*\/\s*/)
              .map(e => this.unescapeHtml(e.trim()))
              .filter(e => e.length > 0)
              .filter(e => {
                const lower = e.toLowerCase();
                return lower !== 'anasayfa' && lower !== 'home' &&
                       !lower.includes(storeDomain) && e !== productTitle && e.length < 50;
              });
            if (parts.length > 0) return parts;
          }
        }
      }

      // Recursive arama
      for (const value of Object.values(json)) {
        if (value && typeof value === 'object') {
          const res = this._extractBreadcrumbsFromJson(value, productTitle, storeDomain);
          if (res.length > 0) return res;
        }
      }
    } else if (Array.isArray(json)) {
      for (const item of json) {
        const res = this._extractBreadcrumbsFromJson(item, productTitle, storeDomain);
        if (res.length > 0) return res;
      }
    }
    return [];
  }

  /** Product JSON-LD'den aggregateRating nesnesini ve ratingValue/ratingCount değerlerini çeker */
  extractRatingFromProductJson(product) {
    if (!product) return null;
    const ratingObj = product['aggregateRating'];
    if (ratingObj && typeof ratingObj === 'object') {
      const rawValue = ratingObj['ratingValue'];
      const rawCount = ratingObj['ratingCount'] || ratingObj['reviewCount'];

      const value = rawValue != null ? parseFloat(rawValue.toString().replace(',', '.')) : null;
      const count = rawCount != null ? parseInt(rawCount.toString()) : null;

      return {
        ratingValue: !isNaN(value) ? value : null,
        ratingCount: !isNaN(count) ? count : null,
      };
    }
    return null;
  }

  /** Product JSON-LD'den brand (marka) ismini çeker */
  extractBrandFromProductJson(product) {
    if (!product) return null;
    const brandObj = product['brand'];
    if (typeof brandObj === 'string' && brandObj.trim().length > 0) {
      return brandObj.trim();
    }
    if (brandObj && typeof brandObj === 'object') {
      const nameVal = brandObj['name'] || brandObj['@name'];
      if (nameVal && nameVal.toString().trim().length > 0) {
        return nameVal.toString().trim();
      }
    }
    return null;
  }
}

module.exports = BaseProductScraper;
