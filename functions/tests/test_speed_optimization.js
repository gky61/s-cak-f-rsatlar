const cheerio = require('cheerio');
const { spawnSync } = require('child_process');

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

async function fetchHtmlWithFallback(targetUrl, timeoutMs = 15000) {
  const startTime = Date.now();

  // Stage 1 (Fastest): Direct Fetch with Googlebot UA
  try {
    const res = await fetch(targetUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
      },
      signal: AbortSignal.timeout(timeoutMs)
    });
    if (res.ok) {
      const html = await res.text();
      if (html && html.length > 5000) {
        return { html, method: 'Direct Googlebot UA (Ultra Fast)', duration: Date.now() - startTime };
      }
    }
  } catch (e) {}

  // Stage 2 (Fast Mobile): Direct Fetch with WhatsApp UA
  try {
    const res = await fetch(targetUrl, {
      headers: {
        'User-Agent': 'WhatsApp/2.23.4.15 A',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
      },
      signal: AbortSignal.timeout(timeoutMs)
    });
    if (res.ok) {
      const html = await res.text();
      if (html && html.length > 5000) {
        return { html, method: 'Direct WhatsApp UA (Fast Mobile)', duration: Date.now() - startTime };
      }
    }
  } catch (e) {}

  // Stage 3 (Cloud WAF Bypass Proxy): Google Translate Proxy
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
      signal: AbortSignal.timeout(timeoutMs)
    });
    if (proxyRes.ok) {
      const html = await proxyRes.text();
      if (html && html.length > 5000) {
        return { html, method: 'Google Translate Proxy (WAF Bypass)', duration: Date.now() - startTime };
      }
    }
  } catch (e) {}

  // Stage 4: Microlink Proxy
  try {
    const microlinkUrl = `https://api.microlink.io/?url=${encodeURIComponent(targetUrl)}&data.html.selector=html&data.html.type=html`;
    const res = await fetch(microlinkUrl, { signal: AbortSignal.timeout(timeoutMs) });
    if (res.ok) {
      const json = await res.json();
      const html = json.data?.html || '';
      if (html && html.length > 3000) {
        return { html, method: 'Microlink Proxy', duration: Date.now() - startTime };
      }
    }
  } catch (e) {}

  // Stage 5: Native OS curl spawnSync
  try {
    const curlArgs = [
      '-s', '-L',
      '--max-time', String(Math.ceil(timeoutMs / 1000)),
      '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      '-H', 'Accept-Language: tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
      targetUrl
    ];
    const curlResult = spawnSync('curl', curlArgs, { encoding: 'utf-8', timeout: timeoutMs + 2000 });
    if (!curlResult.error && curlResult.stdout && curlResult.stdout.length > 5000) {
      return { html: curlResult.stdout, method: 'curl Fallback', duration: Date.now() - startTime };
    }
  } catch (e) {}

  return null;
}

async function testSpeedOptimization() {
  console.log('⚡ Testing Speed-Optimized Fallback Chain for all 18 stores...\n');
  const totalStartTime = Date.now();
  let count = 0;

  for (const store of STORES) {
    const result = await fetchHtmlWithFallback(store.url);
    if (result) {
      const $ = cheerio.load(result.html);
      const items = $('ul#BLI li').length;
      console.log(`✅ [${store.name}] ${result.method} - ${result.duration}ms (${items} items)`);
      if (items > 0) count++;
    } else {
      console.log(`❌ [${store.name}] FAILED ALL STAGES`);
    }
  }

  const totalDuration = ((Date.now() - totalStartTime) / 1000).toFixed(2);
  console.log(`\n🎉 Completed in ${totalDuration}s! Total stores fetched: ${count} / ${STORES.length}`);
}

testSpeedOptimization();
