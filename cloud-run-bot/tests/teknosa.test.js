const assert = require('assert');
const cheerio = require('cheerio');
const TeknosaScraper = require('../scrapers/teknosa_scraper');

async function run() {
  const scraper = new TeknosaScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.teknosa.com/apple-iphone-17-pro-max-256gb-kozmik-turuncu-akilli-telefon-p-100000058776'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. User Provided JSON-LD sample
  const html = `
    <script id="schemaJSON" type="application/ld+json" async="">
    {
      "@context": "https://schema.org",
      "@type": "WebPage",
      "name": "Apple iPhone 17 Pro Max 256GB Kozmik Turuncu Akıllı Telefon",
      "description": "Apple iPhone 17 Pro Max 256GB Kozmik Turuncu Akıllı Telefon özelliklerini incelemek ve en uygun fiyata satın almak için hemen tıkla!",
      "url": "https://www.teknosa.com/apple-iphone-17-pro-max-256gb-kozmik-turuncu-akilli-telefon-p-100000058776",
      "@graph":{
        "@type": "Product",
        "name": "Apple iPhone 17 Pro Max 256GB Kozmik Turuncu Akıllı Telefon",
        "sku":"100000058776",
        "brand": {
          "@type": "Brand",
          "name": "Apple"
        },
        "aggregateRating":{
          "@type":"AggregateRating",
          "ratingValue":"4.3",
          "reviewCount":"39"
        },
        "offers": {
          "@type": "Offer",
          "price": "122499.00",
          "priceCurrency": "TRY"
        }
      }
    }
    </script>
  `;
  const $ = cheerio.load(html);
  assert.strictEqual(scraper.scrapeTitle($), 'Apple iPhone 17 Pro Max 256GB Kozmik Turuncu Akıllı Telefon');
  assert.strictEqual(scraper.scrapePrice($), 122499.0);
  const rating = await scraper.scrapeRating($);
  assert.strictEqual(rating.ratingValue, 4.3);
  assert.strictEqual(rating.ratingCount, 39);
  assert.strictEqual(scraper.scrapeBrand($), 'Apple');
}

module.exports = { run };
