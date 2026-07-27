const assert = require('assert');
const cheerio = require('cheerio');
const MigrosScraper = require('../scrapers/migros_scraper');

async function testMigrosOriginalPrice() {
  console.log('Testing MigrosScraper scrapeOriginalPrice...');
  const scraper = new MigrosScraper();

  // Test 1: DOM with .single-price-amount
  const html1 = `
    <html>
      <body>
        <div class="product-detail">
          <span class="single-price-amount"> 70,00 <span class="currency">TL</span></span>
          <span id="new-amount">50,00 TL</span>
        </div>
      </body>
    </html>
  `;
  const $1 = cheerio.load(html1);
  const price1 = await scraper.scrapePrice($1);
  const origPrice1 = await scraper.scrapeOriginalPrice($1, price1);

  assert.strictEqual(price1, 50);
  assert.strictEqual(origPrice1, 70);
  console.log('✅ Test 1 passed: .single-price-amount extracted originalPrice = 70, currentPrice = 50');

  // Test 2: Product without discount (no .single-price-amount)
  const html2 = `
    <html>
      <body>
        <div class="product-detail">
          <span id="new-amount">50,00 TL</span>
        </div>
      </body>
    </html>
  `;
  const $2 = cheerio.load(html2);
  const price2 = await scraper.scrapePrice($2);
  const origPrice2 = await scraper.scrapeOriginalPrice($2, price2);

  assert.strictEqual(price2, 50);
  assert.strictEqual(origPrice2, null);
  console.log('✅ Test 2 passed: No discount returned null originalPrice');

  console.log('🎉 All Migros original price tests passed successfully!');
}

testMigrosOriginalPrice();
