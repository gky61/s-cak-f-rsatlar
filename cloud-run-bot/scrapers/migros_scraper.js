/**
 * Migros Store Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

const _docCache = new WeakMap();
const _docUrl = new WeakMap();

class MigrosScraper extends BaseProductScraper {
  constructor() {
    super();
    this._lastInfo = null;
    this._lastUrl = null;
  }

  get domain() { return 'migros.com.tr'; }

  canHandle(url) {
    return (url || '').toLowerCase().includes('migros.com.tr');
  }

  _getInfo($) {
    if ($ && (typeof $ === 'object' || typeof $ === 'function')) {
      try {
        const cached = _docCache.get($);
        if (cached) return cached;
      } catch (_) {}
    }
    return this._lastInfo || null;
  }

  _getUrl($) {
    if ($ && (typeof $ === 'object' || typeof $ === 'function')) {
      try {
        const cached = _docUrl.get($);
        if (cached) return cached;
      } catch (_) {}
    }
    const canonical = $ ? ($('link[rel="canonical"]').attr('href') || '') : '';
    return this._lastUrl || canonical || null;
  }

  extractProductId($, url) {
    // 1. URL pattern: -p-([a-fA-F0-9]+) (query ve fragment öncesi path sınırı ile)
    let cleanPath = '';
    try {
      if (url && (url.startsWith('http://') || url.startsWith('https://'))) {
        cleanPath = new URL(url).pathname;
      }
    } catch (_) {}
    const searchUrl = cleanPath || url || '';

    const matchHex = searchUrl.match(/-p-([a-fA-F0-9]+)(?:[/?#]|$)/i);
    if (matchHex) {
      const hex = matchHex[1];
      const dec = parseInt(hex, 16);
      if (!isNaN(dec) && dec > 0) return dec.toString();
      const decFallback = parseInt(hex, 10);
      if (!isNaN(decFallback) && decFallback > 0) return decFallback.toString();
    }

    // 2. Canonical URL or img elements
    if ($) {
      const canonical = $('link[rel="canonical"]').attr('href') || '';
      let canonicalPath = '';
      try {
        if (canonical && (canonical.startsWith('http://') || canonical.startsWith('https://'))) {
          canonicalPath = new URL(canonical).pathname;
        }
      } catch (_) {}
      const searchCanonical = canonicalPath || canonical;

      const matchCanonical = searchCanonical.match(/-p-([a-fA-F0-9]+)(?:[/?#]|$)/i);
      if (matchCanonical) {
        const hex = matchCanonical[1];
        const dec = parseInt(hex, 16);
        if (!isNaN(dec) && dec > 0) return dec.toString();
        const decFallback = parseInt(hex, 10);
        if (!isNaN(decFallback) && decFallback > 0) return decFallback.toString();
      }

      const ogImg = $('meta[property="og:image"]').attr('content') || '';
      const matchImg = ogImg.match(/product\/(\d+)/);
      if (matchImg) return matchImg[1];
    }

    const matchUrlProduct = (url || '').match(/product\/(\d+)/);
    if (matchUrlProduct) return matchUrlProduct[1];

    return null;
  }

  parseSlugTitle(url) {
    if (!url) return null;
    try {
      const parsed = new URL(url);
      const segments = parsed.pathname.split('/').filter(Boolean);
      if (segments.length === 0) return null;

      let lastSegment = segments[segments.length - 1];
      lastSegment = lastSegment.replace(/-p-[a-fA-F0-9]+$/i, '');
      lastSegment = lastSegment.replace(/\.(html|htm|php)$/i, '');
      if (!lastSegment.trim()) return null;

      const words = lastSegment.split(/[-_]/).filter(Boolean).map(w => {
        const lower = w.toLowerCase();
        if (lower === 'soke') return 'Söke';
        if (lower === 'kadin') return 'Kadın';
        if (lower === 'erkek') return 'Erkek';
        if (lower === 'cikolata') return 'Çikolata';
        if (lower === 'sut') return 'Süt';
        if (lower === 'seker') return 'Şeker';
        if (lower === 'cay') return 'Çay';
        if (lower === 'yag') return 'Yağ';
        return lower.charAt(0).toUpperCase() + lower.slice(1);
      });

      if (words.length === 0) return null;
      return words.join(' ');
    } catch (_) {
      return null;
    }
  }

  async prepare($, url) {
    this._lastUrl = url;
    this._lastInfo = null;
    if ($ && (typeof $ === 'object' || typeof $ === 'function')) {
      try { _docUrl.set($, url); } catch (_) {}
    }

    const productId = this.extractProductId($, url);
    if (productId) {
      const info = await this.fetchScreensApi(productId, url);
      if (info) {
        this._lastInfo = info;
        if ($ && (typeof $ === 'object' || typeof $ === 'function')) {
          try { _docCache.set($, info); } catch (_) {}
        }
      }
    }
  }

  _extractCandidatePrice(info) {
    if (!info) return Infinity;
    const prices = [];
    for (const k of ['shownPrice', 'loyaltyPrice', 'salePrice']) {
      let p = info[k];
      if (typeof p === 'string') p = parseFloat(p);
      if (typeof p === 'number' && !isNaN(p) && p > 0) {
        prices.push(p);
      }
    }
    if (prices.length === 0) return Infinity;
    prices.sort((a, b) => a - b);
    return prices[0];
  }

  _scoreCandidate(info) {
    if (!info) return -1;
    let shownPrice = info.shownPrice;
    if (typeof shownPrice === 'string') shownPrice = parseFloat(shownPrice);
    let regularPrice = info.regularPrice;
    if (typeof regularPrice === 'string') regularPrice = parseFloat(regularPrice);
    let loyaltyPrice = info.loyaltyPrice;
    if (typeof loyaltyPrice === 'string') loyaltyPrice = parseFloat(loyaltyPrice);
    let salePrice = info.salePrice;
    if (typeof salePrice === 'string') salePrice = parseFloat(salePrice);
    let discountRate = info.discountRate;
    if (typeof discountRate === 'string') discountRate = parseFloat(discountRate);
    if (typeof discountRate !== 'number' || isNaN(discountRate)) discountRate = 0;

    const effectivePrice = this._extractCandidatePrice(info);

    const hasDiscount = (
      (loyaltyPrice && regularPrice && loyaltyPrice < regularPrice) ||
      (shownPrice && regularPrice && shownPrice < regularPrice) ||
      (loyaltyPrice && salePrice && loyaltyPrice < salePrice) ||
      (shownPrice && salePrice && shownPrice < salePrice) ||
      (discountRate > 0) ||
      (Array.isArray(info.badges) && info.badges.some(b => b && (b.name === 'PRICE_PROMOTED' || b.name === 'CROSS_PROMOTED'))) ||
      (Array.isArray(info.crmDiscountTags) && info.crmDiscountTags.length > 0)
    );

    let score = 0;
    if (hasDiscount) {
      score = 1000 + (discountRate || 1);
      if (regularPrice && effectivePrice < regularPrice) {
        score += (regularPrice - effectivePrice) / 100;
      }
    }
    return score;
  }

  _mergeMissingFields(target, source) {
    if (!target || !source) return;
    if ((!target.images || (Array.isArray(target.images) && target.images.length === 0)) && source.images) {
      target.images = source.images;
    }
    if (!target.brand && source.brand) {
      target.brand = source.brand;
    }
    if ((!target.description || !target.description.toString().trim()) && source.description) {
      target.description = source.description;
    }
    if ((!target.badges || (Array.isArray(target.badges) && target.badges.length === 0)) && source.badges) {
      target.badges = source.badges;
    }
    if ((!target.crmDiscountTags || (Array.isArray(target.crmDiscountTags) && target.crmDiscountTags.length === 0)) && source.crmDiscountTags) {
      target.crmDiscountTags = source.crmDiscountTags;
    }
    if (!target.category && source.category) {
      target.category = source.category;
    }
    if ((!target.categoryAscendants || (Array.isArray(target.categoryAscendants) && target.categoryAscendants.length === 0)) && source.categoryAscendants) {
      target.categoryAscendants = source.categoryAscendants;
    }
  }

  async fetchScreensApi(productId, url) {
    if (!productId) return null;
    const effectiveUrl = url || this._lastUrl || '';
    const isHemenUrl = effectiveUrl.toLowerCase().includes('/hemen/');

    const fetchSingle = async (endpoint) => {
      try {
        const res = await fetch(endpoint, {
          headers: {
            'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
            'X-Pwa': 'true'
          },
          signal: AbortSignal.timeout(3000)
        });
        if (res.ok) {
          const json = await res.json();
          if (json.successful !== false && json.data?.storeProductInfoDTO) {
            return json.data.storeProductInfoDTO;
          }
        }
      } catch (_) {}
      return null;
    };

    // Parallel fetch both primary screens channels (General & Hemen)
    const [infoGeneralRes, infoHemenRes] = await Promise.all([
      fetchSingle(`https://www.migros.com.tr/rest/products/screens/${productId}`),
      fetchSingle(`https://www.migros.com.tr/rest/hemen/products/screens/${productId}`)
    ]);

    let infoGeneral = infoGeneralRes;
    let infoHemen = infoHemenRes;

    // Fallback: If both failed, try sanalmarket endpoint
    if (!infoGeneral && !infoHemen) {
      infoGeneral = await fetchSingle(`https://www.migros.com.tr/rest/sanalmarket/products/screens/${productId}`);
    }

    if (!infoGeneral && !infoHemen) return null;
    if (infoGeneral && !infoHemen) return infoGeneral;
    if (!infoGeneral && infoHemen) return infoHemen;

    const genScore = this._scoreCandidate(infoGeneral);
    const hemenScore = this._scoreCandidate(infoHemen);

    let chosen;
    let alternate;

    if (hemenScore > genScore) {
      chosen = infoHemen;
      alternate = infoGeneral;
    } else if (genScore > hemenScore) {
      chosen = infoGeneral;
      alternate = infoHemen;
    } else {
      const genPrice = this._extractCandidatePrice(infoGeneral);
      const hemenPrice = this._extractCandidatePrice(infoHemen);
      if (hemenPrice < genPrice) {
        chosen = infoHemen;
        alternate = infoGeneral;
      } else if (genPrice < hemenPrice) {
        chosen = infoGeneral;
        alternate = infoHemen;
      } else {
        if (isHemenUrl) {
          chosen = infoHemen;
          alternate = infoGeneral;
        } else {
          chosen = infoGeneral;
          alternate = infoHemen;
        }
      }
    }

    this._mergeMissingFields(chosen, alternate);
    return chosen;
  }

  scrapeImage($, url) {
    // 1. Screens API (En doğru ve yüksek çözünürlüklü ürün görseli)
    const info = this._getInfo($);
    if (info && Array.isArray(info.images)) {
      for (const imgObj of info.images) {
        if (imgObj && imgObj.urls) {
          const raw = imgObj.urls.PRODUCT_HD || imgObj.urls.PRODUCT_DETAIL || imgObj.urls.PRODUCT_LIST;
          if (raw && !this.isLogoUrl(raw)) {
            const r = this.resolveImageUrl(raw, url);
            if (r && !this.isLogoUrl(r)) return r;
          }
        }
      }
    }

    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const r = this.resolveImageUrl(img, url);
        if (r && !this.isLogoUrl(r)) return r;
      }
    }

    // 3. og:image (isLogoUrl ile sanalmarket-seo bannerları filtrelenir)
    const ogImg = $('meta[property="og:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r && !this.isLogoUrl(r)) return r;
    }

    // 4. DOM selectors
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
        if (r && !this.isLogoUrl(r)) return r;
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. Screens API
    const info = this._getInfo($);
    if (info && info.name) {
      const apiTitle = info.name.toString().trim();
      const lower = apiTitle.toLowerCase();
      if (apiTitle && lower !== 'migros' && lower !== 'migros sanalmarket') {
        return apiTitle;
      }
    }

    // 2. JSON-LD
    const product = this.findProductJsonLd($);
    if (product && product['name']) {
      const ldTitle = product['name'].toString().trim();
      const lower = ldTitle.toLowerCase();
      if (ldTitle && lower !== 'migros' && lower !== 'migros sanalmarket') {
        return ldTitle;
      }
    }

    // 3. DOM
    const el = $('h1.product-title, h1').first();
    if (el.length) {
      const domTitle = el.text().trim();
      const lower = domTitle.toLowerCase();
      if (domTitle && lower !== 'migros' && lower !== 'migros sanalmarket') {
        return domTitle;
      }
    }

    // 4. Slug Fallback
    const effectiveUrl = this._getUrl($);
    if (effectiveUrl) {
      const slugTitle = this.parseSlugTitle(effectiveUrl);
      if (slugTitle) return slugTitle;
    }

    return null;
  }

  async scrapePrice($, url) {
    // 1. Screens API
    let info = this._getInfo($);
    if (!info) {
      const effectiveUrl = url || this._getUrl($);
      const productId = this.extractProductId($, effectiveUrl);
      if (productId) {
        info = await this.fetchScreensApi(productId, effectiveUrl);
        if (info) {
          this._lastInfo = info;
          if ($ && (typeof $ === 'object' || typeof $ === 'function')) {
            try { _docCache.set($, info); } catch (_) {}
          }
        }
      }
    }

    if (info) {
      const prices = [];
      for (const k of ['shownPrice', 'loyaltyPrice', 'salePrice']) {
        let p = info[k];
        if (typeof p === 'string') p = parseFloat(p);
        if (typeof p === 'number' && !isNaN(p) && p > 0) {
          prices.push(p / 100);
        }
      }
      if (prices.length > 0) {
        prices.sort((a, b) => a - b);
        return prices[0];
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

    // 1. Screens API (Primary for Migros)
    let info = this._getInfo($);
    if (!info) {
      const effectiveUrl = url || this._getUrl($);
      const productId = this.extractProductId($, effectiveUrl);
      if (productId) {
        info = await this.fetchScreensApi(productId, effectiveUrl);
        if (info) {
          this._lastInfo = info;
          if ($ && (typeof $ === 'object' || typeof $ === 'function')) {
            try { _docCache.set($, info); } catch (_) {}
          }
        }
      }
    }

    if (info) {
      for (const k of ['regularPrice', 'salePrice']) {
        let regVal = info[k];
        if (typeof regVal === 'string') regVal = parseFloat(regVal);
        if (typeof regVal === 'number' && !isNaN(regVal) && regVal > 0) {
          const reg = regVal / 100;
          if (reg > currentPrice) candidates.push(reg);
        }
      }
      if (Array.isArray(info.badges)) {
        const promotedBadge = info.badges.find(b => b && b.name === 'PRICE_PROMOTED' && b.value);
        if (promotedBadge) {
          const val = this.parsePriceText(promotedBadge.value);
          if (val && val > currentPrice) candidates.push(val);
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
            if (spec && spec.priceType && spec.priceType.includes('Strikethrough') && spec.price) {
              const sp = parseFloat(spec.price);
              if (!isNaN(sp) && sp > currentPrice) candidates.push(sp);
            }
          }
        }
      }
    }

    if (candidates.length === 0) return null;
    const filtered = candidates.filter(c => c > currentPrice && c <= currentPrice * 5);
    if (filtered.length === 0) return null;
    filtered.sort((a, b) => a - b);
    return filtered[0];
  }

  cleanDescription(desc) {
    if (!desc) return '';
    let cleaned = desc.replace(/<[^>]*>/g, ' ');
    cleaned = cleaned.replace(/\s+/g, ' ');
    return cleaned.trim();
  }

  async scrapeDescription($) {
    let crmPrefix = '';

    // 1. Screens API'den CRM etiketi
    let info = this._getInfo($);
    if (!info) {
      const effectiveUrl = this._getUrl($);
      const productId = this.extractProductId($, effectiveUrl);
      if (productId) {
        info = await this.fetchScreensApi(productId, effectiveUrl);
        if (info) {
          this._lastInfo = info;
          if ($ && (typeof $ === 'object' || typeof $ === 'function')) {
            try { _docCache.set($, info); } catch (_) {}
          }
        }
      }
    }

    if (info && Array.isArray(info.crmDiscountTags) && info.crmDiscountTags.length > 0) {
      const rawTag = info.crmDiscountTags[0]?.tag;
      if (rawTag) {
        const upper = rawTag.trim().toLocaleUpperCase('tr-TR');
        if (upper && upper !== 'İYİ FİYAT' && upper !== 'IYI FIYAT' && !upper.includes('SADECE MİGROS')) {
          crmPrefix = `**${upper}**`;
        }
      }
    }

    // 2. DOM'dan CRM etiketi
    if (!crmPrefix) {
      const crmEl = $('.product-label.crm').first();
      if (crmEl.length) {
        const crmText = crmEl.text().trim().toLocaleUpperCase('tr-TR');
        if (crmText && crmText !== 'İYİ FİYAT' && crmText !== 'IYI FIYAT' && !crmText.includes('SADECE MİGROS')) {
          crmPrefix = `**${crmText}**`;
        }
      }
    }

    let baseDesc = '';

    // 3. Screens API'den açıklama
    if (info && info.description) {
      baseDesc = this.cleanDescription(info.description.toString());
    }

    // 4. JSON-LD Product
    if (!baseDesc) {
      const product = this.findProductJsonLd($);
      if (product && product['description']) {
        baseDesc = this.cleanDescription(product['description'].toString());
      } else {
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
    }

    // 5. DOM Meta
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
    // 1. Screens API (En doğru ve net veri kaynağı)
    let info = this._getInfo($);
    if (!info) {
      const effectiveUrl = this._getUrl($);
      const productId = this.extractProductId($, effectiveUrl);
      if (productId) {
        info = await this.fetchScreensApi(productId, effectiveUrl);
        if (info) {
          this._lastInfo = info;
          if ($ && (typeof $ === 'object' || typeof $ === 'function')) {
            try { _docCache.set($, info); } catch (_) {}
          }
        }
      }
    }

    if (info) {
      // A. crmDiscountTags
      const crmTags = info.crmDiscountTags;
      if (Array.isArray(crmTags) && crmTags.length > 0 && crmTags[0]?.tag) {
        const rawTag = crmTags[0].tag.trim();
        const upperTag = rawTag.toLocaleUpperCase('tr-TR');
        if (upperTag && upperTag !== 'İYİ FİYAT' && upperTag !== 'IYI FIYAT' && !upperTag.includes('SADECE MİGROS')) {
          return rawTag;
        }
      }

      // B. badges listesi
      const badges = Array.isArray(info.badges) ? info.badges : [];
      for (const b of badges) {
        if (b) {
          const bName = (b.name || '').toString();
          const bValue = (b.value || '').toString().trim();
          if (bName === 'CROSS_PROMOTED' && bValue) {
            return bValue;
          }
          if (bName === 'PRICE_PROMOTED') {
            return 'Money ile';
          }
        }
      }

      // C. Sadakat/Money fiyat farkı veya indirim oranı kontrolü
      let shownPrice = info.shownPrice;
      if (typeof shownPrice === 'string') shownPrice = parseFloat(shownPrice);
      let regularPrice = info.regularPrice;
      if (typeof regularPrice === 'string') regularPrice = parseFloat(regularPrice);
      let salePrice = info.salePrice;
      if (typeof salePrice === 'string') salePrice = parseFloat(salePrice);
      let loyaltyPrice = info.loyaltyPrice;
      if (typeof loyaltyPrice === 'string') loyaltyPrice = parseFloat(loyaltyPrice);
      let discountRate = info.discountRate;
      if (typeof discountRate === 'string') discountRate = parseFloat(discountRate);
      if (typeof discountRate !== 'number' || isNaN(discountRate)) discountRate = 0;

      if ((loyaltyPrice && regularPrice && loyaltyPrice < regularPrice) ||
          (loyaltyPrice && salePrice && loyaltyPrice < salePrice) ||
          (shownPrice && salePrice && shownPrice < salePrice) ||
          (shownPrice && regularPrice && shownPrice < regularPrice) ||
          (discountRate > 0)) {
        return 'Money ile';
      }
    }

    // 2. DOM Kontrolü
    const crmEl = $('.product-label.crm, .product-badges .badge').first();
    if (crmEl.length) {
      const rawText = crmEl.text().trim();
      const upper = rawText.toLocaleUpperCase('tr-TR');
      if (upper && upper !== 'İYİ FİYAT' && upper !== 'IYI FIYAT' && !upper.includes('SADECE MİGROS') && upper.length <= 50) {
        return rawText;
      }
    }

    return null;
  }

  scrapeBrand($) {
    const info = this._getInfo($);
    if (info?.brand?.name) {
      return info.brand.name.toString().trim();
    }

    const product = this.findProductJsonLd($);
    if (product && product.brand) {
      if (typeof product.brand === 'string') return product.brand.trim();
      if (product.brand.name) return product.brand.name.toString().trim();
    }

    const brandEl = $('a[class*="brand"], .brand-name').first();
    if (brandEl.length) {
      return brandEl.text().trim();
    }

    return null;
  }

  scrapeBreadcrumbs($) {
    const info = this._getInfo($);
    if (info) {
      const list = [];
      if (Array.isArray(info.categoryAscendants)) {
        for (const c of info.categoryAscendants) {
          if (c && c.name && c.name.toString().trim()) {
            list.push(c.name.toString().trim());
          }
        }
      }
      if (info.category?.name) {
        list.push(info.category.name.toString().trim());
      }
      if (list.length > 0) return list;
    }

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
