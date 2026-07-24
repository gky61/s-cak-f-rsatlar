const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Karınca Yumurtası Yağı)',
    url: 'https://www.trendyol.com/ornate/karinca-yumurtasi-yagli-tuy-azaltici-ve-tuy-serum-30ml-0-5-formic-acid-10-aloe-vera-p-474728905?boutiqueId=61',
    expectedDiscounted: 249.99,
    expectedOriginal: 259.99,
  },
  {
    name: 'Link 2 (Mavi Kil Maskesi)',
    url: 'https://www.trendyol.com/qremfi/sifir-gozenek-siyah-nokta-mavi-kil-maskesi-aha-bha-pha-100-ml-p-1087380299?boutiqueId=61',
    expectedDiscounted: 272.66,
    expectedOriginal: 279.90,
  },
  {
    name: 'Link 3 (Çubuklu Oda Kokusu)',
    url: 'https://www.trendyol.com/secret-of-love/cubuklu-oda-kokusu-beyaz-sabun-100ml-p-856508217?boutiqueId=61&merchantId=476096',
    expectedDiscounted: 155.78,
    expectedOriginal: 163.98,
  },
  {
    name: 'Link 4 (Gürme Sütlü Çikolata)',
    url: 'https://www.trendyol.com/swedent/gurme-serisi-sutlu-cikolata-sos-kremsi-dokusu-ile-zengin-ve-akiskan-kivam-p-1130262186?boutiqueId=61',
    expectedDiscounted: 249.90,
    expectedOriginal: 269.90,
  },
  {
    name: 'Link 5 (Dyson Süpürge)',
    url: 'https://www.trendyol.com/dyson/big-ball-absolute-2-kablolu-supurge-p-1106741113?boutiqueId=61&merchantId=117947',
    expectedDiscounted: 16999.00,
    expectedOriginal: 19999.00,
  },
];

async function run() {
  console.log('🚀 Starting Node.js Trendyol Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} TRENDYOL ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
