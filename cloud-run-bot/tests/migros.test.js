const MigrosScraper = require('../scrapers/migros_scraper');
const cheerio = require('cheerio');
const assert = require('assert');

async function testMigrosScraper() {
  const scraper = new MigrosScraper();

  // Test 1: DOM label extraction
  const html = `
    <html>
      <body>
        <div class="product-label crm">50 TL SEPETTE 299 TL</div>
      </body>
    </html>
  `;
  const $ = cheerio.load(html);
  const priceLabel = await scraper.scrapePriceLabel($);
  assert.strictEqual(priceLabel, '50 TL SEPETTE 299 TL');
  console.log('✅ Test 1: DOM CRM label extraction passed!');

  // Test 2: Missing label returns null
  const html2 = `
    <html>
      <body>
        <div>No Label</div>
      </body>
    </html>
  `;
  const $2 = cheerio.load(html2);
  const priceLabel2 = await scraper.scrapePriceLabel($2);
  assert.strictEqual(priceLabel2, null);
  console.log('✅ Test 2: Missing label returns null passed!');
}

testMigrosScraper().catch(err => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
