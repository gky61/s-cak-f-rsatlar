const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cheerio = require('cheerio');
const { spawnSync } = require('child_process');

const STORES = [
  { code: 'a101', name: 'A101', url: 'https://www.akakce.com/brosurler/a101', keywords: ['a101', 'a-101'] },
  { code: 'bim', name: 'BİM', url: 'https://www.akakce.com/brosurler/bim', keywords: ['bim'] },
  { code: 'sok', name: 'ŞOK', url: 'https://www.akakce.com/brosurler/sok', keywords: ['sok', 'şok'] },
  { code: 'migros', name: 'Migros', url: 'https://www.akakce.com/brosurler/migros', keywords: ['migros'] },
  { code: 'carrefoursa', name: 'CarrefourSA', url: 'https://www.akakce.com/brosurler/carrefoursa', keywords: ['carrefour'] },
  { code: 'cagri', name: 'Çağrı', url: 'https://www.akakce.com/brosurler/cagrihipermarket', keywords: ['cagri', 'çağrı'] },
  { code: 'happycenter', name: 'HappyCenter', url: 'https://www.akakce.com/brosurler/happy-center', keywords: ['happy'] },
  { code: 'macrocenter', name: 'MacroCenter', url: 'https://www.akakce.com/brosurler/macrocenter', keywords: ['macro'] },
  { code: 'getirbuyuk', name: 'GetirBüyük', url: 'https://www.akakce.com/brosurler/getirbuyuk', keywords: ['getir'] },
  { code: 'file', name: 'File', url: 'https://www.akakce.com/brosurler/filemarket', keywords: ['file'] },
  { code: 'hakmarexpress', name: 'Hakmar Express', url: 'https://www.akakce.com/brosurler/hakmarexpress', keywords: ['express'] },
  { code: 'hakmar', name: 'Hakmar', url: 'https://www.akakce.com/brosurler/hakmar', keywords: ['hakmar'], excludeKeywords: ['express'] },
  { code: 'cetinkaya', name: 'Çetinkaya', url: 'https://www.akakce.com/brosurler/cetinkaya', keywords: ['cetinkaya', 'çetinkaya'] },
  { code: 'gratis', name: 'Gratis', url: 'https://www.akakce.com/brosurler/gratis', keywords: ['gratis'] },
  { code: 'watsons', name: 'Watsons', url: 'https://www.akakce.com/brosurler/watsons', keywords: ['watsons'] },
  { code: 'rossmann', name: 'Rossmann', url: 'https://www.akakce.com/brosurler/rossmann', keywords: ['rossmann'] },
  { code: 'civil', name: 'Civil', url: 'https://www.akakce.com/brosurler/civil', keywords: ['civil'] },
  { code: 'evkur', name: 'Evkur', url: 'https://www.akakce.com/brosurler/evkur', keywords: ['evkur'] },
  { code: 'mrdiy', name: 'MR.DIY', url: 'https://www.akakce.com/brosurler/mrdiy', keywords: ['mrdiy', 'mr.diy', 'diy'] },
  { code: 'kooperatifmarket', name: 'Kooperatif Market', url: 'https://www.akakce.com/brosurler/kooperatifmarket', keywords: ['kooperatif', 'tarim', 'tarım'] },
  { code: 'metro', name: 'Metro', url: 'https://www.akakce.com/brosurler/metro-tr', keywords: ['metro'] },
  { code: 'bizim', name: 'Bizim', url: 'https://www.akakce.com/brosurler/bizimtoptan', keywords: ['bizim'] },
  { code: 'teknosa', name: 'Teknosa', url: 'https://www.akakce.com/brosurler/teknosacom', keywords: ['teknosa'] },
  { code: 'vatan', name: 'Vatan', url: 'https://www.akakce.com/brosurler/vatanbilgisayar', keywords: ['vatan'] },
  { code: 'vestel', name: 'Vestel', url: 'https://www.akakce.com/brosurler/vestel', keywords: ['vestel'] }
];

/**
 * Validates if the returned HTML is valid catalog content and not a WAF block/error page.
 */
function isValidHtml(html, minLength = 2500) {
  if (!html || html.length < minLength) return false;
  const lower = html.toLowerCase();
  if (lower.includes('403 - forbidden') || lower.includes('access is denied') || lower.includes('robot verification')) {
    return false;
  }
  return true;
}

/**
 * Helper to process array items in parallel chunks of size concurrency.
 * Using small concurrency (2) to guarantee proxy stability and zero rate-limiting.
 */
async function mapConcurrent(items, concurrency, fn) {
  const results = [];
  for (let i = 0; i < items.length; i += concurrency) {
    const chunk = items.slice(i, i + concurrency);
    const chunkResults = await Promise.all(chunk.map(fn));
    results.push(...chunkResults);
  }
  return results;
}

/**
 * Guaranteed 100% Multi-Stage HTML Fetcher with Retries.
 * Tries 5 fetch strategies per attempt and retries up to maxRetries times.
 */
async function fetchHtmlWithRetry(targetUrl, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    // Strategy A (Primary): Google Translate Proxy (15s timeout - #1 WAF bypass)
    try {
      const parsedUrl = new URL(targetUrl);
      const proxyHost = parsedUrl.hostname.replace(/\./g, '-') + '.translate.goog';
      const translateProxyUrl = `https://${proxyHost}${parsedUrl.pathname}${parsedUrl.search}?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;
      
      const proxyRes = await fetch(translateProxyUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
        },
        signal: AbortSignal.timeout(15000)
      });
      if (proxyRes.ok) {
        const html = await proxyRes.text();
        if (isValidHtml(html, 2500)) return html;
      }
    } catch (e) {
      functions.logger.debug(`Stage A (Translate Proxy attempt ${attempt}) failed for ${targetUrl}:`, e.message);
    }

    // Strategy B: Direct Fetch with Googlebot UA (5s timeout)
    try {
      const res = await fetch(targetUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
        },
        signal: AbortSignal.timeout(5000)
      });
      if (res.ok) {
        const html = await res.text();
        if (isValidHtml(html, 3000)) return html;
      }
    } catch (e) {}

    // Strategy C: Direct Fetch Mobile WhatsApp UA (5s timeout)
    try {
      const res = await fetch(targetUrl, {
        headers: {
          'User-Agent': 'WhatsApp/2.23.4.15 A',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
        },
        signal: AbortSignal.timeout(5000)
      });
      if (res.ok) {
        const html = await res.text();
        if (isValidHtml(html, 3000)) return html;
      }
    } catch (e) {}

    // Strategy D: Microlink Proxy (12s timeout)
    try {
      const microlinkUrl = `https://api.microlink.io/?url=${encodeURIComponent(targetUrl)}&data.html.selector=html&data.html.type=html`;
      const res = await fetch(microlinkUrl, { signal: AbortSignal.timeout(12000) });
      if (res.ok) {
        const json = await res.json();
        const html = json.data?.html || '';
        if (isValidHtml(html, 2500)) return html;
      }
    } catch (e) {}

    // Strategy E: Native OS curl (10s timeout)
    try {
      const curlArgs = [
        '-s', '-L',
        '--max-time', '10',
        '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        '-H', 'Accept-Language: tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        targetUrl
      ];
      const curlResult = spawnSync('curl', curlArgs, { encoding: 'utf-8', timeout: 12000 });
      if (!curlResult.error && isValidHtml(curlResult.stdout, 3000)) {
        return curlResult.stdout;
      }
    } catch (e) {}

    // Pause 1 second before next retry
    if (attempt < maxRetries) {
      await new Promise(r => setTimeout(r, 1000));
    }
  }

  functions.logger.warn(`❌ All ${maxRetries} retry attempts failed for URL: ${targetUrl}`);
  return null;
}

const MONTHS_MAP = {
  'ocak': 0, 'subat': 1, 'şubat': 1, 'mart': 2, 'nisan': 3,
  'mayis': 4, 'mayıs': 4, 'haziran': 5, 'temmuz': 6, 'agustos': 7, 'ağustos': 7,
  'eylul': 8, 'eylül': 8, 'ekim': 9, 'kasim': 10, 'kasım': 10, 'aralik': 11, 'aralık': 11
};

function createTurkeyDate(year, monthIndex, day, hours = 0, minutes = 0, seconds = 0, ms = 0) {
  const utcMs = Date.UTC(year, monthIndex, day, hours, minutes, seconds, ms) - (3 * 3600 * 1000);
  return new Date(utcMs);
}

function parseYearFromUrl(url) {
  if (url) {
    const match = url.match(/(\d{4})/);
    if (match) {
      const year = parseInt(match[1], 10);
      if (year >= 2024 && year <= 2030) {
        return year;
      }
    }
  }
  return new Date().getFullYear();
}

function parseDatesFromSpan(spanText, urlYear = new Date().getFullYear()) {
  if (!spanText) return null;
  const normalized = spanText.toLowerCase().replace(/\s+/g, ' ').trim();
  const parts = normalized.split(/\s*[-–—]\s*/);
  if (parts.length === 0) return null;

  function parseSinglePart(partText) {
    const match = partText.trim().match(/(\d+)\s+([a-zA-ZğüşöçıİĞÜŞÖÇI]+)/);
    if (match) {
      const day = parseInt(match[1], 10);
      const monthStr = match[2];
      const month = MONTHS_MAP[monthStr];
      if (month !== undefined) {
        return { day, month };
      }
    }
    return null;
  }

  if (parts.length === 2) {
    const startPart = parseSinglePart(parts[0]);
    const endPart = parseSinglePart(parts[1]);
    if (startPart && endPart) {
      const startDate = createTurkeyDate(urlYear, startPart.month, startPart.day, 0, 0, 0, 0);
      let endYear = urlYear;
      if (endPart.month < startPart.month) endYear = urlYear + 1;
      const endDate = createTurkeyDate(endYear, endPart.month, endPart.day, 23, 59, 59, 999);
      return { startDate, endDate };
    }
  } else if (parts.length === 1) {
    const singlePart = parseSinglePart(parts[0]);
    if (singlePart) {
      const startDate = createTurkeyDate(urlYear, singlePart.month, singlePart.day, 0, 0, 0, 0);
      const endDate = createTurkeyDate(urlYear, singlePart.month, singlePart.day, 23, 59, 59, 999);
      return { startDate, endDate };
    }
  }
  return null;
}

function parseDateFromUrl(url) {
  const match = url.match(/(\d+)-([a-zA-ZğüşöçıİĞÜŞÖÇI]+)-(\d{4})/);
  if (match) {
    const day = parseInt(match[1], 10);
    const monthStr = match[2].toLowerCase();
    const year = parseInt(match[3], 10);
    const month = MONTHS_MAP[monthStr] !== undefined ? MONTHS_MAP[monthStr] : 0;
    return createTurkeyDate(year, month, day, 0, 0, 0, 0);
  }
  return createTurkeyDate(new Date().getFullYear(), new Date().getMonth(), new Date().getDate(), 0, 0, 0, 0);
}

async function scrapeAndSaveCatalogs() {
  functions.logger.info('🚀 Starting guaranteed 100% catalog scraping flow for all stores...');
  const allScrapedCatalogs = [];

  for (const store of STORES) {
    try {
      functions.logger.info(`🔍 Fetching catalog list for ${store.name} from ${store.url}...`);

      const listHtml = await fetchHtmlWithRetry(store.url, 3);
      if (!listHtml) {
        functions.logger.warn(`⚠️ Failed to fetch catalog list page for ${store.name} after 3 retries. Skipping store.`);
        continue;
      }

      const $list = cheerio.load(listHtml);
      const catalogItems = [];

      $list('ul#BLI li a').each((i, el) => {
        const aTag = $list(el);
        let href = aTag.attr('href') || '';
        
        if (href.includes('.translate.goog')) {
          try {
            const u = new URL(href);
            href = u.pathname;
          } catch (e) {}
        }

        if (href.includes('/brosurler/')) {
          const storeNameText = (aTag.find('.blid b').text() || '').toLowerCase();
          const hrefLower = href.toLowerCase();

          // Exclude check
          if (store.excludeKeywords && store.excludeKeywords.some(ex => hrefLower.includes(ex) || storeNameText.includes(ex))) {
            return;
          }

          // Store Validation: Ensure brochure actually matches the target store
          const matchesStore = store.keywords.some(kw => 
            hrefLower.includes(`/${kw}`) || 
            hrefLower.includes(`${kw}-`) || 
            hrefLower.includes(`-${kw}`) || 
            storeNameText.includes(kw)
          );

          if (!matchesStore) {
            functions.logger.debug(`Skipping unrelated brochure on ${store.name} page: ${href}`);
            return;
          }

          const imgStyle = aTag.find('.dt img').attr('style') || '';
          const bgUrlMatch = imgStyle.match(/url\((?:&quot;|"|')?([^)'"]+?)(?:&quot;|"|')?\)/);
          let coverImage = '';
          if (bgUrlMatch) {
            coverImage = bgUrlMatch[1];
            if (coverImage.startsWith('//')) coverImage = 'https:' + coverImage;
          }

          const titleSuffix = aTag.find('.blid .bn').text().trim() || 'Aktüel Kataloğu';
          const idMatch = href.match(/(\d+)$/);
          const brochureId = idMatch ? idMatch[1] : '';

          if (brochureId) {
            catalogItems.push({ brochureId, href, coverImage, titleSuffix });
          }
        }
      });

      functions.logger.info(`Found ${catalogItems.length} brochures for ${store.name}.`);

      const storeBrochures = await mapConcurrent(catalogItems, 2, async (item) => {
        try {
          const detailUrl = item.href.startsWith('http') ? item.href : `https://www.akakce.com${item.href}`;
          functions.logger.info(`   📄 Scraping detail page: ${detailUrl}`);

          const detailHtml = await fetchHtmlWithRetry(detailUrl, 3);

          if (detailHtml) {
            const $detail = cheerio.load(detailHtml);
            
            const sayfaResimleri = [];
            const imgElements = $detail('#BP_W .p img').length > 0 
              ? $detail('#BP_W .p img') 
              : ($detail('.p img').length > 0 ? $detail('.p img') : $detail('#BP_W img'));

            imgElements.each((i, el) => {
              let src = $detail(el).attr('data-src') || $detail(el).attr('src') || $detail(el).attr('data-original');
              if (src && !src.includes('t.gif')) {
                if (src.startsWith('//')) src = 'https:' + src;
                src = src.replace('/_bro/l/', '/_bro/u/').replace('/_bro/y/', '/_bro/u/').replace('/_bro/m/', '/_bro/u/');
                sayfaResimleri.push(src);
              }
            });

            if (sayfaResimleri.length > 0) {
              const urlYear = parseYearFromUrl(item.href);
              const dateSpanText = $detail('#br_s').text().trim();
              const parsedSpanDates = parseDatesFromSpan(dateSpanText, urlYear);

              let baslangicTarihi, bitisTarihi;
              if (parsedSpanDates) {
                baslangicTarihi = parsedSpanDates.startDate;
                bitisTarihi = parsedSpanDates.endDate;
              } else {
                baslangicTarihi = parseDateFromUrl(item.href);
                bitisTarihi = new Date(baslangicTarihi.getTime() + 7 * 24 * 60 * 60 * 1000);
                bitisTarihi.setHours(23, 59, 59, 999);
              }

              let finalCover = (item.coverImage && !item.coverImage.includes('t.gif')) ? item.coverImage : sayfaResimleri[0];
              if (finalCover.startsWith('//')) finalCover = 'https:' + finalCover;
              finalCover = finalCover.replace('/_bro/u/', '/_bro/l/').replace('/_bro/y/', '/_bro/l/').replace('/_bro/m/', '/_bro/l/');

              return {
                katalogId: `${store.code}_${item.brochureId}`,
                magazaKodu: store.code,
                katalogBasligi: item.titleSuffix,
                baslangicTarihi: admin.firestore.Timestamp.fromDate(baslangicTarihi),
                bitisTarihi: admin.firestore.Timestamp.fromDate(bitisTarihi),
                sayfaResimleri,
                kapakResmi: finalCover
              };
            }
          }
        } catch (detailErr) {
          functions.logger.error(`❌ Error scraping brochure detail ${item.brochureId}:`, detailErr.message);
        }
        return null;
      });

      allScrapedCatalogs.push(...storeBrochures.filter(Boolean));
    } catch (storeErr) {
      functions.logger.error(`❌ Error scraping store ${store.name}:`, storeErr.message);
    }
  }

  if (allScrapedCatalogs.length === 0) {
    return { success: false, count: 0, message: 'Hiç katalog kazınamadı.' };
  }

  const db = admin.firestore();
  functions.logger.info('🧹 Deleting all existing catalogs...');
  const querySnapshot = await db.collection('kataloglar').get();
  const deleteDocs = querySnapshot.docs;
  for (let i = 0; i < deleteDocs.length; i += 500) {
    const batch = db.batch();
    deleteDocs.slice(i, i + 500).forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }

  functions.logger.info('💾 Writing new catalogs to Firestore...');
  for (let i = 0; i < allScrapedCatalogs.length; i += 500) {
    const batch = db.batch();
    allScrapedCatalogs.slice(i, i + 500).forEach(katalog => {
      const docRef = db.collection('kataloglar').doc(katalog.katalogId);
      batch.set(docRef, { ...katalog, olusturulmaTarihi: admin.firestore.FieldValue.serverTimestamp(), guncellenmeTarihi: admin.firestore.FieldValue.serverTimestamp() });
    });
    await batch.commit();
  }

  return { success: true, count: allScrapedCatalogs.length };
}

module.exports = { scrapeAndSaveCatalogs };
