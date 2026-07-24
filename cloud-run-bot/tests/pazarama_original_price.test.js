const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (LG 65QNED TV)',
    url: 'https://www.pazarama.com/lg-65qned70b6c-4k-uhd-qned-mini-led-tv-165-cm-8806096774205-p-8806096774205?magaza=mediamarkt',
    expectedDiscounted: 49882.00,
    expectedOriginal: 50900.00,
  },
  {
    name: 'Link 2 (Einhell Akülü Çivi Zımba)',
    url: 'https://www.pazarama.com/einhell-te-cn-18-li-akulu-civi-ve-zimba-tabancasi-seti-25-ah-aku-ve-sarj-cihazi-dahildir-p-8694301331219?magaza=pazarama',
    expectedDiscounted: 5140.00,
    expectedOriginal: 5440.00,
  },
  {
    name: 'Link 3 (Peros Sıvı Sabun)',
    url: 'https://www.pazarama.com/peros-sivi-sabun-3-kg-aqua-deniz-esintisi-p-8697713838895',
    expectedDiscounted: 104.41,
    expectedOriginal: 149.90,
  },
  {
    name: 'Link 4 (Philips Vantilatör)',
    url: 'https://www.pazarama.com/philips-cx-553500-kule-tipi-vantilator-beyaz-p-8720389036972',
    expectedDiscounted: 5758.00,
    expectedOriginal: 7200.00,
  },
  {
    name: 'Link 5 (Flormar Fondöten Kapatıcı)',
    url: 'https://www.pazarama.com/yogun-kapaticilik-sunan-2li-fondotenkapatici-seti-acik-tensoguk-alt-ton-p-SET137?magaza=flormar',
    expectedDiscounted: 617.50,
    expectedOriginal: 899.99,
  },
];

async function run() {
  console.log('🚀 Starting Node.js Pazarama Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} PAZARAMA ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
