const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Soft Premium Açık Mavi Polo Tişört)',
    url: 'https://www.mavi.com/soft-premium-acik-mavi-polo-tisort/p/0613271-70802',
    expectedDiscounted: 749.99,
    expectedOriginal: 1499.99,
  },
  {
    name: 'Link 2 (Road Runner Baskılı Mavi Tişört)',
    url: 'https://www.mavi.com/road-runner-baskili-mavi-tisort/p/0613200-70758',
    expectedDiscounted: 449.99,
    expectedOriginal: 629.99,
  },
  {
    name: 'Link 3 (Mini Mavi Logo Baskılı Interlok Siyah Basic Tişört)',
    url: 'https://www.mavi.com/mini-mavi-logo-baskili-interlok-siyah-basic-tisort/p/1612122-900',
    expectedDiscounted: 419.99,
    expectedOriginal: 599.99,
  },
];

async function run() {
  console.log('🚀 Starting Node.js Mavi Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} MAVI ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
