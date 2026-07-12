const assert = require('assert');
const cheerio = require('cheerio');
const MediaMarktScraper = require('../scrapers/mediamarkt_scraper');

function run() {
  const scraper = new MediaMarktScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.mediamarkt.com.tr/tr/product/apple-123.html'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. MediaMarkt elements
  const html = `
    <head>
      <meta property="og:image" content="https://assets.mediamarkt.com.tr/123.jpg">
      <meta name="description" content="APPLE Watch SE 2. nesil akıllı saat.">
      <script type="application/ld+json" data-rh="true">
      {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
          {"@type": "ListItem", "position": 1, "name": "home", "item": "https://www.mediamarkt.com.tr"},
          {"@type": "ListItem", "position": 2, "name": "Bilgisayar", "item": "https://www.mediamarkt.com.tr/category/504925.html"},
          {"@type": "ListItem", "position": 3, "name": "Laptop", "item": "https://www.mediamarkt.com.tr/category/504926.html"},
          {"@type": "ListItem", "position": 4, "name": "Mac", "item": "https://www.mediamarkt.com.tr/category/mac-645068.html"},
          {"@type": "ListItem", "position": 5, "name": "MacBook Air", "item": "https://www.mediamarkt.com.tr/category/macbook-air-645070.html"},
          {"@type": "ListItem", "position": 6, "name": "APPLE MacBook Air M5", "item": "https://www.mediamarkt.com.tr/tr/product/apple-1252857.html"}
        ]
      }
      </script>
      <script type="application/ld+json">
      {
        "@type": "Product",
        "name": "APPLE MacBook Air M5",
        "offers": {
          "price": "39999.00"
        }
      }
      </script>
    </head>
    <body>
      <h1 class="mms-ui-title">APPLE MacBook Air M5</h1>
    </body>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'APPLE MacBook Air M5');
  assert.strictEqual(scraper.scrapePrice($), 39999.0);
  assert.strictEqual(scraper.scrapeDescription($), 'APPLE Watch SE 2. nesil akıllı saat.');
  assert.strictEqual(scraper.scrapeImage($, 'https://www.mediamarkt.com.tr/tr/product/apple-123.html'), 'https://assets.mediamarkt.com.tr/123.jpg');
  assert.deepStrictEqual(scraper.scrapeBreadcrumbs($), ['Bilgisayar', 'Laptop', 'Mac', 'MacBook Air']);
}

module.exports = { run };
