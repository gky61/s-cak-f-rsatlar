const assert = require('assert');
const cheerio = require('cheerio');
const MaviScraper = require('../scrapers/mavi_scraper');

function run() {
  const scraper = new MaviScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.mavi.com/lisbon-classic-denim-koyu-indigo-mavisi-jean-pantolon/p/0010039-A3934'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. normal price, title, image, description from nested offers
  const html = `
    <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "WebPage",
      "name": "Lisbon Classic Denim Koyu Indigo Mavisi Jean Pantolon",
      "mainEntity": {
        "@type": "WebPageElement",
        "offers": {
          "@type": "Offer",
          "itemOffered": [
            {
              "@type": "Product",
              "name": "Lisbon Classic Denim Koyu Indigo Mavisi Jean Pantolon",
              "description": "Mavi nin denim koleksiyonundan Lisbon Classic Denim Koyu Indigo Mavisi Jean Pantolon. Loose, bol kesim. Normal bel. Düz paçası ile sokak giyimi ve 9 lar ilhamlı Jean lerden biri.",
              "image": [
                {
                  "@type": "ImageObject",
                  "contentUrl": "https://sky-static.mavi.com/mnresize/820/1162/0010039-A3934_image_1.jpg?v=1783678883967"
                }
              ],
              "offers": {
                "@type": "Offer",
                "price": "1799.99"
              }
            }
          ]
        }
      }
    }
    </script>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'Lisbon Classic Denim Koyu Indigo Mavisi Jean Pantolon');
  assert.strictEqual(scraper.scrapePrice($), 1799.99);
  assert.ok(scraper.scrapeDescription($).includes('Mavi nin denim koleksiyonundan Lisbon Classic Denim Koyu Indigo Mavisi Jean Pantolon.'));
  assert.strictEqual(scraper.scrapeImage($, 'https://www.mavi.com/lisbon-classic-denim-koyu-indigo-mavisi-jean-pantolon/p/0010039-A3934'), 'https://sky-static.mavi.com/mnresize/820/1162/0010039-A3934_image_1.jpg?v=1783678883967');
}

module.exports = { run };
