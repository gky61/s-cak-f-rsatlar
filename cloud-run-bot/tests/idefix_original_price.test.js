const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Sony DualSense 007 LE)',
    url: 'https://www.idefix.com/sony-playstation-dualsensebond-007-le-bilkom-garantili-p-25934572',
    expectedDiscounted: 6047.90,
    expectedOriginal: 6234.95,
  },
  {
    name: 'Link 2 (Lenovo XT62 Kulaklık)',
    url: 'https://www.idefix.com/lenovo-xt62-kulaklik-bluetooth-53-kablosuz-kulakici-kulaklik-hd-cagri-siyah-p-3442168',
    expectedDiscounted: 793.90,
    expectedOriginal: 850.00,
  },
  {
    name: 'Link 3 (Ray-Ban Güneş Gözlüğü)',
    url: 'https://www.idefix.com/ray-ban-2186-90171-49-20-kadin-gunes-gozlugu-p-7613778',
    expectedDiscounted: 4307.53,
    expectedOriginal: 5334.40,
  },
  {
    name: 'Link 4 (Samsung Süpürge)',
    url: 'https://www.idefix.com/samsung-vc07r302mvr-kirmizi-750-w-toz-torbasiz-supurge-p-771736',
    expectedDiscounted: 4560.00,
    expectedOriginal: 7290.00,
  },
];

async function run() {
  console.log('🚀 Starting Node.js idefix Original Price Unit Tests...\n');
  let passed = 0;

  for (const tc of testCases) {
    console.log(`------------------------------------------------------------`);
    console.log(`Testing: ${tc.name}`);
    console.log(`URL: ${tc.url}`);
    
    const result = await linkScraperService.scrapeProductFromUrl(tc.url);
    console.log(`Scraped Discounted Price: ${result.price} TL (Expected: ${tc.expectedDiscounted} TL)`);
    console.log(`Scraped Original Price:   ${result.originalPrice} TL (Expected: ${tc.expectedOriginal} TL)`);

    assert.ok(result.price !== null, 'Discounted price should not be null');
    assert.strictEqual(result.price, tc.expectedDiscounted, `Discounted price should match ${tc.expectedDiscounted}`);
    assert.strictEqual(result.originalPrice, tc.expectedOriginal, `Original price should match ${tc.expectedOriginal}`);

    if (result.originalPrice !== null && result.price !== null && result.originalPrice > result.price) {
      const discountPercent = Math.round(((result.originalPrice - result.price) / result.originalPrice) * 100);
      console.log(`Calculated Discount Percentage: %${discountPercent}`);
    }
    console.log(`✅ PASSED: ${tc.name}\n`);
    passed++;
  }

  console.log(`🎉 ALL ${passed}/${testCases.length} IDEFIX ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
