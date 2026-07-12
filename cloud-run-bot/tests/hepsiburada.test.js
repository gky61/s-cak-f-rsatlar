const assert = require('assert');
const cheerio = require('cheerio');
const HepsiburadaScraper = require('../scrapers/hepsiburada_scraper');

async function run() {
  const scraper = new HepsiburadaScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.hepsiburada.com/product-p-HBCV0000AHHOFE'), true);
  assert.strictEqual(scraper.canHandle('https://hb.biz/some-short-url'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. normal price
  const html1 = `
    <script type="application/ld+json">
    {
      "@type": "Product",
      "name": "Apple iPhone 17 Pro Max 256 GB",
      "offers": {
        "price": "120499.00"
      }
    }
    </script>
  `;
  const $1 = cheerio.load(html1);
  assert.strictEqual(scraper.scrapeTitle($1), 'Apple iPhone 17 Pro Max 256 GB');
  assert.strictEqual(await scraper.scrapePrice($1), 120499.00);

  // 3. premium price 1
  const html2 = `
    <script type="application/ld+json">
    {
      "@type": "Product",
      "name": "Selpak® Kağıt Havlu"
    }
    </script>
    <span>Premium ile <b>282,67 TL</b></span>
  `;
  const $2 = cheerio.load(html2);
  assert.strictEqual(scraper.scrapeTitle($2), 'Selpak® Kağıt Havlu');
  assert.strictEqual(await scraper.scrapePrice($2), 282.67);
}

module.exports = { run };
