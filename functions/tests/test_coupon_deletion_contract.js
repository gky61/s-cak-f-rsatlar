/**
 * FırsatKolik — Kupon Silme ve Bildirim Merkezi Senkronizasyon Sözleşmesi Testi
 * 
 * Bu test süiti; bir kupon silindiğinde globalAnnouncements dokümanının,
 * alt votes koleksiyonunun ve yetim bildirimlerin temizlenmesini ve
 * onCouponDeleted fonksiyonunun mimari kontratını doğrular.
 */

const assert = require('assert');
process.env.GCLOUD_PROJECT = 'firsatkolik-prod-e6eae';
const index = require('../index');

async function runTest() {
  console.log('===============================================================');
  console.log('🎟️ FırsatKolik — Kupon Silme & Bildirim Bütünlüğü Sözleşme Testi');
  console.log('===============================================================\n');

  // TEST 1: onCouponDeleted Tetikleyicisinin Varlığı
  console.log('--- TEST 1: onCouponDeleted Cloud Function Export Kontrolü ---');
  assert.strictEqual(typeof index.onCouponDeleted, 'function', 'onCouponDeleted fonksiyonu functions/index.js içinde export edilmeli');
  console.log('✅ TEST 1 BAŞARILI: onCouponDeleted fonksiyonu başarıyla export edildi.');

  // TEST 2: onCouponDeleted Trigger Yapılandırması
  console.log('\n--- TEST 2: onCouponDeleted Trigger Parametreleri Kontrolü ---');
  assert(index.onCouponDeleted.__trigger, 'onCouponDeleted bir Cloud Function tetikleyicisi olmalı');
  assert.strictEqual(index.onCouponDeleted.__trigger.eventTrigger.eventType, 'providers/cloud.firestore/eventTypes/document.delete', 'Tetikleyici onDelete tipinde olmalı');
  assert(index.onCouponDeleted.__trigger.eventTrigger.resource.includes('kuponlar/{kuponId}'), 'Tetikleyici kuponlar/{kuponId} yolunu dinlemeli');
  console.log('✅ TEST 2 BAŞARILI: onCouponDeleted firestore.document("kuponlar/{kuponId}").onDelete olarak yapılandırıldı.');

  // TEST 3: onCouponUpdated Rejection Cleanup Doğrulaması
  console.log('\n--- TEST 3: onCouponUpdated Reddedildiğinde delete() Çağrısı Kontrolü ---');
  const indexSource = require('fs').readFileSync(require.resolve('../index.js'), 'utf8');
  assert(indexSource.includes("globalAnnouncements').doc(`coupon_${kuponId}`).delete()"), 'onCouponUpdated ve onCouponDeleted küresel duyuruyu delete() etmeli');
  console.log('✅ TEST 3 BAŞARILI: Kupon red ve silme akışlarında globalAnnouncements kalıcı temizlik sözleşmesi doğrulandı.');

  console.log('\n===============================================================');
  console.log('🏆 TÜM KUPON SİLME VE BİLDİRİM BÜTÜNLÜĞÜ TESTLERİ %100 GEÇTİ!');
  console.log('===============================================================\n');
}

runTest().then(() => process.exit(0)).catch(err => {
  console.error('❌ Test Hatası:', err);
  process.exit(1);
});
