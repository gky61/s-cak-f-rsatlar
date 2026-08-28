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

  // 5. priceLabel Tests (False Positive Prevention vs True Premium)
  console.log('\n--- priceLabel (Premium) testleri ---');
  // 5.1. False Positive Prevention (Genel kupon/taksit tag'leri Premium sayılmamalı)
  const htmlFalse = `
    <script id="reduxStore" type="application/json">
    {
      "productState": {
        "product": {
          "name": "Pepsi Strawberries",
          "tagList": [
            {"tagId": "premiumlulara-ozel-gida-icecek-urunlerinde-50-tl-uzeri-15-indirim"},
            {"tagId": "premium-a-ozel-supermarket-urunlerinde-750-tl-ye-150-tl-kupon-firsati"},
            {"tagId": "premiuma-gec-50-tl-indirim-kazanma-firsati"},
            {"tagId": "premium-vade-farksiz"}
          ],
          "mainProductTagList": [
            {"tagId": "premium-vade-farksiz"}
          ],
          "paymentTag": "premium-vade-farksiz"
        }
      }
    }
    </script>
    <header><a class="sf-TopLinks-P85WSaCVLc_4UmgwMQJt">Hepsiburada Premium</a></header>
  `;
  const $false = cheerio.load(htmlFalse);
  assert.strictEqual(scraper.scrapePriceLabel($false), null, 'Genel kupon ve taksit tagleri Premium olarak algılanmamalıdır!');

  // 5.2. True Premium (DOM Eşleşmesi)
  const htmlTrueDom = `
    <div><span class="premium-price">Premium ile <b>1.411,83 TL</b></span></div>
  `;
  const $trueDom = cheerio.load(htmlTrueDom);
  assert.strictEqual(scraper.scrapePriceLabel($trueDom), 'Premium ile', 'DOM Premium ile algılanmalı');

  // 5.3. True Premium (Doğrudan Satıcı İndirim Etiketi)
  const htmlTrueRedux = `
    <script id="reduxStore" type="application/json">
    {
      "productState": {
        "product": {
          "name": "Altınyıldız Polo Tişört",
          "tagList": [
            {"tagId": "92520395-premium-a-ozel-altinyildiz-classics-saticili-secili-urunlerde-10-indirim"}
          ]
        }
      }
    }
    </script>
  `;
  const $trueRedux = cheerio.load(htmlTrueRedux);
  assert.strictEqual(scraper.scrapePriceLabel($trueRedux), 'Premium ile', 'Satıcıya özel Premium etiketi algılanmalı');

  // 6. hb.biz kısa link çözümleme testi (Adjust fallback → hepsiburada.com)
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

