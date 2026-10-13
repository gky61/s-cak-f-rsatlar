/**
 * FırsatKolik — FS-20: Users searchKeywords Veri Göçü (Migration) Betiği
 * 
 * Bu betik, Firestore veritabanındaki users koleksiyonunu tarayarak,
 * her kullanıcının 'username', 'displayName', 'nickname' alanlarından
 * küçük harfli normalize edilmiş ve prefix (edge n-gram) destekli
 * 'searchKeywords' dizisini oluşturur.
 * 
 * Çalıştırmak için: node functions/tests/migrate_users_search_keywords.js
 * Canlı ortam için: node functions/tests/migrate_users_search_keywords.js --prod
 */

const admin = require('firebase-admin');
const isProd = process.argv.includes('--prod') || process.env.FIREBASE_ENV === 'prod';
const isForce = process.argv.includes('--force');
const keyPath = isProd ? '../../cloud-run-bot/prod_firebase_key.json' : '../../cloud-run-bot/dev_firebase_key.json';
console.log(`🔌 Bağlanılan Ortam: ${isProd ? 'PROD (Canlı)' : 'DEV (Geliştirme)'}${isForce ? ' (FORCE MODE)' : ''}`);
const serviceAccount = require(keyPath);

// Firebase Admin initialization
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}
const db = admin.firestore();

function normalize(str) {
  if (!str || typeof str !== 'string') return '';
  return str
    .replace(/İ/g, 'i').replace(/I/g, 'i').replace(/ı/g, 'i')
    .replace(/Ç/g, 'c').replace(/ç/g, 'c')
    .replace(/Ğ/g, 'g').replace(/ğ/g, 'g')
    .replace(/Ö/g, 'o').replace(/ö/g, 'o')
    .replace(/Ş/g, 's').replace(/ş/g, 's')
    .replace(/Ü/g, 'u').replace(/ü/g, 'u')
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function generateUserSearchKeywords(userData) {
  const kwSet = new Set();
  const addTokens = (name) => {
    const norm = normalize(name);
    if (!norm) return;
    const tokens = norm.split(' ').filter(t => t.length >= 2 || /^\d+$/.test(t));
    tokens.forEach(token => {
      kwSet.add(token);
      const maxLen = Math.min(token.length, 25);
      for (let i = 2; i <= maxLen; i++) {
        kwSet.add(token.substring(0, i));
      }
    });
    if (tokens.length > 1) {
      const spaceJoined = tokens.join(' ');
      if (spaceJoined.length >= 2 && spaceJoined.length <= 40) {
        kwSet.add(spaceJoined);
      }
      const joined = tokens.join('');
      if (joined.length >= 2 && joined.length <= 30) {
        kwSet.add(joined);
        const maxJ = Math.min(joined.length, 20);
        for (let i = 2; i <= maxJ; i++) {
          kwSet.add(joined.substring(0, i));
        }
      }
    }
  };

  addTokens(userData.username);
  if (userData.displayName && userData.displayName !== userData.username) addTokens(userData.displayName);
  if (userData.nickname && userData.nickname !== userData.username && userData.nickname !== userData.displayName) addTokens(userData.nickname);

  return Array.from(kwSet).slice(0, 60);
}

async function migrateUserSearchKeywords() {
  console.log('🚀 Users searchKeywords veri göçü başlatılıyor...');
  const usersSnap = await db.collection('users').get();
  console.log(`👤 Toplam ${usersSnap.size} kullanıcı inceleniyor...`);

  let updatedCount = 0;
  let skippedCount = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of usersSnap.docs) {
    const data = doc.data();
    if (!isForce && Array.isArray(data.searchKeywords) && data.searchKeywords.length > 0) {
      skippedCount++;
      continue;
    }

    const keywords = generateUserSearchKeywords(data);
    if (keywords.length === 0) {
      skippedCount++;
      continue;
    }

    batch.update(doc.ref, { searchKeywords: keywords });
    batchCount++;
    updatedCount++;

    if (batchCount >= 400) {
      await batch.commit();
      console.log(`💾 400 kullanıcı güncellendi (${updatedCount}/${usersSnap.size})...`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  console.log(`\n🎉 Göç Tamamlandı!`);
  console.log(`   - Güncellenen: ${updatedCount}`);
  console.log(`   - Zaten güncel / Atlanan: ${skippedCount}`);
  console.log(`   - Toplam: ${usersSnap.size}\n`);
}

migrateUserSearchKeywords()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('❌ Göç sırasında hata:', err);
    process.exit(1);
  });
