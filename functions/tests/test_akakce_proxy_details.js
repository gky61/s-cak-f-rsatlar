const cheerio = require('cheerio');

async function testAkakceProxy() {
  const targetUrl = 'https://www.akakce.com/brosurler/a101';
  
  // 1. translate.goog
  const translateGoogUrl = 'https://www-akakce-com.translate.goog/brosurler/a101?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr';
  console.log('Testing translate.goog URL:', translateGoogUrl);
  try {
    const res = await fetch(translateGoogUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
    });
    console.log(`translate.goog Status: ${res.status}`);
    const text = await res.text();
    console.log(`translate.goog Body length: ${text.length}`);
    const $ = cheerio.load(text);
    console.log(`ul#BLI items in translate.goog:`, $('ul#BLI li').length);
    if ($('ul#BLI li').length === 0) {
      console.log('Sample body:', text.substring(0, 500));
    }
  } catch (e) {
    console.error('translate.goog error:', e.message);
  }

  // 2. translate.google.com web translate URL
  const translateWebUrl = `https://translate.google.com/translate?sl=auto&tl=tr&u=${encodeURIComponent(targetUrl)}`;
  console.log('\nTesting translate.google.com Web URL:', translateWebUrl);
  try {
    const res = await fetch(translateWebUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
      }
    });
    console.log(`translate.google.com Status: ${res.status}`);
    const text = await res.text();
    console.log(`translate.google.com Body length: ${text.length}`);
  } catch (e) {
    console.error('translate.google.com error:', e.message);
  }

  // 3. Microlink HTML API
  const microlinkUrl = `https://api.microlink.io/?url=${encodeURIComponent(targetUrl)}&data.html.selector=html&data.html.type=html`;
  console.log('\nTesting Microlink HTML API:', microlinkUrl);
  try {
    const res = await fetch(microlinkUrl);
    console.log(`Microlink Status: ${res.status}`);
    const json = await res.json();
    const html = json.data?.html || '';
    console.log(`Microlink HTML length: ${html.length}`);
    const $ = cheerio.load(html);
    console.log(`ul#BLI items in Microlink:`, $('ul#BLI li').length);
  } catch (e) {
    console.error('Microlink error:', e.message);
  }
}

testAkakceProxy();
