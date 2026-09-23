/**
 * FırsatKolik — Akıllı Mükerrer Link ve Spam Engelleme (Cooldown) Entegrasyon Testi
 * 
 * Çalıştırmak için: node functions/tests/test_duplicate_cooldown.js
 */

const admin = require('firebase-admin');
const isProd = process.argv.includes('--prod') || process.env.FIREBASE_ENV === 'prod';
const keyPath = isProd ? '../../cloud-run-bot/prod_firebase_key.json' : '../../cloud-run-bot/dev_firebase_key.json';
console.log(`🔌 Bağlanılan Ortam: ${isProd ? 'PROD (Canlı)' : 'DEV (Geliştirme)'}`);
const serviceAccount = require(keyPath);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}
const db = admin.firestore();

// URL parametrelerini temizleyen fonksiyon
function cleanProductUrl(urlStr) {
  if (!urlStr || typeof urlStr !== 'string') return '';
  try {
    const url = new URL(urlStr.trim());
    const paramsToRemove = [
      'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
      'merchantId', 'spm', 'adjust_t', 'adjust_tracker', 'adjust_campaign',
      'adjust_adgroup', 'adjust_creative', 'gclid', 'fbclid', 'clickid', 'affiliate'
    ];
    paramsToRemove.forEach(p => url.searchParams.delete(p));
    let result = url.toString();
    if (result.endsWith('?')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  } catch (e) {
    return urlStr;
  }
}

// Mükerrerlik Karar Mantığı (Prod-Ready)
async function checkDuplicate(mainLink, newPrice = null) {
  const cleanUrl = cleanProductUrl(mainLink);
  if (!cleanUrl) return { isDuplicate: false };

  const querySnapshot = await db.collection('deals')
    .where('cleanUrl', '==', cleanUrl)
    .get();

  if (querySnapshot.empty) {
    return { isDuplicate: false };
  }

  const now = new Date();
  for (const doc of querySnapshot.docs) {
    const dealData = doc.data();

    // 1. Reddedilmiş fırsat kontrolü
    const isRejected = dealData.isRejected === true || dealData.status === 'rejected';
    if (isRejected) {
      continue;
    }

    // 2. Yaş Kontrolü (48 saatlik aktif pencere)
    const createdAtRaw = dealData.createdAt || dealData.timestamp;
    let dealCreatedAt = null;
    if (createdAtRaw && typeof createdAtRaw.toDate === 'function') {
      dealCreatedAt = createdAtRaw.toDate();
    } else if (createdAtRaw instanceof Date) {
      dealCreatedAt = createdAtRaw;
    } else if (typeof createdAtRaw === 'string') {
      dealCreatedAt = new Date(createdAtRaw);
    }

    const isOlderThan48Hours = dealCreatedAt && (now - dealCreatedAt) > (48 * 60 * 60 * 1000);
    if (isOlderThan48Hours) {
      continue; // 48 saati geçmiş, arşiv fırsat, mükerrer sayılmaz!
    }

    // 3. Pasif/Biten Kontrolleri:
    const isExpired = dealData.isExpired === true || dealData.status === 'expired';
    const expiredVotes = dealData.expiredVotes || 0;
    if (isExpired || expiredVotes >= 15) {
      continue;
    }

    // 4. Soğuk oylama kontrolü:
    const hotVotes = dealData.hotVotes || 0;
    const coldVotes = dealData.coldVotes || 0;
    const totalVotes = hotVotes + coldVotes;
    if (totalVotes >= 5) {
      const hotPercentage = (hotVotes / totalVotes * 100);
      if (hotPercentage < 20) {
        continue;
      }
    }
    if (hotVotes - coldVotes <= -5) {
      continue;
    }

    // 5. Fiyat Düşüşü Toleransı (%5 ve üzeri indirim)
    const existingPrice = Number(dealData.price) || 0;
    if (newPrice !== null && newPrice > 0 && existingPrice > 0 && newPrice <= (existingPrice * 0.95)) {
      continue; // Fiyat belirgin şekilde düşmüş, paylaşıma izin ver!
    }

    // 6. Onay Durumu Kontrolü
    const isApproved = dealData.isApproved === true;
    if (!isApproved) {
      return { isDuplicate: true, isPending: true, activeDocId: doc.id };
    }

    // Aktif eşleşme bulundu!
    return { isDuplicate: true, isPending: false, activeDocId: doc.id };
  }

  return { isDuplicate: false };
}

async function runTests() {
  console.log('🧪 Akıllı Mükerrer Link Kontrolü Entegrasyon Testleri Başlatılıyor...\n');
  const testCleanUrl = 'https://www.trendyol.com/test-urun-cooldown';
  const testLinkWithUtm = 'https://www.trendyol.com/test-urun-cooldown?utm_source=firsatkolik&merchantId=777';
  const testLinkWithAnotherUtm = 'https://www.trendyol.com/test-urun-cooldown?utm_source=another&spm=123';
  
  // Önceki test dokümanlarını temizle
  const existingDocs = await db.collection('deals').where('cleanUrl', '==', testCleanUrl).get();
  for (const doc of existingDocs.docs) {
    await doc.ref.delete();
  }
  // test_deal_cooldown_doc dokümanını da sil
  try {
    await db.collection('deals').doc('test_deal_cooldown_doc').delete();
  } catch (e) {}
  console.log('🧹 Eski test verileri temizlendi.');

  // TEST 1: Eşleşme yoksa -> Paylaşıma İzin Verilmeli
  console.log('\n--- TEST 1: İlk Paylaşım (Eşleşme Yok) ---');
  let result = await checkDuplicate(testLinkWithUtm);
  console.log(`🔍 Sonuç: Mükerrer mi? ${result.isDuplicate} (Beklenen: false)`);
  if (result.isDuplicate) throw new Error('Test 1 başarısız!');

  // Test için ilk dokümanı aktif ve onaylanmış olarak ekle (Fiyat: 1000 TL)
  const docRef = db.collection('deals').doc('test_deal_cooldown_doc');
  await docRef.set({
    title: 'Test Ürünü',
    link: testLinkWithUtm,
    cleanUrl: testCleanUrl,
    price: 1000,
    isApproved: true,
    isExpired: false,
    expiredVotes: 0,
    hotVotes: 0,
    coldVotes: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  console.log('✅ Aktif ve Onaylanmış fırsat veritabanına eklendi (Fiyat: 1000 TL).');

  // TEST 2: Aktif eşleşme varsa (Aynı Fiyat) -> Paylaşım Engellenmeli
  console.log('\n--- TEST 2: Aktif Eşleşme (Mükerrer Paylaşım - Aynı Fiyat) ---');
  result = await checkDuplicate(testLinkWithAnotherUtm, 1000);
  console.log(`🔍 Sonuç: Mükerrer mi? ${result.isDuplicate} (Beklenen: true, isPending: false)`);
  if (!result.isDuplicate || result.isPending) throw new Error('Test 2 başarısız!');
  console.log(`   └─ Yönlendirilecek Fırsat ID: ${result.activeDocId}`);

  // TEST 3: Fiyat Düşüşü Toleransı (%5+ Ucuz: 900 TL) -> Paylaşıma İzin Verilmeli
  console.log('\n--- TEST 3: Fiyat Düşüşü Toleransı (%10 Ucuz: 900 TL) ---');
  result = await checkDuplicate(testLinkWithAnotherUtm, 900);
  console.log(`🔍 Sonuç: Mükerrer mi? ${result.isDuplicate} (Beklenen: false)`);
  if (result.isDuplicate) throw new Error('Test 3 başarısız! Fiyat düşüşü izin vermedi.');

  // TEST 4: Fırsat 48 Saatten Eski İse -> Paylaşıma İzin Verilmeli
  console.log('\n--- TEST 4: 48 Saatten Eski Fırsat (Arşiv) ---');
  const threeDaysAgo = new Date(Date.now() - (72 * 60 * 60 * 1000));
  await docRef.update({ createdAt: threeDaysAgo, isExpired: false });
  console.log('🔄 Fırsat tarihi 3 gün öncesi olarak güncellendi (isExpired hala false).');
  result = await checkDuplicate(testLinkWithAnotherUtm, 1000);
  console.log(`🔍 Sonuç: Mükerrer mi? ${result.isDuplicate} (Beklenen: false)`);
  if (result.isDuplicate) throw new Error('Test 4 başarısız! 48 saat aşımı algılanamadı.');

  // Tarihi tekrar günümüze al
  await docRef.update({ createdAt: admin.firestore.FieldValue.serverTimestamp() });

  // TEST 5: Fırsat pasif (isExpired: true) -> Paylaşıma İzin Verilmeli
  console.log('\n--- TEST 5: Pasif Eşleşme (isExpired: true) ---');
  await docRef.update({ isExpired: true });
  console.log('🔄 Fırsat süresi bitti olarak güncellendi (isExpired: true).');
  result = await checkDuplicate(testLinkWithAnotherUtm, 1000);
  console.log(`🔍 Sonuç: Mükerrer mi? ${result.isDuplicate} (Beklenen: false)`);
  if (result.isDuplicate) throw new Error('Test 5 başarısız!');

  // TEST 6: Fırsat pasif (expiredVotes >= 15) -> Paylaşıma İzin Verilmeli
  console.log('\n--- TEST 6: Pasif Eşleşme (expiredVotes >= 15) ---');
  await docRef.update({ isApproved: true, isExpired: false, expiredVotes: 15 });
  console.log('🔄 Fırsat topluluk oylarıyla bitti olarak güncellendi (expiredVotes: 15).');
  result = await checkDuplicate(testLinkWithAnotherUtm, 1000);
  console.log(`🔍 Sonuç: Mükerrer mi? ${result.isDuplicate} (Beklenen: false)`);
  if (result.isDuplicate) throw new Error('Test 6 başarısız!');

  // TEST 7: Fırsat pasif (Soğuk Fırsat: hotVotes-coldVotes <= -5) -> Paylaşıma İzin Verilmeli
  console.log('\n--- TEST 7: Pasif Eşleşme (Soğuk Fırsat - Oylama) ---');
  await docRef.update({ expiredVotes: 0, coldVotes: 10, hotVotes: 2 }); // Puan: -8
  console.log('🔄 Fırsat topluluk oylarıyla soğutuldu (hotVotes: 2, coldVotes: 10).');
  result = await checkDuplicate(testLinkWithAnotherUtm, 1000);
  console.log(`🔍 Sonuç: Mükerrer mi? ${result.isDuplicate} (Beklenen: false)`);
  if (result.isDuplicate) throw new Error('Test 7 başarısız!');

  // TEST 8: Reddedilmiş Fırsat (isRejected: true) -> Paylaşıma İzin Verilmeli
  console.log('\n--- TEST 8: Reddedilmiş Fırsat (isRejected: true) ---');
  await docRef.update({ isApproved: false, isRejected: true, expiredVotes: 0, coldVotes: 0, hotVotes: 0 });
  console.log('🔄 Fırsat yönetici tarafından reddedildi (isRejected: true).');
  result = await checkDuplicate(testLinkWithAnotherUtm, 1000);
  console.log(`🔍 Sonuç: Mükerrer mi? ${result.isDuplicate} (Beklenen: false)`);
  if (result.isDuplicate) throw new Error('Test 8 başarısız!');

  // TEST 9: Onay Bekleyen Fırsat (isApproved: false) -> isPending: true olarak tespit edilmeli
  console.log('\n--- TEST 9: Onay Bekleyen Fırsat (isApproved: false) ---');
  await docRef.update({ isApproved: false, isRejected: false });
  console.log('🔄 Fırsat onay bekliyor durumuna getirildi (isApproved: false).');
  result = await checkDuplicate(testLinkWithAnotherUtm, 1000);
  console.log(`🔍 Sonuç: Mükerrer mi? ${result.isDuplicate}, Onayda mı? ${result.isPending} (Beklenen: true, isPending: true)`);
  if (!result.isDuplicate || !result.isPending) throw new Error('Test 9 başarısız!');

  // Temizleme
  await docRef.delete();
  console.log('\n🧹 Test dokümanı veritabanından silindi.');
  console.log('\n🎉 TÜM TESTLER BAŞARIYLA GEÇTİ!');
  process.exit(0);
}

runTests().catch(err => {
  console.error('\n❌ Test hatası:', err.message);
  process.exit(1);
});
