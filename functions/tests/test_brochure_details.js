const cheerio = require('cheerio');

const TEST_BROCHURES = [
  'https://www.akakce.com/brosurler/mrdiy-1-temmuz-2026-aktuel-katalogu-indirim-brosuru-59054',
  'https://www.akakce.com/brosurler/evkur-24-temmuz-2026-aktuel-katalogu-indirim-brosuru-59789',
  'https://www.akakce.com/brosurler/kilpamarket-20-temmuz-2026-aktuel-katalogu-kasap-indirim-brosuru-59540',
  'https://www.akakce.com/brosurler/tahtakalespot-24-temmuz-2026-aktuel-katalogu-indirim-brosuru-59764',
  'https://www.akakce.com/brosurler/kooperatifmarket-24-temmuz-2026-aktuel-katalogu-indirimli-urunler-59779',
  'https://www.akakce.com/brosurler/metro-tr-1-temmuz-2026-aktuel-katalogu-kisisel-bakim-ve-temizlik-58916',
  'https://www.akakce.com/brosurler/metro-tr-22-temmuz-2026-aktuel-katalogu-balik-restoranlari-59643',
  'https://www.akakce.com/brosurler/metro-tr-22-temmuz-2026-aktuel-katalogu-kebap-59656',
  'https://www.akakce.com/brosurler/bizimtoptan-15-temmuz-2026-aktuel-katalogu-horeca-indirim-brosuru-59410'
];

async function testDetailPages() {
  console.log('🔍 Inspecting detail page HTML structure for brochures...\n');

  for (const url of TEST_BROCHURES) {
    const parsedUrl = new URL(url);
    const proxyHost = parsedUrl.hostname.replace(/\./g, '-') + '.translate.goog';
    const proxyUrl = `https://${proxyHost}${parsedUrl.pathname}?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;

    try {
      const res = await fetch(proxyUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
        }
      });
      const text = await res.text();
      const $ = cheerio.load(text);
      
      const bpWImgs = $('#BP_W .p img').length;
      const allImgs = $('img').length;
      const broImgs = $('img[src*="_bro"]').length;
      const dataSrcImgs = $('img[data-src]').length;

      console.log(` Bro: ${url.split('-').pop()}`);
      console.log(`   #BP_W .p img: ${bpWImgs}`);
      console.log(`   img[src*="_bro"]: ${broImgs}`);
      console.log(`   img[data-src]: ${dataSrcImgs}`);
      console.log(`   total img: ${allImgs}`);

      if (bpWImgs === 0) {
        console.log('   Sample image srcs:');
        $('img').slice(0, 10).each((i, el) => {
          console.log(`     - src: "${$(el).attr('src')}" | data-src: "${$(el).attr('data-src')}" | style: "${$(el).attr('style')}"`);
        });
      }
    } catch (e) {
      console.log(` Error for ${url}: ${e.message}`);
    }
  }
}

testDetailPages();
