const assert = require('assert');
const cheerio = require('cheerio');
const IncehesapScraper = require('../scrapers/incehesap_scraper');

function run() {
  const scraper = new IncehesapScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.incehesap.com/aoc-monitor-fiyati-87639/'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. dataLayer parsing (no basket discount)
  const html1 = `
    <head>
      <script>
        window.dataLayer = window.dataLayer || [];
        window.dataLayer.push({"event":"view_item","ecommerce":{"currency":"TRY","value":6899,"items":[{"id":87639,"item_name":"AOC 27G50Z 27″ 260Hz Oyuncu Monitörü","image":"https:\\/\\/www.incehesap.com\\/resim\\/urun\\/500.webp","price":6899}]}});
      </script>
      <meta name="description" content="AOC 27G50Z 27 inç oyuncu monitörü açıklaması">
    </head>
    <body>
      <div class="price">6.899 TL</div>
    </body>
  `;
  const $1 = cheerio.load(html1);

  assert.strictEqual(scraper.scrapeTitle($1), 'AOC 27G50Z 27″ 260Hz Oyuncu Monitörü');
  assert.strictEqual(scraper.scrapePrice($1), 6899.0);
  assert.strictEqual(scraper.scrapeDescription($1), 'AOC 27G50Z 27 inç oyuncu monitörü açıklaması');
  assert.strictEqual(scraper.scrapeImage($1, 'https://www.incehesap.com/aoc-monitor-fiyati-87639/'), 'https://www.incehesap.com/resim/urun/500.webp');

  // 3. price from DOM due to basket discount label
  const html2 = `
    <head>
      <script>
        window.dataLayer = window.dataLayer || [];
        window.dataLayer.push({"event":"view_item","ecommerce":{"value":6899,"items":[{"price":6899}]}});
      </script>
    </head>
    <body>
      <div class="basketdiscount-label-detail">%6 indirim</div>
      <div class="price">6.485,06 TL</div>
    </body>
  `;
  const $2 = cheerio.load(html2);
  assert.strictEqual(scraper.scrapePrice($2), 6485.06);
}

module.exports = { run };
