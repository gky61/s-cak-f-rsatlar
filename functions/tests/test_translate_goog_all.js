const cheerio = require('cheerio');

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

async function testTranslateGoogAll() {
  console.log('🧪 Testing translate.goog for all 18 stores...\n');
  let count = 0;

  for (const store of STORES) {
    const parsedUrl = new URL(store.url);
    const proxyHost = parsedUrl.hostname.replace(/\./g, '-') + '.translate.goog';
    const proxyUrl = `https://${proxyHost}${parsedUrl.pathname}?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;
    
    try {
      const res = await fetch(proxyUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
        }
      });
      if (res.ok) {
        const text = await res.text();
        const $ = cheerio.load(text);
        const items = $('ul#BLI li').length;
        console.log(`✅ [${store.name}] Status: ${res.status}, Items: ${items}`);
        if (items > 0) count++;
      } else {
        console.log(`❌ [${store.name}] Status: ${res.status}`);
      }
    } catch (e) {
      console.log(`❌ [${store.name}] Error: ${e.message}`);
    }
  }

  console.log(`\nSummary: ${count} / ${STORES.length} stores fetched via Google Translate Proxy!`);
}

testTranslateGoogAll();
