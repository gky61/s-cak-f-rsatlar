const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Microsoft Xbox Series Wireless Gamepad)',
    url: 'https://www.itopya.com/microsoft-xbox-series-wireless-ice-breaker-gamepad_u31675',
    expectedDiscounted: 3846.19,
    expectedOriginal: 6080.09,
    expectedBrand: 'MICROSOFT',
  },
  {
    name: 'Link 2 (ASUS ROG Strix XG27AQDMGR Monitör)',
    url: 'https://www.itopya.com/asus-rog-strix-xg27aqdmgr-265-240hz-003ms-hdmi-dp-usb-32-adaptivesync-pivot-hdr10-woled-monitor_u31945',
    expectedDiscounted: 28144.33,
    expectedOriginal: 36594.98,
    expectedBrand: 'ASUS',
  },
  {
    name: 'Link 3 (ASUS TUF Gaming Laptop / PC)',
    url: 'https://www.itopya.com/asus-tuf-gaming-t500mv-07240h0860-core-7-240h-16gb-ddr5-1tb-ssd-660w-80-gold-rtx-5060-dual-8gb-gddr_u33227',
    expectedDiscounted: 67999.00,
    expectedOriginal: 83208.24,
    expectedBrand: 'ASUS',
  },
  {
    name: 'Link 4 (AOC QD-OLED Monitör)',
    url: 'https://www.itopya.com/aoc-q27g41zdf-27-240hz-003ms-hdmi-dp-adaptive-sync-hdr10-qhd-qd-oled-gaming-monitor_u32391',
    expectedDiscounted: 21999.00,
    expectedOriginal: 22671.82,
    expectedBrand: 'AOC',
    expectedRatingValue: 5,
    expectedRatingCount: 4,
  },
];

async function run() {
  console.log('🚀 Starting Node.js İtopya Original Price Unit Tests...\n');
  let passed = 0;

  for (const tc of testCases) {
    console.log(`------------------------------------------------------------`);
    console.log(`Testing: ${tc.name}`);
    console.log(`URL: ${tc.url}`);
    
    const result = await linkScraperService.scrapeProductFromUrl(tc.url);
    console.log(`Scraped Discounted Price: ${result.price} TL (Expected: ${tc.expectedDiscounted} TL)`);
    console.log(`Scraped Original Price:   ${result.originalPrice} TL (Expected: ${tc.expectedOriginal} TL)`);
    console.log(`Scraped Brand:            ${result.brand} (Expected: ${tc.expectedBrand})`);
    console.log(`Scraped Rating:           ${JSON.stringify(result.rating)}`);

    assert.ok(result.price !== null, 'Discounted price should not be null');
    assert.ok(Math.abs(result.price - tc.expectedDiscounted) < 0.01, `Discounted price should match ${tc.expectedDiscounted}`);
    assert.ok(Math.abs(result.originalPrice - tc.expectedOriginal) < 0.01, `Original price should match ${tc.expectedOriginal}`);
    assert.ok(result.brand && result.brand.toUpperCase() === tc.expectedBrand.toUpperCase(), `Brand should match ${tc.expectedBrand}`);

    if (tc.expectedRatingValue && result.rating && result.rating.ratingValue) {
      assert.ok(result.rating.ratingValue === tc.expectedRatingValue, `Rating value should match ${tc.expectedRatingValue}`);
    }
    if (tc.expectedRatingCount && result.rating && result.rating.ratingCount) {
      assert.ok(result.rating.ratingCount === tc.expectedRatingCount, `Rating count should match ${tc.expectedRatingCount}`);
    }

    if (result.originalPrice !== null && result.price !== null && result.originalPrice > result.price) {
      const discountPercent = Math.round(((result.originalPrice - result.price) / result.originalPrice) * 100);
      console.log(`Calculated Discount Percentage: %${discountPercent}`);
    }
    console.log(`✅ PASSED: ${tc.name}\n`);
    passed++;
  }

  console.log(`🎉 ALL ${passed}/${testCases.length} İTOPYA ORIGINAL PRICE & RATING TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
