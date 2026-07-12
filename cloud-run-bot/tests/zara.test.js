const assert = require('assert');
const cheerio = require('cheerio');
const ZaraScraper = require('../scrapers/zara_scraper');

function run() {
  const scraper = new ZaraScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.zara.com/tr/tr/soyut-desenli-dokumlu-gomlek-p04206102.html'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. JSON-LD
  const html1 = `
    <script type="application/ld+json">
    {
      "@context": "https://schema.org/",
      "@type": "ProductGroup",
      "name": "SOYUT DESENLİ DÖKÜMLÜ GÖMLEK",
      "description": "Viskoz, liyosel ve %18 keten karışımlı kumaştan relaxed fit gömlek.",
      "image": [
        "https://static.zara.net/assets/public/952d/21a3/97354a2baf15/cc4c9a95e115/04206102112-p/04206102112-p.jpg?ts=1779785865421&w=1920"
      ],
      "hasVariant": [
        {
          "@type": "Product",
          "name": "SOYUT DESENLİ DÖKÜMLÜ GÖMLEK - Maviler - S (US S)",
          "offers": {
            "price": "1090"
          }
        }
      ]
    }
    </script>
  `;
  const $1 = cheerio.load(html1);

  assert.strictEqual(scraper.scrapeTitle($1), 'SOYUT DESENLİ DÖKÜMLÜ GÖMLEK');
  assert.strictEqual(scraper.scrapePrice($1), 1090.0);
  assert.strictEqual(scraper.scrapeDescription($1), 'Viskoz, liyosel ve %18 keten karışımlı kumaştan relaxed fit gömlek.');
  assert.strictEqual(scraper.scrapeImage($1, 'https://www.zara.com/tr/tr/soyut-desenli-dokumlu-gomlek-p04206102.html'), 'https://static.zara.net/assets/public/952d/21a3/97354a2baf15/cc4c9a95e115/04206102112-p/04206102112-p.jpg?ts=1779785865421&w=1920');

  // 3. script analyticsData and meta
  const html2 = `
    <head>
      <meta property="og:image" content="https://static.zara.net/assets/public/952d/21a3/97354a2baf15/cc4c9a95e115/04206102112-p/04206102112-p.jpg?ts=1779785865421&w=560">
      <meta name="description" content="Viskoz, liyosel ve %18 keten karışımlı kumaştan relaxed fit gömlek.">
    </head>
    <body>
      <script>
        var zara = window.zara || {};
        zara.analyticsData = {
          "mainPrice": 1090,
          "productName": "SOYUT DESENLİ DÖKÜMLÜ GÖMLEK"
        };
      </script>
    </body>
  `;
  const $2 = cheerio.load(html2);

  assert.strictEqual(scraper.scrapeTitle($2), 'SOYUT DESENLİ DÖKÜMLÜ GÖMLEK');
  assert.strictEqual(scraper.scrapePrice($2), 1090.0);
  assert.strictEqual(scraper.scrapeDescription($2), 'Viskoz, liyosel ve %18 keten karışımlı kumaştan relaxed fit gömlek.');
  assert.strictEqual(scraper.scrapeImage($2, 'https://www.zara.com/tr/tr/soyut-desenli-dokumlu-gomlek-p04206102.html'), 'https://static.zara.net/assets/public/952d/21a3/97354a2baf15/cc4c9a95e115/04206102112-p/04206102112-p.jpg?ts=1779785865421&w=560');
}

module.exports = { run };
