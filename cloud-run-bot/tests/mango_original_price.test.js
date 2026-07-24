const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Erkek Süet Ayakkabı)',
    url: 'https://shop.mango.com/tr/tr/p/erkek/ayakkab%C4%B1/deri/suet-ayakkab%C4%B1/37091356/CG/00',
    expectedDiscounted: 2499.99,
    expectedOriginal: 3699.99,
  },
  {
    name: 'Link 2 (Erkek Gabardin Trençkot / Parka)',
    url: 'https://shop.mango.com/tr/tr/p/erkek/gabardin-trenckotlar/su-gecirmez-parka--c%C4%B1kar%C4%B1labilir-kapusonlu/27034409/56/00',
    expectedDiscounted: 2399.99,
    expectedOriginal: 7999.99,
  },
];

async function run() {
  console.log('🚀 Starting Node.js Mango Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} MANGO ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
