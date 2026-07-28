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

const WEEKDAYS_MAP = {
  'pazartesi': 1, 'sali': 2, 'salı': 2, 'carsamba': 3, 'çarşamba': 3,
  'persembe': 4, 'perşembe': 4, 'cuma': 5, 'cumartesi': 6, 'pazar': 0
};

/**
 * Parses start and end dates from detail page span#br_s text.
 */
function parseDatesFromSpan(spanText, baslangicTarihiFromUrl) {
  if (!spanText) return null;
  const normalized = spanText.toLowerCase().replace(/\s+/g, ' ').trim();
  
  const parts = normalized.split(/[-–]/);
  if (parts.length === 0) return null;

  const urlYear = baslangicTarihiFromUrl.getFullYear();
  
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
      const startDate = new Date(urlYear, startPart.month, startPart.day);
      startDate.setHours(0, 0, 0, 0);
      let endYear = urlYear;
      if (endPart.month < startPart.month) {
        endYear = urlYear + 1;
      }
      const endDate = new Date(endYear, endPart.month, endPart.day);
      endDate.setHours(23, 59, 59, 999);
      return { startDate, endDate };
    }
  } else if (parts.length === 1) {
    const singlePart = parseSinglePart(parts[0]);
    if (singlePart) {
      const startDate = new Date(urlYear, singlePart.month, singlePart.day);
      startDate.setHours(0, 0, 0, 0);
      const endDate = new Date(urlYear, singlePart.month, singlePart.day);
      endDate.setHours(23, 59, 59, 999);
      return { startDate, endDate };
    }
  }
  
  return null;
}

/**
 * Parses start date from relative URL.
 * Example: /brosurler/bim-24-mart-2026-aktuel-katalogu-indirimli-urunler-56190
 */
function parseDateFromUrl(url) {
  const match = url.match(/(\d+)-([a-zA-ZğüşöçıİĞÜŞÖÇI]+)-(\d{4})/);
  if (match) {
    const day = parseInt(match[1], 10);
    const monthStr = match[2].toLowerCase();
    const year = parseInt(match[3], 10);
    const month = MONTHS_MAP[monthStr] !== undefined ? MONTHS_MAP[monthStr] : 0;
    return new Date(year, month, day);
  }
  return new Date();
}

/**
 * Calculates end date based on remaining time text.
 */
function calculateEndDate(baslangicTarihi, timeRemainingText) {
  const normalizedText = timeRemainingText.toLowerCase().trim();
  const today = new Date();
  
  // "X gün kaldı"
  const gunMatch = normalizedText.match(/(\d+)\s+gün\s+kaldı/);
  if (gunMatch) {
    const days = parseInt(gunMatch[1], 10);
    const endDate = new Date(today.getTime() + days * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "X hafta kaldı"
  const haftaMatch = normalizedText.match(/(\d+)\s+hafta\s+kaldı/);
  if (haftaMatch) {
    const weeks = parseInt(haftaMatch[1], 10);
    const endDate = new Date(today.getTime() + weeks * 7 * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "X ay kaldı"
  const ayMatch = normalizedText.match(/(\d+)\s+ay\s+kaldı/);
  if (ayMatch) {
    const months = parseInt(ayMatch[1], 10);
    const endDate = new Date(today.getTime() + months * 30 * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "1 ay sonra başlıyor" etc.
  if (normalizedText.includes('başlıyor')) {
    const endDate = new Date(baslangicTarihi.getTime() + 7 * 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "Bugün son" or "Bugün son gün"
  if (normalizedText.includes('bugün son')) {
    const endDate = new Date(today);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "Yarın son"
  if (normalizedText.includes('yarın son')) {
    const endDate = new Date(today.getTime() + 24 * 60 * 60 * 1000);
    endDate.setHours(23, 59, 59, 999);
    return endDate;
  }

  // "Son gün Pazartesi" / "Son gün Salı" vb.
  const sonGunMatch = normalizedText.match(/son\s+gün\s+([a-zA-ZğüşöçıİĞÜŞÖÇI]+)/);
  if (sonGunMatch) {
    const dayName = sonGunMatch[1].toLowerCase();
    if (WEEKDAYS_MAP[dayName] !== undefined) {
      const targetDay = WEEKDAYS_MAP[dayName];
      const currentDay = today.getDay();
      let daysToAdd = (targetDay - currentDay + 7) % 7;
      if (daysToAdd === 0) daysToAdd = 7;
      const endDate = new Date(today.getTime() + daysToAdd * 24 * 60 * 60 * 1000);
      endDate.setHours(23, 59, 59, 999);
      return endDate;
    }
  }

  // Fallback: başlangıç tarihinden 7 gün sonra
  const endDate = new Date(baslangicTarihi.getTime() + 7 * 24 * 60 * 60 * 1000);
  endDate.setHours(23, 59, 59, 999);
  return endDate;
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
              let baslangicTarihi = parseDateFromUrl(item.href);
              let bitisTarihi = calculateEndDate(baslangicTarihi, item.timeRemainingText);

              // Extract precise dates from span#br_s on the detail page if present
              const dateSpanText = $detail('#br_s').text().trim();
              if (dateSpanText) {
                const parsedDates = parseDatesFromSpan(dateSpanText, baslangicTarihi);
                if (parsedDates) {
                  baslangicTarihi = parsedDates.startDate;
                  bitisTarihi = parsedDates.endDate;
                  functions.logger.info(`   📅 Date override for brochure ${item.brochureId}: ${baslangicTarihi.toLocaleDateString('tr-TR')} - ${bitisTarihi.toLocaleDateString('tr-TR')}`);
                }
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
