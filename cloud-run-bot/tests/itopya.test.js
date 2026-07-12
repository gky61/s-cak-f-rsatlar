const assert = require('assert');
const cheerio = require('cheerio');
const ItopyaScraper = require('../scrapers/itopya_scraper');

function run() {
  const scraper = new ItopyaScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.itopya.com/lenovo-legion-gaming-monitor-u33428'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. Itopya elements
  const html = `
    <head>
      <meta property="og:image" content="https://www.itopya.com/product.jpg">
      <meta name="description" content="Lenovo Legion oyuncu monitörü Itopya güvencesiyle.">
      <script type="application/ld+json">
      {
        "@context": "http://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
          {"@type": "ListItem", "position": 1, "item": {"@id": "/", "name": "Ana Sayfa"}},
          {"@type": "ListItem", "position": 2, "item": {"@id": "/cevre", "name": "Çevre Birimleri"}},
          {"@type": "ListItem", "position": 3, "item": {"@id": "/monitor", "name": "Monitör"}}
        ]
      }
      </script>
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Lenovo Legion Gaming Monitör",
        "offers": {
          "price": "6799.00"
        }
      }
      </script>
    </head>
    <body>
      <h1 class="product-details-title">Lenovo Legion Gaming Monitör</h1>
    </body>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'Lenovo Legion Gaming Monitör');
  assert.strictEqual(scraper.scrapePrice($), 6799.0);
  assert.strictEqual(scraper.scrapeDescription($), 'Lenovo Legion oyuncu monitörü Itopya güvencesiyle.');
  assert.strictEqual(scraper.scrapeImage($, 'https://www.itopya.com/lenovo-legion-gaming-monitor-u33428'), 'https://www.itopya.com/product.jpg');
  assert.deepStrictEqual(scraper.scrapeBreadcrumbs($), ['Çevre Birimleri', 'Monitör']);
}

module.exports = { run };
