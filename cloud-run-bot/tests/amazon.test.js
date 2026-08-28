const assert = require('assert');
const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');
const AmazonScraper = require('../scrapers/amazon_scraper');

async function run() {
  const scraper = new AmazonScraper();

  // 1. canHandle
  assert.strictEqual(scraper.canHandle('https://www.amazon.com.tr/dp/B0GGB6P1JF'), true);
  assert.strictEqual(scraper.canHandle('https://amzn.eu/d/07A3YdHA'), true);
  assert.strictEqual(scraper.canHandle('https://www.google.com'), false);

  // 2. DOM-based test
  const htmlDom = `
    <html>
      <body>
        <h1 id="productTitle">iFFALCON 75U75A 75 İnç Smart TV</h1>
        <div id="averageCustomerReviews">
          <span class="a-icon-alt">5 yıldız üzerinden 4,3</span>
          <span id="acrCustomerReviewText">(16)</span>
        </div>
        <table>
          <tr class="po-brand">
            <td class="po-break-word">iFFALCON</td>
          </tr>
        </table>
      </body>
    </html>
  `;
  const $dom = cheerio.load(htmlDom);
  const ratingDom = scraper.scrapeRating($dom);
  assert.strictEqual(ratingDom.ratingValue, 4.3, 'ratingValue should be 4.3');
  assert.strictEqual(ratingDom.ratingCount, 16, 'ratingCount should be 16');
  assert.strictEqual(scraper.scrapeBrand($dom), 'iFFALCON', 'brand should be iFFALCON');

  // 4. priceLabel Prime Delivery Exclusion (Prime ile Ücretsiz Teslimat Prime Fırsatı rozeti vermemeli!)
  const htmlDelivery = `
    <html>
      <body>
        <div id="navbar"><a href="/prime">Prime Fırsat Günleri</a></div>
        <div id="mir-layout-DELIVERY_BLOCK">
          <span>Prime ile ÜCRETSİZ teslimat: Yarın</span>
        </div>
        <div class="a-section">Normal Fiyat: 500 TL</div>
      </body>
    </html>
  `;
  const $delivery = cheerio.load(htmlDelivery);
  assert.strictEqual(scraper.scrapePriceLabel($delivery), null, 'Prime teslimat veya header bannerları Prime Fırsatı rozeti vermemeli!');

  // 5. priceLabel True Prime Deal (dealBadgeSupportingText veya primeExclusivePricing)
  const htmlPrimeDeal = `
    <html>
      <body>
        <div id="apex_desktop">
          <span id="dealBadgeSupportingText">Prime Fırsatı</span>
          <span class="a-price">299,00 TL</span>
        </div>
      </body>
    </html>
  `;
  const $prime = cheerio.load(htmlPrimeDeal);
  assert.strictEqual(scraper.scrapePriceLabel($prime), 'Prime Fırsatı', 'Gerçek Prime Fırsatı doğru algılanmalı!');
  console.log('✅ Amazon priceLabel testleri başarıyla geçti!');
}

module.exports = { run };

if (require.main === module) {
  run();
}

