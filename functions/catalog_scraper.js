const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cheerio = require('cheerio');

const STORES = [
  { code: 'a101', name: 'A101', url: 'https://www.akakce.com/brosurler/a101' },
  { code: 'bim', name: 'BİM', url: 'https://www.akakce.com/brosurler/bim' },
  { code: 'sok', name: 'ŞOK', url: 'https://www.akakce.com/brosurler/sok' },
  { code: 'migros', name: 'Migros', url: 'https://www.akakce.com/brosurler/migros' },
  { code: 'carrefoursa', name: 'CarrefourSA', url: 'https://www.akakce.com/brosurler/carrefoursa' },
  { code: 'cagri', name: 'Çağrı', url: 'https://www.akakce.com/brosurler/cagrihipermarket' },
  { code: 'happycenter', name: 'HappyCenter', url: 'https://www.akakce.com/brosurler/happy-center' },
  { code: 'macrocenter', name: 'MacroCenter', url: 'https://www.akakce.com/brosurler/macrocenter' },
  { code: 'getirbuyuk', name: 'GetirBüyük', url: 'https://www.akakce.com/brosurler/getirbuyuk' },
  { code: 'file', name: 'File', url: 'https://www.akakce.com/brosurler/filemarket' },
  { code: 'hakmar', name: 'Hakmar', url: 'https://www.akakce.com/brosurler/hakmarexpress' },
  { code: 'gratis', name: 'Gratis', url: 'https://www.akakce.com/brosurler/gratis' },
  { code: 'watsons', name: 'Watsons', url: 'https://www.akakce.com/brosurler/watsons' },
  { code: 'kooperatifmarket', name: 'Kooperatif Market', url: 'https://www.akakce.com/brosurler/kooperatifmarket' },
  { code: 'metro', name: 'Metro', url: 'https://www.akakce.com/brosurler/metro-tr' },
  { code: 'bizim', name: 'Bizim', url: 'https://www.akakce.com/brosurler/bizimtoptan' },
  { code: 'teknosa', name: 'Teknosa', url: 'https://www.akakce.com/brosurler/teknosacom' },
  { code: 'vatan', name: 'Vatan', url: 'https://www.akakce.com/brosurler/vatanbilgisayar' }
];

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const { spawnSync } = require('child_process');

/**
 * Validates if the returned HTML is valid catalog content and not a WAF block/error page.
 */
function isValidHtml(html, minLength = 3000) {
  if (!html || html.length < minLength) return false;
  const lower = html.toLowerCase();
  if (lower.includes('403 - forbidden') || lower.includes('access is denied') || lower.includes('robot verification')) {
    return false;
  }
  return true;
}

/**
 * Helper to process array items in parallel chunks of size concurrency
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
 * Speed-Optimized Multi-Stage HTML Fetcher:
 * 1. Direct Fetch with Googlebot UA (1.5s quick timeout - ~25ms ultra-fast for unblocked stores)
 * 2. Google Translate Proxy (6s timeout - ~400ms WAF 403 bypass for Cloudflare protected stores)
 * 3. Direct Fetch with WhatsApp UA (2s quick timeout - fast mobile fallback)
 * 4. Microlink HTML API Proxy (6s timeout)
 * 5. Native OS curl spawnSync (8s timeout)
 */
async function fetchHtmlWithFallback(targetUrl, timeoutMs = 12000) {
  // Stage 1 (Fastest): Direct Fetch with Googlebot UA
  try {
    const res = await fetch(targetUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
      },
      signal: AbortSignal.timeout(1500)
    });
    if (res.ok) {
      const html = await res.text();
      if (isValidHtml(html, 4000)) {
        return html;
      }
    }
  } catch (e) {
    functions.logger.debug(`Stage 1 (Googlebot UA) info:`, e.message);
  }

  // Stage 2 (Cloud WAF Bypass Proxy): Google Translate Proxy
  try {
    const parsedUrl = new URL(targetUrl);
    const proxyHost = parsedUrl.hostname.replace(/\./g, '-') + '.translate.goog';
    const translateProxyUrl = `https://${proxyHost}${parsedUrl.pathname}${parsedUrl.search}?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;
    
    const proxyRes = await fetch(translateProxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
      },
      signal: AbortSignal.timeout(6000)
    });
    if (proxyRes.ok) {
      const html = await proxyRes.text();
      if (isValidHtml(html, 3000)) {
        return html;
      }
    }
  } catch (e) {
    functions.logger.debug(`Stage 2 (Translate Proxy) info:`, e.message);
  }

  // Stage 3 (Fast Mobile): Direct Fetch with WhatsApp UA
  try {
    const res = await fetch(targetUrl, {
      headers: {
        'User-Agent': 'WhatsApp/2.23.4.15 A',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
      },
      signal: AbortSignal.timeout(2000)
    });
    if (res.ok) {
      const html = await res.text();
      if (isValidHtml(html, 4000)) {
        return html;
      }
    }
  } catch (e) {
    functions.logger.debug(`Stage 3 (WhatsApp UA) info:`, e.message);
  }

  // Stage 4: Fallback - Microlink Proxy
  try {
    const microlinkUrl = `https://api.microlink.io/?url=${encodeURIComponent(targetUrl)}&data.html.selector=html&data.html.type=html`;
    const res = await fetch(microlinkUrl, { signal: AbortSignal.timeout(6000) });
    if (res.ok) {
      const json = await res.json();
      const html = json.data?.html || '';
      if (isValidHtml(html, 3000)) {
        return html;
      }
    }
  } catch (e) {
    functions.logger.debug(`Stage 4 (Microlink Proxy) info:`, e.message);
  }

  // Stage 5: Fallback - Native OS curl spawnSync
  try {
    const curlArgs = [
      '-s', '-L',
      '--max-time', '6',
      '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      '-H', 'Accept-Language: tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
      targetUrl
    ];
    const curlResult = spawnSync('curl', curlArgs, { encoding: 'utf-8', timeout: 8000 });
    if (!curlResult.error && isValidHtml(curlResult.stdout, 4000)) {
      return curlResult.stdout;
    }
  } catch (e) {
    functions.logger.debug(`Stage 5 (curl) info:`, e.message);
  }

  functions.logger.warn(`❌ All 5 fetch strategies failed for ${targetUrl}`);
  return null;
}

const MONTHS_MAP = {
  'ocak': 0, 'subat': 1, 'şubat': 1, 'mart': 2, 'nisan': 3,
  'mayis': 4, 'mayıs': 4, 'haziran': 5, 'temmuz': 6, 'agustos': 7, 'ağustos': 7,
  'eylul': 8, 'eylül': 8, 'ekim': 9, 'kasim': 10, 'kasım': 10, 'aralik': 11, 'aralık': 11
};

/**
 * Extracts year from URL (e.g. /brosurler/bim-24-mart-2026...) or defaults to current year.
 */
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

/**
 * Parses start and end dates strictly from detail page DOM element span#br_s text.
 * Example spanTexts:
 * - "1 Temmuz - 31 Temmuz" -> Start: 01.07.2026 00:00:00, End: 31.07.2026 23:59:59
 * - "29 Temmuz - 11 Ağustos" -> Start: 29.07.2026 00:00:00, End: 11.08.2026 23:59:59
 * - "24 Temmuz" -> Start: 24.07.2026 00:00:00, End: 24.07.2026 23:59:59
 */
function parseDatesFromSpan(spanText, urlYear = new Date().getFullYear()) {
  if (!spanText) return null;
  const normalized = spanText.toLowerCase().replace(/\s+/g, ' ').trim();
  
  // Split by dash / en-dash / em-dash
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
      const startDate = new Date(urlYear, startPart.month, startPart.day, 0, 0, 0, 0);
      let endYear = urlYear;
      if (endPart.month < startPart.month) {
        endYear = urlYear + 1;
      }
      const endDate = new Date(endYear, endPart.month, endPart.day, 23, 59, 59, 999);
      return { startDate, endDate };
    }
  } else if (parts.length === 1) {
    const singlePart = parseSinglePart(parts[0]);
    if (singlePart) {
      const startDate = new Date(urlYear, singlePart.month, singlePart.day, 0, 0, 0, 0);
      const endDate = new Date(urlYear, singlePart.month, singlePart.day, 23, 59, 59, 999);
      return { startDate, endDate };
    }
  }
  
  return null;
}

/**
 * Fallback: parses start date from relative URL if span#br_s is missing in DOM.
 * Example: /brosurler/bim-24-mart-2026-aktuel-katalogu-indirimli-urunler-56190
 */
function parseDateFromUrl(url) {
  const match = url.match(/(\d+)-([a-zA-ZğüşöçıİĞÜŞÖÇI]+)-(\d{4})/);
  if (match) {
    const day = parseInt(match[1], 10);
    const monthStr = match[2].toLowerCase();
    const year = parseInt(match[3], 10);
    const month = MONTHS_MAP[monthStr] !== undefined ? MONTHS_MAP[monthStr] : 0;
    return new Date(year, month, day, 0, 0, 0, 0);
  }
  return new Date();
}

/**
 * Main scraper function for active catalog brochures.
 */
async function scrapeAndSaveCatalogs() {
  functions.logger.info('🚀 Active Catalog scraping process started...');
  const allScrapedCatalogs = [];

  for (const store of STORES) {
    try {
      functions.logger.info(`🔍 Fetching catalog list for ${store.name} from ${store.url}...`);
      
      const html = await fetchHtmlWithFallback(store.url, 15000);

      if (!html) {
        functions.logger.warn(`⚠️ Failed to fetch catalog page for ${store.name} via all mechanisms.`);
        continue;
      }

      const $ = cheerio.load(html);
      const catalogItems = [];

      // Parse catalog lists inside ul#BLI
      $('ul#BLI li').each((i, el) => {
        const aTag = $(el).find('a');
        let href = aTag.attr('href') || '';
        
        // Clean proxy prefix if present from Google Translate
        if (href.includes('.translate.goog')) {
          try {
            const u = new URL(href);
            href = u.pathname;
          } catch (e) {}
        }

        if (href.includes('/brosurler/')) {
          // Extract cover thumbnail from style (background: url(...))
          const imgStyle = aTag.find('.dt img').attr('style') || '';
          const bgUrlMatch = imgStyle.match(/url\((?:&quot;|"|')?([^)'"]+?)(?:&quot;|"|')?\)/);
          let coverImage = '';
          if (bgUrlMatch) {
            coverImage = bgUrlMatch[1];
            if (coverImage.startsWith('//')) {
              coverImage = 'https:' + coverImage;
            }
          }

          // Suffix catalog title
          const titleSuffix = aTag.find('.blid .bn').text().trim() || 'Aktüel Kataloğu';
          const timeRemainingText = aTag.find('span.b').text().trim();
          
          // Brochure ID from url end
          const idMatch = href.match(/(\d+)$/);
          const brochureId = idMatch ? idMatch[1] : '';

          if (brochureId) {
            catalogItems.push({
              brochureId,
              href,
              coverImage,
              titleSuffix,
              timeRemainingText
            });
          }
        }
      });

      functions.logger.info(`Found ${catalogItems.length} brochures for ${store.name}.`);

      // Scrape detail pages concurrently in batches of 5
      const storeBrochures = await mapConcurrent(catalogItems, 5, async (item) => {
        try {
          const detailUrl = item.href.startsWith('http') ? item.href : `https://www.akakce.com${item.href}`;
          functions.logger.info(`   📄 Scraping detail page: ${detailUrl}`);

          const detailHtml = await fetchHtmlWithFallback(detailUrl, 8000);

          if (detailHtml) {
            const $detail = cheerio.load(detailHtml);
            
            const sayfaResimleri = [];
            $detail('#BP_W .p img').each((i, el) => {
              let src = $(el).attr('data-src') || $(el).attr('src');
              if (src && !src.includes('t.gif')) {
                if (src.startsWith('//')) {
                  src = 'https:' + src;
                }
                // Convert low-res thumbnail paths (/l/, /y/, /m/) to high-res upload path (/u/)
                src = src.replace('/_bro/l/', '/_bro/u/')
                         .replace('/_bro/y/', '/_bro/u/')
                         .replace('/_bro/m/', '/_bro/u/');
                
                sayfaResimleri.push(src);
              }
            });

            if (sayfaResimleri.length > 0) {
              const urlYear = parseYearFromUrl(item.href);
              const dateSpanText = $detail('#br_s').text().trim();
              const parsedSpanDates = parseDatesFromSpan(dateSpanText, urlYear);

              let baslangicTarihi;
              let bitisTarihi;

              if (parsedSpanDates) {
                baslangicTarihi = parsedSpanDates.startDate;
                bitisTarihi = parsedSpanDates.endDate;
                functions.logger.info(`   📅 Parsed dates from span#br_s for brochure ${item.brochureId}: ${baslangicTarihi.toLocaleDateString('tr-TR')} - ${bitisTarihi.toLocaleDateString('tr-TR')}`);
              } else {
                // Fallback: parse start date from URL slug, end date = start date + 7 days
                baslangicTarihi = parseDateFromUrl(item.href);
                bitisTarihi = new Date(baslangicTarihi.getTime() + 7 * 24 * 60 * 60 * 1000);
                bitisTarihi.setHours(23, 59, 59, 999);
                functions.logger.info(`   📅 Fallback dates for brochure ${item.brochureId}: ${baslangicTarihi.toLocaleDateString('tr-TR')} - ${bitisTarihi.toLocaleDateString('tr-TR')}`);
              }

              // Use first page image as cover if cover thumbnail is empty or a placeholder
              let finalCover = (item.coverImage && !item.coverImage.includes('t.gif'))
                ? item.coverImage
                : sayfaResimleri[0];

              if (finalCover.startsWith('//')) {
                finalCover = 'https:' + finalCover;
              }
              // Convert to large thumbnail path (/l/) for fast grid listing
              finalCover = finalCover.replace('/_bro/u/', '/_bro/l/')
                                     .replace('/_bro/y/', '/_bro/l/')
                                     .replace('/_bro/m/', '/_bro/l/');

              return {
                katalogId: `${store.code}_${item.brochureId}`,
                magazaKodu: store.code,
                katalogBasligi: item.titleSuffix,
                baslangicTarihi,
                bitisTarihi,
                sayfaResimleri,
                kapakResmi: finalCover
              };
            } else {
              functions.logger.warn(`   ⚠️ No pages found inside brochure ${item.brochureId}. Skipping.`);
            }
          }
        } catch (detailErr) {
          functions.logger.error(`❌ Error scraping brochure detail ${item.brochureId}:`, detailErr.message);
        }
        return null;
      });

      const validStoreBrochures = storeBrochures.filter(Boolean);
      allScrapedCatalogs.push(...validStoreBrochures);

    } catch (storeErr) {
      functions.logger.error(`❌ Error scraping store ${store.name}:`, storeErr.message);
    }
  }

  functions.logger.info(`✨ Scraping completed. Total catalogs scraped: ${allScrapedCatalogs.length}`);

  if (allScrapedCatalogs.length === 0) {
    functions.logger.warn('⚠️ No catalogs scraped. Keeping existing data to prevent blank screen.');
    return { success: false, count: 0, message: 'Hiç katalog kazınamadı.' };
  }

  const db = admin.firestore();

  // 1. Delete all existing catalogs to ensure fresh reload (matching coupons scraper)
  functions.logger.info('🧹 Deleting all existing catalogs from Firestore...');
  const querySnapshot = await db.collection('kataloglar').get();
  const deleteDocs = querySnapshot.docs;
  const deleteChunks = [];
  
  for (let i = 0; i < deleteDocs.length; i += 500) {
    deleteChunks.push(deleteDocs.slice(i, i + 500));
  }

  for (const chunk of deleteChunks) {
    const batch = db.batch();
    chunk.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
  }
  functions.logger.info(`Deleted ${deleteDocs.length} old catalogs.`);

  // 2. Add newly scraped catalogs
  functions.logger.info('💾 Saving new catalogs to Firestore...');
  const writeChunks = [];
  for (let i = 0; i < allScrapedCatalogs.length; i += 500) {
    writeChunks.push(allScrapedCatalogs.slice(i, i + 500));
  }

  for (const chunk of writeChunks) {
    const batch = db.batch();
    chunk.forEach((catalog) => {
      const docRef = db.collection('kataloglar').doc(catalog.katalogId);
      
      // Convert Date objects to Firestore Timestamp
      const dataToSave = {
        ...catalog,
        baslangicTarihi: admin.firestore.Timestamp.fromDate(catalog.baslangicTarihi),
        bitisTarihi: admin.firestore.Timestamp.fromDate(catalog.bitisTarihi),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.set(docRef, dataToSave);
    });
    await batch.commit();
  }

  functions.logger.info('🎉 Catalog sync finished successfully.');
  return { success: true, count: allScrapedCatalogs.length };
}

module.exports = {
  scrapeAndSaveCatalogs
};
