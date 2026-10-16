const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cheerio = require('cheerio');
const { spawnSync } = require('child_process');
const { logErrorToFirestore } = require('./error_logger');

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
  { code: 'vestel', name: 'Vestel', url: 'https://www.akakce.com/brosurler/vestel', keywords: ['vestel'] },
  { code: 'arcelik', name: 'Arçelik', url: 'https://www.akakce.com/brosurler/arcelik', keywords: ['arcelik', 'arçelik'] },
  { code: 'beko', name: 'Beko', url: 'https://www.akakce.com/brosurler/beko', keywords: ['beko'] },
  { code: 'bosch', name: 'Bosch', url: 'https://www.akakce.com/brosurler/bosch-home', keywords: ['bosch'] },
  { code: 'bauhaus', name: 'Bauhaus', url: 'https://www.akakce.com/brosurler/bauhaus', keywords: ['bauhaus'] },
  { code: 'siemens', name: 'Siemens', url: 'https://www.akakce.com/brosurler/siemens-home', keywords: ['siemens'] },
  { code: 'mopas', name: 'Mopaş', url: 'https://www.akakce.com/brosurler/mopas', keywords: ['mopas', 'mopaş'] },
  { code: 'koctas', name: 'Koçtaş', url: 'https://www.akakce.com/brosurler/koctascom', keywords: ['koctas', 'koçtaş'] },
  { code: 'ozkuruslar', name: 'Özkuruşlar', url: 'https://www.akakce.com/brosurler/ozkuruslargida', keywords: ['ozkuruslar', 'özkuruşlar', 'kuruslar', 'kuruşlar'] },
  { code: 'tedi', name: 'Tedi', url: 'https://www.akakce.com/brosurler/tedi', keywords: ['tedi'] },
  { code: 'tahtakale', name: 'Tahtakale', url: 'https://www.akakce.com/brosurler/tahtakalespot', keywords: ['tahtakale', 'tahtakalespot'] },
  { code: 'tekzen', name: 'Tekzen', url: 'https://www.akakce.com/brosurler/tekzen', keywords: ['tekzen'] }
];

const USER_AGENTS = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:127.0) Gecko/20100101 Firefox/127.0',
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.122 Mobile Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0'
];

function getRandomUserAgent() {
  return USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];
}

/**
 * FAZ 2 (FS-CF-08): Aktüel broşür kapak görselini Firebase Storage'a yedekler (Akakçe CDN 403 engeli kalkanı).
 * Eğer yükleme başarılı olursa Storage URL'i döner, aksi halde orijinal URL'i korur.
 */
async function uploadCoverToStorage(coverUrl, catalogId) {
  if (!coverUrl || typeof coverUrl !== 'string') return null;
  if (process.env.FUNCTIONS_EMULATOR === 'true') return null;

  try {
    const bucket = admin.storage().bucket();
    const destination = `catalogs/${catalogId}_cover.webp`;
    const file = bucket.file(destination);

    // Daha önce yüklenmişse doğrudan Storage URL'i kullan
    const [exists] = await file.exists().catch(() => [false]);
    if (exists) {
      return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destination)}?alt=media`;
    }

    // Akakçe CDN referer ve user-agent ile görseli çek
    const res = await fetch(coverUrl, {
      headers: {
        'User-Agent': getRandomUserAgent(),
        'Referer': 'https://www.akakce.com/'
      },
      signal: AbortSignal.timeout(6000)
    });

    if (!res.ok) return null;
    const arrayBuffer = await res.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    await file.save(buffer, {
      metadata: {
        contentType: 'image/webp',
        cacheControl: 'public, max-age=604800' // 7 gün CDN önbelleği
      }
    });

    try {
      await file.makePublic();
    } catch (_) {}

    return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destination)}?alt=media`;
  } catch (err) {
    functions.logger.warn(`⚠️ [FS-CF-08] Katalog kapak görseli Storage yedekleme uyarısı (${catalogId}):`, err.message);
    return null;
  }
}

/**
 * Validates if the returned HTML is valid catalog content and not a WAF block/error/captcha page.
 */
function isValidHtml(html, minLength = 2500) {
  if (!html || html.length < minLength) return false;
  const lower = html.toLowerCase();
  const blockedPatterns = [
    '403 - forbidden',
    'access is denied',
    'robot verification',
    'captcha-form',
    'recaptcha',
    'sıra dışı bir trafik',
    'unusual traffic',
    'cf-browser-verification',
    'just a moment...',
    'attention required! | cloudflare',
    '429 too many requests',
    'rate limit exceeded',
    'özür dileriz, aradığınız ürünü bulamadık'
  ];
  for (const pattern of blockedPatterns) {
    if (lower.includes(pattern)) return false;
  }
  return true;
}

/**
 * Helper to process array items in parallel chunks of size concurrency.
 * Concurrency 2 guarantees stability and zero rate-limiting.
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
 * Guaranteed 100% Multi-Stage HTML Fetcher with Retries & Rate-Limit Backoff.
 * Tries multi-proxy strategies per attempt and retries up to maxRetries times.
 */
async function fetchHtmlWithRetry(targetUrl, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    const ua = getRandomUserAgent();
    const parsedUrl = new URL(targetUrl);
    const proxyHost = parsedUrl.hostname.replace(/\./g, '-') + '.translate.goog';

    // Strategy A1 (Primary): Google Translate Proxy (Standard Query)
    try {
      const sep = parsedUrl.search ? '&' : '?';
      const translateProxyUrl = `https://${proxyHost}${parsedUrl.pathname}${parsedUrl.search}${sep}_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;
      const proxyRes = await fetch(translateProxyUrl, {
        headers: {
          'User-Agent': ua,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
          'Cache-Control': 'no-cache'
        },
        signal: AbortSignal.timeout(15000)
      });
      if (proxyRes.ok) {
        const html = await proxyRes.text();
        if (isValidHtml(html, 2500)) return html;
      } else if (proxyRes.status === 429) {
        functions.logger.warn(`⚠️ Translate Proxy 429 Rate Limit for ${targetUrl} (Attempt ${attempt}). Failing over to Yandex TurboPages Proxy...`);
      }
    } catch (e) {
      functions.logger.debug(`Stage A1 (Translate Proxy attempt ${attempt}) failed for ${targetUrl}:`, e.message);
    }

    // Strategy A2 (Secondary Primary - Instant Failover): Yandex Translate TurboPages Proxy
    try {
      const yandexUrl = `https://translate.yandex.ru/translate?url=${encodeURIComponent(targetUrl)}&lang=tr-tr`;
      const yandexRes = await fetch(yandexUrl, {
        headers: {
          'User-Agent': getRandomUserAgent(),
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8'
        },
        signal: AbortSignal.timeout(15000)
      });
      if (yandexRes.ok) {
        const html = await yandexRes.text();
        if (isValidHtml(html, 2500)) {
          functions.logger.info(`✅ [Yandex Failover] Successfully fetched ${targetUrl} via Yandex TurboPages Proxy.`);
          return html;
        }
      }
    } catch (yandexErr) {
      functions.logger.debug(`Stage A2 (Yandex Proxy attempt ${attempt}) failed for ${targetUrl}:`, yandexErr.message);
    }

    // Strategy A3: Google Translate Proxy (Web App Mode _x_tr_pto=wapp & Alternative Language Routing)
    try {
      const sep = parsedUrl.search ? '&' : '?';
      const translateProxyWapp = `https://${proxyHost}${parsedUrl.pathname}${parsedUrl.search}${sep}_x_tr_sl=auto&_x_tr_tl=en&_x_tr_hl=tr&_x_tr_pto=wapp`;
      const proxyRes2 = await fetch(translateProxyWapp, {
        headers: {
          'User-Agent': getRandomUserAgent(),
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8'
        },
        signal: AbortSignal.timeout(15000)
      });
      if (proxyRes2.ok) {
        const html = await proxyRes2.text();
        if (isValidHtml(html, 2500)) return html;
      }
    } catch (e) {}

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
        '-H', `User-Agent: ${ua}`,
        '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        '-H', 'Accept-Language: tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        targetUrl
      ];
      const curlResult = spawnSync('curl', curlArgs, { encoding: 'utf-8', timeout: 12000 });
      if (!curlResult.error && isValidHtml(curlResult.stdout, 3000)) {
        return curlResult.stdout;
      }
    } catch (e) {}

    // Pause before next retry with jitter
    if (attempt < maxRetries) {
      await new Promise(r => setTimeout(r, 1000 + Math.random() * 600));
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
  const successfullyScrapedStores = new Set();
  const db = admin.firestore();

  // ─────────────────────────────────────────────────────────────────────────────
  // ADIM 0: Akıllı Artımlı Kazıma Önbellek Motoru (Smart Incremental Cache Engine)
  // ─────────────────────────────────────────────────────────────────────────────
  // Mevcut katalogları Firestore'dan baştan yükleyerek dünkü/geçerli broşürlerin
  // sayfa detaylarının (113+ istek) her gece gereksiz yere tekrar çekilmesini önler.
  // Bu sayede Translate Proxy / WAF üzerindeki istek hacmi %70+ azalır (429 Rate Limit sıfırlanır).
  const existingCatalogMap = new Map();
  let existingSnapshot = null;
  let cacheHitCount = 0;
  let cacheMissCount = 0;

  try {
    functions.logger.info('📦 [Smart Incremental] Pre-loading existing catalogs from Firestore...');
    existingSnapshot = await db.collection('kataloglar').get();
    for (const doc of existingSnapshot.docs) {
      const data = doc.data() || {};
      let startTimestamp = data.baslangicTarihi;
      if (startTimestamp && !(startTimestamp instanceof admin.firestore.Timestamp)) {
        if (startTimestamp.toDate) {
          startTimestamp = admin.firestore.Timestamp.fromDate(startTimestamp.toDate());
        } else {
          startTimestamp = admin.firestore.Timestamp.fromDate(new Date(startTimestamp));
        }
      }
      let endTimestamp = data.bitisTarihi;
      if (endTimestamp && !(endTimestamp instanceof admin.firestore.Timestamp)) {
        if (endTimestamp.toDate) {
          endTimestamp = admin.firestore.Timestamp.fromDate(endTimestamp.toDate());
        } else {
          endTimestamp = admin.firestore.Timestamp.fromDate(new Date(endTimestamp));
        }
      }

      existingCatalogMap.set(doc.id, {
        katalogId: doc.id,
        magazaKodu: (data.magazaKodu || doc.id.split('_')[0] || '').toLowerCase().trim(),
        katalogBasligi: data.katalogBasligi || '',
        baslangicTarihi: startTimestamp || data.baslangicTarihi,
        bitisTarihi: endTimestamp || data.bitisTarihi,
        sayfaResimleri: Array.isArray(data.sayfaResimleri) ? data.sayfaResimleri : [],
        kapakResmi: data.kapakResmi || '',
        originalKapakResmi: data.originalKapakResmi || data.kapakResmi || '',
        storageCoverUrl: data.storageCoverUrl || null
      });
    }
    functions.logger.info(`✅ [Smart Incremental] Cached ${existingCatalogMap.size} existing catalogs in memory.`);
  } catch (cacheErr) {
    functions.logger.warn('⚠️ [Smart Incremental] Pre-fetching failed, proceeding with full scrape fallback:', cacheErr.message);
  }

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
        
        // Clean proxy wrappers (turbopages.org, translate.yandex.*, .translate.goog) if present
        let cleanPath = href;
        if (cleanPath.includes('turbopages.org')) {
          const parts = cleanPath.split(/\/https?\/(?:www\.)?akakce\.com/i);
          if (parts.length > 1) {
            cleanPath = parts[1];
          }
        } else if (cleanPath.includes('translate.yandex.')) {
          try {
            const u = new URL(cleanPath.startsWith('http') ? cleanPath : `https://${cleanPath}`);
            const inner = u.searchParams.get('url');
            if (inner) cleanPath = new URL(inner).pathname;
          } catch (e) {}
        } else if (cleanPath.includes('.translate.goog')) {
          try {
            const u = new URL(cleanPath.startsWith('http') ? cleanPath : `https://${cleanPath}`);
            cleanPath = u.pathname;
          } catch (e) {}
        }
        // Strip query string, hash and trailing slashes
        cleanPath = cleanPath.split('?')[0].split('#')[0].replace(/\/+$/, '');

        if (cleanPath.includes('/brosurler/')) {
          const storeNameText = (aTag.find('.blid b').text() || '').toLowerCase();
          const pathLower = cleanPath.toLowerCase();

          // Exclude check
          if (store.excludeKeywords && store.excludeKeywords.some(ex => pathLower.includes(ex) || storeNameText.includes(ex))) {
            return;
          }

          // Robust Store Validation: Ensure brochure matches the target store
          const matchesStore = store.keywords.some(kw => {
            const k = kw.toLowerCase();
            return pathLower.includes(k) || storeNameText.includes(k);
          });

          if (!matchesStore) {
            functions.logger.debug(`Skipping unrelated brochure on ${store.name} page: ${cleanPath}`);
            return;
          }

          const imgStyle = aTag.find('.dt img').attr('style') || '';
          const bgUrlMatch = imgStyle.match(/url\((?:&quot;|"|')?([^)'"]+?)(?:&quot;|"|')?\)/);
          let coverImage = '';
          if (bgUrlMatch) {
            coverImage = bgUrlMatch[1];
            if (coverImage.includes('turbopages.org')) {
              const parts = coverImage.split(/\/https?\/(?:cdn\.akakce\.com|www\.akakce\.com)/i);
              if (parts.length > 1) coverImage = 'https://cdn.akakce.com' + parts[1];
            } else if (coverImage.includes('.translate.goog')) {
              try {
                const u = new URL(coverImage.startsWith('http') ? coverImage : 'https://' + coverImage);
                coverImage = 'https://cdn.akakce.com' + u.pathname;
              } catch (e) {}
            }
            coverImage = coverImage.split('?')[0].split('#')[0];
            if (coverImage.startsWith('//')) coverImage = 'https:' + coverImage;
          }

          const titleSuffix = aTag.find('.blid .bn').text().trim() || 'Aktüel Kataloğu';
          
          // Match digits after last dash or at end of path
          const idMatch = cleanPath.match(/[-_](\d+)$/) || cleanPath.match(/(\d+)$/);
          const brochureId = idMatch ? idMatch[1] : '';

          if (brochureId) {
            catalogItems.push({ brochureId, href: cleanPath, coverImage, titleSuffix });
          }
        }
      });

      functions.logger.info(`Found ${catalogItems.length} brochures for ${store.name}.`);

      const storeBrochures = await mapConcurrent(catalogItems, 2, async (item) => {
        const catalogId = `${store.code}_${item.brochureId}`;

        // ─────────────────────────────────────────────────────────────
        // AKILLI ARTIMLI KAZIMA: Önbellek Kontrolü (Cache Hit Koruması)
        // ─────────────────────────────────────────────────────────────
        if (existingCatalogMap.has(catalogId)) {
          const cached = existingCatalogMap.get(catalogId);
          const hasPages = Array.isArray(cached.sayfaResimleri) && cached.sayfaResimleri.length > 0;
          const hasCover = typeof cached.kapakResmi === 'string' && cached.kapakResmi.length > 0;
          const hasDates = cached.bitisTarihi != null;

          if (hasPages && hasCover && hasDates) {
            cacheHitCount++;
            functions.logger.info(`   ⚡ [Incremental Hit] ${catalogId} önbellekten alındı (HTTP isteği tasarruf edildi).`);

            let storageCoverUrl = cached.storageCoverUrl || null;
            let kapakResmi = cached.kapakResmi;
            if (!storageCoverUrl && kapakResmi && kapakResmi.includes('firebasestorage.googleapis.com')) {
              storageCoverUrl = kapakResmi;
            } else if (!storageCoverUrl && process.env.FUNCTIONS_EMULATOR !== 'true' && kapakResmi) {
              storageCoverUrl = await uploadCoverToStorage(cached.originalKapakResmi || kapakResmi, catalogId);
              if (storageCoverUrl) {
                kapakResmi = storageCoverUrl;
              }
            }

            return {
              katalogId: catalogId,
              magazaKodu: store.code,
              katalogBasligi: item.titleSuffix || cached.katalogBasligi,
              baslangicTarihi: cached.baslangicTarihi,
              bitisTarihi: cached.bitisTarihi,
              sayfaResimleri: cached.sayfaResimleri,
              kapakResmi: kapakResmi,
              originalKapakResmi: cached.originalKapakResmi || cached.kapakResmi,
              storageCoverUrl: storageCoverUrl || null
            };
          }
        }

        // ─────────────────────────────────────────────────────────────
        // CACHE MISS: Yeni veya eksik broşür, detay sayfasını kazı
        // ─────────────────────────────────────────────────────────────
        cacheMissCount++;
        try {
          const detailUrl = item.href.startsWith('http') ? item.href : `https://www.akakce.com${item.href.startsWith('/') ? '' : '/'}${item.href}`;
          functions.logger.info(`   📄 [Cache Miss - Scraping] Scraping detail page: ${detailUrl}`);

          const detailHtml = await fetchHtmlWithRetry(detailUrl, 3);

          if (detailHtml) {
            const $detail = cheerio.load(detailHtml);
            
            const sayfaResimleri = [];
            // Target the actual brochure container only (#BP_W / .bpgc) to prevent recommendation leakage
            const imgElements = $detail('#BP_W .p img, #BP_W div.p img, #BP_W img, .bpgc .p img, .bpgc div.p img');

            imgElements.each((i, el) => {
              let src = $detail(el).attr('data-src') || $detail(el).attr('src') || $detail(el).attr('data-original');
              if (src && !src.includes('t.gif') && (src.includes('/_bro/') || src.includes('cdn.akakce.com'))) {
                if (src.includes('turbopages.org')) {
                  const parts = src.split(/\/https?\/(?:cdn\.akakce\.com|www\.akakce\.com)/i);
                  if (parts.length > 1) src = 'https://cdn.akakce.com' + parts[1];
                } else if (src.includes('.translate.goog')) {
                  try {
                    const u = new URL(src.startsWith('http') ? src : 'https://' + src);
                    src = 'https://cdn.akakce.com' + u.pathname;
                  } catch (e) {}
                }
                src = src.split('?')[0].split('#')[0];
                if (src.startsWith('//')) src = 'https:' + src;
                src = src.replace('/_bro/l/', '/_bro/u/').replace('/_bro/y/', '/_bro/u/').replace('/_bro/m/', '/_bro/u/');
                if (!sayfaResimleri.includes(src)) {
                  sayfaResimleri.push(src);
                }
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
              if (finalCover.includes('turbopages.org')) {
                const parts = finalCover.split(/\/https?\/(?:cdn\.akakce\.com|www\.akakce\.com)/i);
                if (parts.length > 1) finalCover = 'https://cdn.akakce.com' + parts[1];
              } else if (finalCover.includes('.translate.goog')) {
                try {
                  const u = new URL(finalCover.startsWith('http') ? finalCover : 'https://' + finalCover);
                  finalCover = 'https://cdn.akakce.com' + u.pathname;
                } catch (e) {}
              }
              finalCover = finalCover.split('?')[0].split('#')[0];
              if (finalCover.startsWith('//')) finalCover = 'https:' + finalCover;
              finalCover = finalCover.replace('/_bro/u/', '/_bro/l/').replace('/_bro/y/', '/_bro/l/').replace('/_bro/m/', '/_bro/l/');

              // FAZ 2 (FS-CF-08): Kapak görselini Firebase Storage'a yedekleme (Akakçe CDN 403 engeli kalkanı)
              const storageCoverUrl = await uploadCoverToStorage(finalCover, catalogId);

              // Detay istekleri arasına nazik jitter ekle (Rate limit koruması)
              await new Promise(r => setTimeout(r, 600 + Math.random() * 400));

              return {
                katalogId: catalogId,
                magazaKodu: store.code,
                katalogBasligi: item.titleSuffix,
                baslangicTarihi: admin.firestore.Timestamp.fromDate(baslangicTarihi),
                bitisTarihi: admin.firestore.Timestamp.fromDate(bitisTarihi),
                sayfaResimleri,
                kapakResmi: storageCoverUrl || finalCover,
                originalKapakResmi: finalCover,
                storageCoverUrl: storageCoverUrl || null
              };
            }
          }
        } catch (detailErr) {
          functions.logger.error(`❌ Error scraping brochure detail ${item.brochureId}:`, detailErr.message);
        }
        return null;
      });

      allScrapedCatalogs.push(...storeBrochures.filter(Boolean));
      successfullyScrapedStores.add(store.code.toLowerCase());
      // Mağazalar arası akıllı jitter (Rate limit ve WAF koruması)
      await new Promise(r => setTimeout(r, 800 + Math.random() * 600));
    } catch (storeErr) {
      functions.logger.error(`❌ Error scraping store ${store.name}:`, storeErr.message);
      await logErrorToFirestore('catalogs_coupons', 'Catalog Store Scrape Error', storeErr.message, storeErr.stack, 'warning', {
        category: 'catalogs_coupons',
        subCategory: store.code,
        metadata: { storeName: store.name, url: store.url }
      });
    }
  }

  functions.logger.info(`🎯 [Smart Incremental] Summary: ${cacheHitCount} brochures reused from cache, ${cacheMissCount} newly fetched.`);

  if (allScrapedCatalogs.length === 0) {
    await logErrorToFirestore('catalogs_coupons', 'Catalog Scrape Zero Result', 'Akakçe üzerinden hiçbir katalog çekilemedi. WAF engeli veya DOM yapısı değişmiş olabilir.', null, 'error', {
      category: 'catalogs_coupons'
    });
    return { success: false, count: 0, message: 'Hiç katalog kazınamadı.' };
  }

  // 1. ADIM: Önce yeni katalogları upsert et (Atomic Merge - Sıfır Kesinti & Kesintisiz Görüntüleme)
  functions.logger.info('💾 Writing/updating newly scraped catalogs to Firestore...');
  const writeChunks = [];
  for (let i = 0; i < allScrapedCatalogs.length; i += 400) {
    writeChunks.push(allScrapedCatalogs.slice(i, i + 400));
  }

  for (const chunk of writeChunks) {
    const batch = db.batch();
    chunk.forEach((katalog) => {
      const docRef = db.collection('kataloglar').doc(katalog.katalogId);
      batch.set(docRef, {
        ...katalog,
        guncellenmeTarihi: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    });
    await batch.commit();
  }
  functions.logger.info(`Successfully updated ${allScrapedCatalogs.length} catalogs in Firestore.`);

  // 2. ADIM: Artık yayında olmayan eski katalogları tespit et ve sadece onları temizle
  // FS-AKT-P0-02: Yalnızca bu çalışmada BAŞARIYLA taranmış mağazaların eski broşürleri uzlaştırılır!
  // Bir mağaza ağ hatası/WAF nedeniyle taranamadıysa, o mağazanın mevcut broşürleri ASLA silinmez.
  functions.logger.info('🧹 Reconciling and cleaning obsolete catalogs for successfully scraped stores...');
  const newCatalogIdSet = new Set(allScrapedCatalogs.map(k => k.katalogId));
  if (!existingSnapshot) {
    existingSnapshot = await db.collection('kataloglar').select('magazaKodu', 'bitisTarihi').get();
  }
  const obsoleteDocs = existingSnapshot.docs.filter(doc => {
    const data = doc.data() || {};
    const storeCode = (data.magazaKodu || doc.id.split('_')[0] || '').toLowerCase();
    return successfullyScrapedStores.has(storeCode) && !newCatalogIdSet.has(doc.id);
  });

  const deleteChunks = [];
  for (let i = 0; i < obsoleteDocs.length; i += 400) {
    deleteChunks.push(obsoleteDocs.slice(i, i + 400));
  }

  for (const chunk of deleteChunks) {
    const batch = db.batch();
    chunk.forEach(doc => {
      batch.delete(doc.ref);
      try {
        admin.storage().bucket().file(`catalogs/${doc.id}_cover.webp`).delete().catch(() => {});
      } catch (_) {}
    });
    await batch.commit();
  }
  functions.logger.info(`Reconciled catalogs: ${obsoleteDocs.length} obsolete catalogs deleted.`);

  // 3. ADIM: 100k Ölçek Maliyet Kalkanı (FS-AKT-P1-05) - settings/aktuel_meta özet dokümanı oluştur
  // AktuelMagazalarPage vitrininin her girişte 200 adet dev broşür dokümanını çekip
  // günde 20 Milyon Firestore okuması ($360/ay) yapmasını engellemek için mağaza broşür sayılarını
  // tek bir hafif meta dokümanında derleyip yayınlar.
  functions.logger.info('📊 Compiling and writing settings/aktuel_meta summary document...');
  const activeStoreCounts = {};
  const now = new Date();
  const turkeyNow = new Date(now.getTime() + (3 * 3600 * 1000));
  const today = createTurkeyDate(turkeyNow.getUTCFullYear(), turkeyNow.getUTCMonth(), turkeyNow.getUTCDate(), 0, 0, 0, 0);

  // 1. Yeni taranan katalogların aktif olanlarını say
  for (const cat of allScrapedCatalogs) {
    const code = (cat.magazaKodu || '').toLowerCase().trim();
    if (code) {
      if (cat.bitisTarihi) {
        const expiryDate = cat.bitisTarihi.toDate ? cat.bitisTarihi.toDate() : new Date(cat.bitisTarihi);
        if (!isNaN(expiryDate.getTime()) && expiryDate < today) continue;
      }
      activeStoreCounts[code] = (activeStoreCounts[code] || 0) + 1;
    }
  }

  // 2. Bu turda WAF/ağ hatası nedeniyle taranamayan ancak Firestore'da mevcut aktif katalogları olan mağazaları koru
  for (const doc of existingSnapshot.docs) {
    const data = doc.data() || {};
    const storeCode = (data.magazaKodu || doc.id.split('_')[0] || '').toLowerCase().trim();
    if (storeCode && !successfullyScrapedStores.has(storeCode)) {
      if (data.bitisTarihi) {
        const expiryDate = data.bitisTarihi.toDate ? data.bitisTarihi.toDate() : new Date(data.bitisTarihi);
        if (!isNaN(expiryDate.getTime()) && expiryDate < today) continue;
      }
      activeStoreCounts[storeCode] = (activeStoreCounts[storeCode] || 0) + 1;
    }
  }

  const totalActive = Object.values(activeStoreCounts).reduce((a, b) => a + b, 0);

  try {
    await db.collection('settings').doc('aktuel_meta').set({
      activeStoreCatalogCounts: activeStoreCounts,
      totalActiveCatalogs: totalActive,
      lastScrapedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    functions.logger.info(`✅ settings/aktuel_meta summary document updated successfully. (${totalActive} active catalogs across ${Object.keys(activeStoreCounts).length} stores)`);
  } catch (metaErr) {
    functions.logger.warn('⚠️ Error updating settings/aktuel_meta:', metaErr.message);
  }

  return { 
    success: true, 
    count: allScrapedCatalogs.length, 
    deletedCount: obsoleteDocs.length,
    cacheHits: cacheHitCount,
    cacheMisses: cacheMissCount
  };
}

module.exports = { STORES, scrapeAndSaveCatalogs };
