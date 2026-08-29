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
    'rate limit exceeded'
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

    // Strategy A1: Translate Proxy with Standard Query
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
        // Jitter delay on 429
        await new Promise(r => setTimeout(r, 1200 + Math.random() * 800));
      }
    } catch (e) {}

    // Strategy A2: Translate Proxy with _x_tr_pto=wapp (Web App mode)
    try {
      const translateProxyWapp = `https://${proxyHost}${parsedUrl.pathname}${parsedUrl.search}?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr&_x_tr_pto=wapp`;
      const proxyRes2 = await fetch(translateProxyWapp, {
        headers: {
          'User-Agent': getRandomUserAgent(),
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8'
        },
        signal: AbortSignal.timeout(15000)
      });
      if (proxyRes2.ok) {
        const html = await proxyRes2.text();
        if (isValidHtml(html, 2500)) return html;
      }
    } catch (e) {}

    // Strategy B: Direct Googlebot UA
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

    // Strategy C: Direct WhatsApp Mobile UA
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

    // Strategy D: Microlink Proxy
    try {
      const microlinkUrl = `https://api.microlink.io/?url=${encodeURIComponent(targetUrl)}&data.html.selector=html&data.html.type=html`;
      const res = await fetch(microlinkUrl, { signal: AbortSignal.timeout(12000) });
      if (res.ok) {
        const json = await res.json();
        const html = json.data?.html || '';
        if (isValidHtml(html, 2500)) return html;
      }
    } catch (e) {}

    // Strategy E: Native OS curl
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

const TEST_STORES = [
  { code: 'arcelik', name: 'Arçelik', url: 'https://www.akakce.com/brosurler/arcelik', keywords: ['arcelik', 'arçelik'] },
  { code: 'beko', name: 'Beko', url: 'https://www.akakce.com/brosurler/beko', keywords: ['beko'] },
  { code: 'bosch', name: 'Bosch', url: 'https://www.akakce.com/brosurler/bosch-home', keywords: ['bosch'] },
  { code: 'siemens', name: 'Siemens', url: 'https://www.akakce.com/brosurler/siemens-home', keywords: ['siemens'] },
  { code: 'vestel', name: 'Vestel', url: 'https://www.akakce.com/brosurler/vestel', keywords: ['vestel'] },
  { code: 'teknosa', name: 'Teknosa', url: 'https://www.akakce.com/brosurler/teknosacom', keywords: ['teknosa'] },
  { code: 'vatan', name: 'Vatan', url: 'https://www.akakce.com/brosurler/vatanbilgisayar', keywords: ['vatan'] },
];

async function run() {
  console.log('Testing bulletproof scraper on tech stores...');
  for (const s of TEST_STORES) {
    const html = await fetchHtmlWithRetry(s.url, 3);
    if (!html) {
      console.log(`❌ Failed for ${s.name}`);
      continue;
    }
    const $ = cheerio.load(html);
    const brochures = [];
    $('ul#BLI li a').each((i, el) => {
      const a = $(el);
      let href = a.attr('href') || '';
      let cleanPath = href.includes('.translate.goog') ? new URL(href.startsWith('http') ? href : `https://${href}`).pathname : href;
      cleanPath = cleanPath.split('?')[0].split('#')[0].replace(/\/+$/, '');
      const storeNameText = (a.find('.blid b').text() || '').toLowerCase();
      const pathLower = cleanPath.toLowerCase();

      const matches = s.keywords.some(kw => pathLower.includes(kw) || storeNameText.includes(kw));
      if (matches) {
        brochures.push({ href: cleanPath, title: a.find('.blid .bn').text().trim() });
      }
    });
    console.log(`✅ ${s.name}: successfully fetched and parsed ${brochures.length} brochures.`);
  }
}

run();
