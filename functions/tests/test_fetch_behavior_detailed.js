const cheerio = require('cheerio');

async function testCloudFunctionsFetchBehavior(targetUrl) {
  console.log(`\n==================================================`);
  console.log(`Testing Fetch Behavior for: ${targetUrl}`);
  console.log(`==================================================\n`);

  // 1. Direct Googlebot UA
  console.log('1. Direct Googlebot UA...');
  try {
    const res = await fetch(targetUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
      }
    });
    console.log(`   Status: ${res.status} ${res.statusText}`);
    const text = await res.text();
    console.log(`   Body length: ${text.length}`);
    const $ = cheerio.load(text);
    console.log(`   Items in ul#BLI: ${$('ul#BLI li').length}`);
    if (res.status !== 200) console.log(`   Snippet:`, text.substring(0, 300));
  } catch (e) {
    console.log(`   Error: ${e.message}`);
  }

  // 2. Google Translate Proxy (translate.goog)
  const parsedUrl = new URL(targetUrl);
  const proxyHost = parsedUrl.hostname.replace(/\./g, '-') + '.translate.goog';
  const translateProxyUrl = `https://${proxyHost}${parsedUrl.pathname}${parsedUrl.search}?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;
  console.log('\n2. Google Translate Proxy (translate.goog)...');
  console.log(`   URL: ${translateProxyUrl}`);
  try {
    const res = await fetch(translateProxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
      }
    });
    console.log(`   Status: ${res.status} ${res.statusText}`);
    const text = await res.text();
    console.log(`   Body length: ${text.length}`);
    const $ = cheerio.load(text);
    console.log(`   Items in ul#BLI: ${$('ul#BLI li').length}`);
    if (res.status !== 200) console.log(`   Snippet:`, text.substring(0, 300));
  } catch (e) {
    console.log(`   Error: ${e.message}`);
  }

  // 3. Alternative Google Translate Proxy (translate.google.com/translate?u=...)
  const translateWebUrl = `https://translate.google.com/translate?sl=auto&tl=tr&u=${encodeURIComponent(targetUrl)}`;
  console.log('\n3. Google Translate Web URL (translate.google.com/translate)...');
  console.log(`   URL: ${translateWebUrl}`);
  try {
    const res = await fetch(translateWebUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
    });
    console.log(`   Status: ${res.status} ${res.statusText}`);
    const text = await res.text();
    console.log(`   Body length: ${text.length}`);
    const $ = cheerio.load(text);
    console.log(`   Items in ul#BLI: ${$('ul#BLI li').length}`);
    if (res.status !== 200) console.log(`   Snippet:`, text.substring(0, 300));
  } catch (e) {
    console.log(`   Error: ${e.message}`);
  }
}

async function main() {
  await testCloudFunctionsFetchBehavior('https://www.akakce.com/brosurler/a101');
  await testCloudFunctionsFetchBehavior('https://www.akakce.com/brosurler/vatanbilgisayar');
}

main();
