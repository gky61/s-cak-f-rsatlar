const assert = require('assert');
const cheerio = require('cheerio');
const VatanScraper = require('../scrapers/vatan_scraper');

function run() {
  const scraper = new VatanScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.vatanbilgisayar.com/asus-vivobook-16.html'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. Vatan page elements (decoding entities, special price prioritisation)
  const html = `
    <head>
      <meta property="og:image" content="https://vatanbilgisayar.com/product.jpg">
      <meta name="description" content="Asus Vivobook Laptop vatan bilgisayardan alınır.">
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
          {
            "@type": "ListItem",
            "position": 1,
            "item": {
              "name": "T&#xFC;ketici Elektroni&#x11F;i"
            }
          },
          {
            "@type": "ListItem",
            "position": 2,
            "item": {
              "name": "Notebook"
            }
          }
        ]
      }
      </script>
    </head>
    <body>
      <h1 class="product_title">ASUS VIVOBOOK 16 ULTRA 5</h1>
      <span id="priceSpecial"> 27.599<span> TL </span></span>
      <script>
        UpdateProductDetayItem({"ProductId":"123","ProductName":"ASUS VIVOBOOK 16 ULTRA 5","ProductPrice":"28500.00"})
      </script>
    </body>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'ASUS VIVOBOOK 16 ULTRA 5');
  assert.strictEqual(scraper.scrapePrice($), 27599.0);
  assert.strictEqual(scraper.scrapeDescription($), 'Asus Vivobook Laptop vatan bilgisayardan alınır.');
  assert.strictEqual(scraper.scrapeImage($, 'https://www.vatanbilgisayar.com/asus-vivobook-16.html'), 'https://vatanbilgisayar.com/product.jpg');
  assert.deepStrictEqual(scraper.scrapeBreadcrumbs($), ['Tüketici Elektroniği', 'Notebook']);

  // 3. Vatan ld+json with ratingValue "4,71", reviewCount "248", brand LENOVO
  const vatanLdJson = `
    <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "Product",
      "name": "Lenovo Ideapad Slim 3 13.Nesil Core i5 13420H-8Gb-512Gb Ssd-16inc-W11",
      "brand": {
        "@type": "Brand",
        "name": "LENOVO"
      },
      "offers": {
        "@type": "Offer",
        "price": "26999"
      },
      "aggregateRating": {
        "@type": "AggregateRating",
        "ratingValue": "4,71",
        "reviewCount": "248"
      }
    }
    </script>
  `;
  const $2 = cheerio.load(vatanLdJson);
  assert.strictEqual(scraper.scrapeTitle($2), 'Lenovo Ideapad Slim 3 13.Nesil Core i5 13420H-8Gb-512Gb Ssd-16inc-W11');
  assert.strictEqual(scraper.scrapePrice($2), 26999);
  const rating2 = scraper.scrapeRating($2);
  assert.strictEqual(rating2.ratingValue, 4.71);
  assert.strictEqual(rating2.ratingCount, 248);
  assert.strictEqual(scraper.scrapeBrand($2), 'LENOVO');
}

module.exports = { run };
