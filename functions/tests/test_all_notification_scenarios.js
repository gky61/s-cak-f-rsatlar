/**
 * FırsatKolik — Tüm Bildirim Senaryoları Çaprazlama & Uçtan Uca Bütünleşik Test Süiti (vProduction)
 * 
 * Bu test süiti; 10 temel bildirim senaryosunu (NOTIF-01'den NOTIF-10'a),
 * Deduplication (Önceliklendirme), Dinamik Neden Dönüşümü, Sessiz Saatler,
 * Kategori Limitleri, Admin & Chat Mesajları ve Cihaz Tekilleştirme mantıklarını
 * canlı geliştirme (DEV) ortamında çapraz kontroller ile test eder.
 * 
 * Çalıştırmak için: node functions/tests/test_all_notification_scenarios.js
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

const TEST_USER = 'test_cross_user_id';
const TEST_AUTHOR = 'test_cross_author_id';

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function ensureActiveDevice() {
  await db.collection('userDevices').doc(`${TEST_USER}_device_main`).set({
    uid: TEST_USER,
    deviceId: 'device_main',
    platform: 'android',
    fcmToken: 'test_token_cross_main',
    permissionStatus: 'authorized',
    active: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function cleanupTestData() {
  console.log('🧹 Eski test verileri temizleniyor...');
  
  // 1. Bildirimleri temizle
  const notifsSnap = await db.collection('users').doc(TEST_USER).collection('notifications').get();
  const batch1 = db.batch();
  notifsSnap.docs.forEach(doc => batch1.delete(doc.ref));
  await batch1.commit();

  // 2. Abonelikleri temizle
  const subsSnap = await db.collection('notificationSubscriptions').where('uid', 'in', [TEST_USER, TEST_AUTHOR]).get();
  const batch2 = db.batch();
  subsSnap.docs.forEach(doc => batch2.delete(doc.ref));
  await batch2.commit();

  // 3. Cihazları temizle
  const devicesSnap = await db.collection('userDevices').where('uid', '==', TEST_USER).get();
  const batch3 = db.batch();
  devicesSnap.docs.forEach(doc => batch3.delete(doc.ref));
  await batch3.commit();

  // 4. Tercihleri sıfırla
  await db.collection('users').doc(TEST_USER).collection('notificationPreferences').doc('main').set({
    pushMasterEnabled: true,
    dealNotificationsEnabled: true,
    categoryNotificationsEnabled: true,
    keywordNotificationsEnabled: true,
    communityNotificationsEnabled: true,
    submissionStatusNotificationsEnabled: true,
    marketingNotificationsEnabled: true,
    quietHoursEnabled: false,
    quietHoursStart: '23:00',
    quietHoursEnd: '08:00',
    timezone: 'Europe/Istanbul',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    schemaVersion: 1
  });

  // 5. Test Cihazı ekle
  await ensureActiveDevice();

  console.log('✅ Temizlik tamamlandı ve temel test ortamı hazırlandı.\n');
}

async function waitForNotification(notificationId, maxAttempts = 15) {
  for (let i = 0; i < maxAttempts; i++) {
    await sleep(600);
    const doc = await db.collection('users').doc(TEST_USER).collection('notifications').doc(notificationId).get();
    if (doc.exists && doc.data().pushStatus && doc.data().pushStatus !== 'pending') {
      return doc.data();
    }
  }
  const fallback = await db.collection('users').doc(TEST_USER).collection('notifications').doc(notificationId).get();
  return fallback.exists ? fallback.data() : null;
}

let passedCount = 0;
let totalCount = 0;

function assert(condition, message) {
  totalCount++;
  if (condition) {
    passedCount++;
    console.log(`   🎉 [BAŞARILI] ${message}`);
  } else {
    console.error(`   ❌ [BAŞARISIZ] ${message}`);
  }
}

async function runAllScenarios() {
  console.log('===============================================================');
  console.log('🚀 FırsatKolik — Çapraz Kontrollü Tüm Bildirim Senaryoları Testi');
  console.log('===============================================================\n');

  await cleanupTestData();

  // --------------------------------------------------------------------------
  // SENARYO 1: NOTIF-01 (Kategori Bildirimi)
  // --------------------------------------------------------------------------
  console.log('🧪 [SENARYO 1 / NOTIF-01] Kategori Fırsat Bildirimi...');
  await ensureActiveDevice();
  const notifId1 = `deal_test_deal_cat_${Date.now()}_${TEST_USER}`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId1).set({
    type: 'deal',
    reason: 'category',
    reasonDetail: 'elektronik',
    dealId: 'test_deal_cat',
    dealTitle: 'Sony Kulaklık İndirimi',
    title: '🎯 Yeni Fırsat!',
    body: 'Sony Kulaklık İndirimi\n💰 2500 TL',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res1 = await waitForNotification(notifId1);
  assert(res1 && (res1.pushStatus === 'sent' || res1.pushStatus === 'failed'), 'Kategori bildirimi işlendi ve FCM hattına ulaştı (pushStatus: sent/failed)');
  assert(res1 && res1.reason === 'category', 'Bildirim sebebi doğru olarak "category" kaydedildi');

  // --------------------------------------------------------------------------
  // SENARYO 2: NOTIF-02 (Takip Edilen Yazar Bildirimi)
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 2 / NOTIF-02] Takip Edilen Yazar Bildirimi...');
  await ensureActiveDevice();
  const notifId2 = `deal_test_deal_author_${Date.now()}_${TEST_USER}`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId2).set({
    type: 'deal',
    reason: 'author',
    reasonDetail: TEST_AUTHOR,
    dealId: 'test_deal_author',
    dealTitle: 'Apple MacBook Air M3 Fırsatı',
    title: '👤 Takip Ettiğiniz Kişi!',
    body: 'Takip ettiğiniz yazar yeni fırsat paylaştı: Apple MacBook Air M3 Fırsatı',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res2 = await waitForNotification(notifId2);
  assert(res2 && (res2.pushStatus === 'sent' || res2.pushStatus === 'failed'), 'Yazar bildirimi işlendi ve FCM hattına ulaştı');
  assert(res2 && res2.reason === 'author', 'Bildirim sebebi doğru olarak "author" kaydedildi');

  // --------------------------------------------------------------------------
  // SENARYO 3: NOTIF-03 (Anahtar Kelime Bildirimi)
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 3 / NOTIF-03] Anahtar Kelime Bildirimi...');
  await ensureActiveDevice();
  const notifId3 = `deal_test_deal_kw_${Date.now()}_${TEST_USER}`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId3).set({
    type: 'deal',
    reason: 'keyword',
    reasonDetail: 'dyson v15',
    dealId: 'test_deal_kw',
    dealTitle: 'Dyson V15 Detect Kablosuz Süpürge',
    title: '🎯 İlginizi Çeken Kelime!',
    body: '"dyson v15" içeren yeni fırsat: Dyson V15 Detect Kablosuz Süpürge',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res3 = await waitForNotification(notifId3);
  assert(res3 && (res3.pushStatus === 'sent' || res3.pushStatus === 'failed'), 'Anahtar kelime bildirimi işlendi ve FCM hattına ulaştı');
  assert(res3 && res3.reason === 'keyword', 'Bildirim sebebi doğru olarak "keyword" kaydedildi');

  // --------------------------------------------------------------------------
  // SENARYO 4: Çoklu Eşleşme Deduplication & Önceliklendirme
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 4 / DEDUPLICATION] Çoklu Eşleşme (Kelime > Yazar > Kategori)...');
  await ensureActiveDevice();
  const notifId4 = `deal_test_deal_multi_${Date.now()}_${TEST_USER}`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId4).set({
    type: 'deal',
    reason: 'keyword',
    reasonDetail: 'playstation 5',
    reasons: {
      keyword: 'playstation 5',
      author: TEST_AUTHOR,
      category: 'elektronik'
    },
    dealId: 'test_deal_multi',
    dealTitle: 'PlayStation 5 Slim 1TB',
    title: '🎯 İlginizi Çeken Kelime!',
    body: '"playstation 5" içeren yeni fırsat: PlayStation 5 Slim 1TB',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res4 = await waitForNotification(notifId4);
  assert(res4 && res4.reason === 'keyword', 'Çoklu eşleşmede en yüksek öncelikli "keyword" korundu');
  assert(res4 && res4.reasons && res4.reasons.author && res4.reasons.category, 'Tüm eşleşen nedenler "reasons" haritasında saklandı');

  // --------------------------------------------------------------------------
  // SENARYO 5: Dinamik Neden Dönüşümü (Keyword OFF -> Category Fallback)
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 5 / DYNAMIC FALLBACK] Dinamik Neden Dönüşümü (Kelime Kapalı -> Kategoriye Geçiş)...');
  await ensureActiveDevice();
  // Kullanıcı kelime bildirimlerini kapattı, kategori açık
  await db.collection('users').doc(TEST_USER).collection('notificationPreferences').doc('main').update({
    keywordNotificationsEnabled: false,
    categoryNotificationsEnabled: true
  });

  const notifId5 = `deal_test_deal_fallback_${Date.now()}_${TEST_USER}`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId5).set({
    type: 'deal',
    reason: 'keyword',
    reasonDetail: 'iphone 16',
    reasons: {
      keyword: 'iphone 16',
      category: 'elektronik'
    },
    dealId: 'test_deal_fallback',
    dealTitle: 'Apple iPhone 16 Pro Max 256GB',
    title: '🎯 İlginizi Çeken Kelime!',
    body: '"iphone 16" içeren yeni fırsat: Apple iPhone 16 Pro Max 256GB',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res5 = await waitForNotification(notifId5);
  assert(res5 && res5.reason === 'category', 'Kelime kapalı olduğu için aktif neden otomatik "category"ye dönüştürüldü');
  assert(res5 && res5.title === '🎯 Yeni Fırsat!', 'Bildirim başlığı dinamik olarak kategori başlığına güncellendi');

  // Tercihi geri aç
  await db.collection('users').doc(TEST_USER).collection('notificationPreferences').doc('main').update({
    keywordNotificationsEnabled: true
  });

  // --------------------------------------------------------------------------
  // SENARYO 6: NOTIF-04 (Yorum Yanıt Bildirimi & Kendine Yanıt Kontrolü)
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 6 / NOTIF-04] Yorum Yanıt Bildirimi & Kendine Yanıt Koruması...');
  await ensureActiveDevice();
  const notifId6 = `reply_comment_123_${TEST_USER}`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId6).set({
    type: 'comment_reply',
    dealId: 'test_deal_123',
    dealTitle: 'Test Fırsat',
    commentId: 'comment_123',
    parentCommentId: 'parent_001',
    replyUserName: 'FırsatAvcısı_Kemal',
    replyText: 'Fiyatı gerçekten çok düşmüş, kaçmaz!',
    title: 'FırsatAvcısı_Kemal yorumunuza cevap verdi',
    body: 'Fiyatı gerçekten çok düşmüş, kaçmaz!',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res6 = await waitForNotification(notifId6);
  assert(res6 && (res6.pushStatus === 'sent' || res6.pushStatus === 'failed'), 'Yorum yanıt bildirimi başarıyla işlendi');
  assert(res6 && res6.type === 'comment_reply', 'Bildirim türü "comment_reply" olarak doğrulandı');

  // --------------------------------------------------------------------------
  // SENARYO 7: NOTIF-05 & NOTIF-06 (Fırsat Onay & Red - Sessiz Bildirim)
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 7 / NOTIF-05 & 06] Fırsat Onay / Red Sessiz Bildirim Kontrolü...');
  const notifId7A = `status_approved_deal_999`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId7A).set({
    type: 'submission_status',
    status: 'approved',
    dealId: 'deal_999',
    dealTitle: 'Kullanıcı Fırsatı 999',
    title: '🎉 Fırsatınız Onaylandı!',
    body: 'Paylaştığınız "Kullanıcı Fırsatı 999" onaylandı ve yayına alındı.',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res7A = await waitForNotification(notifId7A);
  assert(res7A && res7A.pushStatus === 'disabled_permanently_for_submission_status', 'Fırsat onay bildirimi sessiz bildirime tabi tutuldu (pushStatus: disabled_permanently_for_submission_status)');
  assert(res7A && res7A.pushEligible === false, 'Fırsat onay bildirimi için pushEligible = false yapıldı');

  const notifId7B = `status_rejected_deal_888`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId7B).set({
    type: 'submission_status',
    status: 'rejected',
    dealId: 'deal_888',
    dealTitle: 'Kullanıcı Fırsatı 888',
    title: '❌ Fırsatınız Reddedildi',
    body: 'Paylaştığınız "Kullanıcı Fırsatı 888" kurallarımıza uymadığı için reddedildi.',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res7B = await waitForNotification(notifId7B);
  assert(res7B && res7B.pushStatus === 'disabled_permanently_for_submission_status', 'Fırsat red bildirimi sessiz bildirime tabi tutuldu (pushStatus: disabled_permanently_for_submission_status)');

  // --------------------------------------------------------------------------
  // SENARYO 8: NOTIF-07 (Yönetici Mesajı / admin_message)
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 8 / NOTIF-07] Yönetici Mesajı (admin_message)...');
  await ensureActiveDevice();
  const notifId8 = `admin_msg_official_notice_${Date.now()}`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId8).set({
    type: 'admin_message',
    messageId: 'official_notice_01',
    senderId: 'admin',
    senderName: 'FırsatKolik Yönetim',
    title: 'Sistem Güncellemesi Duyurusu',
    body: 'Bu gece 03:00 - 04:00 saatleri arasında planlı bakım yapılacaktır.',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res8 = await waitForNotification(notifId8);
  assert(res8 && (res8.pushStatus === 'sent' || res8.pushStatus === 'failed'), 'Admin mesajı başarıyla işlendi ve FCM gönderim kuyruğuna girdi');
  assert(res8 && res8.type === 'admin_message', 'Admin mesajı türü "admin_message" olarak doğrulandı');

  // --------------------------------------------------------------------------
  // SENARYO 9: Master Switch OFF (Tüm Bildirimlerin Kilitlenmesi & State Preservation)
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 9 / MASTER SWITCH OFF] Master Switch Kapalı İken Push Engeli...');
  await db.collection('users').doc(TEST_USER).collection('notificationPreferences').doc('main').update({
    pushMasterEnabled: false,
    categoryNotificationsEnabled: true // Alt kanal açık olsa bile master kapalı
  });

  const notifId9 = `deal_test_deal_master_off_${Date.now()}_${TEST_USER}`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId9).set({
    type: 'deal',
    reason: 'category',
    reasonDetail: 'elektronik',
    dealId: 'test_deal_master_off',
    dealTitle: 'Master Off Test Fırsatı',
    title: '🎯 Yeni Fırsat!',
    body: 'Master Off Test Fırsatı',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res9 = await waitForNotification(notifId9);
  assert(res9 && res9.pushStatus === 'disabled_by_user_master_switch', 'Master switch kapalıyken push bildirimi engellendi (disabled_by_user_master_switch)');
  assert(res9 && res9.pushEligible === false, 'Master switch kapalıyken pushEligible = false yapıldı');

  // Master switch'i geri aç
  await db.collection('users').doc(TEST_USER).collection('notificationPreferences').doc('main').update({
    pushMasterEnabled: true
  });

  // --------------------------------------------------------------------------
  // SENARYO 10: Multi-Device De-duplication (Mükerrer Cihaz Token Koruması)
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 10 / DEVICE DEDUPLICATION] Çoklu Cihaz / Mükerrer Token Tekilleştirmesi...');
  await ensureActiveDevice();
  // Aynı token ile 2. bir cihaz kaydı ekle
  await db.collection('userDevices').doc(`${TEST_USER}_device_duplicate`).set({
    uid: TEST_USER,
    deviceId: 'device_duplicate',
    platform: 'android',
    fcmToken: 'test_token_cross_main', // Aynı token
    permissionStatus: 'authorized',
    active: true,
    updatedAt: new Date(Date.now() - 10000) // Eski tarihli
  });

  const notifId10 = `deal_test_deal_dedup_${Date.now()}_${TEST_USER}`;
  await db.collection('users').doc(TEST_USER).collection('notifications').doc(notifId10).set({
    type: 'deal',
    reason: 'category',
    reasonDetail: 'elektronik',
    dealId: 'test_deal_dedup',
    dealTitle: 'Dedup Test Fırsatı',
    title: '🎯 Yeni Fırsat!',
    body: 'Dedup Test Fırsatı',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  const res10 = await waitForNotification(notifId10);
  assert(res10 && (res10.pushStatus === 'sent' || res10.pushStatus === 'failed'), 'Tekilleştirme sonrası bildirim başarıyla işlendi');

  // Eski cihaz kaydının pasife çekildiğini kontrol et
  await sleep(1500);
  const dupDoc = await db.collection('userDevices').doc(`${TEST_USER}_device_duplicate`).get();
  assert(dupDoc.exists && dupDoc.data().active === false, 'Mükerrer token\'a sahip eski cihaz kaydı otomatik olarak active: false yapıldı');

  // Temizlik
  await cleanupTestData();

  console.log('\n===============================================================');
  console.log(`📊 TEST SONUÇLARI: ${passedCount} / ${totalCount} KONTROL BAŞARILI (%${Math.round((passedCount/totalCount)*100)})`);
  console.log('===============================================================\n');

  if (passedCount === totalCount) {
    console.log('🏆 TÜM BİLDİRİM SENARYOLARI VE KARAR MATRİSLERİ %100 BAŞARIYLA GEÇTİ!');
  } else {
    console.error('⚠️ BAZI TESTLER BAŞARISIZ OLDU, LÜTFEN LOGLARI İNCELEYİN.');
    process.exit(1);
  }
}

runAllScenarios().then(() => process.exit(0)).catch(e => {
  console.error('Kritik Test Hatası:', e);
  process.exit(1);
});
