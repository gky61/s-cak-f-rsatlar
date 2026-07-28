const cheerio = require('cheerio');

async function testTranslateProxy59531() {
  const targetUrl = 'https://www.akakce.com/brosurler/vatanbilgisayar-17-temmuz-2026-aktuel-katalogu-instagram-postu-59531';
  const parsedUrl = new URL(targetUrl);
  const proxyHost = parsedUrl.hostname.replace(/\./g, '-') + '.translate.goog';
  const translateProxyUrl = `https://${proxyHost}${parsedUrl.pathname}${parsedUrl.search}?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;

  console.log('Fetching Stage 2 (Translate Proxy):', translateProxyUrl);
  const res = await fetch(translateProxyUrl, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
    }
  });

  const html = await res.text();
  console.log('Translate Proxy HTML Length:', html.length);

  const $ = cheerio.load(html);
  
  console.log('--- Selector #BP_W .p img ---');
  $('#BP_W .p img').each((i, el) => {
    console.log(`img ${i}:`, {
      src: $(el).attr('src'),
      dataSrc: $(el).attr('data-src'),
      dataOriginal: $(el).attr('data-original'),
      style: $(el).attr('style'),
      outerHtml: $.html(el)
    });
  });

  console.log('\n--- Selector .p img (broader) ---');
  $('.p img').each((i, el) => {
    console.log(`img ${i}:`, {
      src: $(el).attr('src'),
      dataSrc: $(el).attr('data-src'),
      outerHtml: $.html(el)
    });
  });

  console.log('\n--- Selector img inside #BP_W ---');
  $('#BP_W img').each((i, el) => {
    console.log(`img ${i}:`, {
      src: $(el).attr('src'),
      dataSrc: $(el).attr('data-src'),
      outerHtml: $.html(el)
    });
  });
}

testTranslateProxy59531();
