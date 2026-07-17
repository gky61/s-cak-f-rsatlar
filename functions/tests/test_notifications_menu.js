/**
 * FırsatKolik — "Bildirimler" Menüsü (Uygulama İçi Bildirim Kutusu) Senaryo Testleri
 * 
 * Bu betik, kullanıcıların uygulama içindeki Bildirim Kutusu'nda (users/{uid}/notifications)
 * birikmesi gereken bildirim senaryolarını test eder ve doğrular.
 * 
 * Çalıştırmak için: node functions/tests/test_notifications_menu.js
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

// Test User IDs
const TESTER_A = 'test_yazar_user_id';
const TESTER_B = 'test_takipci_user_id';

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Güvenli Belge Bekleme Yardımcısı (Race condition engellemek için polling yapar)
async function waitForDoc(docRef, timeoutMs = 15000, intervalMs = 1000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const doc = await docRef.get();
    if (doc.exists) {
      return doc;
    }
    await sleep(intervalMs);
  }
  return null;
}

// Güvenli Sorgu Bekleme Yardımcısı (Çoklu sonuçlar için polling)
async function waitForQuery(query, expectedSize, timeoutMs = 15000, intervalMs = 1000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const snap = await query.get();
    if (snap.size === expectedSize) {
      return snap;
    }
    await sleep(intervalMs);
  }
  return await query.get();
}

// Temizlik Yardımcısı
async function cleanupTestData() {
  console.log('🧹 Eski test verileri temizleniyor...');
  
  // 1. Abonelikleri temizle
  const subsSnap = await db.collection('notificationSubscriptions')
    .where('uid', 'in', [TESTER_A, TESTER_B])
    .get();
  const batch1 = db.batch();
  subsSnap.forEach(doc => batch1.delete(doc.ref));
  await batch1.commit();

  // 2. Bildirimleri temizle
  const notifsASnap = await db.collection('users').doc(TESTER_A).collection('notifications').get();
  const batch2 = db.batch();
  notifsASnap.forEach(doc => batch2.delete(doc.ref));
  await batch2.commit();

  const notifsBSnap = await db.collection('users').doc(TESTER_B).collection('notifications').get();
  const batch3 = db.batch();
  notifsBSnap.forEach(doc => batch3.delete(doc.ref));
  await batch3.commit();

  // 3. Test fırsatlarını ve yorumlarını temizle
  const dealsSnap = await db.collection('deals')
    .where('postedBy', 'in', [TESTER_A, TESTER_B])
    .get();
  
  for (const doc of dealsSnap.docs) {
    const commentsSnap = await doc.ref.collection('comments').get();
    const batchComments = db.batch();
    commentsSnap.forEach(d => batchComments.delete(d.ref));
    await batchComments.commit();
    
    await doc.ref.delete();
  }

  // 4. Test kullanıcı profillerini temizle
  await db.collection('users').doc(TESTER_A).delete();
  await db.collection('users').doc(TESTER_B).delete();

  console.log('✅ Temizlik tamamlandı.\n');
}

// Test Kullanıcılarını Oluştur
async function setupTestUsers() {
  console.log('👥 Test kullanıcıları ve profilleri oluşturuluyor...');
  
  await db.collection('users').doc(TESTER_A).set({
    uid: TESTER_A,
    username: 'AvciTesterA',
    nickname: 'avci_tester_a',
    email: 'tester_a@test.firsatkolik.com',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  await db.collection('users').doc(TESTER_B).set({
    uid: TESTER_B,
    username: 'TakipciTesterB',
    nickname: 'takipci_tester_b',
    email: 'tester_b@test.firsatkolik.com',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // Test cihazları tanımlayalım (FCM test_token)
  await db.collection('userDevices').doc(`device_${TESTER_A}`).set({
    uid: TESTER_A,
    deviceId: `device_${TESTER_A}`,
    platform: 'android',
    fcmToken: `token_${TESTER_A}`,
    permissionStatus: 'authorized',
    active: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  await db.collection('userDevices').doc(`device_${TESTER_B}`).set({
    uid: TESTER_B,
    deviceId: `device_${TESTER_B}`,
    platform: 'android',
    fcmToken: `token_${TESTER_B}`,
    permissionStatus: 'authorized',
    active: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  console.log('✅ Test kullanıcıları hazır.\n');
}

// ---------------------- TEST SENARYOLARI ----------------------

async function runTests() {
  try {
    await cleanupTestData();
    await setupTestUsers();

    // ==========================================
    // SENARYO 1: Paylaşım Durumu Bildirimi - ONAY
    // ==========================================
    console.log('🧪 [TEST 1] Paylaşılan Fırsatın Onaylanma Senaryosu Başlatılıyor...');
    const deal1Ref = db.collection('deals').doc();
    await deal1Ref.set({
      title: 'Test Fırsat 1 - PlayStation 5 Pro',
      description: 'PS5 Pro indirimde kaçırmayın',
      price: 28000,
      store: 'Amazon',
      category: 'elektronik',
      postedBy: TESTER_A,
      isUserSubmitted: true,
      isApproved: false,
      isRejected: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   🔸 Fırsat onay bekliyor durumunda eklendi. Admin onay veriyor...');
    await deal1Ref.update({
      isApproved: true,
      status: 'active',
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   ⏳ Cloud Function tetiklenmesi bekleniyor (polling)...');
    const notif1DocRef = db.collection('users').doc(TESTER_A)
      .collection('notifications')
      .doc(`deal_status_approved_${deal1Ref.id}`);
    
    const notif1Doc = await waitForDoc(notif1DocRef);

    if (notif1Doc) {
      console.log('   🎉 [BAŞARILI] Fırsat onay bildirimi başarıyla oluşturuldu!');
      console.log('      Bildirim Başlığı:', notif1Doc.data().title);
      console.log('      Bildirim İçeriği:', notif1Doc.data().body);
    } else {
      console.error('   ❌ [BAŞARISIZ] Fırsat onay bildirimi bulunamadı!');
    }
    console.log('--------------------------------------------------\n');


    // ==========================================
    // SENARYO 2: Paylaşım Durumu Bildirimi - RED
    // ==========================================
    console.log('🧪 [TEST 2] Paylaşılan Fırsatın Reddedilme Senaryosu Başlatılıyor...');
    const deal2Ref = db.collection('deals').doc();
    await deal2Ref.set({
      title: 'Test Fırsat 2 - Yasaklı Ürün Fırsatı',
      description: 'Politikalara aykırı test fırsatı',
      price: 1500,
      store: 'Trendyol',
      category: 'genel',
      postedBy: TESTER_A,
      isUserSubmitted: true,
      isApproved: false,
      isRejected: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   🔸 Fırsat onay bekliyor durumunda eklendi. Admin reddediyor...');
    await deal2Ref.update({
      isRejected: true,
      status: 'rejected',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   ⏳ Cloud Function tetiklenmesi bekleniyor (polling)...');
    const notif2DocRef = db.collection('users').doc(TESTER_A)
      .collection('notifications')
      .doc(`deal_status_rejected_${deal2Ref.id}`);
    
    const notif2Doc = await waitForDoc(notif2DocRef);

    if (notif2Doc) {
      console.log('   🎉 [BAŞARILI] Fırsat red bildirimi başarıyla oluşturuldu!');
      console.log('      Bildirim Başlığı:', notif2Doc.data().title);
      console.log('      Bildirim İçeriği:', notif2Doc.data().body);
    } else {
      console.error('   ❌ [BAŞARISIZ] Fırsat red bildirimi bulunamadı!');
    }
    console.log('--------------------------------------------------\n');


    // ==========================================
    // SENARYO 3: Takipçi, Kategori ve Kelime Eşleşmeleri ve Deduplication (Tekilleştirme)
    // ==========================================
    console.log('🧪 [TEST 3] Çoklu Eşleşme ve Önceliklendirme (Deduplication) Senaryosu...');
    
    // 1. Abonelikleri Tanımla:
    // TESTER_B: Yazar TESTER_A'yı takip ediyor (zil açık)
    await db.collection('notificationSubscriptions').doc(`${TESTER_B}_author_${TESTER_A}`).set({
      uid: TESTER_B,
      type: 'author',
      key: TESTER_A,
      displayValue: 'AvciTesterA',
      enabled: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // TESTER_B: "elektronik" kategorisine abone
    await db.collection('notificationSubscriptions').doc(`${TESTER_B}_category_elektronik`).set({
      uid: TESTER_B,
      type: 'category',
      key: 'elektronik',
      displayValue: 'Elektronik',
      enabled: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // TESTER_B: "playstation" kelimesine abone
    await db.collection('notificationSubscriptions').doc(`${TESTER_B}_keyword_playstation`).set({
      uid: TESTER_B,
      type: 'keyword',
      key: 'playstation',
      displayValue: 'playstation',
      enabled: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   🔸 TESTER_B için yazar, kategori ("elektronik") ve anahtar kelime ("playstation") abonelikleri kuruldu.');
    
    // TESTER_A yeni PlayStation fırsatı paylaşıyor ve admin onaylıyor
    const deal3Ref = db.collection('deals').doc();
    await deal3Ref.set({
      title: 'Sony PlayStation 5 İndirimi!',
      description: 'Muhteşem PS5 konsolu elektronik kategorisinde',
      price: 18999,
      store: 'Hepsiburada',
      category: 'elektronik',
      postedBy: TESTER_A,
      isUserSubmitted: true,
      isApproved: false,
      isRejected: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   🔸 Fırsat onaylanıyor...');
    await deal3Ref.update({
      isApproved: true,
      status: 'active',
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   ⏳ Cloud Function tetiklenmesi bekleniyor (polling)...');
    const query = db.collection('users').doc(TESTER_B)
      .collection('notifications')
      .where('dealId', '==', deal3Ref.id);
    
    const notifsSnap = await waitForQuery(query, 1);

    console.log(`   📊 Alınan toplam bildirim kaydı sayısı: ${notifsSnap.size} (Beklenen: 1)`);
    
    if (notifsSnap.size === 1) {
      const notifData = notifsSnap.docs[0].data();
      console.log('   🎉 [BAŞARILI] Bildirim başarıyla tekilleştirildi!');
      console.log('      Belirlenen Sebep (reason):', notifData.reason, '(Beklenen: keyword)');
      console.log('      Dinamik Başlık (title):', notifData.title);
      console.log('      Dinamik Gövde (body):', notifData.body);
      
      if (notifData.reason === 'keyword') {
        console.log('   🎯 [BAŞARILI] En yüksek öncelik olan "keyword" başarıyla seçildi!');
      } else {
        console.error('   ❌ [BAŞARISIZ] Hatalı öncelik sebebi:', notifData.reason);
      }
    } else if (notifsSnap.size > 1) {
      console.error('   ❌ [BAŞARISIZ] Mükerrer bildirim oluşturulmuş! Tekilleştirme çalışmadı.');
    } else {
      console.error('   ❌ [BAŞARISIZ] TESTER_B kullanıcısına hiç bildirim oluşturulmadı!');
    }
    console.log('--------------------------------------------------\n');


    // ==========================================
    // SENARYO 4: Yorum Yanıt Bildirimi (Comment Reply)
    // ==========================================
    console.log('🧪 [TEST 4] Yorum Yanıt Senaryosu Başlatılıyor...');

    // 1. TESTER_B bir yorum yazar
    const commentBRef = deal3Ref.collection('comments').doc();
    await commentBRef.set({
      id: commentBRef.id,
      userId: TESTER_B,
      userName: 'TakipciTesterB',
      text: 'Bu fiyata PS5 alınır mı sizce?',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   🔸 TESTER_B ana yoruma yazdı. TESTER_A bu yoruma cevap yazıyor...');
    
    // 2. TESTER_A yanıt yazar
    const commentARef = deal3Ref.collection('comments').doc();
    await commentARef.set({
      id: commentARef.id,
      userId: TESTER_A,
      userName: 'AvciTesterA',
      text: 'Kesinlikle alınır, fiyat çok iyi!',
      parentCommentId: commentBRef.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   ⏳ Cloud Function tetiklenmesi bekleniyor (polling)...');
    const commentNotifDocRef = db.collection('users').doc(TESTER_B)
      .collection('notifications')
      .doc(`reply_${commentARef.id}_${TESTER_B}`);
    
    const commentNotifDoc = await waitForDoc(commentNotifDocRef);

    if (commentNotifDoc) {
      console.log('   🎉 [BAŞARILI] Yorum yanıt bildirimi başarıyla oluşturuldu!');
      console.log('      Bildirim Başlığı:', commentNotifDoc.data().title);
      console.log('      Bildirim İçeriği:', commentNotifDoc.data().body);
    } else {
      console.error('   ❌ [BAŞARISIZ] Yorum yanıt bildirimi bulunamadı!');
    }
    console.log('--------------------------------------------------\n');

  } catch (err) {
    console.error('❌ Hata oluştu:', err);
  } finally {
    // Test verilerini temizle
    await cleanupTestData();
    process.exit(0);
  }
}

runTests();
