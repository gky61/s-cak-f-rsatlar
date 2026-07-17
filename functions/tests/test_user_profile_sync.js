/**
 * FırsatKolik — Profil Resmi ve Kullanıcı Adı Güncelleme Senkronizasyonu Entegrasyon Testi
 * 
 * Bu betik, users/{userId} belgesi güncellendiğinde tetiklenen onUserUpdated
 * Cloud Function tetikleyicisini, denormalize veriye sahip yorumlar ve mesajlar üzerinde test eder.
 * 
 * Çalıştırmak için: node functions/tests/test_user_profile_sync.js
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

// Test IDs
const USER_ID = 'test_user_sync_id';
const DEAL_ID = 'test_deal_sync_id';
const COMMENT_ID = 'test_comment_sync_id';
const MSG_SENT_ID = 'test_msg_sent_sync_id';
const MSG_RECV_ID = 'test_msg_recv_sync_id';

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Güvenli Polling Yardımcısı (Belge alanı değişene kadar bekler)
async function waitForFieldValue(docRef, fieldName, expectedValue, timeoutMs = 15000, intervalMs = 1000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const doc = await docRef.get();
    if (doc.exists && doc.data()[fieldName] === expectedValue) {
      return doc.data();
    }
    await sleep(intervalMs);
  }
  return null;
}

async function cleanUp() {
  console.log('🧹 Eski test verileri temizleniyor...');
  
  // Clean comment
  await db.collection('deals').doc(DEAL_ID).collection('comments').doc(COMMENT_ID).delete().catch(() => {});
  
  // Clean deal
  await db.collection('deals').doc(DEAL_ID).delete().catch(() => {});
  
  // Clean messages
  await db.collection('messages').doc(MSG_SENT_ID).delete().catch(() => {});
  await db.collection('messages').doc(MSG_RECV_ID).delete().catch(() => {});
  
  // Clean user
  await db.collection('users').doc(USER_ID).delete().catch(() => {});
  
  console.log('✅ Temizlik tamamlandı.\n');
}

async function runTests() {
  try {
    await cleanUp();

    console.log('🚀 [ADIM 1] Test verileri Firestore üzerinde oluşturuluyor...');

    // 1. Kullanıcı dokümanı
    await db.collection('users').doc(USER_ID).set({
      username: 'EskiIsim',
      profileImageUrl: 'http://example.com/eski_resim.jpg',
      email: 'test_sync@test.firsatkolik.com',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   👤 Test kullanıcısı oluşturuldu (username: EskiIsim, avatar: eski_resim.jpg)');

    // 2. Fırsat dokümanı (Yorum eklemek için gerekli)
    await db.collection('deals').doc(DEAL_ID).set({
      title: 'Sync Test Fırsatı',
      postedBy: USER_ID,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 3. Yorum dokümanı (Denormalize kullanıcı bilgileriyle)
    const commentRef = db.collection('deals').doc(DEAL_ID).collection('comments').doc(COMMENT_ID);
    await commentRef.set({
      userId: USER_ID,
      userName: 'EskiIsim',
      userProfileImageUrl: 'http://example.com/eski_resim.jpg',
      text: 'Test Yorumu',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   💬 Denormalize test yorumu oluşturuldu.');

    // 4. Gönderilen Mesaj (sender olarak test_user_sync_id)
    const sentMsgRef = db.collection('messages').doc(MSG_SENT_ID);
    await sentMsgRef.set({
      senderId: USER_ID,
      senderName: 'EskiIsim',
      senderImageUrl: 'http://example.com/eski_resim.jpg',
      receiverId: 'other_user_id',
      receiverName: 'Diğer Kullanıcı',
      receiverImageUrl: 'http://example.com/diger_resim.jpg',
      text: 'Gönderilen test mesajı',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   ✉️ Gönderilen test mesajı oluşturuldu.');

    // 5. Alınan Mesaj (receiver olarak test_user_sync_id)
    const recvMsgRef = db.collection('messages').doc(MSG_RECV_ID);
    await recvMsgRef.set({
      senderId: 'other_user_id',
      senderName: 'Diğer Kullanıcı',
      senderImageUrl: 'http://example.com/diger_resim.jpg',
      receiverId: USER_ID,
      receiverName: 'EskiIsim',
      receiverImageUrl: 'http://example.com/eski_resim.jpg',
      text: 'Alınan test mesajı',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   ✉️ Alınan test mesajı oluşturuldu.');

    console.log('\n🚀 [ADIM 2] Kullanıcı bilgileri güncelleniyor (YeniIsim & yeni_resim.jpg)...');
    
    // Kullanıcı profilini güncelle (Cloud Function tetiklenecek!)
    await db.collection('users').doc(USER_ID).update({
      username: 'YeniIsim',
      profileImageUrl: 'http://example.com/yeni_resim.jpg'
    });

    console.log('⏳ Tetikleyicinin (onUserUpdated) çalışması bekleniyor (polling)...');

    // 6. Yorum Güncelleme Kontrolü
    console.log('   🔍 Yorum senkronizasyonu kontrol ediliyor...');
    const updatedComment = await waitForFieldValue(commentRef, 'userProfileImageUrl', 'http://example.com/yeni_resim.jpg');
    if (updatedComment && updatedComment.userName === 'YeniIsim') {
      console.log('   🎉 [BAŞARILI] Yorum başarıyla senkronize edildi!');
    } else {
      throw new Error('Yorum senkronize edilemedi veya zaman aşımına uğradı!');
    }

    // 7. Gönderilen Mesaj Kontrolü
    console.log('   🔍 Gönderilen mesaj senkronizasyonu kontrol ediliyor...');
    const updatedSentMsg = await waitForFieldValue(sentMsgRef, 'senderImageUrl', 'http://example.com/yeni_resim.jpg');
    if (updatedSentMsg && updatedSentMsg.senderName === 'YeniIsim') {
      console.log('   🎉 [BAŞARILI] Gönderilen mesaj başarıyla senkronize edildi!');
    } else {
      throw new Error('Gönderilen mesaj senkronize edilemedi veya zaman aşımına uğradı!');
    }

    // 8. Alınan Mesaj Kontrolü
    console.log('   🔍 Alınan mesaj senkronizasyonu kontrol ediliyor...');
    const updatedRecvMsg = await waitForFieldValue(recvMsgRef, 'receiverImageUrl', 'http://example.com/yeni_resim.jpg');
    if (updatedRecvMsg && updatedRecvMsg.receiverName === 'YeniIsim') {
      console.log('   🎉 [BAŞARILI] Alınan mesaj başarıyla senkronize edildi!');
    } else {
      throw new Error('Alınan mesaj senkronize edilemedi veya zaman aşımına uğradı!');
    }

    console.log('\n🌟 TÜM TESTLER BAŞARIYLA GEÇTİ! Profil resmi ve kullanıcı adı tüm geçmiş yorum ve mesajlarda eşzamanlı güncellendi.');

  } catch (err) {
    console.error('\n❌ TEST BAŞARISIZ:', err.message);
    process.exit(1);
  } finally {
    await cleanUp();
    process.exit(0);
  }
}

runTests();
