const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Adidas Samba OG Koyu Kahverengi Kadın Sneaker)',
    url: 'https://www.beymen.com/tr/p_adidas-samba-og-koyu-kahverengi-kadin-sneaker_1907622',
    expectedDiscounted: 4076,
    expectedOriginal: 7250,
  },
  {
    name: 'Link 2 (Bekaliving Hills Brass Ahşap 3lü Orta Sehpa)',
    url: 'https://www.beymen.com/tr/p_bekaliving-hills-brass-cam-detay-mushroom-ahsap-3lu-orta-sehpa-takimi_1113301',
    expectedDiscounted: 51793,
    expectedOriginal: 73990,
  },
  {
    name: 'Link 3 (Beymen Club Siyah Beyaz Çizgili Sweatshirt)',
    url: 'https://www.beymen.com/tr/p_beymen-club-siyah-beyaz-cizgili-sweatshirt_1921513',
    expectedDiscounted: 2499,
    expectedOriginal: 4999,
  },
];

async function run() {
  console.log('🚀 Starting Node.js Beymen Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} BEYMEN ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
