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

  // 3. Real HTML file test
  const filePath = path.join(__dirname, '../../scratch/amazon-page.html');
  if (fs.existsSync(filePath)) {
    const htmlReal = fs.readFileSync(filePath, 'utf8');
    const $real = cheerio.load(htmlReal);
    const ratingReal = scraper.scrapeRating($real);
    assert.strictEqual(ratingReal.ratingValue, 4.3, 'Real ratingValue should be 4.3');
    assert.strictEqual(ratingReal.ratingCount, 16, 'Real ratingCount should be 16');
    assert.strictEqual(scraper.scrapeBrand($real), 'iFFALCON', 'Real brand should be iFFALCON');
  }
}

module.exports = { run };
