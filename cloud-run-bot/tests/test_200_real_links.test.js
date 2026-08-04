const fs = require('fs');
const path = require('path');
const { isDomainAllowed, getStoreKeyForUrl, isProductUrl } = require('../domain_allowlist');

function test200Links() {
  const jsonPath = path.join(__dirname, '../../documentation/aktuel-logs/20_magaza_200_gercek_urun_linki.json');
  if (!fs.existsSync(jsonPath)) {
    console.error(`❌ Dosya bulunamadı: ${jsonPath}`);
    process.exit(1);
  }

  const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  
  let grandTotal = 0;
  let grandPassed = 0;
  let grandFailed = 0;

  const resultsByStore = {};

  for (const [storeKey, urls] of Object.entries(data)) {
    let storePassed = 0;
    let storeFailed = 0;
    const failedDetails = [];

    for (const url of urls) {
      grandTotal++;
      const domainAllowed = isDomainAllowed(url);
      const productValid = isProductUrl(url);
      const matchedStore = getStoreKeyForUrl(url);

      if (domainAllowed && productValid) {
        storePassed++;
        grandPassed++;
      } else {
        storeFailed++;
        grandFailed++;
        failedDetails.push({
          url,
          domainAllowed,
          productValid,
          matchedStore
        });
      }
    }

    resultsByStore[storeKey] = {
      total: urls.length,
      passed: storePassed,
      failed: storeFailed,
      failedDetails
    };
  }

  console.log('================================================================');
  console.log('📊 20 MAĞAZA 200 GERÇEK ÜRÜN LİNKİ TEST SONUÇLARI');
  console.log('================================================================\n');

  for (const [storeKey, res] of Object.entries(resultsByStore)) {
    const statusIcon = res.failed === 0 ? '✅' : '❌';
    console.log(`${statusIcon} Mağaza: [${storeKey}] -> ${res.passed}/${res.total} Geçti (${res.failed} Başarısız)`);
    if (res.failed > 0) {
      for (const fail of res.failedDetails) {
        console.log(`   ❌ Hatalı Link: ${fail.url}`);
        console.log(`      -> domainAllowed: ${fail.domainAllowed}, productValid: ${fail.productValid}, matchedStore: ${fail.matchedStore}`);
      }
    }
  }

  console.log('\n================================================================');
  console.log(`GENEL SONUÇ: ${grandPassed}/${grandTotal} Ürün Linki Başarıyla Doğrulandı!`);
  console.log(`Başarısız Sayısı: ${grandFailed}`);
  console.log('================================================================\n');

  if (grandFailed > 0) {
    process.exit(1);
  }
}

test200Links();
