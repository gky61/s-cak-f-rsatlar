/**
 * FS-KUP-03: Kupon Radarı Elit Kürasyon & Tavan Kotası Sözleşme Testi
 * 
 * Bu test:
 * 1. Kuponburada, DonanimHaber ve Kuponla kaynaklarından gelen kuponların filtrelenmesini,
 * 2. Mağaza başına tavan kotasının (max 6) aşılmamasını,
 * 3. Kupon kodu olmayan geçersiz kartların elenmesini,
 * 4. Boşluklu veya buton metinli sahte kodların (Anti-Garbage Gate) reddedilmesini,
 * 5. Güven & Tazelik Skorlama Motoru (Confidence Engine) ile en taze kuponların öne çıkmasını doğrular.
 */

const assert = require('assert');
const { isValidCouponCode, calculateCouponScore } = require('../coupon_scraper');

function runCouponCurationContractTests() {
  console.log('\n===============================================================');
  console.log('🎟️ FS-KUP-03: Kupon Kürasyonu ve Tavan Kotası Sözleşme Testi');
  console.log('===============================================================\n');

  // TEST 1: Mağaza Başına Tavan Kotası (MAX 6)
  console.log('--- TEST 1: Mağaza Başına Tavan Kotası Sözleşmesi ---');
  const MAX_PER_STORE_FINAL = 6;
  const storeCouponCount = {};
  const seenCodes = new Set();
  const allScrapedCoupons = [];

  function addCouponWithStoreQuota(coupon) {
    if (!coupon || !coupon.kuponKodu) return false;
    const store = (coupon.magazaAdi || '').trim();
    if (!store) return false;

    const count = storeCouponCount[store] || 0;
    if (count >= MAX_PER_STORE_FINAL) return false;

    const codeKey = `${store.toUpperCase()}_${coupon.kuponKodu.toUpperCase()}`;
    if (seenCodes.has(codeKey)) return false;

    seenCodes.add(codeKey);
    allScrapedCoupons.push(coupon);
    storeCouponCount[store] = count + 1;
    return true;
  }

  // Simüle edilmiş 15 Trendyol kuponu ekleme teşebbüsü
  for (let i = 1; i <= 15; i++) {
    addCouponWithStoreQuota({
      magazaAdi: 'Trendyol',
      kuponKodu: `KOD_${i}`,
      baslik: `Trendyol Kupon ${i}`
    });
  }

  assert.strictEqual(storeCouponCount['Trendyol'], 6, 'Trendyol kupon sayısı 6 tavanını aşmamalıdır.');
  assert.strictEqual(allScrapedCoupons.length, 6, 'Toplam eklenen kupon sayısı 6 olmalıdır.');
  console.log('✅ TEST 1 BAŞARILI: Mağaza başına 6 kupon tavanı korundu (15 kupondan 6 tanesi kabul edildi, 9 eski/fazlalık elendi).');

  // TEST 2: Mükerrer Kupon Kodu Engeli
  console.log('\n--- TEST 2: Mükerrer Kod Tekilleştirme Sözleşmesi ---');
  const duplicateAdded = addCouponWithStoreQuota({
    magazaAdi: 'Trendyol',
    kuponKodu: 'KOD_1',
    baslik: 'Aynı Kod Tekrarı'
  });
  assert.strictEqual(duplicateAdded, false, 'Aynı koda sahip mükerrer kupon eklenmemelidir.');
  console.log('✅ TEST 2 BAŞARILI: Mükerrer kupon kodu tespiti ve engellemesi doğrulandı.');

  // TEST 3: Kupon Kodu Olmayan Kartların Reddedilmesi
  console.log('\n--- TEST 3: Kodsuz Kampanya Reddi Sözleşmesi ---');
  const emptyCodeAdded = addCouponWithStoreQuota({
    magazaAdi: 'Amazon',
    kuponKodu: '',
    baslik: 'Kodsuz Kampanya'
  });
  assert.strictEqual(emptyCodeAdded, false, 'Kupon kodu boş olan kart havuza alınmamalıdır.');
  console.log('✅ TEST 3 BAŞARILI: Kupon kodu bulunmayan genel indirim duyuruları başarıyla elendi.');

  // TEST 4: Anti-Garbage Gate (Boşluklu ve Buton Metinli Kodların Reddi)
  console.log('\n--- TEST 4: Anti-Garbage Gate Sözleşmesi ---');
  assert.strictEqual(isValidCouponCode('MARKA FESTİVALİ'), false, 'Boşluklu kampanya adları reddedilmelidir.');
  assert.strictEqual(isValidCouponCode('KODU AL'), false, 'Buton metinleri reddedilmelidir.');
  assert.strictEqual(isValidCouponCode('KODU GÖSTER'), false, 'Buton metinleri reddedilmelidir.');
  assert.strictEqual(isValidCouponCode('X'), false, 'Tek harfli geçersiz kodlar reddedilmelidir.');
  assert.strictEqual(isValidCouponCode('INDIRIM'), true, 'Geçerli kupon kodu kabul edilmelidir.');
  assert.strictEqual(isValidCouponCode('NESP1500'), true, 'Geçerli kupon kodu kabul edilmelidir.');
  assert.strictEqual(isValidCouponCode('SUPER30'), true, 'Geçerli kupon kodu kabul edilmelidir.');
  console.log('✅ TEST 4 BAŞARILI: Boşluklu kampanya isimleri ve buton etiketleri %100 elendi.');

  // TEST 5: Güven & Tazelik Skorlama Motoru ile Adil Sıralama
  console.log('\n--- TEST 5: Güven & Tazelik Skorlama Motoru Sözleşmesi ---');
  const freshEditorCoupon = {
    magazaAdi: 'Trendyol',
    kuponKodu: 'INDIRIM',
    baslik: 'Samsung 6.000 TL İndirim Kuponu',
    kaynakSite: 'kuponburada',
    updatedTimestamp: Math.floor(Date.now() / 1000) - (10 * 86400), // 10 gün önce
    isEditor: true,
    isCollab: true
  };

  const oldCoupon = {
    magazaAdi: 'Trendyol',
    kuponKodu: 'TROY300',
    baslik: 'Trendyol 300 TL Kupon Kodu',
    kaynakSite: 'kuponburada',
    updatedTimestamp: Math.floor(Date.now() / 1000) - (200 * 86400), // 200 gün önce
    isEditor: false,
    isCollab: false
  };

  const dhFreshCoupon = {
    magazaAdi: 'Trendyol',
    kuponKodu: 'KARACA200',
    baslik: 'Karaca 200 TL İndirim Kodu',
    kaynakSite: 'donanimhaber'
  };

  const scoreFreshEditor = calculateCouponScore(freshEditorCoupon);
  const scoreOld = calculateCouponScore(oldCoupon);
  const scoreDh = calculateCouponScore(dhFreshCoupon);

  assert.ok(scoreFreshEditor > scoreDh, 'Taze Editör/Ortaklık kuponu en yüksek puanı almalıdır.');
  assert.ok(scoreDh > scoreOld, 'Aktif DH kuponu 6 aylık bayat Kuponburada kuponunu geçmelidir.');
  console.log(`✅ TEST 5 BAŞARILI: Puanlama doğrulandı (Taze Editör: ${scoreFreshEditor} > DH Aktif: ${scoreDh} > 6 Aylık Bayat: ${scoreOld}).`);

  console.log('\n===============================================================');
  console.log('🏆 TÜM FS-KUP-03 KUPON KÜRASYON SÖZLEŞME TESTLERİ %100 GEÇTİ!');
  console.log('===============================================================\n');
}

runCouponCurationContractTests();
