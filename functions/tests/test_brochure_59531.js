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

async function fetchHtmlWithFallback(targetUrl, timeoutMs = 12000) {
  // Stage 1
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
        console.log('Stage 1 (Googlebot) succeeded! Length:', html.length);
        return html;
      }
    }
  } catch (e) {
    console.log('Stage 1 failed:', e.message);
  }

  // Stage 2
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
        console.log('Stage 2 (Translate Proxy) succeeded! Length:', html.length);
        return html;
      }
    }
  } catch (e) {
    console.log('Stage 2 failed:', e.message);
  }

  // Stage 3
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
        console.log('Stage 3 (WhatsApp UA) succeeded! Length:', html.length);
        return html;
      }
    }
  } catch (e) {
    console.log('Stage 3 failed:', e.message);
  }

  // Stage 4
  try {
    const microlinkUrl = `https://api.microlink.io/?url=${encodeURIComponent(targetUrl)}&data.html.selector=html&data.html.type=html`;
    const res = await fetch(microlinkUrl, { signal: AbortSignal.timeout(6000) });
    if (res.ok) {
      const json = await res.json();
      const html = json.data?.html || '';
      if (isValidHtml(html, 3000)) {
        console.log('Stage 4 (Microlink) succeeded! Length:', html.length);
        return html;
      }
    }
  } catch (e) {
    console.log('Stage 4 failed:', e.message);
  }

  // Stage 5
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
      console.log('Stage 5 (curl) succeeded! Length:', curlResult.stdout.length);
      return curlResult.stdout;
    }
  } catch (e) {
    console.log('Stage 5 failed:', e.message);
  }

  return null;
}

async function testBrochure59531() {
  const detailUrl = 'https://www.akakce.com/brosurler/vatanbilgisayar-17-temmuz-2026-aktuel-katalogu-instagram-postu-59531';
  console.log('Fetching brochure 59531 detail HTML...');
  const html = await fetchHtmlWithFallback(detailUrl);
  if (!html) {
    console.log('❌ Failed to fetch HTML for 59531!');
    return;
  }

  const $ = cheerio.load(html);
  const sayfaResimleri = [];
  $('#BP_W .p img').each((i, el) => {
    let src = $(el).attr('data-src') || $(el).attr('src');
    if (src && !src.includes('t.gif')) {
      sayfaResimleri.push(src);
    }
  });

  console.log(`Found ${sayfaResimleri.length} images:`, sayfaResimleri);
  console.log('DOM #BP_W html snippet:', $('#BP_W').html());
  console.log('DOM span#br_s text:', $('#br_s').text().trim());
}

testBrochure59531();
