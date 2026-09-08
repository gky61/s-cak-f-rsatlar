const assert = require('assert');
const allowlist = require('../domain_allowlist');
const linkScraperService = require('../link_scraper_service');

async function runTests() {
  console.log('🚀 Starting Teknosa Paylaş Kazan Unit & Integration Tests...\n');

  const paylasKazanUrl = 'https://paylaskazan.teknosa.com/teknosa-F8NSB38NC3';

  // 1. Yönlendirme Çözümü (Redirect Resolution)
  console.log('--- 1. Yönlendirme Çözümü ---');
  const resolvedUrl = await linkScraperService.resolveUrlRedirects(paylasKazanUrl);
  console.log(`Resolved URL: ${resolvedUrl}`);
  assert.ok(resolvedUrl.includes('teknosa.com'), 'Çözülen URL teknosa.com içermeli');
  assert.ok(resolvedUrl.includes('-p-790182989'), 'Çözülen URL ürün kodunu (-p-790182989) içermeli');
  assert.ok(resolvedUrl.includes('shopId=2442'), 'Çözülen URL satıcı kimliğini (shopId=2442) korumalı');

  // 2. Allowlist & Domain Doğrulaması (Çözümlenen Nihai Link Üzerinden)
  console.log('\n--- 2. Çözümlenen URL Allowlist Doğrulaması ---');
  const domainAllowed = allowlist.isDomainAllowed(resolvedUrl);
  console.log(`isDomainAllowed(resolvedUrl): ${domainAllowed}`);
  assert.strictEqual(domainAllowed, true, 'Çözülen URL teknosa.com allowlist tarafından onaylanmalı');

  const isProduct = allowlist.isProductUrl(resolvedUrl);
  console.log(`isProductUrl(resolvedUrl): ${isProduct}`);
  assert.strictEqual(isProduct, true, 'Çözülen URL -p-... regex kuralı ile eşleşmeli');

  const storeKey = allowlist.getStoreKeyForUrl(resolvedUrl);
  console.log(`getStoreKeyForUrl(resolvedUrl): ${storeKey}`);
  assert.strictEqual(storeKey, 'teknosa', 'Mağaza anahtarı "teknosa" olmalı');

  // 3. Uçtan Uca Scraping Doğrulaması
  console.log('\n--- 3. Uçtan Uca Scraping Doğrulaması ---');
  const data = await linkScraperService.scrapeProductFromUrl(paylasKazanUrl);

  console.log('Scraped Title:        ', data.title);
  console.log('Scraped Price:        ', data.price, 'TL');
  console.log('Scraped OriginalPrice:', data.originalPrice, 'TL');
  console.log('Scraped Image:        ', data.imageUrl);
  console.log('Scraped Brand:        ', data.brand);

  assert.ok(data.title && data.title.includes('iPhone XR'), 'Başlık iPhone XR içermeli');
  if (data.price !== null && data.price !== undefined) {
    assert.ok(Number(data.price) > 0, 'İndirimli fiyat pozitif olmalı');
    if (data.originalPrice !== null && data.originalPrice !== undefined) {
      assert.ok(Number(data.originalPrice) >= Number(data.price), 'İndirimsiz fiyat >= indirimli fiyat olmalı');
    }
  } else {
    console.log('ℹ️ Canlı ürün şu an stokta tükenmiş (price=null), başlık/görsel/marka başarıyla doğrulandı.');
  }
  assert.strictEqual(data.brand, 'Apple', 'Marka Apple olmalı');
  assert.ok(data.imageUrl && data.imageUrl.startsWith('http'), 'Geçerli bir görsel URL bulunmalı');

  console.log('\n🎉 ALL TEKNOSA PAYLAŞ KAZAN TESTS PASSED SUCCESSFULLY!\n');
}

runTests().catch(err => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
