const cheerio = require('cheerio');

const STORES = [
  { code: 'a101', name: 'A101', url: 'https://www.akakce.com/brosurler/a101' },
  { code: 'bim', name: 'BİM', url: 'https://www.akakce.com/brosurler/bim' },
  { code: 'sok', name: 'ŞOK', url: 'https://www.akakce.com/brosurler/sok' },
  { code: 'migros', name: 'Migros', url: 'https://www.akakce.com/brosurler/migros' },
  { code: 'carrefoursa', name: 'CarrefourSA', url: 'https://www.akakce.com/brosurler/carrefoursa' },
  { code: 'cagri', name: 'Çağrı', url: 'https://www.akakce.com/brosurler/cagrihipermarket' },
  { code: 'file', name: 'File', url: 'https://www.akakce.com/brosurler/file' },
  { code: 'hakmar', name: 'Hakmar', url: 'https://www.akakce.com/brosurler/hakmar' },
  { code: 'tarimkredi', name: 'Kooperatif Market', url: 'https://www.akakce.com/brosurler/tarim-kredi-koop' },
  { code: 'metro', name: 'Metro', url: 'https://www.akakce.com/brosurler/metro-tr' }
];

function isValidHtml(html, minLength = 3000) {
  if (!html || html.length < minLength) return false;
  const lower = html.toLowerCase();
  if (lower.includes('403 - forbidden') || lower.includes('access is denied') || lower.includes('robot verification')) {
    return false;
  }
  return true;
}

async function fetchHtmlWithFallback(targetUrl) {
  // Stage 1 (Googlebot UA)
  try {
    const res = await fetch(targetUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
      },
      signal: AbortSignal.timeout(2500)
    });
    if (res.ok) {
      const html = await res.text();
      if (isValidHtml(html, 4000)) return html;
    }
  } catch (e) {}

  // Stage 2 (Google Translate Proxy)
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
      signal: AbortSignal.timeout(10000)
    });
    if (proxyRes.ok) {
      const html = await proxyRes.text();
      if (isValidHtml(html, 3000)) return html;
    }
  } catch (e) {}

  // Stage 3 (WhatsApp UA)
  try {
    const res = await fetch(targetUrl, {
      headers: {
        'User-Agent': 'WhatsApp/2.23.4.15 A',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
      },
      signal: AbortSignal.timeout(3000)
    });
    if (res.ok) {
      const html = await res.text();
      if (isValidHtml(html, 4000)) return html;
    }
  } catch (e) {}

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

async function testParallelScrapeWithConcurrency3() {
  const startTime = Date.now();
  let totalBrochuresFound = 0;
  let totalValidBrochures = 0;
  let skippedCount = 0;

  for (const store of STORES) {
    const listHtml = await fetchHtmlWithFallback(store.url);
    if (!listHtml) {
      console.log(`❌ Failed list page for ${store.name}`);
      continue;
    }

    const $list = cheerio.load(listHtml);
    const catalogItems = [];
    $list('ul#BLI li a').each((i, el) => {
      const href = $list(el).attr('href') || '';
      if (href.includes('/brosurler/')) {
        const idMatch = href.match(/(\d+)$/);
        if (idMatch) {
          catalogItems.push({ brochureId: idMatch[1], href });
        }
      }
    });

    totalBrochuresFound += catalogItems.length;

    // Scrape detail pages with concurrency 3
    const detailResults = await mapConcurrent(catalogItems, 3, async (item) => {
      const detailUrl = item.href.startsWith('http') ? item.href : `https://www.akakce.com${item.href}`;
      const detailHtml = await fetchHtmlWithFallback(detailUrl);
      if (detailHtml) {
        const $detail = cheerio.load(detailHtml);
        const images = [];
        $detail('#BP_W .p img').each((i, el) => {
          let src = $detail(el).attr('data-src') || $detail(el).attr('src');
          if (src && !src.includes('t.gif')) images.push(src);
        });

        if (images.length > 0) return true;
      }
      return false;
    });

    const validCount = detailResults.filter(Boolean).length;
    const skippedInStore = catalogItems.length - validCount;
    totalValidBrochures += validCount;
    skippedCount += skippedInStore;

    console.log(`✅ [${store.name}] Valid: ${validCount} / ${catalogItems.length} (Skipped: ${skippedInStore})`);
  }

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
  console.log(`\n🎉 FULL SCRAPE FINISHED in ${elapsed}s!`);
  console.log(`Total valid: ${totalValidBrochures} / ${totalBrochuresFound} (Total skipped: ${skippedCount})`);
}

testParallelScrapeWithConcurrency3();
