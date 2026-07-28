const cheerio = require('cheerio');
const { spawnSync } = require('child_process');

function isValidHtml(html, minLength = 3000) {
  if (!html || html.length < minLength) return false;
  const lower = html.toLowerCase();
  if (lower.includes('403 - forbidden') || lower.includes('access is denied') || lower.includes('robot verification')) {
    return false;
  }
  return true;
}

async function fetchHtmlWithFallback(targetUrl, timeoutMs = 8000) {
  // Stage 1 (Googlebot UA)
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
        return { html, stage: 1 };
      }
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
      signal: AbortSignal.timeout(6000)
    });
    if (proxyRes.ok) {
      const html = await proxyRes.text();
      if (isValidHtml(html, 3000)) {
        return { html, stage: 2 };
      }
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
      signal: AbortSignal.timeout(2000)
    });
    if (res.ok) {
      const html = await res.text();
      if (isValidHtml(html, 4000)) {
        return { html, stage: 3 };
      }
    }
  } catch (e) {}

  // Stage 4 (Microlink)
  try {
    const microlinkUrl = `https://api.microlink.io/?url=${encodeURIComponent(targetUrl)}&data.html.selector=html&data.html.type=html`;
    const res = await fetch(microlinkUrl, { signal: AbortSignal.timeout(6000) });
    if (res.ok) {
      const json = await res.json();
      const html = json.data?.html || '';
      if (isValidHtml(html, 3000)) {
        return { html, stage: 4 };
      }
    }
  } catch (e) {}

  // Stage 5 (curl)
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
      return { html: curlResult.stdout, stage: 5 };
    }
  } catch (e) {}

  return { html: null, stage: 0 };
}

async function testAllFour() {
  const brochures = [
    { id: '59515', url: 'https://www.akakce.com/brosurler/happy-center-17-temmuz-2026-aktuel-katalogu-indirim-brosuru-59515' },
    { id: '59791', url: 'https://www.akakce.com/brosurler/kooperatif-market-24-temmuz-2026-aktuel-katalogu-indirim-brosuru-59791' },
    { id: '59407', url: 'https://www.akakce.com/brosurler/bizimtoptan-15-temmuz-2026-aktuel-katalogu-indirim-brosuru-59407' },
    { id: '59531', url: 'https://www.akakce.com/brosurler/vatanbilgisayar-17-temmuz-2026-aktuel-katalogu-instagram-postu-59531' }
  ];

  for (const b of brochures) {
    console.log(`\nTesting brochure ${b.id} (${b.url})...`);
    const { html, stage } = await fetchHtmlWithFallback(b.url);
    if (!html) {
      console.log(`❌ All 5 stages failed for ${b.id}`);
      continue;
    }

    const $ = cheerio.load(html);
    const images = [];
    $('#BP_W .p img').each((i, el) => {
      let src = $(el).attr('data-src') || $(el).attr('src');
      if (src && !src.includes('t.gif')) {
        images.push(src);
      }
    });

    console.log(`  -> Stage ${stage} succeeded (HTML length ${html.length})`);
    console.log(`  -> Selector #BP_W .p img found ${images.length} images:`, images);

    if (images.length === 0) {
      console.log('  -> Checking alternate selectors...');
      console.log('     #BP_W img count:', $('#BP_W img').length);
      console.log('     .p img count:', $('.p img').length);
      console.log('     #BP_W html snippet:', $('#BP_W').html()?.slice(0, 300));
    }
  }
}

testAllFour();
