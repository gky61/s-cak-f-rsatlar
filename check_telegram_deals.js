/**
 * Firestore'da Telegram'dan gelen deal'leri kontrol et
 */

const admin = require('firebase-admin');

// Firebase Admin'i başlat
if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
} else {
  admin.initializeApp();
}

const db = admin.firestore();

async function checkTelegramDeals() {
  console.log('🔍 Firestore\'da Telegram deal'leri kontrol ediliyor...\n');

  try {
    // Tüm Telegram deal'lerini getir
    const snapshot = await db.collection('deals')
      .where('source', '==', 'telegram')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();

    if (snapshot.empty) {
      console.log('❌ Telegram\'dan gelen deal bulunamadı!');
      console.log('\nKontrol edin:');
      console.log('1. Function çalışıyor mu? (logları kontrol edin)');
      console.log('2. Telegram kanalında mesaj var mı?');
      console.log('3. Mesajlarda URL var mı?');
      return;
    }

    console.log(`✅ ${snapshot.size} Telegram deal bulundu:\n`);

    snapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`📦 Deal ID: ${doc.id}`);
      console.log(`   Başlık: ${data.title}`);
      console.log(`   Fiyat: ${data.price} TL`);
      console.log(`   Mağaza: ${data.store}`);
      console.log(`   Kategori: ${data.category}`);
      console.log(`   Link: ${data.link}`);
      console.log(`   Onay Durumu: ${data.isApproved ? '✅ Onaylı' : '⏳ Bekliyor'}`);
      console.log(`   Kanal/Grup: ${data.telegramChatTitle || data.telegramChatUsername}`);
      console.log(`   Mesaj ID: ${data.telegramMessageId}`);
      console.log(`   Oluşturulma: ${data.createdAt?.toDate() || 'Bilinmiyor'}`);
      console.log('   ---');
    });

    // Onay bekleyen deal sayısı
    const pendingSnapshot = await db.collection('deals')
      .where('source', '==', 'telegram')
      .where('isApproved', '==', false)
      .get();

    console.log(`\n📊 Özet:`);
    console.log(`   Toplam Telegram deal: ${snapshot.size}`);
    console.log(`   Onay bekleyen: ${pendingSnapshot.size}`);
    console.log(`   Onaylanmış: ${snapshot.size - pendingSnapshot.size}`);

  } catch (error) {
    console.error('❌ Hata:', error.message);
    if (error.message.includes('index')) {
      console.log('\n💡 Firestore index oluşturmanız gerekebilir:');
      console.log('   Firebase Console > Firestore > Indexes');
    }
  }

  process.exit(0);
}

checkTelegramDeals();





