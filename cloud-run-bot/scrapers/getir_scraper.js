/**
 * Getir Scraper (Node.js port)
 */
const BaseProductScraper = require('./base_scraper');

class GetirScraper extends BaseProductScraper {
  get domain() { return 'getir.com'; }

  canHandle(url) {
    return url.toLowerCase().includes('getir.com');
  }

  scrapeImage($, url) {
    // 1. Next.js __NEXT_DATA__
    const pData = this._getProductData($);
    if (pData) {
      const picUrls = pData.picURLs;
      if (Array.isArray(picUrls) && picUrls.length > 0) {
        const img = picUrls[0].toString();
        const resolved = this.resolveImageUrl(img, url);
        if (resolved && !this.isLogoUrl(resolved)) {
          return resolved;
        }
      }

      const sqThumb = pData.squareThumbnailURL;
      if (sqThumb) {
        const resolved = this.resolveImageUrl(sqThumb.toString(), url);
        if (resolved && !this.isLogoUrl(resolved)) {
          return resolved;
        }
      }
    }

    // 2. og:image
    const ogImg = $('meta[property="og:image"]').attr('content') ||
                  $('meta[name="twitter:image"]').attr('content');
    if (ogImg && !this.isLogoUrl(ogImg)) {
      const resolved = this.resolveImageUrl(ogImg, url);
      if (resolved) return resolved;
    }

    return null;
  }

  scrapeTitle($) {
    const pData = this._getProductData($);
    if (pData) {
      if (pData.name && pData.name.trim().length > 0) {
        return pData.name.trim();
      }
      if (pData.shortName && pData.shortName.trim().length > 0) {
        return pData.shortName.trim();
      }
    }

    const ogTitle = $('meta[property="og:title"]').attr('content') || $('title').text();
    if (ogTitle && ogTitle.toLowerCase() !== 'null') {
      let title = ogTitle;
      title = title.replace(/ - Getir/g, '').replace(/ \| Getir/g, '');
      return title.trim();
    }

    return null;
  }

  scrapePrice($) {
    const pData = this._getProductData($);
    if (pData && pData.price != null) {
      const parsed = parseFloat(pData.price);
      if (!isNaN(parsed) && parsed > 0) {
        return parsed;
      }
    }
    return null;
  }

  scrapeDescription($) {
    const pData = this._getProductData($);
    if (pData && pData.shortDescription && pData.shortDescription.trim().length > 0) {
      return pData.shortDescription.trim();
    }

    const ogDesc = $('meta[name="description"], meta[property="og:description"]').first();
    if (ogDesc.length) {
      const content = ogDesc.attr('content')?.trim();
      if (content && content.toLowerCase() !== 'null') return content;
    }
    return null;
  }

  scrapeBreadcrumbs($) {
    const pData = this._getProductData($);
    if (!pData) return [];

    const breadcrumbs = [];
    const cats = this._getCategoriesList($);
    if (Array.isArray(cats) && cats.length > 0) {
      const productCatIds = pData.categoryIds;
      const productSubcatIds = pData.subCategoryIds;
      if (Array.isArray(productCatIds)) {
        for (const cat of cats) {
          if (cat && typeof cat === 'object' && productCatIds.includes(cat.id)) {
            if (cat.name) breadcrumbs.push(cat.name);
            const subcats = cat.subCategories;
            if (Array.isArray(subcats) && Array.isArray(productSubcatIds)) {
              for (const sub of subcats) {
                if (sub && typeof sub === 'object' && productSubcatIds.includes(sub.id)) {
                  if (sub.name) breadcrumbs.push(sub.name);
                }
              }
            }
          }
        }
      }
    }

    return breadcrumbs;
  }

  _getProductData($) {
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const id = $(scripts[i]).attr('id');
      const text = $(scripts[i]).text() || '';
      if (id === '__NEXT_DATA__' || text.includes('"productDetail"')) {
        try {
          const data = JSON.parse(text);
          const pData = this._findProductDetailData(data);
          if (pData) return pData;
        } catch (_) {}
      }
    }
    return null;
  }

  _findProductDetailData(json) {
    if (json && typeof json === 'object' && !Array.isArray(json)) {
      if (json.productDetail && typeof json.productDetail === 'object') {
        const pd = json.productDetail;
        if (pd.data && typeof pd.data === 'object' && pd.data.name && pd.data.price != null) {
          return pd.data;
        }
      }
      for (const value of Object.values(json)) {
        const res = this._findProductDetailData(value);
        if (res) return res;
      }
    } else if (Array.isArray(json)) {
      for (const item of json) {
        const res = this._findProductDetailData(item);
        if (res) return res;
      }
    }
    return null;
  }

  _getCategoriesList($) {
    const scripts = $('script');
    for (let i = 0; i < scripts.length; i++) {
      const id = $(scripts[i]).attr('id');
      const text = $(scripts[i]).text() || '';
      if (id === '__NEXT_DATA__' || text.includes('"getirListing"')) {
        try {
          const data = JSON.parse(text);
          return this._findCategoriesList(data);
        } catch (_) {}
      }
    }
    return null;
  }

  _findCategoriesList(json) {
    if (json && typeof json === 'object' && !Array.isArray(json)) {
      if (json.getirListing && typeof json.getirListing === 'object') {
        const gl = json.getirListing;
        if (gl.categories && typeof gl.categories === 'object' && Array.isArray(gl.categories.data)) {
          return gl.categories.data;
        }
      }
      for (const value of Object.values(json)) {
        const res = this._findCategoriesList(value);
        if (res) return res;
      }
    } else if (Array.isArray(json)) {
      for (const item of json) {
        const res = this._findCategoriesList(item);
        if (res) return res;
      }
    }
    return null;
  }
}

module.exports = GetirScraper;
