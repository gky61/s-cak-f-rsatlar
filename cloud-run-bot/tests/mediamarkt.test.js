const assert = require('assert');
const cheerio = require('cheerio');
const MediaMarktScraper = require('../scrapers/mediamarkt_scraper');

async function run() {
  const scraper = new MediaMarktScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.mediamarkt.com.tr/tr/product/_apple-iphone-15.html'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. JSON-LD sample
  const ldJsonHtml = `
    <script type="application/ld+json">
    {
      "@context": "https://schema.org/",
      "@type": "Product",
      "name": "APPLE iPhone 15 128 GB Akıllı Telefon Siyah",
      "image": "https://cms-images.mmst.eu/2c383f5b/321.jpg",
      "brand": {
        "@type": "Brand",
        "name": "Apple"
      },
      "aggregateRating": {
        "@type": "AggregateRating",
        "ratingValue": 4.9,
        "reviewCount": 17,
        "bestRating": 5
      },
      "offers": {
        "@type": "Offer",
        "price": "49999.00"
      }
    }
    </script>
  `;
  const $ldJson = cheerio.load(ldJsonHtml);
  assert.strictEqual(scraper.scrapeTitle($ldJson), 'APPLE iPhone 15 128 GB Akıllı Telefon Siyah');
  assert.strictEqual(scraper.scrapePrice($ldJson), 49999.0);
  const rating1 = await scraper.scrapeRating($ldJson);
  assert.strictEqual(rating1.ratingValue, 4.9);
  assert.strictEqual(rating1.ratingCount, 17);
  assert.strictEqual(scraper.scrapeBrand($ldJson), 'Apple');

  // 3. User Provided DOM Header sample
  const domHtml = `
    <header class="mms-ui-gmypTc mms-ui-lOKb mms-ui-gmEXAU mms-ui-jhxEPr mms-ui-jaLRUs mms-ui-jPTFXc mms-ui-hdSXft mms-ui-gYQtUZ mms-ui-kqNbQS" data-test="mms-pdp-average-rating-summary" aria-label="Ortalama ürün değerlendirmesi 17 incelemelerine göre 4.9 şeklindedir."></header>
    <meta property="product:brand" content="Apple">
  `;
  const $dom = cheerio.load(domHtml);
  const rating2 = await scraper.scrapeRating($dom);
  assert.strictEqual(rating2.ratingValue, 4.9);
  assert.strictEqual(rating2.ratingCount, 17);
  assert.strictEqual(scraper.scrapeBrand($dom), 'Apple');
}

module.exports = { run };
