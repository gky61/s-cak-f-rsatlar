/**
 * Link Scraper Service (Node.js port)
 * Dart karşılığı: lib/services/link_preview_service.dart
 */

const cheerio = require('cheerio');
const scrapers = require('./scrapers');

const DEFAULT_USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36';

function getHeadersForUrl(url) {
  const lowerUrl = url.toLowerCase();
  let userAgent = DEFAULT_USER_AGENT;

  if (lowerUrl.includes('n11.com') ||
      lowerUrl.includes('teknosa.com') ||
      lowerUrl.includes('amazon.') ||
      lowerUrl.includes('amzn.') ||
      lowerUrl.includes('hepsiburada.com') ||
      lowerUrl.includes('mavi.com') ||
      lowerUrl.includes('defacto.com.tr') ||
      lowerUrl.includes('zara.com') ||
      lowerUrl.includes('mango.com') ||
      lowerUrl.includes('beymen.com') ||
      lowerUrl.includes('hb.biz') ||
      lowerUrl.includes('trendyol.com') ||
      lowerUrl.includes('ty.gl') ||
      lowerUrl.includes('pttavm.com') ||
      lowerUrl.includes('incehesap.com')) {
    userAgent = 'WhatsApp/2.23.4.15 A';
  } else if (lowerUrl.includes('vatanbilgisayar.com') || lowerUrl.includes('pazarama.com')) {
    userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  }

  return {
    'User-Agent': userAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
    'Cache-Control': 'max-age=0',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Referer': 'https://www.google.com/',
  };
}

/** URL yönlendirmelerini çözer ve nihai hedef URL'yi döndürür */
async function resolveUrlRedirects(url) {
  const lowerUrl = url.toLowerCase();
  const isShortOrRedirect = lowerUrl.includes('amzn.eu') ||
                           lowerUrl.includes('amzn.to') ||
                           lowerUrl.includes('hb.biz') ||
                           lowerUrl.includes('publicis.link') ||
                           lowerUrl.includes('bit.ly') ||
                           lowerUrl.includes('tinyurl.com') ||
                           lowerUrl.includes('t.co') ||
                           lowerUrl.includes('rebrand.ly') ||
                           lowerUrl.includes('rdrtr.com') ||
                           lowerUrl.includes('ty.gl');

  if (!isShortOrRedirect) return url;

  try {
    console.log(`🔗 Yönlendirme çözülüyor: ${url}`);
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000);

    const response = await fetch(url, {
      method: 'GET',
      headers: getHeadersForUrl(url),
      redirect: 'follow',
      signal: controller.signal
    });

    clearTimeout(timeoutId);
    console.log(`✅ Çözülen URL: ${response.url}`);
    return response.url || url;
  } catch (err) {
    console.warn(`⚠️ Yönlendirme çözülemedi (${err.message}), orijinal URL kullanılacak: ${url}`);
    return url;
  }
}

/** URL'den HTML çekerek Cheerio DOM nesnesi döndürür */
async function fetchHtml(url) {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 12000);

    const response = await fetch(url, {
      headers: getHeadersForUrl(url),
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (response.ok) {
      return await response.text();
    } else {
      console.error(`❌ HTTP hatası (${response.status}): ${url}`);
      return null;
    }
  } catch (err) {
    console.error(`❌ HTML çekme hatası: ${err.message}`);
    return null;
  }
}

/** Verilen URL için ürün bilgilerini çeker */
async function scrapeProductFromUrl(url) {
  try {
    // 1. Kısa veya yönlendirmeli linkleri çöz
    const targetUrl = await resolveUrlRedirects(url);

    // 2. Scraper bul
    let matchedScraper = null;
    for (const scraper of scrapers) {
      if (scraper.canHandle(targetUrl)) {
        matchedScraper = scraper;
        break;
      }
    }

    if (!matchedScraper) {
      console.log(`ℹ️ Eşleşen scraper bulunamadı, genel Open Graph parser kullanılacak: ${targetUrl}`);
    } else {
      console.log(`⚡ Özel Scraper eşleşti: ${matchedScraper.constructor.name} -> ${targetUrl}`);
    }

    // 3. HTML içeriğini çek
    const html = await fetchHtml(targetUrl);
    if (!html) {
      return { url: targetUrl, title: null, price: null, imageUrl: null, breadcrumbs: [] };
    }

    const $ = cheerio.load(html);

    if (matchedScraper) {
      // Özel Scraper akışı
      const title = matchedScraper.scrapeTitle($);
      const price = await matchedScraper.scrapePrice($);
      const rawImage = matchedScraper.scrapeImage($, targetUrl);
      const breadcrumbs = matchedScraper.scrapeBreadcrumbs($) || [];

      // Image URL'yi mutlak hale getir
      const imageUrl = matchedScraper.resolveImageUrl(rawImage, targetUrl);

      return {
        url: targetUrl,
        title: title || null,
        price: price || null,
        imageUrl: imageUrl || null,
        breadcrumbs: breadcrumbs
      };
    } else {
      // Genel Fallback akışı (Open Graph ve standart meta etiketleri)
      const title = $('meta[property="og:title"]').attr('content') || $('title').text();
      const rawImage = $('meta[property="og:image"]').attr('content') || $('link[rel="image_src"]').attr('href');
      const desc = $('meta[property="og:description"]').attr('content') || $('meta[name="description"]').attr('content');
      
      // Fallback fiyat tespiti
      let price = null;
      const priceMeta = $('meta[property="product:price:amount"]').attr('content') || 
                        $('meta[property="og:price:amount"]').attr('content') ||
                        $('meta[name="twitter:data1"]').attr('content');
      if (priceMeta) {
        // Temizle ve parse et
        const cleaned = priceMeta.replace(/[^0-9.,]/g, '').replace(',', '.');
        const parsed = parseFloat(cleaned);
        if (!isNaN(parsed)) price = parsed;
      }

      // Image url resolve
      let imageUrl = null;
      if (rawImage && !rawImage.startsWith('data:')) {
        if (rawImage.startsWith('http://') || rawImage.startsWith('https://')) {
          imageUrl = rawImage;
        } else {
          try {
            const base = new URL(targetUrl);
            imageUrl = new URL(rawImage, base).toString();
          } catch (_) {}
        }
      }

      return {
        url: targetUrl,
        title: title ? title.trim() : null,
        price: price,
        imageUrl: imageUrl,
        breadcrumbs: []
      };
    }
  } catch (err) {
    console.error(`❌ Scrape işleminde beklenmeyen hata: ${err.message}`);
    return { url, title: null, price: null, imageUrl: null, breadcrumbs: [] };
  }
}

module.exports = {
  scrapeProductFromUrl,
  resolveUrlRedirects,
  getHeadersForUrl
};
