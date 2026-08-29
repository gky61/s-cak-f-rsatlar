const { STORES } = require('../catalog_scraper');
const cheerio = require('cheerio');
const { spawnSync } = require('child_process');

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

async function fetchHtmlWithRetry(targetUrl, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    const ua = getRandomUserAgent();
    const parsedUrl = new URL(targetUrl);
    const proxyHost = parsedUrl.hostname.replace(/\./g, '-') + '.translate.goog';

    // Strategy A1
    try {
      const translateProxyUrl = `https://${proxyHost}${parsedUrl.pathname}${parsedUrl.search}?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;
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
        await new Promise(r => setTimeout(r, 1200 + Math.random() * 800));
      }
    } catch (e) {}

    // Strategy A2: wapp mode
    try {
      const translateProxyWapp = `https://${proxyHost}${parsedUrl.pathname}${parsedUrl.search}?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr&_x_tr_pto=wapp`;
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

    // Strategy B: Googlebot
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

    if (attempt < maxRetries) {
      await new Promise(r => setTimeout(r, 1000 + Math.random() * 500));
    }
  }
  return null;
}

async function mapConcurrent(items, concurrency, fn) {
  const results = [];
  for (let i = 0; i < items.length; i += concurrency) {
    const chunk = items.slice(i, i + concurrency);
    const chunkResults = await Promise.all(chunk.map(fn));
    results.push(...chunkResults);
  }
  return results;
}

async function run() {
  console.log(`Starting full simulation for all ${STORES.length} stores...`);
  const results = [];
  let totalBrochures = 0;

  for (const store of STORES) {
    const start = Date.now();
    try {
      const listHtml = await fetchHtmlWithRetry(store.url, 3);
      if (!listHtml) {
        results.push({ name: store.name, code: store.code, count: 0, status: 'FAILED', ms: Date.now() - start });
        console.log(`❌ ${store.name}: Failed to fetch list page.`);
        continue;
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

          if (!matchesStore) return;

          const idMatch = cleanPath.match(/[-_](\d+)$/) || cleanPath.match(/(\d+)$/);
          const brochureId = idMatch ? idMatch[1] : '';

          if (brochureId) {
            catalogItems.push({ brochureId, href: cleanPath });
          }
        }
      });

      totalBrochures += catalogItems.length;
      results.push({
        name: store.name,
        code: store.code,
        count: catalogItems.length,
        status: catalogItems.length > 0 ? 'OK' : 'ZERO_FOUND (No brochures on Akakce)',
        ms: Date.now() - start
      });
      console.log(`✅ ${store.name} (${store.code}): found ${catalogItems.length} brochures (${Date.now() - start}ms)`);
      await new Promise(r => setTimeout(r, 250));
    } catch (e) {
      results.push({ name: store.name, code: store.code, count: 0, status: 'ERROR: ' + e.message, ms: Date.now() - start });
    }
  }

  console.log('\n================ FULL 36 STORES SCRAPE SIMULATION ================');
  console.table(results);
  console.log(`Total Brochures Found across all stores: ${totalBrochures}`);
}

run();
