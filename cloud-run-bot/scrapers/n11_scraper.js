/**
 * N11 Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class N11Scraper extends BaseProductScraper {
  get domain() { return 'n11.com'; }

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
    const model = this._getN11Model($);
    if (model) {
      const images = model?.product?.images;
      if (Array.isArray(images) && images.length > 0) {
        const path = images[0]?.path?.toString();
        if (path) {
          const resolvedPath = path.replace('{0}', '400_570');
          const resolved = this.resolveImageUrl(resolvedPath, url);
          if (resolved && !this.isLogoUrl(resolved)) return resolved;
        }
      }
    }
    const selectors = ['.big-image-wrapper img', 'img.swiper-image', 'img.swiper-lazy', '#product-image img'];
    for (const sel of selectors) {
      const el = $(sel).first();
      const src = el.attr('src') || el.attr('data-src') || el.attr('data-lazy-src');
      if (src && !src.startsWith('data:') && !this.isLogoUrl(src)) {
        const resolved = this.resolveImageUrl(src, url);
        if (resolved) return resolved;
      }
    }
    return null;
  }

  scrapeTitle($) {
    const model = this._getN11Model($);
    if (model) {
      const title = model?.product?.name || model?.seoMetaData?.title;
      if (title) return title.toString().trim();
    }
    // Regex fallback
    const html = $.html();
    const match = html.match(/"title"\s*:\s*"([^"]+)"/);
    if (match) return match[1].trim();
    const el = $('.titleArea h1.title, h1.title, h1.proName').first();
    if (el.length) return el.text().trim();
    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle) return ogTitle.trim();
    return null;
  }

  scrapePrice($) {
    const model = this._getN11Model($);
    if (model) {
      for (const key of ['finalPriceFloat', 'finalPrice', 'priceFloat', 'price', 'displayPriceFloat', 'displayPrice']) {
        const val = this._findValueRecursive(model, key);
        if (val != null) {
          const parsed = key.includes('Float') ? parseFloat(val.toString()) : this.parsePriceText(val.toString());
          if (parsed && parsed > 0) return parsed;
        }
      }
    }
    // Regex fallback
    const html = $.html();
    const fpMatch = html.match(/"finalPrice"\s*:\s*"([^"]+)"/);
    if (fpMatch) {
      const val = this.parsePriceText(fpMatch[1]);
      if (val && val > 0) return val;
    }
    const el = $('.newPrice ins, ins, .newPrice, meta[property="product:price:amount"]').first();
    if (el.length) {
      const text = el.is('meta') ? el.attr('content') : el.text();
      return this.parsePriceText(text || '');
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const title = this.scrapeTitle($) || '';
    const model = this._getN11Model($);
    if (model) {
      const cat = model?.category || model?.categories;
      if (typeof cat === 'string' && cat.length > 0) {
        const parts = cat.split(/\s*>\s*|\s*\/\s*/).map(e => e.trim())
          .filter(e => e.length > 0)
          .filter(e => { const l = e.toLowerCase(); return l !== 'anasayfa' && !l.includes('n11') && l !== title.toLowerCase().trim() && e.length < 50; });
        if (parts.length > 0) return parts;
      } else if (Array.isArray(cat)) {
        const list = [];
        for (const c of cat) {
          const name = (typeof c === 'object' && c.name) ? c.name.toString().trim() : (typeof c === 'string' ? c.trim() : null);
          if (name) {
            const l = name.toLowerCase();
            if (l !== 'anasayfa' && !l.includes('n11') && l !== title.toLowerCase().trim() && name.length < 50) list.push(name);
          }
        }
        if (list.length > 0) return list;
      }
    }
    // DOM fallback
    const breadcrumbs = [];
    $('.breadcrumb-item a, .breadcrumb a, .breadcrumb-group a').each((_, el) => {
      const text = $(el).text().trim();
      if (text) {
        const l = text.toLowerCase();
        if (l !== 'anasayfa' && !l.includes('n11') && l !== title.toLowerCase().trim() && text.length < 50) breadcrumbs.push(text);
      }
    });
    if (breadcrumbs.length > 0) return breadcrumbs;
    return this.extractBreadcrumbsFromJsonLd($, title, 'n11');
  }
}

module.exports = N11Scraper;
