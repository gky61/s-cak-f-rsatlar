const assert = require('assert');
const cheerio = require('cheerio');
const PttavmScraper = require('../scrapers/pttavm_scraper');

function run() {
  const scraper = new PttavmScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.pttavm.com/apple-airpods-pro-p-1462157482'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. PttAVM elements
  const html = `
    <head>
      <meta data-rh="true" name="description" content="Metal Ayakkabılık 4'lü Kilitli Model Siyah yorumları.">
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Apple AirPods Pro 3. Nesil",
        "image": [
          "https://cdn-s3.pttavm.com/pimages/592/146/215/de3a460e-154a-4959-afbb-9154bc6e0c96.webp"
        ],
        "offers": {
          "@type": "Offer",
          "price": 10999.58,
          "highPrice": 12865,
          "lowPrice": 10999.58
        }
      }
      </script>
    </head>
    <body>
    </body>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'Apple AirPods Pro 3. Nesil');
  assert.strictEqual(scraper.scrapePrice($), 10999.58);
  assert.strictEqual(scraper.scrapeDescription($), "Metal Ayakkabılık 4'lü Kilitli Model Siyah yorumları.");
  assert.strictEqual(scraper.scrapeImage($, 'https://www.pttavm.com/apple-airpods-pro-p-1462157482'), 'https://cdn-s3.pttavm.com/pimages/592/146/215/de3a460e-154a-4959-afbb-9154bc6e0c96.webp');
}

module.exports = { run };
