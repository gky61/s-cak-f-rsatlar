/**
 * FırsatKolik — Aktüel Katalog Scraper Testi
 * 
 * Çalıştırmak için: node functions/tests/test_catalog_scraper.js [--prod]
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

// Mock functions logger since we require catalog_scraper outside Firebase runtime
global.functions = {
  logger: {
    info: console.log,
    warn: console.warn,
    error: console.error
  }
};

const { scrapeAndSaveCatalogs } = require('../catalog_scraper');

async function runTest() {
  console.log('🧪 Aktüel Katalog Scraper Akış Testi Başlatılıyor...');

  try {
    const result = await scrapeAndSaveCatalogs();
    console.log('📊 Kazıma Sonucu:', result);

    if (!result.success) {
      throw new Error('Katalog kazıma işlemi başarısız döndü!');
    }

    if (result.count === 0) {
      throw new Error('Hiç katalog kazınamadı!');
    }

    // Firestore'da katalog var mı kontrol et
    const db = admin.firestore();
    const snapshot = await db.collection('kataloglar').limit(5).get();
    console.log(`\n📖 Firestore'dan rastgele ${snapshot.size} adet katalog okundu:`);
    
    snapshot.forEach(doc => {
      const data = doc.data();
      console.log(`   📰 Mağaza: ${data.magazaKodu} | Başlık: ${data.katalogBasligi} | Sayfa Sayısı: ${data.sayfaResimleri.length} | Kapak: ${data.kapakResmi}`);
      console.log(`      📅 Tarih: ${data.baslangicTarihi.toDate().toLocaleDateString('tr-TR')} - ${data.bitisTarihi.toDate().toLocaleDateString('tr-TR')}`);
    });

    console.log('\n🌟 TÜM AKTÜEL KATALOG SCRAKER AKIŞ TESTLERİ BAŞARIYLA GEÇTİ!');
    process.exit(0);

  } catch (error) {
    console.error('\n❌ Entegrasyon testi sırasında hata oluştu:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

runTest();
