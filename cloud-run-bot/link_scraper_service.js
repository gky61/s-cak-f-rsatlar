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

/** Adjust deep-link yönlendirmesinden gerçek fallback URL'ini çıkartır */
function extractAdjustFallback(url) {
  if (url.includes('adj.st') && url.includes('adj_fallback=')) {
    try {
      const parsedUrl = new URL(url);
      const fallback = parsedUrl.searchParams.get('adj_fallback');
      if (fallback) {
        console.log(`[RESOLVE-REDIRECT] 🎯 Adjust URL tespit edildi, adj_fallback çözülüyor: ${fallback}`);
        return decodeURIComponent(fallback);
      }
    } catch (err) {
      console.warn(`[RESOLVE-REDIRECT] ⚠️ Adjust fallback çözme hatası: ${err.message}`);
    }
  }
  return url;
}

/** URL yönlendirmelerini çözer ve nihai hedef URL'yi döndürür */
async function resolveUrlRedirects(url) {
  let targetUrl = extractAdjustFallback(url);
  const lowerUrl = targetUrl.toLowerCase();
  
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

  if (!isShortOrRedirect) return targetUrl;

  try {
    console.log(`[RESOLVE-REDIRECT] 🔗 Yönlendirme çözülüyor: ${targetUrl}`);
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000);

    const headers = getHeadersForUrl(targetUrl);
    console.log(`[RESOLVE-REDIRECT] Giden User-Agent: "${headers['User-Agent']}"`);

    const response = await fetch(targetUrl, {
      method: 'GET',
      headers: headers,
      redirect: 'follow',
      signal: controller.signal
    });

    clearTimeout(timeoutId);
    console.log(`[RESOLVE-REDIRECT] ✅ Çözülen Hedef URL: ${response.url} (Durum: ${response.status} ${response.statusText})`);
    
    let resolvedUrl = response.url || targetUrl;
    resolvedUrl = extractAdjustFallback(resolvedUrl);
    
    return resolvedUrl;
  } catch (err) {
    console.warn(`[RESOLVE-REDIRECT] ⚠️ Yönlendirme çözülemedi (${err.message}), orijinal URL kullanılacak: ${targetUrl}`);
    return targetUrl;
  }
}

/** URL'den HTML çekerek Cheerio DOM nesnesi döndürür */
async function fetchHtml(url) {
  const fetchStartTime = Date.now();
  console.log(`[FETCH-HTML] 📥 İstek başlatılıyor: ${url}`);
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 12000);

    const headers = getHeadersForUrl(url);
    console.log(`[FETCH-HTML] Giden İstek Başlıkları:`, JSON.stringify(headers));

    const response = await fetch(url, {
      headers: headers,
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    const duration = Date.now() - fetchStartTime;
    console.log(`[FETCH-HTML] ⚡ Cevap geldi! Süre: ${duration}ms, Durum Kodu: ${response.status} ${response.statusText}`);
    
    // Response Header'larını logla (Hata çözümü için kritik)
    const respHeaders = {};
    response.headers.forEach((val, key) => {
      respHeaders[key] = val;
    });
    console.log(`[FETCH-HTML] Gelen Cevap Başlıkları:`, JSON.stringify(respHeaders));

    if (response.ok) {
      const htmlText = await response.text();
      console.log(`[FETCH-HTML] Başarılı! Okunan HTML boyutu: ${htmlText.length} karakter.`);
      
      // Sayfa içeriğinde engelleyici imzaları ara
      checkForBotBlockers(htmlText, url);
      
      return htmlText;
    } else {
      console.error(`[FETCH-HTML] ❌ Sunucu Hata Kodu Döndürdü (${response.status}): ${url}`);
      return null;
    }
  } catch (err) {
    console.error(`[FETCH-HTML] ❌ HTML Çekme Hatası: ${err.message}`);
    return null;
  }
}

/** Sayfa içeriğinde bot engelleyici/Cloudflare imzası kontrolü */
function checkForBotBlockers(htmlText, url) {
  const lowerHtml = htmlText.toLowerCase();
  
  const blockSignatures = {
    'Cloudflare Challenge': ['<title>just a moment...</title>', 'cf-challenge', 'checking your browser...'],
    'PerimeterX/Human Challenge': ['px-captcha', 'captcha-delivery.net'],
    'Distil Networks Blocker': ['blocked by distil', 'distil_ident_cookie'],
    'Akamai Edge Shield': ['access denied', 'you don\'t have permission to access'],
    'Generic Firewall Block': ['access forbidden', 'ip blocked', 'request blocked', 'unauthorized access']
  };

  for (const [blockType, keywords] of Object.entries(blockSignatures)) {
    for (const keyword of keywords) {
      if (lowerHtml.includes(keyword)) {
        console.warn(`[BOT ENGELİ TESPİTİ] ⚠️⚠️⚠️ ENGEL ALGINLANDI! ⚠️⚠️⚠️`);
        console.warn(`   Tip        : ${blockType}`);
        console.warn(`   Anahtar Kelime: "${keyword}"`);
        console.warn(`   Link       : ${url}`);
        console.warn(`   Not        : Mağaza IP adresimizi engelledi veya Cloudflare/Akamai doğrulaması gösterdi. Bu yüzden DOM seçicileri çalışmayacaktır.`);
        
        // HTML içeriğinden bir kesit gösterelim (İlk 300 karakter)
        const preview = htmlText.substring(0, 300).replace(/\s+/g, ' ').trim();
        console.warn(`   HTML Kesit : "${preview}..."`);
        return; // İlk eşleşmede dur
      }
    }
  }
}

/** Verilen URL için ürün bilgilerini çeker */
async function scrapeProductFromUrl(url) {
  const startTime = Date.now();
  console.log(`\n============================================================`);
  console.log(`[SCRAPE-SERVICE] 🚀 Ürün Scrape Başlatıldı: ${url}`);
  console.log(`============================================================`);
  
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
      console.log(`[SCRAPE-SERVICE] ℹ️ Eşleşen özel scraper bulunamadı, genel Open Graph parser kullanılacak: ${targetUrl}`);
    } else {
      console.log(`[SCRAPE-SERVICE] ⚡ Özel Scraper eşleşti: "${matchedScraper.constructor.name}" -> ${targetUrl}`);
    }

    // 3. HTML içeriğini çek
    const html = await fetchHtml(targetUrl);
    if (!html) {
      console.error(`[SCRAPE-SERVICE] ❌ HTML içeriği boş veya çekilemedi! Boş veri döndürülüyor.`);
      return { url: targetUrl, title: null, price: null, imageUrl: null, breadcrumbs: [] };
    }

    const $ = cheerio.load(html);

    if (matchedScraper) {
      console.log(`[SCRAPE-SERVICE] Özel Scraper akışı başlıyor...`);
      
      // 1. Başlık Çekimi
      console.log(`[SCRAPE-SERVICE] [TITLE] Başlık çekiliyor...`);
      const title = matchedScraper.scrapeTitle($);
      console.log(`[SCRAPE-SERVICE] [TITLE] Sonuç: "${title || 'BULUNAMADI'}"`);

      // 2. Fiyat Çekimi
      console.log(`[SCRAPE-SERVICE] [PRICE] Fiyat çekiliyor...`);
      const price = await matchedScraper.scrapePrice($);
      console.log(`[SCRAPE-SERVICE] [PRICE] Sonuç: "${price != null ? price + ' TL' : 'BULUNAMADI'}"`);

      // 3. Görsel Çekimi
      console.log(`[SCRAPE-SERVICE] [IMAGE] Görsel çekiliyor...`);
      const rawImage = matchedScraper.scrapeImage($, targetUrl);
      console.log(`[SCRAPE-SERVICE] [IMAGE] Ham Görsel Alanı: "${rawImage || 'BULUNAMADI'}"`);
      const imageUrl = matchedScraper.resolveImageUrl(rawImage, targetUrl);
      console.log(`[SCRAPE-SERVICE] [IMAGE] Mutlak Görsel URL'i: "${imageUrl || 'BULUNAMADI'}"`);

      // 4. Kırıntı Çekimi (Breadcrumbs)
      console.log(`[SCRAPE-SERVICE] [BREADCRUMBS] Kırıntı listesi çekiliyor...`);
      const breadcrumbs = matchedScraper.scrapeBreadcrumbs($) || [];
      console.log(`[SCRAPE-SERVICE] [BREADCRUMBS] Sonuç: ${JSON.stringify(breadcrumbs)}`);

      const totalDuration = Date.now() - startTime;
      console.log(`============================================================`);
      console.log(`[SCRAPE-SERVICE] ✅ Scrape tamamlandı! Toplam süre: ${totalDuration}ms`);
      console.log(`============================================================\n`);

      return {
        url: targetUrl,
        title: title || null,
        price: price || null,
        imageUrl: imageUrl || null,
        breadcrumbs: breadcrumbs
      };
    } else {
      console.log(`[SCRAPE-SERVICE] Genel Fallback akışı (Open Graph) başlıyor...`);
      
      const title = $('meta[property="og:title"]').attr('content') || $('title').text();
      console.log(`[SCRAPE-SERVICE] [TITLE] (Fallback) Sonuç: "${title ? title.trim() : 'BULUNAMADI'}"`);

      const rawImage = $('meta[property="og:image"]').attr('content') || $('link[rel="image_src"]').attr('href');
      console.log(`[SCRAPE-SERVICE] [IMAGE] (Fallback) Ham Görsel: "${rawImage || 'BULUNAMADI'}"`);

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
      console.log(`[SCRAPE-SERVICE] [IMAGE] (Fallback) Mutlak Görsel URL'i: "${imageUrl || 'BULUNAMADI'}"`);

      // Fallback fiyat tespiti
      let price = null;
      const priceMeta = $('meta[property="product:price:amount"]').attr('content') || 
                        $('meta[property="og:price:amount"]').attr('content') ||
                        $('meta[name="twitter:data1"]').attr('content');
      console.log(`[SCRAPE-SERVICE] [PRICE] (Fallback) Fiyat meta verisi: "${priceMeta || 'YOK'}"`);
      
      if (priceMeta) {
        const cleaned = priceMeta.replace(/[^0-9.,]/g, '').replace(',', '.');
        const parsed = parseFloat(cleaned);
        if (!isNaN(parsed)) price = parsed;
      }
      console.log(`[SCRAPE-SERVICE] [PRICE] (Fallback) Parsed Fiyat: "${price != null ? price + ' TL' : 'BULUNAMADI'}"`);

      const totalDuration = Date.now() - startTime;
      console.log(`============================================================`);
      console.log(`[SCRAPE-SERVICE] ✅ Fallback Scrape tamamlandı! Toplam süre: ${totalDuration}ms`);
      console.log(`============================================================\n`);

      return {
        url: targetUrl,
        title: title ? title.trim() : null,
        price: price,
        imageUrl: imageUrl,
        breadcrumbs: []
      };
    }
  } catch (err) {
    console.error(`[SCRAPE-SERVICE] ❌ Scrape işleminde beklenmeyen hata: ${err.message}`, err.stack);
    return { url, title: null, price: null, imageUrl: null, breadcrumbs: [] };
  }
}

module.exports = {
  scrapeProductFromUrl,
  resolveUrlRedirects,
  getHeadersForUrl
};
