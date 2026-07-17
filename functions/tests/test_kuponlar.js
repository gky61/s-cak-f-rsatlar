/**
 * FırsatKolik — Kuponlar Koleksiyonu Entegrasyon Testi
 * 
 * Çalıştırmak için: node functions/tests/test_kuponlar.js [--prod]
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

// Test Verileri
const TEST_KUPON_ID = 'test_kupon_integration_id';
const TEST_USER_ID = 'test_kupon_user_id';

async function runTest() {
  console.log('🧪 Kuponlar Entegrasyon Testi Başlatılıyor...');

  try {
    // Önceki test kalıntılarını temizle
    await db.collection('kuponlar').doc(TEST_KUPON_ID).delete().catch(() => {});

    // 1. Yeni kupon yazma testi
    console.log('📝 1. Kupon veritabanına ekleniyor...');
    const testKupon = {
      magazaAdi: 'Trendyol',
      baslik: '100 TL İndirim',
      aciklama: 'Kupon test açıklaması',
      kuponKodu: 'TEST100',
      paylasanKullaniciId: TEST_USER_ID,
      olusturulmaTarihi: admin.firestore.FieldValue.serverTimestamp()
    };

    await db.collection('kuponlar').doc(TEST_KUPON_ID).set(testKupon);
    console.log('   🎉 Kupon başarıyla eklendi.');

    // 2. Kupon okuma testi
    console.log('📖 2. Kupon veritabanından çekiliyor...');
    const doc = await db.collection('kuponlar').doc(TEST_KUPON_ID).get();
    if (!doc.exists) {
      throw new Error('Eklenen test kuponu bulunamadı!');
    }

    const data = doc.data();
    console.log(`   🔎 Çekilen veri: Magaza = ${data.magazaAdi}, Başlık = ${data.baslik}, Kod = ${data.kuponKodu}`);
    
    if (data.magazaAdi !== 'Trendyol' || data.kuponKodu !== 'TEST100') {
      throw new Error('Kupon verileri uyuşmuyor!');
    }
    console.log('   🎉 [BAŞARILI] Kupon verileri doğrulandı.');

    // 2.5. Kupon güncelleme testi
    console.log('✏️ 2.5. Kupon veritabanında güncelleniyor...');
    await db.collection('kuponlar').doc(TEST_KUPON_ID).update({
      baslik: '200 TL İndirim',
      kuponKodu: 'TEST200'
    });
    
    const updatedDoc = await db.collection('kuponlar').doc(TEST_KUPON_ID).get();
    const updatedData = updatedDoc.data();
    console.log(`   🔎 Güncellenen veri: Başlık = ${updatedData.baslik}, Kod = ${updatedData.kuponKodu}`);
    if (updatedData.baslik !== '200 TL İndirim' || updatedData.kuponKodu !== 'TEST200') {
      throw new Error('Kupon güncellenmiş verileri uyuşmuyor!');
    }
    console.log('   🎉 [BAŞARILI] Kupon güncellemeleri doğrulandı.');

    // 3. Temizlik testi
    console.log('🧹 3. Test verileri temizleniyor...');
    await db.collection('kuponlar').doc(TEST_KUPON_ID).delete();
    
    const checkDoc = await db.collection('kuponlar').doc(TEST_KUPON_ID).get();
    if (checkDoc.exists) {
      throw new Error('Kupon başarıyla silinemedi!');
    }
    console.log('   🎉 [BAŞARILI] Test verisi silindi.');

    console.log('\n🌟 TÜM KUPON ENTEGRASYON TESTLERİ BAŞARIYLA GEÇTİ!');
    process.exit(0);
  } catch (err) {
    console.error('\n❌ TEST BAŞARISIZ:', err.message);
    process.exit(1);
  }
}

runTest();
