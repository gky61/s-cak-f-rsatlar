/**
 * FırsatKolik — Yaşam Döngüsü & Temizlik Fonksiyonları Mimari Doğrulama Testi
 * 
 * Bu test, refactor edilen 4 temizlik fonksiyonunun sözleşmelerini,
 * firestore composite index uyumluluğunu ve parametre sınırlarını doğrular.
 */
const fs = require('fs');
const path = require('path');
const assert = require('assert');

console.log('🧪 Yaşam Döngüsü & Temizlik Sözleşmeleri Doğrulama Testi Başlıyor...\n');

// 1. functions/index.js export kontrolü
const functionsIndex = require('../index.js');

const requiredExports = [
  'cleanupOldImages',
  'cleanupOldImagesManual',
  'cleanupExpiredDeals',
  'cleanupExpiredDealsManual',
  'purgeOldDeals',
  'purgeOldDealsManual',
  'purgeOldNotificationsManual'
];

console.log('1️⃣ Cloud Functions Dışa Aktarımları Kontrol Ediliyor...');
for (const exp of requiredExports) {
  assert(functionsIndex[exp], `❌ Hata: ${exp} fonksiyonu index.js içerisinde dışa aktarılmamış!`);
  console.log(`  ✅ ${exp} başarıyla yüklendi.`);
}

// 2. firestore.indexes.json composite index kontrolü
console.log('\n2️⃣ Firestore Bileşik İndeksleri Kontrol Ediliyor...');
const indexesPath = path.resolve(__dirname, '../../firestore.indexes.json');
const indexesContent = JSON.parse(fs.readFileSync(indexesPath, 'utf8'));

const hasDealsExpiredIndex = indexesContent.indexes.some(idx => {
  if (idx.collectionGroup !== 'deals') return false;
  const fields = idx.fields.map(f => f.fieldPath);
  return fields.includes('isExpired') && fields.includes('createdAt');
});

assert(hasDealsExpiredIndex, '❌ Hata: deals koleksiyonu için isExpired + createdAt bileşik indeksi bulunamadı!');
console.log('  ✅ deals koleksiyonu için [isExpired, createdAt] bileşik indeksi doğrulandı.');

// 3. Kod içeriğinde O(Deals x Users) döngüsünün kaldırıldığının teyidi
console.log('\n3️⃣ Mimari Güvenlik Denetimleri (Anti-Pattern Koruması)...');
const indexJsContent = fs.readFileSync(path.resolve(__dirname, '../index.js'), 'utf8');

// users koleksiyonunu çekip favorites arayan eski kod var mı?
const hasUsersFavoritesScan = indexJsContent.includes("userDoc.ref.collection('favorites').doc(dealId)");
assert(!hasUsersFavoritesScan, '❌ Hata: O(Deals x Users) favori tarama döngüsü kodda hala mevcut!');
console.log('  ✅ O(Deals x Users) kota patlatan döngünün tamamen kaldırıldığı doğrulandı.');

// cleanupOldImages için 40 günlük güvenlik payı var mı?
const has40DaysImages = indexJsContent.includes("days = 40");
assert(has40DaysImages, '❌ Hata: cleanupOldImages 40 günlük güvenlik payına sahip değil!');
console.log('  ✅ cleanupOldImages 40 günlük kırık görsel koruması doğrulandı.');

// _purgeOldNotificationsCore devre kesici tavanı var mı?
const hasMaxBatches = indexJsContent.includes("MAX_BATCHES = 25");
assert(hasMaxBatches, '❌ Hata: _purgeOldNotificationsCore devre kesici tavanı (MAX_BATCHES) eksik!');
console.log('  ✅ _purgeOldNotificationsCore devre kesici tavanı (10.000 limit) doğrulandı.');

console.log('\n🎉 TÜM TESTLER VE MİMARİ DOĞRULAMALAR BAŞARIYLA GEÇTİ!');
