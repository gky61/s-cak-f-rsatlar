const assert = require('assert');
const cheerio = require('cheerio');
const N11Scraper = require('../scrapers/n11_scraper');

async function run() {
  const scraper = new N11Scraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://m.n11.com/urun/siemens-eq6-plus-s700-te657319rw'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. JSON-LD ld+json test
  const htmlLdJson = `
    <script type="application/ld+json">{"@context":"https://schema.org/","@type":"Product","aggregateRating":{"@type":"AggregateRating","ratingCount":"47","ratingValue":4.5,"reviewCount":"47"},"brand":"Siemens","description":"Siemens EQ6 Plus S700 TE657319RW","name":"Siemens EQ6 Plus S700 TE657319RW"}</script>
  `;
  const $ld = cheerio.load(htmlLdJson);
  const ratingLd = scraper.scrapeRating($ld);
  assert.strictEqual(ratingLd.ratingValue, 4.5, 'ratingValue should be 4.5');
  assert.strictEqual(ratingLd.ratingCount, 47, 'ratingCount should be 47');
  assert.strictEqual(scraper.scrapeBrand($ld), 'Siemens', 'brand should be Siemens');
}

module.exports = { run };
