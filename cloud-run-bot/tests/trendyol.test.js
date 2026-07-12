const assert = require('assert');
const cheerio = require('cheerio');
const TrendyolScraper = require('../scrapers/trendyol_scraper');

function run() {
  const scraper = new TrendyolScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.trendyol.com/robeve/550-ml-p-898167691'), true);
  assert.strictEqual(scraper.canHandle('https://ty.gl/some-short-url'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. JSON-LD parsing
  const html = `
    <script type="application/ld+json">{
      "@context": "https://schema.org",
      "@type": "ProductGroup",
      "name": "ROBEVE 550 ml Otomatik Hava Nemlendirici Buhar Makinesi Oda Nemlendirici Aroma Difüzör Beyaz",
      "image": {
        "type": "ImageObject",
        "contentUrl": [
          "https://cdn.dsmcdn.com/ty1783/prod/QC_ENRICHMENT/20251103/21/e1fbb2d1-553b-3dec-af2f-076c33520c1c/1_org_zoom.jpg"
        ]
      },
      "offers": {
        "@type": "Offer",
        "price": "486.67"
      }
    }</script>
  `;
  const $ = cheerio.load(html);

  assert.strictEqual(scraper.scrapeTitle($), 'ROBEVE 550 ml Otomatik Hava Nemlendirici Buhar Makinesi Oda Nemlendirici Aroma Difüzör Beyaz');
  assert.strictEqual(scraper.scrapePrice($), 486.67);
  assert.strictEqual(scraper.scrapeImage($, 'https://www.trendyol.com/some-product'), 'https://cdn.dsmcdn.com/ty1783/prod/QC_ENRICHMENT/20251103/21/e1fbb2d1-553b-3dec-af2f-076c33520c1c/1_org_zoom.jpg');
}

module.exports = { run };
