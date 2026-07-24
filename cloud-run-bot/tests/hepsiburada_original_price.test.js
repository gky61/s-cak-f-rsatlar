const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Seduna Skagen Plus)',
    url: 'https://www.hepsiburada.com/seduna-skagen-plus-calisma-sandalyesi-ofis-koltugu-p-HBV00000NDU7K',
    expectedDiscounted: 4013.86,
    expectedOriginal: 4138.00,
  },
  {
    name: 'Link 2 (Magly Magnetic Cars)',
    url: 'https://www.hepsiburada.com/magly-magnetic-cars-manyetik-arac-oyun-seti-manyetik-yapi-bloklari-araba-eklentisi-p-HBCV0000E3NYHR',
    expectedDiscounted: 336.00,
    expectedOriginal: 545.00,
  },
  {
    name: 'Link 3 (Philips 8000 Kahve Makinesi)',
    url: 'https://www.hepsiburada.com/philips-8000-serisi-caf-aromis-kahve-makinesi-evde-kafe-kalitesi-54-farkli-icecek-ep8757-92-p-HBCV0000F9H40O',
    expectedDiscounted: 42999.00,
    expectedOriginal: 47999.00,
  },
  {
    name: 'Link 4 (Lego Technic Kazıcı Yükleyici)',
    url: 'https://www.hepsiburada.com/lego-technic-kazici-yukleyici-42197-7-yas-uzeri-cocuklar-icin-yaratici-oyuncak-model-yapim-seti-104-parca-p-HBCV00007GPXE2',
    expectedDiscounted: 399.01,
    expectedOriginal: 498.76,
  },
  {
    name: 'Link 5 (Apple MacBook Pro M5 - İndirim Yok)',
    url: 'https://www.hepsiburada.com/apple-macbook-pro-m5-pro-24gb-2tb-ssd-macos-14-tasinabilir-bilgisayar-uzay-siyahi-mjlw4tua-p-HBCV0000D5WX1P?url_src=and-product-detail',
    expectedDiscounted: 166499.00,
    expectedOriginal: null,
  },
  {
    name: 'Link 6 (Lego Futbol Topu - İndirim Yok)',
    url: 'https://www.hepsiburada.com/lego--editions-futbol-topu-43019---10-cocuklar-icin-yaratici-oyuncak-yapim-seti---dunya-kupasi-koleksiyonu-1498-parca-p-HBCV0000CT57NP?magaza=Toyzz+Shop&url_src=and-product-detail',
    expectedDiscounted: 5699.00,
    expectedOriginal: null,
  },
];

async function run() {
  console.log('🚀 Starting Node.js Hepsiburada Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} HEPSİBURADA ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
