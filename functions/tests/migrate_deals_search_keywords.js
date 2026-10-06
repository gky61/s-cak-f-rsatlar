/**
 * FırsatKolik — FS-20: Deals searchKeywords Veri Göçü (Migration) Betiği
 * 
 * Bu betik, Firestore veritabanındaki deals koleksiyonunu tarayarak,
 * her belgenin 'title', 'brand', 'store', 'category' alanlarından
 * küçük harfli normalize edilmiş 'searchKeywords' dizisini oluşturur.
 * 
 * Çalıştırmak için: node functions/tests/migrate_deals_search_keywords.js
 * Canlı ortam için: node functions/tests/migrate_deals_search_keywords.js --prod
 */

const admin = require('firebase-admin');
const isProd = process.argv.includes('--prod') || process.env.FIREBASE_ENV === 'prod';
const keyPath = isProd ? '../../cloud-run-bot/prod_firebase_key.json' : '../../cloud-run-bot/dev_firebase_key.json';
console.log(`🔌 Bağlanılan Ortam: ${isProd ? 'PROD (Canlı)' : 'DEV (Geliştirme)'}`);
const serviceAccount = require(keyPath);

// Firebase Admin initialization
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}
const db = admin.firestore();

function normalizeKw(str) {
  if (!str || typeof str !== 'string') return '';
  return str.toLowerCase()
    .replace(/ç/g, 'c').replace(/ğ/g, 'g').replace(/ı/g, 'i')
    .replace(/ö/g, 'o').replace(/ş/g, 's').replace(/ü/g, 'u')
    .replace(/[^\w\s]/g, ' ')
    .replace(/\s+/g, ' ').trim();
}

function generateSearchKeywords(dealData) {
  const kwSet = new Set();
  const fields = [
    dealData.title,
    dealData.brand,
    dealData.store,
    dealData.category,
    dealData.subCategory,
  ];

  fields.forEach(f => {
    const norm = normalizeKw(f);
    if (norm) {
      norm.split(' ').forEach(t => {
        if (t.length >= 2 || /^\d+$/.test(t)) kwSet.add(t);
      });
    }
  });

  return Array.from(kwSet).slice(0, 50);
}

async function migrateSearchKeywords() {
  console.log('🚀 searchKeywords veri göçü başlatılıyor...');
  const dealsSnap = await db.collection('deals').get();
  console.log(`📦 Toplam ${dealsSnap.size} fırsat inceleniyor...`);

  let updatedCount = 0;
  let skippedCount = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of dealsSnap.docs) {
    const data = doc.data();
    if (Array.isArray(data.searchKeywords) && data.searchKeywords.length > 0) {
      skippedCount++;
      continue;
    }

    const keywords = generateSearchKeywords(data);
    batch.update(doc.ref, { searchKeywords: keywords });
    batchCount++;
    updatedCount++;

    if (batchCount >= 400) {
      await batch.commit();
      console.log(`💾 400 doküman güncellendi (${updatedCount}/${dealsSnap.size})...`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  console.log(`\n🎉 Göç Tamamlandı!`);
  console.log(`   - Güncellenen: ${updatedCount}`);
  console.log(`   - Zaten güncel: ${skippedCount}`);
  console.log(`   - Toplam: ${dealsSnap.size}\n`);
}

migrateSearchKeywords()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('❌ Göç sırasında hata:', err);
    process.exit(1);
  });
