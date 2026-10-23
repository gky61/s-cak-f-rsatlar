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

  // 3. parsePriceText: ardışık rakamlı tam sayılar (99 TL, 999 TL) ve dublike koruması
  assert.strictEqual(scraper.parsePriceText('99 TL'), 99, '99 TL should be 99');
  assert.strictEqual(scraper.parsePriceText('99'), 99, '99 should be 99');
  assert.strictEqual(scraper.parsePriceText('159 TL'), 159, '159 TL should be 159');
  assert.strictEqual(scraper.parsePriceText('88 TL'), 88, '88 TL should be 88');
  assert.strictEqual(scraper.parsePriceText('999 TL'), 999, '999 TL should be 999');
  assert.strictEqual(scraper.parsePriceText('1010 TL'), 1010, '1010 TL should be 1010');
  assert.strictEqual(scraper.parsePriceText('2525 TL'), 2525, '2525 TL should be 2525');
  assert.strictEqual(scraper.parsePriceText('269,91TL269,91TL'), 269.91, '269,91TL269,91TL should be 269.91');
  assert.strictEqual(scraper.parsePriceText('269,91269,91'), 269.91, '269,91269,91 should be 269.91');
  assert.strictEqual(scraper.parsePriceText('38160TL38160TL'), 38160, '38160TL38160TL should be 38160');
  assert.strictEqual(scraper.parsePriceText('3816038160'), 38160, '3816038160 should be 38160');
  console.log('✅ N11 testleri ve parsePriceText doğrulamaları başarıyla geçti!');
}

module.exports = { run };
