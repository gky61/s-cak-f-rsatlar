const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'sicak-firsatlar-e6eae',
  });
}

const db = admin.firestore();

(async () => {
  try {
    console.log('🔍 Son 5 fırsatı çekiyorum...');
    const snapshot = await db.collection('deals')
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();

    if (snapshot.empty) {
      console.log('❌ Hiç fırsat bulunamadı.');
      return;
    }

    snapshot.forEach(doc => {
      const data = doc.data();
      console.log(`-------------------`);
      console.log(`ID: ${doc.id}`);
      console.log(`Başlık: ${data.title}`);
      console.log(`Görsel: ${data.imageUrl || 'YOK'}`);
      console.log(`Kanal: ${data.telegramChatTitle || 'N/A'}`);
      console.log(`Tarih: ${data.createdAt?.toDate ? data.createdAt.toDate().toISOString() : data.createdAt}`);
    });
  } catch (error) {
    console.error('❌ Hata:', error.message);
  } finally {
    process.exit(0);
  }
})();
