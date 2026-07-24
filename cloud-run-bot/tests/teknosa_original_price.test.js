const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Honor Magic 8 Lite 5G)',
    url: 'https://www.teknosa.com/honor-magic-8-lite-5g-8512gb-kizil-kahve-akilli-telefon-p-100000060344?shopId=teknosa',
    expectedDiscounted: 25999.00,
    expectedOriginal: 29999.00,
  },
  {
    name: 'Link 2 (Samsung Galaxy S26 Ultra 5G)',
    url: 'https://www.teknosa.com/samsung-galaxy-s26-ultra-5g-12512gb-mor-akilli-telefon-p-100000061511?shopId=teknosa',
    expectedDiscounted: 99999.00,
    expectedOriginal: 105999.00,
  },
  {
    name: 'Link 3 (Philips 55PUS900062 TV)',
    url: 'https://www.teknosa.com/philips-55pus900062-55-139-ekran-4k-uhd-titan-os-ambilight-tv-p-100000055139?shopId=teknosa',
    expectedDiscounted: 43299.00,
    expectedOriginal: 49999.00,
  },
  {
    name: 'Link 4 (TCL 55 C6K TV)',
    url: 'https://www.teknosa.com/tcl-55-c6k-premium-qd-mini-led-tv-p-100000055042?shopId=teknosa',
    expectedDiscounted: 49999.00,
    expectedOriginal: 56999.00,
  },
];

async function run() {
  console.log('🚀 Starting Node.js Teknosa Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} TEKNOSA ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
