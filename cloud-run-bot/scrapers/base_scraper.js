/**
 * Base Product Scraper - Tüm mağaza scraperları için temel sınıf (Node.js portu)
 * Dart karşılığı: lib/services/scrapers/base_scraper.dart
 */

const cheerio = require('cheerio');

// --- Fiyat Ayrıştırma için Performans ve DoS/ReDoS Korumalı Precompiled Regex Tanımları ---
const RAW_DUP_REGEX = /^(.+?(?:TL|₺|TRY|\$|€))\s*\1+$/i;
const CLEAN_CURRENCY_REGEX = /[₺$€\s]|TL|tl|Tl|TRY|try/gi;
const DECIMAL_DUP_REGEX = /^(\d+[.,]\d{1,2})\1+$/;
const INTEGER_DUP_REGEX = /^(\d{4,})\1+$/;
const HAS_LETTERS_OR_WORDS_REGEX = /[^\d.,]/;
const CURRENCY_PRICE_REGEX = /(?:^|[^\d])((?:\d{1,3}(?:\.\d{3})+|\d+)(?:[.,]\d{1,2})?)\s*(?:TL|₺|TRY|\$|€)/gi;
const GENERIC_PRICE_REGEX = /(?:^|[^\d])((?:\d{1,3}(?:\.\d{3})+|\d+)(?:[.,]\d{1,2})?)(?=[^\d]|$)/g;

class BaseProductScraper {
  get domain() { return ''; }

  canHandle(url) {
    return url.toLowerCase().includes(this.domain);
  }

  /** Scraper'ın kazıma öncesi hazırlık yapabilmesi (örneğin SPA / REST API sorguları) için çağrılır */
  async prepare($, url) {}

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

  /** HTML'den kanonik URL'yi çeker (<link rel="canonical"> veya <meta property="og:url">) */
  scrapeCanonicalUrl($, url) {
    try {
      if (!$) return null;
      let canonical = $('link[rel="canonical"]').attr('href');
      if (!canonical || !canonical.trim()) {
        canonical = $('meta[property="og:url"]').attr('content');
      }
      if (!canonical || !canonical.trim()) return null;
      canonical = canonical.trim();

      const resolved = this.resolveImageUrl(canonical, url);
      if (!resolved) return null;

      const pageHost = new URL(url).hostname.replace(/^www\./, '').toLowerCase();
      const canonHost = new URL(resolved).hostname.replace(/^www\./, '').toLowerCase();
      const isDomainMatch = pageHost === canonHost ||
        pageHost.endsWith('.' + canonHost) ||
        canonHost.endsWith('.' + pageHost);
      if (!isDomainMatch) {
        return null;
      }
      return resolved;
    } catch (_) {
      return null;
    }
  }

  // ─── Yardımcı Metotlar ───

  /** Fiyat metnini temizleyip float değere dönüştürür */
  parsePriceText(priceText) {
    if (!priceText || typeof priceText !== 'string') return null;
    const trimmed = priceText.trim();
    if (!trimmed || trimmed.length > 300) return null;

    // 1. Ham metin üzerinde para birimli tekrar kontrolü:
    // Örn: '269,91TL269,91TL' veya '99TL99TL' veya '38160 ₺ 38160 ₺'
    const rawDupMatch = trimmed.match(RAW_DUP_REGEX);
    if (rawDupMatch && rawDupMatch[1]) {
      return this.parsePriceText(rawDupMatch[1]);
    }

    // 2. Para birimi ve gereksiz karakterleri temizle
    let cleaned = trimmed.replace(CLEAN_CURRENCY_REGEX, '').trim();
    if (!cleaned) return null;

    // 3. Dublike fiyat savunması:
    // a) Ondalıklı dublike: örn. 269,91269,91 veya 299.90299.90 (ondalık ayırıcı ZORUNLU)
    const decDupMatch = cleaned.match(DECIMAL_DUP_REGEX);
    if (decDupMatch && decDupMatch[1]) {
      cleaned = decDupMatch[1];
    } else {
      // b) Tam sayı dublike: Yalnızca en az 4 basamaklı tam sayılar tekrar ettiğinde (örn. 3816038160 -> 38160)
      // 99, 88, 999, 1010, 2525 gibi geçerli perakende fiyatlarının bozulmasını kesinlikle engeller.
      const intDupMatch = cleaned.match(INTEGER_DUP_REGEX);
      if (intDupMatch && intDupMatch[1]) {
        cleaned = intDupMatch[1];
      }
    }

    // 4. Metin içinde halen yabancı harfler/kelimeler kalmışsa (örn: 'Sepette %10 indirimle 150 TL' veya 'Sepette 269,91'):
    if (HAS_LETTERS_OR_WORDS_REGEX.test(cleaned)) {
      // A) Öncelikle yanında para birimi olan gerçek fiyat kalıbını ara (yüzde indirimleri '%10' vb. elenir)
      const currencyMatches = [...trimmed.matchAll(CURRENCY_PRICE_REGEX)];
      if (currencyMatches.length > 0) {
        const lastMatch = currencyMatches[currencyMatches.length - 1][1];
        if (lastMatch && lastMatch.trim() !== trimmed) {
          return this.parsePriceText(lastMatch);
        }
      }

      // B) Para birimsiz genel sayı kalıbı (metindeki en son geçerli fiyat adayı)
      const genericMatches = [...trimmed.matchAll(GENERIC_PRICE_REGEX)];
      if (genericMatches.length > 0) {
        for (let i = genericMatches.length - 1; i >= 0; i--) {
          const candidate = genericMatches[i][1];
          if (candidate && candidate.length > 0) {
            const parsedCandidate = this.parsePriceText(candidate);
            if (parsedCandidate != null && parsedCandidate > 0) {
              return parsedCandidate;
            }
          }
        }
      }
    }

    // 5. Sayısal Ayrıştırma (Türkçe / Uluslararası Format Uyumu)
    const hasDot = cleaned.includes('.');
    const hasComma = cleaned.includes(',');

    if (hasDot && hasComma) {
      const lastDotIndex = cleaned.lastIndexOf('.');
      const lastCommaIndex = cleaned.lastIndexOf(',');
      if (lastCommaIndex > lastDotIndex) {
        // TR Format: 1.234,56 veya 1.234.567,89 -> noktalar binlik, virgül ondalık
        cleaned = cleaned.replace(/\./g, '').replace(/,/g, '.');
      } else {
        // US Format: 1,234.56 veya 1,234,567.89 -> virgüller binlik, nokta ondalık
        cleaned = cleaned.replace(/,/g, '');
      }
    } else if (hasComma) {
      const parts = cleaned.split(',');
      if (parts.length === 2) {
        if (parts[1].length === 3 && parts[0].length >= 1 && parts[0].length <= 3) {
          // Binlik ayırıcı (örn. 6,447 -> 6447)
          cleaned = cleaned.replace(/,/g, '');
        } else {
          // Ondalık ayırıcı (örn. 423,99 -> 423.99 veya 75,5 -> 75.5)
          cleaned = cleaned.replace(/,/g, '.');
        }
      } else {
        cleaned = cleaned.replace(/,/g, '');
      }
    } else if (hasDot) {
      const parts = cleaned.split('.');
      if (parts.length === 2) {
        if (parts[1].length === 3 && parts[0].length >= 1 && parts[0].length <= 3) {
          // Binlik ayırıcı (örn. 1.798 -> 1798 veya 48.020 -> 48020)
          cleaned = cleaned.replace(/\./g, '');
        }
      } else {
        // Çoklu nokta: 1.234.567 -> 1234567
        cleaned = cleaned.replace(/\./g, '');
      }
    }

    const val = parseFloat(cleaned);
    return (isNaN(val) || !isFinite(val)) ? null : val;
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
        const str = priceVal.toString();
        if (str.includes(',')) {
          return this.parsePriceText(str);
        }
        const parsed = parseFloat(str);
        if (!isNaN(parsed)) return parsed;
        return this.parsePriceText(str);
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
    if (lower.includes('sanalmarket-seo') || lower.includes('hemen-seo') || (lower.includes('migrosone.com') && lower.includes('/custom/'))) return true;
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
