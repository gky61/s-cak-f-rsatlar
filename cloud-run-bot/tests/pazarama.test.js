const assert = require('assert');
const cheerio = require('cheerio');
const PazaramaScraper = require('../scrapers/pazarama_scraper');

function run() {
  const scraper = new PazaramaScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.pazarama.com/product-p-1234'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. normal price, title, description
  const html1 = `
    <script type="application/ld+json">
    {
      "@type": "Product",
      "name": "Normal Pazarama Urunu",
      "offers": {
        "price": "47879.00"
      }
    }
    </script>
    <meta name="description" content="Normal pazarama urun aciklamasi">
  `;
  const $1 = cheerio.load(html1);

  assert.strictEqual(scraper.scrapeTitle($1), 'Normal Pazarama Urunu');
  assert.strictEqual(scraper.scrapePrice($1), 47879.0);
  assert.strictEqual(scraper.scrapeDescription($1), 'Normal pazarama urun aciklamasi');

  // 3. plus price
  const html2 = `
    <script type="application/ld+json">
    {
      "@type": "Product",
      "name": "Plus Pazarama Urunu"
    }
    </script>
    <meta name="description" content="Plus pazarama urun aciklamasi">
    <div>
      <img src="pz-plus-icon" alt="plus-icon">
      <span>455,24 TL</span>
    </div>
  `;
  const $2 = cheerio.load(html2);

  assert.strictEqual(scraper.scrapeTitle($2), 'Plus Pazarama Urunu');
  assert.strictEqual(scraper.scrapePrice($2), 455.24);
  assert.strictEqual(scraper.scrapeDescription($2), 'Plus pazarama urun aciklamasi');

  // 4. Pazarama ld+json rating and brand
  const html3 = `
    <script data-n-head="ssr" type="application/ld+json">{"@context":"https://schema.org","@type":"Product","sku":"8855f485-cec1-40f9-84f9-08dd9ef7b3d2","url":"https://www.pazarama.com/apple-airpods-4-mxp63tua-p-195949688553","name":"Apple AirPods 4. Nesil MXP63TU/A Bluetooth Kulaklık","brand":{"@type":"Brand","name":"Apple"},"image":"https://img.pzrmcdn.com/asset/195949688553/images/appleairpods4mxp63tua-6.jpg","aggregateRating":{"@type":"AggregateRating","bestRating":"5","worstRating":"1","reviewCount":158,"ratingValue":4.5},"offers":{"@type":"Offer","price":5999,"priceCurrency":"TRY"}}</script>
  `;
  const $3 = cheerio.load(html3);
  assert.strictEqual(scraper.scrapeTitle($3), 'Apple AirPods 4. Nesil MXP63TU/A Bluetooth Kulaklık');
  assert.strictEqual(scraper.scrapePrice($3), 5999.0);
  const rating3 = scraper.scrapeRating($3);
  assert.strictEqual(rating3.ratingValue, 4.5);
  assert.strictEqual(rating3.ratingCount, 158);
  assert.strictEqual(scraper.scrapeBrand($3), 'Apple');
}

module.exports = { run };
