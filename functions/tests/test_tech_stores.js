const cheerio = require('cheerio');
const { spawnSync } = require('child_process');

const STORES_TEST = [
  { code: 'arcelik', name: 'Arçelik', url: 'https://www.akakce.com/brosurler/arcelik', keywords: ['arcelik', 'arçelik'] },
  { code: 'beko', name: 'Beko', url: 'https://www.akakce.com/brosurler/beko', keywords: ['beko'] },
  { code: 'bosch', name: 'Bosch', url: 'https://www.akakce.com/brosurler/bosch-home', keywords: ['bosch'] },
];

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

function isValidHtml(html, minLength = 2500) {
  if (!html || html.length < minLength) return false;
  const lower = html.toLowerCase();
  if (lower.includes('403 - forbidden') || lower.includes('access is denied') || lower.includes('robot verification')) {
    return false;
  }
  return true;
}

async function fetchHtmlWithRetry(targetUrl, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    // Strategy A (Primary): Google Translate Proxy
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
    } catch (e) {}

    // Strategy B: Googlebot UA
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

    // Strategy E: curl
    try {
      const curlArgs = [
        '-s', '-L',
        '--max-time', '10',
        '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        targetUrl
      ];
      const curlResult = spawnSync('curl', curlArgs, { encoding: 'utf-8', timeout: 12000 });
      if (!curlResult.error && isValidHtml(curlResult.stdout, 3000)) {
        return curlResult.stdout;
      }
    } catch (e) {}

    if (attempt < maxRetries) {
      await new Promise(r => setTimeout(r, 500));
    }
  }
  return null;
}

async function testStore(store) {
  console.log(`\n==============================================`);
  console.log(`Testing store: ${store.name} (${store.url})`);
  const listHtml = await fetchHtmlWithRetry(store.url, 2);
  if (!listHtml) {
    console.log(`❌ Failed to fetch list HTML for ${store.name}`);
    return;
  }

  const $list = cheerio.load(listHtml);
  const catalogItems = [];

  $list('ul#BLI li a').each((i, el) => {
    const aTag = $list(el);
    let href = aTag.attr('href') || '';
    
    let cleanPath = href;
    if (cleanPath.includes('.translate.goog')) {
      try {
        const u = new URL(cleanPath.startsWith('http') ? cleanPath : `https://${cleanPath}`);
        cleanPath = u.pathname;
      } catch (e) {}
    }
    cleanPath = cleanPath.split('?')[0].split('#')[0].replace(/\/+$/, '');

    if (cleanPath.includes('/brosurler/')) {
      const storeNameText = (aTag.find('.blid b').text() || '').toLowerCase();
      const pathLower = cleanPath.toLowerCase();

      if (store.excludeKeywords && store.excludeKeywords.some(ex => pathLower.includes(ex) || storeNameText.includes(ex))) {
        return;
      }

      const matchesStore = store.keywords.some(kw => {
        const k = kw.toLowerCase();
        return pathLower.includes(k) || storeNameText.includes(k);
      });

      if (!matchesStore) {
        console.log(`Unmatched item on ${store.name}: ${cleanPath}`);
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
      const idMatch = cleanPath.match(/[-_](\d+)$/) || cleanPath.match(/(\d+)$/);
      const brochureId = idMatch ? idMatch[1] : '';

      if (brochureId) {
        catalogItems.push({ brochureId, href: cleanPath, coverImage, titleSuffix });
      }
    }
  });

  console.log(`Found ${catalogItems.length} catalog items on list page.`);

  for (const item of catalogItems) {
    const detailUrl = item.href.startsWith('http') ? item.href : `https://www.akakce.com${item.href.startsWith('/') ? '' : '/'}${item.href}`;
    console.log(`\n  📄 Scraping detail: ${item.brochureId} - ${detailUrl}`);
    const detailHtml = await fetchHtmlWithRetry(detailUrl, 2);
    if (!detailHtml) {
      console.log(`  ❌ Failed to fetch detail HTML for ${item.brochureId}`);
      continue;
    }

    const $detail = cheerio.load(detailHtml);
    const sayfaResimleri = [];

    // Look specifically inside #BP_W for main brochure pages!
    const bpwImages = $detail('#BP_W .p img, #BP_W img, .bpgc .p img');
    console.log(`  #BP_W images count: ${bpwImages.length}`);

    bpwImages.each((i, el) => {
      let src = $detail(el).attr('data-src') || $detail(el).attr('src') || $detail(el).attr('data-original');
      if (src && !src.includes('t.gif')) {
        if (src.startsWith('//')) src = 'https:' + src;
        src = src.replace('/_bro/l/', '/_bro/u/').replace('/_bro/y/', '/_bro/u/').replace('/_bro/m/', '/_bro/u/');
        if (!sayfaResimleri.includes(src)) {
          sayfaResimleri.push(src);
        }
      }
    });

    const urlYear = parseYearFromUrl(item.href);
    const dateSpanText = $detail('#br_s').text().trim();
    const parsedSpanDates = parseDatesFromSpan(dateSpanText, urlYear);

    console.log(`  Parsed ${sayfaResimleri.length} pages. #br_s: "${dateSpanText}". Dates:`, parsedSpanDates);
  }
}

async function run() {
  for (const s of STORES_TEST) {
    await testStore(s);
  }
}

run();
