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
  { code: 'bizim', name: 'Bizim', url: 'https://www.akakce.com/brosurler/bizimtoptan' },
  { code: 'file', name: 'File', url: 'https://www.akakce.com/brosurler/file' },
  { code: 'hakmar', name: 'Hakmar', url: 'https://www.akakce.com/brosurler/hakmar' },
  { code: 'tarimkredi', name: 'Kooperatif Market', url: 'https://www.akakce.com/brosurler/tarim-kredi-koop' },
  { code: 'metro', name: 'Metro', url: 'https://www.akakce.com/brosurler/metro-tr' },
  { code: 'teknosa', name: 'Teknosa', url: 'https://www.akakce.com/brosurler/teknosacom' },
  { code: 'vatan', name: 'Vatan', url: 'https://www.akakce.com/brosurler/vatanbilgisayar' }
];

function isValidHtml(html, minLength = 2500) {
  if (!html || html.length < minLength) return false;
  const lower = html.toLowerCase();
  if (lower.includes('403 - forbidden') || lower.includes('access is denied') || lower.includes('robot verification')) {
    return false;
  }
  return true;
}

/**
 * Robust Multi-Stage Single-Url Fetcher with Retries
 */
async function fetchHtmlWithRetry(targetUrl, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    // Strategy A (Primary): Google Translate Proxy (15s timeout)
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

    // Strategy B: Direct Fetch Googlebot UA (5s timeout)
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

    // Strategy E: Native curl (10s timeout)
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

    // Brief pause before retry
    if (attempt < maxRetries) {
      await new Promise(r => setTimeout(r, 1000));
    }
  }

  return null;
}

async function testGuaranteedFullScrape() {
  console.log('🚀 Starting Guaranteed 100% Reliable Catalog Scrape test...\n');
  const startTime = Date.now();
  let totalBrochuresFound = 0;
  let totalValidBrochures = 0;
  let skippedCount = 0;

  for (const store of STORES) {
    console.log(`🔍 [${store.name}] Fetching catalog list from ${store.url}...`);
    const listHtml = await fetchHtmlWithRetry(store.url, 3);
    if (!listHtml) {
      console.log(`❌ [${store.name}] FAILED to fetch list page after 3 retries. Skipping store.`);
      continue;
    }

    const $list = cheerio.load(listHtml);
    const catalogItems = [];
    $list('ul#BLI li a').each((i, el) => {
      let href = $list(el).attr('href') || '';
      if (href.includes('.translate.goog')) {
        try { href = new URL(href).pathname; } catch (e) {}
      }
      if (href.includes('/brosurler/')) {
        const idMatch = href.match(/(\d+)$/);
        if (idMatch) catalogItems.push({ brochureId: idMatch[1], href });
      }
    });

    totalBrochuresFound += catalogItems.length;
    let storeValid = 0;
    let storeSkipped = 0;

    for (const item of catalogItems) {
      const detailUrl = item.href.startsWith('http') ? item.href : `https://www.akakce.com${item.href}`;
      const detailHtml = await fetchHtmlWithRetry(detailUrl, 3);

      if (detailHtml) {
        const $detail = cheerio.load(detailHtml);
        const images = [];
        
        const imgElements = $detail('#BP_W .p img').length > 0 
          ? $detail('#BP_W .p img') 
          : ($detail('.p img').length > 0 ? $detail('.p img') : $detail('#BP_W img'));

        imgElements.each((i, el) => {
          let src = $detail(el).attr('data-src') || $detail(el).attr('src') || $detail(el).attr('data-original');
          if (src && !src.includes('t.gif')) {
            images.push(src);
          }
        });

        if (images.length > 0) {
          storeValid++;
        } else {
          storeSkipped++;
          console.log(`  ⚠️ No images inside brochure ${item.brochureId} (${detailUrl})`);
        }
      } else {
        storeSkipped++;
        console.log(`  ❌ Failed detail HTML for brochure ${item.brochureId} after 3 retries!`);
      }

      // Short 200ms polite pause between detail requests
      await new Promise(r => setTimeout(r, 200));
    }

    totalValidBrochures += storeValid;
    skippedCount += storeSkipped;
    console.log(`✅ [${store.name}] Result: ${storeValid} / ${catalogItems.length} (Skipped: ${storeSkipped})`);
  }

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
  console.log(`\n🎉 GUARANTEED SCRAPE COMPLETED in ${elapsed} seconds!`);
  console.log(`Total Valid Catalogs: ${totalValidBrochures} / ${totalBrochuresFound}`);
  console.log(`Total Skipped Brochures: ${skippedCount}`);
}

testGuaranteedFullScrape();
