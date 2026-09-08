const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Ulike Air 3 Lazer Epilasyon)',
    url: 'https://www.n11.com/urun/ulike-air-3-ipl-lazer-epilasyon-cihazi-beyaz-87746993',
    expectedDiscounted: 23422.00,
    expectedOriginal: 23899.00,
  },
  {
    name: 'Link 2 (Torima Sac Sekillendirici)',
    url: 'https://www.n11.com/urun/torima-thd-01-pembe-7-in-1-hava-uflemeli-sac-sekillendirici-85589731?magaza=torima',
    expectedDiscounted: 6578.00,
    expectedOriginal: 7150.00,
  },
  {
    name: 'Link 3 (Vicco Isikli Cocuk Ayakkabi)',
    url: 'https://www.n11.com/urun/vicco-toyga-isikli-erkek-cocuk-beyaz-spor-ayakkabi-126873713?numara=32&magaza=vicco',
    expectedDiscounted: 1759.92,
    expectedOriginal: 2199.90,
  },
  {
    name: 'Link 4 (Oto Koltuk Minderi)',
    url: 'https://www.n11.com/urun/oto-koltuk-minderi-bambu-bel-destekli-ergonomik-terletmez-universal-fa1-625-1-adet-78679123?magaza=otoaksesuarist',
    expectedDiscounted: 790.15,
    expectedOriginal: 888.92,
  },
  {
    name: 'Link 5 (BMW Direksiyon Logosu)',
    url: 'https://www.n11.com/urun/bmw-direksiyon-logosu-oem-metal-47-mm-tam-olcu-sticker-degil-hatasiz-uyum-47mm-120238944?magaza=onurexpresstuning',
    expectedDiscounted: 399.20,
    expectedOriginal: 449.10,
  },
  {
    name: 'Link 6 (Ayak Alti Led Lamba)',
    url: 'https://www.n11.com/urun/ayak-alti-led-lamba-sese-duyarli-led-muzige-duyarli-led-12-led-440870900-23334181?magaza=onurexpresstuning',
    expectedDiscounted: 295.20,
    expectedOriginal: 295.31,
  },
  {
    name: 'Link 7 (Lifos Oto Koltuk Kilifi)',
    url: 'https://www.n11.com/urun/lifos-hafif-ticari-serisi-koton-kumas-oto-koltuk-kilifi-tam-set-berlingo-caddy-connect-courier-doblo-dokker-partner-gri-126246337?magaza=smotokilif',
    expectedDiscounted: 2979.00,
    expectedOriginal: 3379.00,
  },
  {
    name: 'Link 8 (Honda Forza 250 Ekran Koruyucu)',
    url: 'https://www.n11.com/urun/honda-forza-250-ekran-koruyucu-5-inc-dijital-ekran-2024-2025-sadece-ekran-koruyucu-65754218?magaza=engo',
    expectedDiscounted: 199.20,
    expectedOriginal: 287.90,
  },
  {
    name: 'Link 9 (Samsung Galaxy Z Fold 7)',
    url: 'https://www.n11.com/urun/samsung-galaxy-z-fold7-512-gb-samsung-turkiye-garantili-89325266?magaza=cephaneteknoloji&renk=gece-siyahi',
    expectedDiscounted: 89209.96,
    expectedOriginal: 90139.23,
  },
  {
    name: 'Link 10 (Apple iPhone 17e - Calisan Referans)',
    url: 'https://www.n11.com/urun/apple-iphone-17e-256-gb-apple-turkiye-garantili-120966170?renk=acik-pembe&magaza=bszelektronik',
    expectedDiscounted: 62399.04,
    expectedOriginal: 64999.00,
  },
];

async function run() {
  console.log('🚀 Starting Node.js N11 Original Price Unit Tests (All 10 User Links)...\n');
  let passed = 0;

  for (const tc of testCases) {
    console.log(`------------------------------------------------------------`);
    console.log(`Testing: ${tc.name}`);
    console.log(`URL: ${tc.url}`);
    
    const result = await linkScraperService.scrapeProductFromUrl(tc.url);
    console.log(`Scraped Discounted Price: ${result.price} TL (Expected: ${tc.expectedDiscounted} TL)`);
    console.log(`Scraped Original Price:   ${result.originalPrice} TL (Expected: ${tc.expectedOriginal} TL)`);
    if (result.priceLabel) console.log(`Scraped Price Label:      ${result.priceLabel}`);

    assert.ok(result.price !== null, 'Discounted price should not be null');
    assert.strictEqual(result.price, tc.expectedDiscounted, `Discounted price should match ${tc.expectedDiscounted}`);
    assert.strictEqual(result.originalPrice, tc.expectedOriginal, `Original price should match ${tc.expectedOriginal}`);
    assert.strictEqual(result.priceLabel, null, 'N11 must not have membership priceLabel');

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
