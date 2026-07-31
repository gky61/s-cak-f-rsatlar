const assert = require('assert');
const cheerio = require('cheerio');
const HepsiburadaScraper = require('../scrapers/hepsiburada_scraper');
const { resolveUrlRedirects } = require('../link_scraper_service');

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

  // 4. rating and brand
  const html3 = `
    <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@graph": [
        {
          "@type": "Product",
          "name": "Apple Watch Series 11",
          "brand": { "@additionalType": "Organization", "name": "Apple" },
          "aggregateRating": { "@type": "AggregateRating", "ratingValue": 4.8, "ratingCount": 1173 },
          "offers": { "price": "20999.00" }
        }
      ]
    }
    </script>
  `;
  const $3 = cheerio.load(html3);
  assert.strictEqual(scraper.scrapeTitle($3), 'Apple Watch Series 11');
  assert.strictEqual(await scraper.scrapePrice($3), 20999.00);
  const rating3 = scraper.scrapeRating($3);
  assert.strictEqual(rating3.ratingValue, 4.8);
  assert.strictEqual(rating3.ratingCount, 1173);
  assert.strictEqual(scraper.scrapeBrand($3), 'Apple');

  // 5. hb.biz kısa link çözümleme testi (Adjust fallback → hepsiburada.com)
  console.log('\n--- hb.biz kısa link çözümleme testleri ---');
  const hbBizTestUrls = [
    'https://app.hb.biz/ycpwZNyv7dFK',
    'https://app.hb.biz/a5bzztOjKFMB',
    'https://app.hb.biz/RRAGeZnddSrr'
  ];
  for (const shortUrl of hbBizTestUrls) {
    const resolved = await resolveUrlRedirects(shortUrl);
    assert.ok(
      resolved.includes('hepsiburada.com'),
      `hb.biz resolve FAILED: ${shortUrl} → ${resolved} (hepsiburada.com bekleniyor)`
    );
    console.log(`✅ ${shortUrl} → ${resolved.substring(0, 80)}...`);
  }
}

module.exports = { run };
