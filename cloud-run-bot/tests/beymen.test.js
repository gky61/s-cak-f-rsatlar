const assert = require('assert');
const cheerio = require('cheerio');
const BeymenScraper = require('../scrapers/beymen_scraper');

function run() {
  const scraper = new BeymenScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.beymen.com/tr/p_etro-lacivert-etnik-desenli-gomlek_1627505'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. normal price, title, image, description
  const html = `
    <script type="application/ld+json">
    {
        "@context": "https://schema.org/",
        "@type": "Product",
        "name": "Lacivert Etnik Desenli Gömlek",
        "image": [
            "https://cdn.beymen.com/productimages/aj4ffhsd.rcf_IMG_01_2110099740461.jpg"
        ],
        "description": "Düğmeli yaka, etnik desenli gömlek.",
        "offers": {
            "@type": "Offer",
            "price": "30450.00"
        }
    }
    </script>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'Lacivert Etnik Desenli Gömlek');
  assert.strictEqual(scraper.scrapePrice($), 30450.0);
  assert.strictEqual(scraper.scrapeDescription($), 'Düğmeli yaka, etnik desenli gömlek.');
  assert.strictEqual(scraper.scrapeImage($, 'https://www.beymen.com/tr/p_etro-lacivert-etnik-desenli-gomlek_1627505'), 'https://cdn.beymen.com/productimages/aj4ffhsd.rcf_IMG_01_2110099740461.jpg');
}

module.exports = { run };
