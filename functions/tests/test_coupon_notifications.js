/**
 * FırsatKolik — Topluluk Kuponları Bildirim Sistemi Uçtan Uca Test Süiti (NOTIF-15)
 * 
 * Bu test süiti; topluluk tarafından paylaşılan kuponlar için bildirim oluşturma,
 * push motoru entegrasyonu, kullanıcı tercih kontrolü, sessiz saatler ve
 * self-notification koruması senaryolarını canlı DEV ortamında test eder.
 * 
 * Çalıştırmak için: node functions/tests/test_coupon_notifications.js
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

const TEST_USER = 'test_coupon_user_id';
const TEST_SHARER = 'test_coupon_sharer_id';

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function ensureActiveDevice() {
  await db.collection('userDevices').doc(`${TEST_USER}_device_main`).set({
    uid: TEST_USER,
    deviceId: 'device_main',
    platform: 'android',
    fcmToken: 'test_coupon_token_main',
    permissionStatus: 'authorized',
    active: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function cleanupTestData() {
  console.log('🧹 Eski kupon test verileri temizleniyor...');

  // 1. Bildirimleri temizle
  const notifsSnap = await db.collection('users').doc(TEST_USER).collection('notifications').get();
  const batch1 = db.batch();
  notifsSnap.docs.forEach(doc => batch1.delete(doc.ref));
  await batch1.commit();

  // 2. Cihazları temizle
  const devicesSnap = await db.collection('userDevices').where('uid', '==', TEST_USER).get();
  const batch2 = db.batch();
  devicesSnap.docs.forEach(doc => batch2.delete(doc.ref));
  await batch2.commit();

  // 3. Test kuponlarını temizle
  const couponsSnap = await db.collection('kuponlar').where('paylasanKullaniciId', 'in', [TEST_SHARER, TEST_USER]).get();
  const batch3 = db.batch();
  couponsSnap.docs.forEach(doc => batch3.delete(doc.ref));
  await batch3.commit();

  // 4. Tercihleri sıfırla (communityNotificationsEnabled = true)
  await db.collection('users').doc(TEST_USER).set({
    displayName: 'Test Kupon Kullanıcısı',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

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

  // 5. Paylaşan kullanıcıyı oluştur
  await db.collection('users').doc(TEST_SHARER).set({
    displayName: 'Kupon Paylaşıcı',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

  // 6. Test Cihazı ekle
  await ensureActiveDevice();

  console.log('✅ Temizlik tamamlandı ve kupon test ortamı hazırlandı.\n');
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

async function runCouponTests() {
  console.log('===============================================================');
  console.log('🎟️  FırsatKolik — Topluluk Kuponları Bildirim Testi (NOTIF-15)');
  console.log('===============================================================\n');

  await cleanupTestData();

  // --------------------------------------------------------------------------
  // SENARYO 1: Topluluk Kuponu Oluşturulduğunda Bildirim Oluşturulur
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 1 / COUPON_CREATED] Topluluk kuponu oluşturuluyor...');
  const kuponId1 = `test_coupon_${Date.now()}`;
  await db.collection('kuponlar').doc(kuponId1).set({
    baslik: 'Trendyol %30 İndirim Kuponu',
    kuponKodu: 'TREND30',
    magazaAdi: 'Trendyol',
    kaynakTipi: 'topluluk',
    durum: 'aktif',
    paylasanKullaniciId: TEST_SHARER,
    paylasanKullaniciAdi: 'Kupon Paylaşıcı',
    olusturmaTarihi: admin.firestore.FieldValue.serverTimestamp()
  });

  // onCouponCreated tetiklenecek, bildirim oluşturulacak
  const notifId1 = `coupon_${kuponId1}_${TEST_USER}`;
  const res1 = await waitForNotification(notifId1);
  assert(res1 !== null, 'Topluluk kuponu için bildirim dokümanı oluşturuldu');
  assert(res1 && res1.type === 'coupon', `Bildirim tipi 'coupon' olarak ayarlandı (gerçek: ${res1?.type})`);
  assert(res1 && res1.kuponId === kuponId1, `kuponId doğru iletildi (gerçek: ${res1?.kuponId})`);
  assert(res1 && res1.magazaAdi === 'Trendyol', `magazaAdi doğru (gerçek: ${res1?.magazaAdi})`);
  assert(res1 && res1.read === false, 'Bildirim okunmamış olarak oluşturuldu');

  // --------------------------------------------------------------------------
  // SENARYO 2: Kuponu Paylaşan Kullanıcıya Bildirim GÖNDERİLMEZ (Self-notification koruması)
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 2 / SELF_NOTIFICATION] Kuponu paylaşan kullanıcıya bildirim gitmemeli...');
  const sharerNotifId = `coupon_${kuponId1}_${TEST_SHARER}`;
  await sleep(3000); // onCouponCreated'ın tamamlanmasını bekle
  const sharerNotif = await db.collection('users').doc(TEST_SHARER).collection('notifications').doc(sharerNotifId).get();
  assert(!sharerNotif.exists, 'Kuponu paylaşan kullanıcıya bildirim GÖNDERİLMEDİ (self-notification koruması)');

  // --------------------------------------------------------------------------
  // SENARYO 3: Web Kaynaklı Kuponlar İçin Bildirim OLUŞTURULMAZ
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 3 / WEB_COUPON_SKIP] Web kaynaklı kupon için bildirim oluşturulmamalı...');
  const webKuponId = `test_web_coupon_${Date.now()}`;
  await db.collection('kuponlar').doc(webKuponId).set({
    baslik: 'Amazon Web Kuponu',
    kuponKodu: 'WEB10',
    magazaAdi: 'Amazon',
    kaynakTipi: 'web', // Web kazıma kaynaklı
    durum: 'aktif',
    paylasanKullaniciId: 'scraper_bot',
    olusturmaTarihi: admin.firestore.FieldValue.serverTimestamp()
  });

  await sleep(4000);
  const webNotifId = `coupon_${webKuponId}_${TEST_USER}`;
  const webNotif = await db.collection('users').doc(TEST_USER).collection('notifications').doc(webNotifId).get();
  assert(!webNotif.exists, 'Web kaynaklı kupon için bildirim oluşturulmadı (kaynakTipi filtresi çalıştı)');

  // --------------------------------------------------------------------------
  // SENARYO 4: Geçersiz Durumlu Kuponlar İçin Bildirim OLUŞTURULMAZ
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 4 / INVALID_COUPON_SKIP] Geçersiz kupon için bildirim oluşturulmamalı...');
  const invalidKuponId = `test_invalid_coupon_${Date.now()}`;
  await db.collection('kuponlar').doc(invalidKuponId).set({
    baslik: 'Geçersiz Kupon',
    kuponKodu: 'INVALID',
    magazaAdi: 'Test Mağaza',
    kaynakTipi: 'topluluk',
    durum: 'gecersiz', // Geçersiz durum
    paylasanKullaniciId: TEST_SHARER,
    olusturmaTarihi: admin.firestore.FieldValue.serverTimestamp()
  });

  await sleep(4000);
  const invalidNotifId = `coupon_${invalidKuponId}_${TEST_USER}`;
  const invalidNotif = await db.collection('users').doc(TEST_USER).collection('notifications').doc(invalidNotifId).get();
  assert(!invalidNotif.exists, 'Geçersiz durumlu kupon için bildirim oluşturulmadı (durum filtresi çalıştı)');

  // --------------------------------------------------------------------------
  // SENARYO 5: communityNotificationsEnabled = false iken Push GÖNDERİLMEZ
  //            (Bildirim Merkezi'nde kalır ama push bastırılır)
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 5 / COMMUNITY_DISABLED] Topluluk bildirimleri kapatıldığında push engellenmeli...');
  await db.collection('users').doc(TEST_USER).collection('notificationPreferences').doc('main').update({
    communityNotificationsEnabled: false
  });

  const kuponId5 = `test_coupon_disabled_${Date.now()}`;
  await db.collection('kuponlar').doc(kuponId5).set({
    baslik: 'N11 %20 İndirim',
    kuponKodu: 'N11INDIRIM',
    magazaAdi: 'N11',
    kaynakTipi: 'topluluk',
    durum: 'aktif',
    paylasanKullaniciId: TEST_SHARER,
    paylasanKullaniciAdi: 'Kupon Paylaşıcı',
    olusturmaTarihi: admin.firestore.FieldValue.serverTimestamp()
  });

  const notifId5 = `coupon_${kuponId5}_${TEST_USER}`;
  const res5 = await waitForNotification(notifId5);
  assert(res5 !== null, 'Bildirim dokümanı oluşturuldu (Bildirim Merkezinde kalır)');
  assert(
    res5 && (res5.pushStatus === 'disabled_by_user_group_community' || res5.pushStatus === 'disabled_by_user_preference'),
    `Push engellendi: communityNotificationsEnabled=false (pushStatus: ${res5?.pushStatus})`
  );

  // Tercihi geri aç
  await db.collection('users').doc(TEST_USER).collection('notificationPreferences').doc('main').update({
    communityNotificationsEnabled: true
  });

  // --------------------------------------------------------------------------
  // SENARYO 6: Master Switch Kapalıyken Push GÖNDERİLMEZ
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 6 / MASTER_SWITCH_OFF] Master switch kapalıyken kupon push engellenmeli...');
  await db.collection('users').doc(TEST_USER).collection('notificationPreferences').doc('main').update({
    pushMasterEnabled: false
  });

  const kuponId6 = `test_coupon_master_off_${Date.now()}`;
  await db.collection('kuponlar').doc(kuponId6).set({
    baslik: 'Hepsiburada %15 İndirim',
    kuponKodu: 'HB15',
    magazaAdi: 'Hepsiburada',
    kaynakTipi: 'topluluk',
    durum: 'aktif',
    paylasanKullaniciId: TEST_SHARER,
    paylasanKullaniciAdi: 'Kupon Paylaşıcı',
    olusturmaTarihi: admin.firestore.FieldValue.serverTimestamp()
  });

  const notifId6 = `coupon_${kuponId6}_${TEST_USER}`;
  const res6 = await waitForNotification(notifId6);
  assert(res6 !== null, 'Bildirim dokümanı oluşturuldu (Bildirim Merkezinde kalır)');
  assert(
    res6 && res6.pushStatus === 'disabled_by_user_master_switch',
    `Master switch kapalıyken push engellendi (pushStatus: ${res6?.pushStatus})`
  );

  // Master switch'i geri aç
  await db.collection('users').doc(TEST_USER).collection('notificationPreferences').doc('main').update({
    pushMasterEnabled: true
  });

  // --------------------------------------------------------------------------
  // SENARYO 7: Bildirim Payload Doğrulaması
  // --------------------------------------------------------------------------
  console.log('\n🧪 [SENARYO 7 / PAYLOAD_VALIDATION] Kupon bildirimi payload yapısı doğrulanıyor...');
  // Senaryo 1'den kalan bildirim verisini kullan
  if (res1) {
    assert(res1.title && res1.title.includes('Trendyol'), `Bildirim başlığında mağaza adı var (${res1.title})`);
    assert(res1.body && res1.body.includes('Kupon Paylaşıcı'), `Bildirim gövdesinde paylaşan adı var`);
    assert(res1.body && res1.body.includes('Trendyol'), `Bildirim gövdesinde mağaza adı var`);
    assert(res1.authorId === TEST_SHARER, `authorId doğru (${res1.authorId})`);
    assert(res1.kuponKodu === 'TREND30', `kuponKodu doğru (${res1.kuponKodu})`);
    assert(res1.reason === 'community', `reason 'community' olarak ayarlandı (${res1.reason})`);
  } else {
    assert(false, 'Senaryo 1 verisi bulunamadı, payload doğrulaması yapılamadı');
  }

  // --------------------------------------------------------------------------
  // TEMİZLİK
  // --------------------------------------------------------------------------
  console.log('\n🧹 Test verileri temizleniyor...');

  // Test kuponlarını temizle
  const testCouponIds = [kuponId1, webKuponId, invalidKuponId, kuponId5, kuponId6];
  for (const id of testCouponIds) {
    await db.collection('kuponlar').doc(id).delete().catch(() => {});
  }

  await cleanupTestData();

  console.log('\n===============================================================');
  console.log(`📊 TEST SONUÇLARI: ${passedCount} / ${totalCount} KONTROL BAŞARILI (%${Math.round((passedCount/totalCount)*100)})`);
  console.log('===============================================================\n');

  if (passedCount === totalCount) {
    console.log('🏆 TÜM TOPLULUK KUPONU BİLDİRİM SENARYOLARI %100 BAŞARIYLA GEÇTİ!');
  } else {
    console.error('⚠️ BAZI TESTLER BAŞARISIZ OLDU, LÜTFEN LOGLARI İNCELEYİN.');
    process.exit(1);
  }
}

runCouponTests().then(() => process.exit(0)).catch(e => {
  console.error('Kritik Test Hatası:', e);
  process.exit(1);
});
