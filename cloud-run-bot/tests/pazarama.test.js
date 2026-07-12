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
}

module.exports = { run };
