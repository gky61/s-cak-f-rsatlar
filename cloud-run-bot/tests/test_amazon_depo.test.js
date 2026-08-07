const { checkIsAmazonWarehouse } = require('../link_scraper_service');

function runTests() {
  console.log('🧪 Amazon Depo (smid=A215JX4S9CANSO) Testleri Başlatılıyor...\n');

  const depoUrls = [
    'https://www.amazon.com.tr/dp/B0F9Z1D5S3?smid=A215JX4S9CANSO&th=1&tag=firsatkolik-21',
    'https://www.amazon.com.tr/dp/B0BJQP23Y8?smid=A215JX4S9CANSO&th=1&ref=123',
    'https://www.amazon.com.tr/dp/B0D7VNP61V?smid=A215JX4S9CANSO&th=1&tag=test',
    'https://www.amazon.com.tr/dp/B0DZDC5R6C?smid=a215jx4s9canso&th=1&tag=lowercase_check',
  ];

  const normalUrls = [
    'https://www.amazon.com.tr/dp/B08N5WRWNW',
    'https://www.amazon.com.tr/gp/product/B08N5WRWNW',
    'https://www.trendyol.com/brand/product-p-12345',
  ];

  let passed = 0;
  let total = 0;

  console.log('--- 1. Amazon Depo Linkleri (Beklenen: TRUE) ---');
  for (const url of depoUrls) {
    total++;
    const isDepo = checkIsAmazonWarehouse(url);
    if (isDepo) {
      console.log(`✅ PASSED (Depo Tespit Edildi): ${url}`);
      passed++;
    } else {
      console.error(`❌ FAILED (Depo Tespit Edilemedi): ${url}`);
    }
  }

  console.log('\n--- 2. Normal Ürün Linkleri (Beklenen: FALSE) ---');
  for (const url of normalUrls) {
    total++;
    const isDepo = checkIsAmazonWarehouse(url);
    if (!isDepo) {
      console.log(`✅ PASSED (Normal Ürün): ${url}`);
      passed++;
    } else {
      console.error(`❌ FAILED (Yanlış Depo Tespiti): ${url}`);
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
