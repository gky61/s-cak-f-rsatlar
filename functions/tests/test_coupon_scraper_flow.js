/**
 * FırsatKolik — Kupon Scraper Entegrasyon Akış Testi
 * 
 * Çalıştırmak için: node functions/tests/test_coupon_scraper_flow.js [--prod]
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

const { scrapeAndSaveCoupons } = require('../coupon_scraper');

async function runTest() {
  console.log('🧪 Kupon Scraper Akış Testi Başlatılıyor...');

  try {
    const result = await scrapeAndSaveCoupons();
    console.log('📊 Kazıma Sonucu:', result);

    if (!result.success) {
      throw new Error('Kupon kazıma işlemi başarısız döndü!');
    }

    if (result.count === 0) {
      throw new Error('Hiç kupon kazınamadı!');
    }

    // Firestore'da kupon var mı kontrol et
    const db = admin.firestore();
    const snapshot = await db.collection('kuponlar').limit(5).get();
    console.log(`📖 Firestore'dan rastgele ${snapshot.size} adet kazınmış kupon okundu:`);
    
    snapshot.forEach(doc => {
      const data = doc.data();
      console.log(`   🏷️ Mağaza: ${data.magazaAdi} | Başlık: ${data.baslik} | Kod: ${data.kuponKodu}`);
    });

    console.log('\n🌟 TÜM KUPON SCRAKER AKIŞ TESTLERİ BAŞARIYLA GEÇTİ!');
    process.exit(0);

  } catch (error) {
    console.error('\n❌ Entegrasyon testi sırasında hata oluştu:', error.message);
    process.exit(1);
  }
}

runTest();
