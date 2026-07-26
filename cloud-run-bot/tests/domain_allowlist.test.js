const { isDomainAllowed, getStoreKeyForUrl } = require('../domain_allowlist');

function runTests() {
  console.log('🧪 Domain Allowlist Unit Tests başlatılıyor...\n');

  const validUrls = [
    { url: 'https://www.trendyol.com/brand/product-p-12345', expectedStore: 'trendyol' },
    { url: 'https://m.trendyol.com/item-p-999', expectedStore: 'trendyol' },
    { url: 'https://www.hepsiburada.com/product-p-HBV000', expectedStore: 'hepsiburada' },
    { url: 'https://www.amazon.com.tr/dp/B08N5WRWNW', expectedStore: 'amazon_tr' },
    { url: 'https://www.n11.com/urun/sample-123', expectedStore: 'n11' },
    { url: 'https://www.pazarama.com/product/123', expectedStore: 'pazarama' },
    { url: 'https://www.idefix.com/p-123', expectedStore: 'idefix' },
    { url: 'https://www.pttavm.com/item-123', expectedStore: 'pttavm' },
    { url: 'https://www.teknosa.com/item-123', expectedStore: 'teknosa' },
    { url: 'https://www.mediamarkt.com.tr/item', expectedStore: 'mediamarkt_tr' },
    { url: 'https://www.vatanbilgisayar.com/item', expectedStore: 'vatan_bilgisayar' },
    { url: 'https://www.itopya.com/item', expectedStore: 'itopya' },
    { url: 'https://www.incehesap.com/item', expectedStore: 'incehesap' },
    { url: 'https://www.mavi.com/item', expectedStore: 'mavi' },
    { url: 'https://www.defacto.com.tr/item', expectedStore: 'defacto_tr' },
    { url: 'https://www.zara.com/tr/item', expectedStore: 'zara_tr' },
    { url: 'https://www.mango.com/tr/item', expectedStore: 'mango_tr' },
    { url: 'https://www.beymen.com/item', expectedStore: 'beymen' },
    { url: 'https://www.migros.com.tr/item', expectedStore: 'migros' },
    { url: 'https://getir.com/item', expectedStore: 'getir' },
    { url: 'https://www.havitstore.com.tr/item', expectedStore: 'havit_turkiye' }
  ];

  let passed = 0;
  let total = 0;

  console.log('--- 1. Geçerli 20 Mağaza Domain Testleri ---');
  for (const item of validUrls) {
    total++;
    const isAllowed = isDomainAllowed(item.url);
    const storeKey = getStoreKeyForUrl(item.url);
    if (isAllowed && storeKey === item.expectedStore) {
      console.log(`✅ PASSED: ${item.url} -> Store: ${storeKey}`);
      passed++;
    } else {
      console.error(`❌ FAILED: ${item.url} -> isAllowed: ${isAllowed}, storeKey: ${storeKey} (Beklenen: ${item.expectedStore})`);
    }
  }

  const invalidUrls = [
    'https://fake-trendyol.com/item',
    'https://trendyol.com.phishing.org/item',
    'https://google.com/search?q=trendyol',
    'https://facebook.com/posts/123',
    'https://malicious-site.net/phish',
    'https://hepsiburada.fake.site',
    'https://amazon.com/dp/B000000000', // amazon.com (US) is not amazon.com.tr
  ];

  console.log('\n--- 2. Geçersiz / Phishing / Dış Domain Testleri ---');
  for (const url of invalidUrls) {
    total++;
    const isAllowed = isDomainAllowed(url);
    if (!isAllowed) {
      console.log(`✅ PASSED (Engellendi): ${url}`);
      passed++;
    } else {
      console.error(`❌ FAILED (Gözden Kaçtı): ${url} izin verilmemeliydi!`);
    }
  }

  console.log(`\n==================================================`);
  console.log(`Test Sonucu: ${passed}/${total} test geçti!`);
  console.log(`==================================================\n`);

  if (passed !== total) {
    process.exit(1);
  }
}

runTests();
