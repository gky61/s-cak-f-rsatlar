const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Cepli İnterlok Sweatshirt)',
    url: 'https://www.zara.com/tr/tr/cepli-interlok-sweatshirt-p00761409.html?v1=498899772&v2=2537962',
    expectedDiscounted: 590,
    expectedOriginal: 750,
  },
  {
    name: 'Link 2 (Yün Karışımlı Yama Cepli Blazer)',
    url: 'https://www.zara.com/tr/tr/yun-karisimli-yama-cepli-blazer-p04422136.html?v1=513992488&v2=2724459',
    expectedDiscounted: 1290,
    expectedOriginal: 1690,
  },
  {
    name: 'Link 3 (Deri Makosen)',
    url: 'https://www.zara.com/tr/tr/deri-makosen-p12653720.html?v1=508357135&v2=2721511',
    expectedDiscounted: 3390,
    expectedOriginal: 3990,
  },
];

async function run() {
  console.log('🚀 Starting Node.js Zara Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} ZARA ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
