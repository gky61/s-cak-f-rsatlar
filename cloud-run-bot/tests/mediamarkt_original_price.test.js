const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (ASUS TUF Gaming F16)',
    url: 'https://www.mediamarkt.com.tr/tr/product/_asus-tuf-gaming-f16-fx608jhr-rv047wintelr-coretm-i7-14650hx16-gb-ram512-gb-ssdrtx-505016w11-laptop-1247804.html',
    expectedDiscounted: 66999.00,
    expectedOriginal: 69999.00,
  },
  {
    name: 'Link 2 (Momax iPhone 15 Pro Kılıf)',
    url: 'https://www.mediamarkt.com.tr/tr/product/_momax-mrap23me-iphone-15-pro-roller-magsafe-kilif-uzay-grisi-1237656.html',
    expectedDiscounted: 99.00,
    expectedOriginal: 399.00,
  },
  {
    name: 'Link 3 (ASUS Zenbook 14 - Sepette İndirim)',
    url: 'https://www.mediamarkt.com.tr/tr/product/_asus-zenbook14-ux3405ca-st825wcore-u9-285h32114w11-1252868.html',
    expectedDiscounted: 71999.10,
    expectedOriginal: 79999.00,
  },
  {
    name: 'Link 4 (Logitech G Pro X2 - Sepette İndirim)',
    url: 'https://www.mediamarkt.com.tr/tr/product/_logitech-g-pro-x2-superstrike-kablosuz-oyuncu-mouse-beyaz-910-007777-1252130.html',
    expectedDiscounted: 9499.05,
    expectedOriginal: 9999.00,
  },
  {
    name: 'Link 5 (Philips Fan Isıtıcı 3ü1)',
    url: 'https://www.mediamarkt.com.tr/tr/product/_philips-amf87015-1-fan-isitici-3u-arada-hava-temizleyici-1228048.html',
    expectedDiscounted: 22199.00,
    expectedOriginal: 23999.00,
  },
  {
    name: 'Link 6 (Dyson V10 Submarine)',
    url: 'https://www.mediamarkt.com.tr/tr/product/_dyson-cyclone-v10-submarine-islak-kuru-sarjli-dikey-supurge-1251854.html',
    expectedDiscounted: 23999.00,
    expectedOriginal: 27999.00,
  },
];

async function run() {
  console.log('🚀 Starting Node.js MediaMarkt Original Price Unit Tests...\n');
  let passed = 0;

  for (const tc of testCases) {
    console.log(`------------------------------------------------------------`);
    console.log(`Testing: ${tc.name}`);
    console.log(`URL: ${tc.url}`);
    
    const result = await linkScraperService.scrapeProductFromUrl(tc.url);
    console.log(`Scraped Discounted Price: ${result.price} TL (Expected: ${tc.expectedDiscounted} TL)`);
    console.log(`Scraped Original Price:   ${result.originalPrice} TL (Expected: ${tc.expectedOriginal} TL)`);

    assert.ok(result.price !== null, 'Discounted price should not be null');
    assert.ok(Math.abs(result.price - tc.expectedDiscounted) < 0.1, `Discounted price should match ${tc.expectedDiscounted}`);
    assert.strictEqual(result.originalPrice, tc.expectedOriginal, `Original price should match ${tc.expectedOriginal}`);

    if (result.originalPrice !== null && result.price !== null && result.originalPrice > result.price) {
      const discountPercent = Math.round(((result.originalPrice - result.price) / result.originalPrice) * 100);
      console.log(`Calculated Discount Percentage: %${discountPercent}`);
    }
    console.log(`✅ PASSED: ${tc.name}\n`);
    passed++;
  }

  console.log(`🎉 ALL ${passed}/${testCases.length} MEDIAMARKT ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
