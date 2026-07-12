const assert = require('assert');
const cheerio = require('cheerio');
const IdefixScraper = require('../scrapers/idefix_scraper');

function run() {
  const scraper = new IdefixScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.idefix.com/klimalar-c-123'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. Idefix elements
  const html = `
    <head>
      <meta property="og:image" content="https://www.idefix.com/product.jpg">
      <meta name="description" content="Duvar tipi klima en iyi fiyatla Idefix'te.">
      <script type="application/ld+json">
      {
        "@context": "https://schema.org/",
        "@type": "BreadcrumbList",
        "itemListElement": [
          {"@type": "ListItem", "position": 0, "name": "Ana sayfa", "item": "https://www.idefix.com/"},
          {"@type": "ListItem", "position": 1, "name": "Teknoloji", "item": "https://www.idefix.com/teknoloji-c-23"},
          {"@type": "ListItem", "position": 2, "name": "Klimalar", "item": "https://www.idefix.com/klimalar-c-23"}
        ]
      }
      </script>
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "Duvar Tipi Klima",
        "offers": {
          "price": "14500.00"
        }
      }
      </script>
    </head>
    <body>
      <h1>Duvar Tipi Klima</h1>
    </body>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'Duvar Tipi Klima');
  assert.strictEqual(scraper.scrapePrice($), 14500.0);
  assert.strictEqual(scraper.scrapeDescription($), "Duvar tipi klima en iyi fiyatla Idefix'te.");
  assert.strictEqual(scraper.scrapeImage($, 'https://www.idefix.com/klimalar-c-123'), 'https://www.idefix.com/product.jpg');
  assert.deepStrictEqual(scraper.scrapeBreadcrumbs($), ['Teknoloji', 'Klimalar']);
}

module.exports = { run };
