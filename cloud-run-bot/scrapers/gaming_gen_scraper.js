const BaseProductScraper = require('./base_scraper');

/**
 * Gaming Gen (gaming.gen.tr) Mağaza Kazıyıcı Sınıfı
 * WooCommerce altyapısını kullanır.
 */
class GamingGenScraper extends BaseProductScraper {
  get domain() {
    return 'gaming.gen.tr';
  }

  canHandle(url) {
    return url.toLowerCase().includes('gaming.gen.tr');
  }

  scrapeTitle($) {
    // 1. DOM Ürün başlığı (Öncelikli)
    const titleEl = $('h1.product_title, h1.entry-title, .product_title').first();
    if (titleEl.length) {
      const title = titleEl.text().trim();
      if (title) return title;
    }

    // 2. JSON-LD Şeması
    const product = this.findProductJsonLd($);
    if (product && product.name) {
      const name = product.name.trim();
      if (name) return name;
    }

    // 3. Fallback: H1 veya og:title
    const h1 = $('h1').first().text().trim();
    if (h1) return h1;

    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle && ogTitle.trim()) {
      let clean = ogTitle.trim();
      clean = clean.replace(/\s*[-|]\s*(?:Gaming\.Gen\.TR|Gaming Gen).*$/i, '').trim();
      if (clean) return clean;
    }

    return null;
  }

  scrapePrice($, html) {
    // 1. DOM Ana Ürün Fiyatı (.summary veya .entry-summary doğrudan altındaki .price)
    // WooCommerce'da ana ürün fiyatı .summary > .price veya .entry-summary > .price içindedir.
    const summary = $('.summary, .entry-summary, .product-summary').first();
    const mainPriceEl = summary.children('.price, p.price').first();

    if (mainPriceEl.length) {
      // İndirimli satış fiyatı ins içindedir
      const insEl = mainPriceEl.find('ins .woocommerce-Price-amount, ins');
      if (insEl.length) {
        const val = this.parsePriceText(insEl.first().text());
        if (val !== null && val > 0) return val;
      }

      // Normal veya tek fiyat (.woocommerce-Price-amount)
      const amountEl = mainPriceEl.find('.woocommerce-Price-amount');
      if (amountEl.length) {
        const val = this.parsePriceText(amountEl.first().text());
        if (val !== null && val > 0) return val;
      }

      // Düz metin (örn. "En Düşük: 99.999,00 ₺")
      const textVal = this.parsePriceText(mainPriceEl.text());
      if (textVal !== null && textVal > 0) return textVal;
    }

    // 2. Genel DOM Seçicileri (Fallback)
    const fallbackPriceEl = $('p.price, .price').not('.bundled_product_optional_checkbox .price, .bundle_form .price').first();
    if (fallbackPriceEl.length) {
      const insEl = fallbackPriceEl.find('ins .woocommerce-Price-amount, ins');
      if (insEl.length) {
        const val = this.parsePriceText(insEl.first().text());
        if (val !== null && val > 0) return val;
      }
      const val = this.parsePriceText(fallbackPriceEl.text());
      if (val !== null && val > 0) return val;
    }

    // 3. JSON-LD Şeması
    const product = this.findProductJsonLd($);
    if (product) {
      const priceLd = this.extractPriceFromProductJson(product);
      if (priceLd !== null && priceLd > 0) return priceLd;
    }

    return null;
  }

  scrapeOriginalPrice($, currentPrice) {
    if (!currentPrice || currentPrice <= 0) return null;

    // 1. Ana ürün fiyat bloğundaki del etiketi (Öncelikli)
    const summary = $('.summary, .entry-summary, .product-summary').first();
    const mainPriceEl = summary.children('.price, p.price').first();

    if (mainPriceEl.length) {
      const delEl = mainPriceEl.find('del .woocommerce-Price-amount, del');
      if (delEl.length) {
        const val = this.parsePriceText(delEl.first().text());
        if (val !== null && val > currentPrice) return val;
      }
    }

    // 2. DOM Fallback Aday Seçicileri
    const candidates = [];
    const selectors = [
      'del .woocommerce-Price-amount',
      '.summary del',
      'del',
      's',
      '.old-price',
      '.original-price'
    ];

    for (const selector of selectors) {
      $(selector).not('.bundled_product_optional_checkbox del').each((_, el) => {
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

    candidates.sort((a, b) => a - b);
    return candidates[0];
  }

  scrapeImage($, pageUrl, html) {
    // 1. JSON-LD Şeması (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product && product.image) {
      const imgLd = this.extractImageFromProductJson(product.image);
      if (imgLd && typeof imgLd === 'string' && imgLd.trim()) {
        const clean = imgLd.trim();
        if (!this.isLogoUrl(clean)) {
          return this.resolveImageUrl(clean, pageUrl);
        }
      }
    }

    // 2. Open Graph meta tag
    const ogImage = $('meta[property="og:image"]').attr('content');
    if (ogImage && ogImage.trim() && !this.isLogoUrl(ogImage)) {
      return this.resolveImageUrl(ogImage.trim(), pageUrl);
    }

    // 3. WooCommerce Galeri Görselleri (DOM)
    const galleryImg = $('.woocommerce-product-gallery__image img, .wp-post-image').first();
    if (galleryImg.length) {
      const src = galleryImg.attr('data-large_image') ||
                  galleryImg.attr('data-src') ||
                  galleryImg.attr('src');
      if (src && src.trim() && !this.isLogoUrl(src)) {
        return this.resolveImageUrl(src.trim(), pageUrl);
      }
    }

    return null;
  }

  scrapeBrand($, html) {
    // 1. JSON-LD Şeması (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product && product.brand) {
      const brand = this.extractBrandFromProductJson(product);
      if (brand && brand.trim()) return brand.trim();
    }

    // 2. DOM Seçicileri (.product_meta, a[rel="tag"])
    const brandTag = $('.product_meta a[href*="marka/"], .product_meta a[href*="brand/"]').first();
    if (brandTag.length) {
      const text = brandTag.text().trim();
      if (text) return text;
    }

    // 3. Script regex fallback
    if (html) {
      const brandMatch = html.match(/"brand"\s*:\s*\{\s*"@type"\s*:\s*"Brand"\s*,\s*"name"\s*:\s*"([^"]+)"/i);
      if (brandMatch) {
        return brandMatch[1].trim();
      }
    }

    return null;
  }

  scrapeDescription($, html) {
    // 1. JSON-LD Şeması
    const product = this.findProductJsonLd($);
    if (product && product.description) {
      const desc = product.description.trim();
      if (desc) return desc;
    }

    // 2. DOM Seçicileri
    const descEl = $('meta[name="description"]').attr('content') ||
                   $('meta[property="og:description"]').attr('content') ||
                   $('.woocommerce-product-details__short-description').first().text().trim();
    if (descEl && descEl.trim()) {
      return descEl.trim();
    }

    return null;
  }

  scrapeBreadcrumbs($, html) {
    const title = this.scrapeTitle($) || '';

    // 1. DOM WooCommerce Breadcrumb (Öncelikli — Gaming Gen'de gerçek kategori ağacını içerir)
    const bcElements = $('nav.woocommerce-breadcrumb a, .woocommerce-breadcrumb a');
    if (bcElements.length > 0) {
      const list = [];
      bcElements.each((_, el) => {
        const text = $(el).text().trim();
        if (text) {
          const lower = text.toLowerCase();
          if (lower !== 'anasayfa' && lower !== 'ana sayfa' && lower !== 'gaming.gen.tr' && lower !== 'gaming gen' && lower !== 'gaming.gen' && text !== title && text.length < 50) {
            list.push(text);
          }
        }
      });
      if (list.length > 0) return list;
    }

    // 2. JSON-LD BreadcrumbList (Fallback)
    const breadcrumbs = this.extractBreadcrumbsFromJsonLd($, title, 'gaming');
    if (breadcrumbs && breadcrumbs.length > 0) {
      return breadcrumbs;
    }

    return [];
  }

  scrapeRating($) {
    let ratingValue = null;
    let ratingCount = null;

    // 1. JSON-LD Şeması (Öncelikli)
    const product = this.findProductJsonLd($);
    if (product && product.aggregateRating) {
      const agg = product.aggregateRating;
      if (agg.ratingValue) {
        const val = parseFloat(agg.ratingValue.toString().replace(',', '.'));
        if (!isNaN(val) && val > 0) {
          ratingValue = Math.round(val * 10) / 10;
        }
      }
      if (agg.reviewCount || agg.ratingCount) {
        const cnt = parseInt((agg.reviewCount || agg.ratingCount).toString(), 10);
        if (!isNaN(cnt) && cnt > 0) {
          ratingCount = cnt;
        }
      }
    }

    // 2. DOM Seçicileri (Fallback)
    if (ratingValue === null) {
      const ratingEl = $('.summary .woocommerce-product-rating strong.rating, .entry-summary .woocommerce-product-rating strong.rating').first();
      if (ratingEl.length) {
        const val = parseFloat(ratingEl.text().trim().replace(',', '.'));
        if (!isNaN(val) && val > 0) {
          ratingValue = Math.round(val * 10) / 10;
        }
      }
    }

    if (ratingCount === null) {
      const countEl = $('.summary .woocommerce-product-rating span.count, .entry-summary .woocommerce-product-rating span.count').first();
      if (countEl.length) {
        const cnt = parseInt(countEl.text().trim(), 10);
        if (!isNaN(cnt) && cnt > 0) {
          ratingCount = cnt;
        }
      }
    }

    // Eğer değerlendirme sayısı yoksa veya 0 ise, rating de geçersizdir
    if (!ratingCount || ratingCount <= 0) {
      return { ratingValue: null, ratingCount: null };
    }

    return { ratingValue, ratingCount };
  }

  scrapePriceLabel() {
    return null;
  }
}

module.exports = GamingGenScraper;
