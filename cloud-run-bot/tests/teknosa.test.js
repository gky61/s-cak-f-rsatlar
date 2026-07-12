const assert = require('assert');
const cheerio = require('cheerio');
const TeknosaScraper = require('../scrapers/teknosa_scraper');

function run() {
  const scraper = new TeknosaScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.teknosa.com/sony-playstation.html'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. Teknosa elements
  const html = `
    <head>
      <meta property="og:image" content="https://images.teknosa.com/123.jpg">
      <meta name="description" content="Sony Playstation 5 Konsolu Teknosa kalitesiyle.">
      <script id="schemaJSON" type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "WebPage",
        "name": "Sony Playstation 5 Slim 1 TB",
        "breadcrumb": {
          "@type": "BreadcrumbList",
          "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": "Anasayfa", "item": "https://www.teknosa.com"},
            {"@type": "ListItem", "position": 2, "name": "Bilgisayar & Tablet", "item": "https://www.teknosa.com/playstation"},
            {"@type": "ListItem", "position": 3, "name": "Konsol", "item": "https://www.teknosa.com/playstation"}
          ]
        }
      }
      </script>
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Sony Playstation 5 Slim 1 TB",
        "offers": {
          "price": "18999.00"
        }
      }
      </script>
    </head>
    <body>
      <h1 class="product-title">Sony Playstation 5 Slim 1 TB</h1>
    </body>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'Sony Playstation 5 Slim 1 TB');
  assert.strictEqual(scraper.scrapePrice($), 18999.0);
  assert.strictEqual(scraper.scrapeDescription($), 'Sony Playstation 5 Konsolu Teknosa kalitesiyle.');
  assert.strictEqual(scraper.scrapeImage($, 'https://www.teknosa.com/sony-playstation.html'), 'https://images.teknosa.com/123.jpg');
  assert.deepStrictEqual(scraper.scrapeBreadcrumbs($), ['Bilgisayar & Tablet', 'Konsol']);
}

module.exports = { run };
