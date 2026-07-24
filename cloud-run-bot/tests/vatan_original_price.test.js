const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (iPad A16 Tablet - İndirim Yok)',
    url: 'https://www.vatanbilgisayar.com/ipad-a16-tablet.html',
    expectedDiscounted: 24999.00,
    expectedOriginal: null,
  },
  {
    name: 'Link 2 (Philips PSG9050 Ütü)',
    url: 'https://www.vatanbilgisayar.com/philips-psg9050-20-perfectcare-9000-serisi-buhar-kazanli-utu.html',
    expectedDiscounted: 27499.00,
    expectedOriginal: 32379.00,
  },
  {
    name: 'Link 3 (Cougar Defansor Oyuncu Koltuğu)',
    url: 'https://www.vatanbilgisayar.com/cougar-defansor-gold-f-siyah-sari-oyuncu-koltugu.html',
    expectedDiscounted: 17499.00,
    expectedOriginal: 20329.00,
  },
  {
    name: 'Link 4 (MacBook Neo)',
    url: 'https://www.vatanbilgisayar.com/macbook-neo-mhfe4tu-a-a18-pro-8gb-512gb-ssd-13inc-puslu-sari.html',
    expectedDiscounted: 42299.00,
    expectedOriginal: 46999.00,
  },
  {
    name: 'Link 5 (JBL Charge 6 Hoparlör)',
    url: 'https://www.vatanbilgisayar.com/jbl-charge6-bluetooth-hoparlor-kirmizi.html',
    expectedDiscounted: 8456.00,
    expectedOriginal: 9949.00,
  },
];

async function run() {
  console.log('🚀 Starting Node.js Vatan Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} VATAN ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
