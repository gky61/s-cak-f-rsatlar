/**
 * Mango Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class MangoScraper extends BaseProductScraper {
  get domain() { return 'mango.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('mango.com');
  }

  scrapeImage($, url) {
    // 1. og:image / twitter:image
    const ogImg = $('meta[property="og:image"]').attr('content') ||
                  $('meta[name="twitter:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const r = this.resolveImageUrl(ogImg, url);
      if (r) return r;
    }

    // 2. Modern DOM selectors (ZoomableImage / product gallery)
    const imgSelectors = [
      'button[class*="ZoomableImage"] img',
      'img[class*="ZoomableImage"]',
      'img[src*="media.mango.com"]',
      'img[src*="st.mngbcn.com"]',
      '.product-image img',
      'img[class*="product"]',
      'main img'
    ];
    for (const sel of imgSelectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src');
      if (src && !this.isLogoUrl(src)) {
        const r = this.resolveImageUrl(src, url);
        if (r) return r;
      }
    }

    // 3. Fallback: URL içindeki ürün kodu ve renk kodundan CDN görseli
    if (url) {
      const match = url.match(/(3\d{7})\/(\d{2})/);
      if (match) {
        return `https://st.mngbcn.com/rcs/pics/static/T3/fotos/S/${match[1]}_${match[2]}.jpg`;
      }
    }

    // 4. JSON-LD fallback
    const product = this.findProductJsonLd($);
    if (product && product['image']) {
      const img = this.extractImageFromProductJson(product['image']);
      if (img && !this.isLogoUrl(img)) {
        const r = this.resolveImageUrl(img, url);
        if (r) return r;
      }
    }
    return null;
  }

  scrapeTitle($) {
    // 1. og:title / title tag
    const ogTitle = $('meta[property="og:title"]').attr('content') || $('title').text();
    if (ogTitle && ogTitle.toLowerCase() !== 'null') {
      const cleaned = ogTitle
        .replace(/\s*\|\s*MANGO.*$/i, '')
        .replace(/\s*-\s*MANGO.*$/i, '')
        .replace(/\s*-\s*(?:Erkek|Kadın|Çocuk|Teen|Home|Baby|Bebek).*$/i, '')
        .trim();
      if (cleaned.length > 0) return cleaned;
    }

    // 2. DOM (h1 / product-name)
    const el = $('h1, [class*="ProductDetail"] h1, .product-name').first();
    if (el.length && el.text().trim().length > 0) return el.text().trim();

    // 3. JSON-LD fallback
    const product = this.findProductJsonLd($);
    if (product && product['name']) return product['name'].toString().trim();

    return null;
  }

  scrapePrice($) {
    // 1. Yeni Mango CSS Sınıfı: [class*="SinglePrice"][class*="discounted"] veya [class*="discounted"]
    const discEl = $('[class*="SinglePrice"][class*="discounted"], span[class*="discounted"]').first();
    if (discEl.length) {
      const val = this.parsePriceText(discEl.text());
      if (val && val > 0) return val;
    }

    // 2. Yeni Mango DOM: "Güncel fiyat [2.299,99 TL ]" sr-only seçicisi
    let guncelPrice = null;
    $('span[class*="srOnly"], span[class*="sr-only"]').each((_, el) => {
      const text = $(el).text();
      const match = text.match(/Güncel\s+fiyat\s*\[?([0-9.,]+)\s*TL/i);
      if (match && !guncelPrice) {
        const val = this.parsePriceText(match[1]);
        if (val && val > 0) guncelPrice = val;
      }
    });
    if (guncelPrice) return guncelPrice;

    // 3. Schema.org Offer (İndirimli ürün teklifi)
    let schemaPrice = null;
    $('[itemprop="offers"]').each((_, el) => {
      const isDisc = $(el).find('[class*="discounted"]').length > 0;
      if (isDisc && !schemaPrice) {
        const val = $(el).find('meta[itemprop="price"]').attr('content');
        if (val) {
          const num = parseFloat(val);
          if (!isNaN(num) && num > 0) schemaPrice = num;
        }
      }
    });
    if (schemaPrice) return schemaPrice;

    // 4. İndirimsiz tek fiyatlı ürünler için Schema.org Offer fiyatı
    $('[itemprop="offers"]').each((_, el) => {
      const isCrossed = $(el).find('[class*="crossed"]').length > 0;
      if (!isCrossed && !schemaPrice) {
        const val = $(el).find('meta[itemprop="price"]').attr('content');
        if (val) {
          const num = parseFloat(val);
          if (!isNaN(num) && num > 0) schemaPrice = num;
        }
      }
    });
    if (schemaPrice) return schemaPrice;

    // 5. DOM finalPrice (Eski sürüm uyumluluğu)
    const finalPriceEl = $('span[class*="finalPrice"], [class*="SinglePrice"][class*="finalPrice"]').first();
    if (finalPriceEl.length) {
      const val = this.parsePriceText(finalPriceEl.text());
      if (val && val > 0) return val;
    }

    // 6. Next.js script push data (Eski sayfa uyumluluğu)
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('price')) {
        const match = text.match(/\\?"price\\?"\s*:\s*\{\s*\\?"amount\\?"\s*:\s*([0-9.]+)/) ||
                      text.match(/\\?"price\\?"\s*:\s*\\?"?([0-9.]+)\\?"?/);
        if (match) {
          const val = parseFloat(match[1]);
          if (!isNaN(val) && val > 0) return val;
        }
      }
    }

    // 7. JSON-LD fallback
    const product = this.findProductJsonLd($);
    if (product) {
      const p = this.extractPriceFromProductJson(product);
      if (p && p > 0) return p;
    }

    // 8. DOM selectors fallback
    const priceSelectors = [
      '[data-testid="pdp.productInfo.price"]',
      '.pdp-price',
      '.product-price',
      'span[class*="price"]'
    ];
    for (const sel of priceSelectors) {
      const priceEl = $(sel).first();
      if (priceEl.length) {
        const parsed = this.parsePriceText(priceEl.text());
        if (parsed && parsed > 0) return parsed;
      }
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    // 1. Yeni Mango CSS Sınıfı: [class*="SinglePrice"][class*="crossed"] veya [class*="crossed"]
    const crossedEl = $('[class*="SinglePrice"][class*="crossed"], span[class*="crossed"]').first();
    if (crossedEl.length) {
      const val = this.parsePriceText(crossedEl.text());
      if (val && val > currentPrice) return val;
    }

    // 2. Yeni Mango DOM: "Üstü çizili ilk fiyat [2.999,99 TL ]" sr-only seçicisi
    let crossedPrice = null;
    $('span[class*="srOnly"], span[class*="sr-only"]').each((_, el) => {
      const text = $(el).text();
      const match = text.match(/Üstü\s+çizili\s+ilk\s+fiyat\s*\[?([0-9.,]+)\s*TL/i);
      if (match && !crossedPrice) {
        const val = this.parsePriceText(match[1]);
        if (val && val > currentPrice) crossedPrice = val;
      }
    });
    if (crossedPrice) return crossedPrice;

    // 3. Schema.org Offer (Üstü çizili / ilk fiyat meta etiketi)
    let schemaCrossed = null;
    $('[itemprop="offers"]').each((_, el) => {
      const isCrossed = $(el).find('[class*="crossed"]').length > 0;
      if (isCrossed && !schemaCrossed) {
        const val = $(el).find('meta[itemprop="price"]').attr('content');
        if (val) {
          const num = parseFloat(val);
          if (!isNaN(num) && num > currentPrice) schemaCrossed = num;
        }
      }
    });
    if (schemaCrossed) return schemaCrossed;

    // 4. Next.js script crossedOutPrices (Eski sayfa uyumluluğu)
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const text = $(scripts[i]).text() || '';
      if (text.includes('crossedOutPrices')) {
        const match = text.match(/\\?"crossedOutPrices\\?"\s*:\s*\[\{\s*\\?"amount\\?"\s*:\s*([0-9.]+)/);
        if (match) {
          const val = parseFloat(match[1]);
          if (!isNaN(val) && val > currentPrice) return val;
        }
      }
    }

    // 5. Fallback selectors
    let candidates = [];
    const selectors = [
      'del',
      's',
      '.old-price',
      '.original-price'
    ];
    for (const selector of selectors) {
      $(selector).each((_, el) => {
        const txt = $(el).text().trim();
        if (txt.includes('TL') || txt.includes('₺')) {
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

  scrapeDescription($) {
    const descEl = $('meta[property="og:description"], meta[name="description"]').first();
    if (descEl.length) {
      const content = descEl.attr('content')?.trim();
      if (content && content.toLowerCase() !== 'null') return content;
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'mango');
    if (breadcrumbs && breadcrumbs.length > 0) return breadcrumbs;

    // 1. Microdata / Schema.org BreadcrumbList
    const els = $('[itemprop="itemListElement"] [itemprop="name"], ol[itemtype*="BreadcrumbList"] span[itemprop="name"], ol[itemtype*="BreadcrumbList"] [itemprop="name"], [itemtype*="BreadcrumbList"] [itemprop="name"]');
    if (els.length) {
      const list = [];
      els.each((_, el) => {
        const text = $(el).text().trim();
        if (text) {
          const lower = text.toLowerCase();
          if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('mango') && lower !== title.toLowerCase().trim() && text.length < 50) {
            list.push(text);
          }
        }
      });
      if (list.length > 0) return list;
    }

    // 2. DOM Fallback
    const list = [];
    $('.breadcrumb a, .breadcrumbs a, .breadcrumb-item a, nav a, ol li a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const lower = text.toLowerCase();
        if (lower !== 'anasayfa' && lower !== 'ana sayfa' && !lower.includes('mango') && lower !== title.toLowerCase().trim() && text.length < 50) {
          list.push(text);
        }
      }
    });
    return list;
  }
}

module.exports = MangoScraper;
