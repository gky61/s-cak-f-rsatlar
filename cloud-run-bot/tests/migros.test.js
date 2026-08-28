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

  // Test 2: Multi-buy campaign from DOM (3 AL 2 ÖDE)
  const html3a2o = `
    <html>
      <body>
        <div class="product-label crm">3 AL 2 ÖDE</div>
      </body>
    </html>
  `;
  const $3a2o = cheerio.load(html3a2o);
  const priceLabel3a2o = await scraper.scrapePriceLabel($3a2o);
  assert.strictEqual(priceLabel3a2o, '3 AL 2 ÖDE');
  console.log('✅ Test 2: DOM 3 AL 2 ÖDE extraction passed!');

  // Test 3: Money gift campaign preserved as is (3 Al 2'si Money Hediye)
  const htmlDido = `
    <html>
      <body>
        <div class="product-label crm">3 Al 2'si Money Hediye</div>
      </body>
    </html>
  `;
  const $dido = cheerio.load(htmlDido);
  const priceLabelDido = await scraper.scrapePriceLabel($dido);
  assert.strictEqual(priceLabelDido, "3 Al 2'si Money Hediye");
  console.log('✅ Test 3: DOM 3 Al 2\'si Money Hediye extraction passed!');

  // Test 4: Generic 'İYİ FİYAT' returns null
  const htmlGoodPrice = `
    <html>
      <body>
        <div class="product-label crm">İYİ FİYAT</div>
      </body>
    </html>
  `;
  const $goodPrice = cheerio.load(htmlGoodPrice);
  const priceLabelGood = await scraper.scrapePriceLabel($goodPrice);
  assert.strictEqual(priceLabelGood, null);
  console.log('✅ Test 4: Generic İYİ FİYAT returns null passed!');

  // Test 5: Missing label returns null
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
  console.log('✅ Test 4: Missing label returns null passed!');
}

testMigrosScraper().catch(err => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
