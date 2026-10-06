/**
 * FırsatKolik — FS-21: Messages participants Veri Göçü (Migration) Betiği
 * 
 * Bu betik, Firestore veritabanındaki messages koleksiyonunu tarayarak,
 * her belgenin 'senderId' ve 'receiverId' alanlarından 'participants: [senderId, receiverId]'
 * dizi alanını oluşturur. Tekil stream sorgusunun security rules ile uyumlu çalışmasını sağlar.
 * 
 * Çalıştırmak için: node functions/tests/migrate_messages_participants.js
 * Canlı ortam için: node functions/tests/migrate_messages_participants.js --prod
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

async function migrateMessagesParticipants() {
  console.log('🚀 messages participants veri göçü başlatılıyor...');
  const snap = await db.collection('messages').get();
  console.log(`📦 Toplam ${snap.size} mesaj taranıyor...`);

  let updatedCount = 0;
  let skippedCount = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    if (Array.isArray(data.participants) && data.participants.length >= 2) {
      skippedCount++;
      continue;
    }

    const participants = [data.senderId, data.receiverId].filter(Boolean);
    batch.update(doc.ref, { participants: participants });
    batchCount++;
    updatedCount++;

    if (batchCount >= 400) {
      await batch.commit();
      console.log(`💾 400 mesaj güncellendi (${updatedCount}/${snap.size})...`);
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
  console.log(`   - Toplam: ${snap.size}\n`);
}

migrateMessagesParticipants()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('❌ Göç sırasında hata:', err);
    process.exit(1);
  });
