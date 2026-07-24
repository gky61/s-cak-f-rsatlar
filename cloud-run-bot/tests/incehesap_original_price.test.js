const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (AOC 27G50Z)',
    url: 'https://www.incehesap.com/aoc-27g50z-27-260hzoc-0-3ms-full-hd-freesync-fast-ips-oyuncu-monitoru-fiyati-87639/',
    expectedDiscounted: 6999.00,
    expectedOriginal: 7099.00,
  },
  {
    name: 'Link 2 (ASUS TUF Gaming VG259Q5A)',
    url: 'https://www.incehesap.com/asus-tuf-gaming-vg259q5a-24-5-inc-200hz-0-3ms-elmb-sync-fast-ips-gaming-oyuncu-monitor-fiyati-83654/',
    expectedDiscounted: 5799.00,
    expectedOriginal: 5899.00,
  },
];

async function run() {
  console.log('🚀 Starting Node.js İncehesap Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} İNCEHESAP ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
