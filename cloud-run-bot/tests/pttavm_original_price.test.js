const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Cata CT-1156 Dolunay LED Ampul)',
    url: 'https://www.pttavm.com/cata-ct-1156-dolunay-72w-fanli-kumandali-led-ampul-3-renk-p-1456659184',
    expectedDiscounted: 1722.62,
    expectedOriginal: 1980.02,
  },
  {
    name: 'Link 2 (Rivaistanbul Ahşap Lambader)',
    url: 'https://www.pttavm.com/rivaistanbul-hasir-dokulu-silindir-baslik-ahsap-uc-ayakli-lambader-p-846468199',
    expectedDiscounted: 799.72,
    expectedOriginal: 929.90,
  },
];

async function run() {
  console.log('🚀 Starting Node.js PttAVM Original Price Unit Tests...\n');
  let passed = 0;

  for (const tc of testCases) {
    console.log(`------------------------------------------------------------`);
    console.log(`Testing: ${tc.name}`);
    console.log(`URL: ${tc.url}`);
    
    const result = await linkScraperService.scrapeProductFromUrl(tc.url);
    console.log(`Scraped Discounted Price: ${result.price} TL (Expected: ${tc.expectedDiscounted} TL)`);
    console.log(`Scraped Original Price:   ${result.originalPrice} TL (Expected: ${tc.expectedOriginal} TL)`);

    assert.ok(result.price !== null, 'Discounted price should not be null');
    assert.ok(Math.abs(result.price - tc.expectedDiscounted) < 0.01, `Discounted price should match ${tc.expectedDiscounted}`);
    assert.ok(Math.abs(result.originalPrice - tc.expectedOriginal) < 0.01, `Original price should match ${tc.expectedOriginal}`);

    if (result.originalPrice !== null && result.price !== null && result.originalPrice > result.price) {
      const discountPercent = Math.round(((result.originalPrice - result.price) / result.originalPrice) * 100);
      console.log(`Calculated Discount Percentage: %${discountPercent}`);
    }
    console.log(`✅ PASSED: ${tc.name}\n`);
    passed++;
  }

  console.log(`🎉 ALL ${passed}/${testCases.length} PTTAVM ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
