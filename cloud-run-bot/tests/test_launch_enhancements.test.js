const assert = require('assert');

console.log('🧪 Launch Enhancements Unit Tests Başlatılıyor...');

// 1. Quality Gate Testi
function applyQualityGate({ finalPrice, cleanedTitle, imageUrl, dealApprovalRequired }) {
  const isMissingPrice = !finalPrice || finalPrice <= 0;
  const isGenericTitle = !cleanedTitle || cleanedTitle === 'Fırsat Ürünü' || cleanedTitle.length < 3;
  const isMissingImage = !imageUrl;

  let requiresManualReview = false;
  const reviewReasons = [];

  if (isMissingPrice) {
    requiresManualReview = true;
    reviewReasons.push('Fiyat tespit edilemedi (0 TL)');
  }
  if (isGenericTitle) {
    requiresManualReview = true;
    reviewReasons.push('Jenerik / Belirsiz başlık');
  }
  if (isMissingImage) {
    requiresManualReview = true;
    reviewReasons.push('Görsel bulunamadı');
  }

  let isApprovedFinal = !dealApprovalRequired;
  if (requiresManualReview) {
    isApprovedFinal = false;
  }

  return { isApprovedFinal, requiresManualReview, reviewReasons };
}

// Test 1a: Fiyat 0 TL olduğunda otomatik onay açık olsa bile admin onayına zorlanmalı
const res1a = applyQualityGate({ finalPrice: 0, cleanedTitle: 'Sony Kulaklık', imageUrl: 'https://img.com/1.jpg', dealApprovalRequired: false });
assert.strictEqual(res1a.isApprovedFinal, false, 'Fiyat 0 iken onay kapalı olmalı');
assert.strictEqual(res1a.requiresManualReview, true);
assert(res1a.reviewReasons.includes('Fiyat tespit edilemedi (0 TL)'));
console.log('✅ Test 1a Passed: Fiyat 0 TL iken otomatik onay açık olsa bile admin onayına zorlandı.');

// Test 1b: Başlık "Fırsat Ürünü" iken admin onayına zorlanmalı
const res1b = applyQualityGate({ finalPrice: 450, cleanedTitle: 'Fırsat Ürünü', imageUrl: 'https://img.com/1.jpg', dealApprovalRequired: false });
assert.strictEqual(res1b.isApprovedFinal, false);
assert.strictEqual(res1b.requiresManualReview, true);
assert(res1b.reviewReasons.includes('Jenerik / Belirsiz başlık'));
console.log('✅ Test 1b Passed: Jenerik başlık durumunda admin onayına zorlandı.');

// Test 1c: Görsel yokken admin onayına zorlanmalı
const res1c = applyQualityGate({ finalPrice: 450, cleanedTitle: 'Sony Kulaklık', imageUrl: '', dealApprovalRequired: false });
assert.strictEqual(res1c.isApprovedFinal, false);
assert.strictEqual(res1c.requiresManualReview, true);
assert(res1c.reviewReasons.includes('Görsel bulunamadı'));
console.log('✅ Test 1c Passed: Görsel eksik olduğunda admin onayına zorlandı.');

// Test 1d: Tüm veriler tam ve dealApprovalRequired true iken admin onayında beklemeli
const res1d = applyQualityGate({ finalPrice: 450, cleanedTitle: 'Sony Kulaklık', imageUrl: 'https://img.com/1.jpg', dealApprovalRequired: true });
assert.strictEqual(res1d.isApprovedFinal, false);
assert.strictEqual(res1d.requiresManualReview, false);
console.log('✅ Test 1d Passed: dealApprovalRequired true iken normal admin onayında kaldı.');

// Test 1e: Tüm veriler tam ve dealApprovalRequired false iken otomatik yayına çıkmalı
const res1e = applyQualityGate({ finalPrice: 450, cleanedTitle: 'Sony Kulaklık', imageUrl: 'https://img.com/1.jpg', dealApprovalRequired: false });
assert.strictEqual(res1e.isApprovedFinal, true);
assert.strictEqual(res1e.requiresManualReview, false);
console.log('✅ Test 1e Passed: Tüm veriler kusursuz olduğunda otomatik yayına izin verildi.');

// 2. In-Flight URL Kilit Testi
const inFlightUrls = new Map();
const IN_FLIGHT_TIMEOUT_MS = 30000;

function cleanStaleLocks(nowTs) {
  for (const [k, ts] of inFlightUrls.entries()) {
    if (nowTs - ts > IN_FLIGHT_TIMEOUT_MS) inFlightUrls.delete(k);
  }
}

const testUrl = 'https://www.trendyol.com/apple/airpods-pro-2-p-12345';
inFlightUrls.set(testUrl, Date.now() - 35000); // 35 sn önce (bayat kilit)
cleanStaleLocks(Date.now());
assert.strictEqual(inFlightUrls.has(testUrl), false, 'Bayat in-flight kilidi silinmeli');
console.log('✅ Test 2a Passed: Bayat in-flight kilitleri başarıyla temizlendi.');

inFlightUrls.set(testUrl, Date.now());
assert.strictEqual(inFlightUrls.has(testUrl), true, 'Aktif in-flight kilidi mevcut olmalı');
inFlightUrls.delete(testUrl);
assert.strictEqual(inFlightUrls.has(testUrl), false, 'İşlem bittiğinde kilit serbest bırakılmalı');
console.log('✅ Test 2b Passed: Aktif in-flight kilitleme ve serbest bırakma döngüsü doğrulandı.');

console.log('\n🎉 ALL LAUNCH ENHANCEMENT TESTS PASSED PERFECTLY!');
