const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (LG 65QNED TV)',
    url: 'https://www.n11.com/urun/lg-65qned70b6c-65-165-ekran-uydu-alicili-4k-ultra-hd-smart-webos-miniled-tv-128133247?magaza=tekno11',
    expectedDiscounted: 46409.09,
    expectedOriginal: 50999.00,
  },
  {
    name: 'Link 2 (Samsung Mikrodalga)',
    url: 'https://www.n11.com/urun/samsung-ms23k3614awtr-23-lt-solo-mikrodalga-firin-61161984?magaza=samsungturkiye',
    expectedDiscounted: 4912.20,
    expectedOriginal: 5167.80,
  },
  {
    name: 'Link 3 (Tefal Tencere Seti)',
    url: 'https://www.n11.com/urun/tefal-optispace-6-parca-tencere-seti-16784781?magaza=tefal',
    expectedDiscounted: 3999.00,
    expectedOriginal: 5499.00,
  },
  {
    name: 'Link 4 (Samsung Galaxy A17)',
    url: 'https://www.n11.com/urun/samsung-galaxy-a17-5g-8-gb-256-gb-samsung-turkiye-garantili-98196396?renk=gri&magaza=n11',
    expectedDiscounted: 16399.00,
    expectedOriginal: 19399.00,
  },
  {
    name: 'Link 5 (Yunuşoğlu Plaj Çantası)',
    url: 'https://www.n11.com/urun/yunusoglu-home-genis-hacimli-ham-bez-plaj-cantasi-ic-cepli-sik-tasarim-bordo-35-cm-x-45-cm-128529494?magaza=yunusogluhome',
    expectedDiscounted: 275.91,
    expectedOriginal: 299.90,
  },
  {
    name: 'Link 6 (Karaca Barbekü Mangal Seti)',
    url: 'https://www.n11.com/urun/onluklu-7-parca-ahsap-sapli-barbekumangal-seti-94403175?magaza=karaca',
    expectedDiscounted: 819.98,
    expectedOriginal: 919.98,
  },
];

async function run() {
  console.log('🚀 Starting Node.js N11 Original Price Unit Tests...\n');
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

  console.log(`🎉 ALL ${passed}/${testCases.length} N11 ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
