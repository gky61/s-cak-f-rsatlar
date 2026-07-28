const cheerio = require('cheerio');

/**
 * Validates if the returned HTML is valid catalog HTML and not a WAF block/error page.
 */
function isValidHtml(html, minLength = 3000) {
  if (!html || html.length < minLength) return false;
  const lower = html.toLowerCase();
  if (lower.includes('403 - forbidden') || lower.includes('access is denied') || lower.includes('robot verification')) {
    return false;
  }
  return true;
}

async function fetchHtmlWithFallback(targetUrl, timeoutMs = 7000) {
  // Stage 1 (Fastest): Direct Fetch with Googlebot UA (1.5s quick timeout)
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
  } catch (e) {}

  // Stage 2 (Cloud WAF Bypass Proxy): Google Translate Proxy (6s timeout)
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
  } catch (e) {}

  return null;
}

/**
 * Helper to process array items in parallel chunks of size chunkSize
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

async function testParallelFullScrape() {
  console.log('🚀 Testing Parallel Full Scrape Flow for all stores...\n');
  const startTime = Date.now();

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

  let totalCatalogsScraped = 0;
  let totalBrochuresAttempted = 0;

  for (const store of STORES) {
    const listHtml = await fetchHtmlWithFallback(store.url);
    if (!listHtml) continue;

    const $ = cheerio.load(listHtml);
    const catalogItems = [];

    $('ul#BLI li').each((i, el) => {
      const aTag = $(el).find('a');
      let href = aTag.attr('href') || '';
      if (href.includes('.translate.goog')) {
        try {
          href = new URL(href).pathname;
        } catch (e) {}
      }

      if (href.includes('/brosurler/')) {
        const idMatch = href.match(/(\d+)$/);
        const brochureId = idMatch ? idMatch[1] : '';
        if (brochureId) {
          catalogItems.push({ brochureId, href });
        }
      }
    });

    totalBrochuresAttempted += catalogItems.length;

    // Fetch detail pages in parallel concurrency of 5
    const scrapedResults = await mapConcurrent(catalogItems, 5, async (item) => {
      const detailUrl = item.href.startsWith('http') ? item.href : `https://www.akakce.com${item.href}`;
      const detailHtml = await fetchHtmlWithFallback(detailUrl);
      if (!detailHtml) return null;

      const $detail = cheerio.load(detailHtml);
      const sayfaResimleri = [];
      $detail('#BP_W .p img').each((i, el) => {
        let src = $(el).attr('data-src') || $(el).attr('src');
        if (src && !src.includes('t.gif')) {
          sayfaResimleri.push(src);
        }
      });

      if (sayfaResimleri.length > 0) {
        return { brochureId: item.brochureId, pagesCount: sayfaResimleri.length };
      }
      return null;
    });

    const validCatalogs = scrapedResults.filter(Boolean);
    totalCatalogsScraped += validCatalogs.length;
    console.log(`✅ [${store.name}] Scraped ${validCatalogs.length} / ${catalogItems.length} brochures.`);
  }

  const durationSec = ((Date.now() - startTime) / 1000).toFixed(2);
  console.log(`\n🎉 FULL SCRAPE FINISHED in ${durationSec} seconds!`);
  console.log(`Total valid catalogs with pages: ${totalCatalogsScraped} / ${totalBrochuresAttempted}`);
}

testParallelFullScrape();
