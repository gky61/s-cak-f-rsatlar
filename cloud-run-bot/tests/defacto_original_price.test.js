const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Pamuklu Regular Fit Polo Tişört)',
    url: 'https://www.defacto.com.tr/pamuklu-regular-fit-kisa-kollu-polo-tisort-3429279',
    expectedDiscounted: 399.99,
    expectedOriginal: 799.99,
  },
  {
    name: 'Link 2 (Regular Fit Pamuklu Smart Casual Pantolon)',
    url: 'https://www.defacto.com.tr/regular-fit-pamuklu-smart-casual-pantolon-3376806',
    expectedDiscounted: 499.99,
    expectedOriginal: 999.99,
  },
  {
    name: 'Link 3 (Erkek Ürün)',
    url: 'https://www.defacto.com.tr/erkek-3414636',
    expectedDiscounted: 209.99,
    expectedOriginal: 349.99,
  },
];

async function run() {
  console.log('🚀 Starting Node.js DeFacto Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} DEFACTO ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
