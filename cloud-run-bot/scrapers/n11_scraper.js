/**
 * N11 Scraper (Node.js port)
 * Master: lib/services/scrapers/n11_scraper.dart
 */
const https = require('https');
const BaseProductScraper = require('./base_scraper');

class N11Scraper extends BaseProductScraper {
  constructor() {
    super();
    this._lastApiResult = null;
  }

  get domain() { return 'n11.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('n11.com');
  }

  _postJson(url, postData, timeoutMs = 4000) {
    return new Promise((resolve) => {
      try {
        const parsedUrl = new URL(url);
        const dataStr = JSON.stringify(postData);

        const options = {
          hostname: parsedUrl.hostname,
          port: parsedUrl.port || 443,
          path: parsedUrl.pathname + (parsedUrl.search || ''),
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json, text/plain, */*',
            'User-Agent': 'WhatsApp/2.23.4.15 A',
            'Accept-Language': 'tr-TR,tr;q=0.9',
            'Content-Length': Buffer.byteLength(dataStr)
          },
          timeout: timeoutMs
        };

        const req = https.request(options, (res) => {
          let raw = '';
          res.on('data', chunk => raw += chunk);
          res.on('end', () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              try {
                resolve(JSON.parse(raw));
              } catch (_) {
                resolve(null);
              }
            } else {
              resolve(null);
            }
          });
        });

        req.on('timeout', () => {
          req.destroy();
          resolve(null);
        });

        req.on('error', () => {
          resolve(null);
        });

        req.write(dataStr);
        req.end();
      } catch (_) {
        resolve(null);
      }
    });
  }

  async _fetchPersonalizedDetailPrice($) {
    try {
      const model = this._getN11Model($);
      const p = model?.product;
      const rawProductId = model?.productId || p?.id;
      if (!rawProductId) return null;

      const productId = parseInt(rawProductId.toString(), 10);
      if (isNaN(productId) || productId <= 0) return null;

      const categoryId = p?.category?.id ? parseInt(p.category.id.toString(), 10) : null;

      let slug = '';
      const canonical = model?.seoMetaData?.canonical ||
                        $('link[rel="canonical"]').attr('href') ||
                        $('meta[property="og:url"]').attr('content') ||
                        p?.url;
      if (canonical && canonical.includes('/urun/')) {
        try {
          const parsed = new URL(canonical, 'https://www.n11.com');
          const pathname = parsed.pathname;
          if (pathname.includes('/urun/')) {
            slug = pathname.substring(pathname.indexOf('/urun/') + 6);
            if (slug.includes('?')) slug = slug.substring(0, slug.indexOf('?'));
          }
        } catch (_) {}
      }

      const postData = {
        productId: productId,
        categoryId: categoryId,
        productSlug: slug,
        vue: true
      };

      const data = await this._postJson('https://www.n11.com/rest/v1/personalizedDetail', postData);
      if (data && typeof data === 'object') {
        const resp = data.response;
        if (resp && typeof resp === 'object') {
          const prod = resp.product && typeof resp.product === 'object' ? resp.product : null;

          const instantDiscountStr = resp.instantDiscountedPrice?.toString();
          const finalPriceStr = prod?.finalPrice?.toString();
          const oldPriceStr = prod?.oldPrice?.toString();
          const displayPriceStr = prod?.displayPrice?.toString();
          const badge = prod?.finalPriceBadge?.toString() || resp.instantDiscountMessage?.toString();

          const instantDiscount = instantDiscountStr ? this.parsePriceText(instantDiscountStr) : null;
          const finalPrice = finalPriceStr ? this.parsePriceText(finalPriceStr) : null;
          const oldPrice = oldPriceStr ? this.parsePriceText(oldPriceStr) : null;
          const displayPrice = displayPriceStr ? this.parsePriceText(displayPriceStr) : null;

          // 1. İndirimli Satış Fiyatı
          let discPrice = instantDiscount != null ? instantDiscount : finalPrice;
          if (discPrice == null && displayPrice != null && oldPrice != null && displayPrice < oldPrice) {
            discPrice = displayPrice;
          }

          // 2. İndirimsiz Liste / Piyasa Fiyatı
          let origPrice = null;
          if (oldPrice != null && discPrice != null && oldPrice > discPrice) {
            origPrice = oldPrice;
          } else if (displayPrice != null && discPrice != null && displayPrice > discPrice) {
            origPrice = displayPrice;
          }

          if (discPrice != null && discPrice > 0) {
            const result = {
              discountedPrice: discPrice,
              originalPrice: origPrice
            };
            this._lastApiResult = result;
            return result;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  _getN11Model($) {
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).html() || '';
      if (text.includes('window.model =')) {
        const modelIndex = text.indexOf('window.model =');
        if (modelIndex !== -1) {
          const startJson = text.indexOf('{', modelIndex);
          const endJson = text.lastIndexOf('}');
          if (startJson !== -1 && endJson !== -1 && endJson > startJson) {
            try {
              return JSON.parse(text.substring(startJson, endJson + 1));
            } catch (_) {}
          }
        }
      }
    }
    return null;
  }

  _findValueRecursive(json, targetKey) {
    if (json && typeof json === 'object' && !Array.isArray(json)) {
      if (json.hasOwnProperty(targetKey)) return json[targetKey];
      for (const value of Object.values(json)) {
        if (value && typeof value === 'object') {
          const res = this._findValueRecursive(value, targetKey);
          if (res != null) return res;
        }
      }
    } else if (Array.isArray(json)) {
      for (const item of json) {
        const res = this._findValueRecursive(item, targetKey);
        if (res != null) return res;
      }
    }
    return null;
  }

  scrapeImage($, url) {
    // 1. window.model JSON'ından görseli çekmeyi dene (Öncelikli)
    const model = this._getN11Model($);
    if (model) {
      const images = model?.product?.images;
      if (Array.isArray(images) && images.length > 0) {
        const path = images[0]?.path?.toString();
        if (path) {
          // {0} boyut belirtecini standart 400_570 boyutuyla değiştir
          const resolvedPath = path.replace('{0}', '400_570');
          const resolved = this.resolveImageUrl(resolvedPath, url);
          if (resolved && !this.isLogoUrl(resolved)) return resolved;
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    const selectors = [
      '.big-image-wrapper img',
      'img.swiper-image',
      'img.swiper-lazy',
      'img[class*="swiper"]',
      '#product-image img',
      '.product-images img'
    ];
    for (const sel of selectors) {
      const elements = $(sel);
      for (let i = 0; i < elements.length; i++) {
        const el = $(elements[i]);
        const src = el.attr('src') || el.attr('data-src') || el.attr('data-lazy-src');
        if (src && !src.startsWith('data:') && !this.isLogoUrl(src)) {
          const resolved = this.resolveImageUrl(src, url);
          if (resolved) return resolved;
        }
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. window.model JSON'ından başlığı çekmeyi dene (Öncelikli)
    const model = this._getN11Model($);
    if (model) {
      const p = model.product;
      const title = p?.title || p?.name || p?.proName || model.seoMetaData?.title;
      if (title && title.toString().trim().length > 0) {
        return title.toString().trim();
      }
    }

    // 2. DOM Başlık Seçicileri (h1.title, .titleArea h1.title, h1.proName)
    const el = $('.titleArea h1.title, h1.title, h1.proName, h1.product-name, h1[class*="title"], .proName').first();
    if (el.length && el.text().trim().length > 0) {
      return el.text().trim();
    }
    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle && ogTitle.trim().length > 0) {
      return ogTitle.trim();
    }

    // 3. JSON-LD Şeması Fallback
    const product = this.findProductJsonLd($);
    if (product && product.name) {
      return product.name
        .replace(/\s*Fiyatları ve Özellikleri.*$/i, '')
        .replace(/\s*-\s*n11\.com$/i, '')
        .trim();
    }

    // 4. window.model product JSON bloğundan regex ile çekmeyi dene
    const html = $.html();
    const productTitleMatch = html.match(/"product"\s*:\s*\{[^}]*"title"\s*:\s*"([^"]+)"/);
    if (productTitleMatch && productTitleMatch[1].trim().length > 0) {
      return productTitleMatch[1].trim();
    }

    const proNameMatch = html.match(/"proName"\s*:\s*"([^"]+)"/);
    if (proNameMatch && proNameMatch[1].trim().length > 0) {
      return proNameMatch[1].trim();
    }

    return null;
  }

  async scrapePrice($) {
    // 1. Canlı API Çağrısı (Öncelikli)
    const apiResult = await this._fetchPersonalizedDetailPrice($);
    if (apiResult?.discountedPrice != null && apiResult.discountedPrice > 0) {
      return apiResult.discountedPrice;
    }

    // 2. window.model JSON'ından fiyatı çekmeyi dene (Öncelikli Statik Fallback)
    const model = this._getN11Model($);
    if (model) {
      const p = model.product;
      const pers = p?.personalizedData;

      // Eğer personalizedData zaten model içinde varsa (nadir durumlar)
      const instantPrice = pers?.instantDiscountedPrice;
      if (instantPrice != null) {
        const parsed = typeof instantPrice === 'number' ? instantPrice : this.parsePriceText(instantPrice.toString());
        if (parsed != null && parsed > 0) return parsed;
      }

      const finalPrice = pers?.product?.finalPrice || p?.finalPriceFloat || p?.finalPrice;
      if (finalPrice != null) {
        const parsed = typeof finalPrice === 'number' ? finalPrice : this.parsePriceText(finalPrice.toString());
        if (parsed != null && parsed > 0) return parsed;
      }

      // price ve displayPrice alanlarını parse et ve karşılaştır!
      let priceVal = null;
      let displayVal = null;
      if (p) {
        const rawPrice = p.priceFloat !== undefined ? p.priceFloat : p.price;
        if (rawPrice != null) {
          priceVal = typeof rawPrice === 'number' ? rawPrice : this.parsePriceText(rawPrice.toString());
        }
        const rawDisplay = p.displayPriceFloat !== undefined ? p.displayPriceFloat : p.displayPrice;
        if (rawDisplay != null) {
          displayVal = typeof rawDisplay === 'number' ? rawDisplay : this.parsePriceText(rawDisplay.toString());
        }
      }

      if (priceVal != null && displayVal != null && priceVal > 0 && displayVal > 0) {
        // İki fiyat da mevcutsa DÜŞÜK OLAN satış fiyatıdır (indirimli fiyattır)!
        return priceVal < displayVal ? priceVal : displayVal;
      } else if (priceVal != null && priceVal > 0) {
        return priceVal;
      } else if (displayVal != null && displayVal > 0) {
        return displayVal;
      }
    }

    // 3. window.model içinden regex ile fiyat çekmeyi dene (Fallback 1)
    const html = $.html();
    const fpMatch = html.match(/"finalPrice"\s*:\s*"([^"]+)"/);
    if (fpMatch) {
      const val = this.parsePriceText(fpMatch[1]);
      if (val && val > 0) return val;
    }
    const pMatch = html.match(/"price"\s*:\s*"([^"]+)"/);
    if (pMatch) {
      const val = this.parsePriceText(pMatch[1]);
      if (val && val > 0) return val;
    }

    // 4. DOM Seçicileri (Fallback 2)
    const el = $('.newPrice ins, ins, .newPrice, meta[property="product:price:amount"]').first();
    if (el.length) {
      const text = el.is('meta') ? el.attr('content') : el.text();
      return this.parsePriceText(text || '');
    }
    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    // 1. Canlı API Sonucu Önceliği (_lastApiResult)
    if (this._lastApiResult?.originalPrice != null && this._lastApiResult.originalPrice > currentPrice) {
      return this._lastApiResult.originalPrice;
    }

    let candidates = [];

    // 2. window.model JSON'ından eski / liste fiyatlarını çek
    const model = this._getN11Model($);
    if (model) {
      const p = model.product;
      const pers = p?.personalizedData;

      const modelCandidates = [
        pers?.product?.oldPrice,
        pers?.product?.displayPrice,
        p?.displayPriceFloat,
        p?.displayPrice,
        p?.oldPriceFloat,
        p?.oldPrice,
        p?.priceFloat,
        p?.price
      ];

      for (const val of modelCandidates) {
        if (val !== undefined && val !== null) {
          const parsed = typeof val === 'number' ? val : this.parsePriceText(val.toString());
          if (parsed !== null && parsed > currentPrice) {
            candidates.push(parsed);
          }
        }
      }
    }

    // 3. DOM selectors for old / strikethrough / original prices
    const selectors = [
      '.oldPrice',
      '.old-price',
      '[class*="oldPrice"]',
      '[class*="old-price"]',
      'del',
      's'
    ];

    for (const selector of selectors) {
      $(selector).each((_, el) => {
        const txt = $(el).text().trim();
        const parsed = this.parsePriceText(txt);
        if (parsed !== null && parsed > currentPrice) {
          candidates.push(parsed);
        }
      });
    }

    if (candidates.length === 0) return null;

    candidates = candidates.filter(c => c > currentPrice && c <= currentPrice * 5);
    if (candidates.length === 0) return null;

    candidates.sort((a, b) => a - b);
    return candidates[0];
  }


  scrapeDescription($) {
    // 1. window.model JSON'ından açıklamayı çekmeyi dene (Öncelikli)
    const model = this._getN11Model($);
    if (model) {
      const desc = model?.seoMetaData?.description;
      if (desc && desc.toString().trim().length > 0) {
        return desc.toString().trim();
      }
    }

    // 2. DOM Seçicileri (Fallback)
    const descEl = $('meta[name="description"], meta[property="og:description"]').first();
    return descEl.length ? descEl.attr('content')?.trim() : null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';

    // window.model JSON'ından aramayı dene
    const model = this._getN11Model($);
    if (model) {
      const cat = model?.category || model?.categories;
      if (typeof cat === 'string' && cat.length > 0) {
        const parts = cat.split(/\s*>\s*|\s*\/\s*/).map(e => e.trim())
          .filter(e => e.length > 0)
          .filter(e => {
            const l = e.toLowerCase();
            return l !== 'anasayfa' && l !== 'ana sayfa' && !l.includes('n11') && l !== title.toLowerCase().trim() && e.length < 50;
          });
        if (parts.length > 0) return parts;
      } else if (Array.isArray(cat)) {
        const list = [];
        for (const c of cat) {
          const name = (typeof c === 'object' && c.name) ? c.name.toString().trim() : (typeof c === 'string' ? c.trim() : null);
          if (name) {
            const l = name.toLowerCase();
            if (l !== 'anasayfa' && l !== 'ana sayfa' && !l.includes('n11') && l !== title.toLowerCase().trim() && name.length < 50) list.push(name);
          }
        }
        if (list.length > 0) return list;
      }
    }

    // DOM Fallback
    const breadcrumbs = [];
    $('.breadcrumb-item a, .breadcrumb a, .breadcrumb-group a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const l = text.toLowerCase();
        if (l !== 'anasayfa' && l !== 'ana sayfa' && !l.includes('n11') && l !== title.toLowerCase().trim() && text.length < 50) breadcrumbs.push(text);
      }
    });
    if (breadcrumbs.length > 0) return breadcrumbs;
    return this.extractBreadcrumbsFromJsonLd($, title, 'n11');
  }

  scrapeRating($) {
    let ratingValue = null;
    let ratingCount = null;

    // 1. JSON-LD Şeması
    const product = this.findProductJsonLd($);
    if (product) {
      const rating = this.extractRatingFromProductJson(product);
      if (rating && (rating.ratingValue != null || rating.ratingCount != null)) {
        return rating;
      }
    }

    // 2. window.model Fallback
    const model = this._getN11Model($);
    if (model) {
      const ratingScore = this._findValueRecursive(model, 'ratingScore') ||
                          this._findValueRecursive(model, 'ratingValue') ||
                          this._findValueRecursive(model, 'averageRating');
      if (ratingScore != null) {
        const val = parseFloat(ratingScore.toString().replace(',', '.'));
        if (!isNaN(val) && val > 0 && val <= 5.0) ratingValue = val;
      }

      const reviewCount = this._findValueRecursive(model, 'reviewCount') ||
                          this._findValueRecursive(model, 'ratingCount') ||
                          this._findValueRecursive(model, 'commentCount');
      if (reviewCount != null) {
        const cnt = parseInt(reviewCount.toString(), 10);
        if (!isNaN(cnt) && cnt > 0) ratingCount = cnt;
      }
    }

    // 3. DOM Fallback
    if (!ratingValue) {
      const ratingEl = $('.ratingScore, [itemprop="ratingValue"], .rating-score, .rating-cont .rating-text').first();
      if (ratingEl.length) {
        const text = ratingEl.text().trim();
        const match = text.match(/([0-5][.,]\d)/);
        if (match) {
          const val = parseFloat(match[1].replace(',', '.'));
          if (!isNaN(val) && val > 0 && val <= 5.0) ratingValue = val;
        }
      }
    }

    if (!ratingCount) {
      const countEl = $('.ratingCount, [itemprop="reviewCount"], [itemprop="ratingCount"], .review-count').first();
      if (countEl.length) {
        const text = countEl.text().trim();
        const match = text.match(/(\d+)/);
        if (match) {
          const cnt = parseInt(match[1], 10);
          if (!isNaN(cnt) && cnt > 0) ratingCount = cnt;
        }
      }
    }

    return { ratingValue, ratingCount };
  }

  scrapeBrand($) {
    // 1. JSON-LD Şeması
    const product = this.findProductJsonLd($);
    if (product) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand) return brand;
    }

    // 2. window.model Fallback
    const model = this._getN11Model($);
    if (model) {
      const brand = model?.product?.brand?.name ||
                    model?.product?.brandName ||
                    this._findValueRecursive(model, 'brandName');
      if (brand && brand.toString().trim().length > 0) {
        return brand.toString().trim();
      }
    }

    // 3. DOM Fallback
    const brandEl = $('.brand-name, [itemprop="brand"], .unf-p-detail-brand').first();
    if (brandEl.length) {
      const text = brandEl.text().trim();
      if (text.length > 0) return text;
    }

    return null;
  }
}

module.exports = N11Scraper;
