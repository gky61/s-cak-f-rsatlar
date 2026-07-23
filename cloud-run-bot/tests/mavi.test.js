const assert = require('assert');
const cheerio = require('cheerio');
const MaviScraper = require('../scrapers/mavi_scraper');

async function run() {
  const scraper = new MaviScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.mavi.com/mini-mavi-logo-baskili-interlok-beyaz-basic-tisort/p/1612122-70057'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. DOM birinci öncelik: DOM rating (4.8, 5) JSON-LD'deki (4.5, 1) yerine gelecek
  const htmlDom = `
    <div class="average-rate">
      <span class="average-rate__number type:small">4.8</span>
    </div>
    <div class="rate-info type:small">5&nbsp;Değerlendirme</div>
    <script type="application/ld+json">
    {
      "@context":"https://schema.org",
      "@type":"WebPage",
      "mainEntity":{
        "@type":"WebPageElement",
        "offers":{"@type":"Offer","itemOffered":[{
          "@type":"Product","name":"Test",
          "aggregateRating":{"@type":"AggregateRating","ratingValue":"4.5","reviewCount":"1"}
        }]}
      }
    }
    </script>
  `;
  const $dom = cheerio.load(htmlDom);
  const ratingDom = await scraper.scrapeRating($dom);
  assert.strictEqual(ratingDom.ratingValue, 4.8, 'DOM birinci öncelik: ratingValue 4.8 olmalı');
  assert.strictEqual(ratingDom.ratingCount, 5, 'DOM birinci öncelik: ratingCount 5 olmalı');

  // 3. JSON-LD fallback: DOM yok
  const htmlLd = `
    <script type="application/ld+json">
    {
      "@context":"https://schema.org",
      "@type":"WebPage",
      "mainEntity":{
        "@type":"WebPageElement",
        "offers":{"@type":"Offer","itemOffered":[{
          "@type":"Product",
          "name":"Mini Mavi Logo Baskılı İnterlok Beyaz Basic Tişört",
          "brand":{"@type":"Brand","name":"Mavi"},
          "offers":{"@type":"Offer","price":"419.99","priceCurrency":"TRY"},
          "aggregateRating":{"@type":"AggregateRating","ratingValue":"4.5","reviewCount":"1"}
        }]}
      }
    }
    </script>
  `;
  const $ld = cheerio.load(htmlLd);
  assert.strictEqual(scraper.scrapeTitle($ld), 'Mini Mavi Logo Baskılı İnterlok Beyaz Basic Tişört');
  assert.strictEqual(scraper.scrapePrice($ld), 419.99);
  const ratingLd = await scraper.scrapeRating($ld);
  assert.strictEqual(ratingLd.ratingValue, 4.5, 'JSON-LD fallback: ratingValue 4.5 olmalı');
  assert.strictEqual(ratingLd.ratingCount, 1, 'JSON-LD fallback: ratingCount 1 olmalı');
  assert.strictEqual(scraper.scrapeBrand($ld), 'Mavi');
}

module.exports = { run };
