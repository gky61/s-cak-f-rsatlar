/**
 * FırsatKolik — "Bildirim Ayarları" (Push Bildirimleri ve Ayar Karar Mekanizması) Senaryo Testleri
 * 
 * Bu betik, kullanıcıların push ayarlarını (sessiz saatler, master switch, kanal engelleri, kategori limitleri vb.)
 * simüle ederek anlık push bildirimlerinin (FCM) gönderilme/engellenme karar süreçlerini parametrik olarak test eder.
 * 
 * Çalıştırmak için: node functions/tests/test_notification_settings.js
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

// Test User ID
const TESTER_USER = 'test_ayarlar_user_id';

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Güvenli Belge Bekleme Yardımcısı (onNotificationCreated tetiklenmesini beklemek için polling yapar)
async function waitForDocUpdate(docRef, checkField = 'pushStatus', timeoutMs = 15000, intervalMs = 1000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const doc = await docRef.get();
    if (doc.exists && doc.data()[checkField] !== undefined) {
      return doc;
    }
    await sleep(intervalMs);
  }
  return await docRef.get();
}

// Temizlik Yardımcısı
async function cleanupTestData() {
  console.log('🧹 Eski test verileri temizleniyor...');
  
  // 1. Bildirimleri temizle
  const notifsSnap = await db.collection('users').doc(TESTER_USER).collection('notifications').get();
  const batch = db.batch();
  notifsSnap.forEach(doc => batch.delete(doc.ref));
  await batch.commit();

  // 2. Tercihleri temizle
  await db.collection('users').doc(TESTER_USER).collection('notificationPreferences').doc('main').delete();
  await db.collection('users').doc(TESTER_USER).delete();

  // 3. Cihazları temizle
  const devicesSnap = await db.collection('userDevices').where('uid', '==', TESTER_USER).get();
  const batchDevs = db.batch();
  devicesSnap.forEach(doc => batchDevs.delete(doc.ref));
  await batchDevs.commit();

  // 4. Sistem limitlerini sıfırla (varsayılan limitlere getir)
  await db.collection('systemConfig').doc('notifications').set({
    enabled: true,
    categoryHourlyLimit: 3,
    categoryDailyLimit: 8,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  console.log('✅ Temizlik tamamlandı.\n');
}

// Test Kullanıcı ve Varsayılan Tercih Kurulumu
async function setupTestEnvironment(prefsOverrides = {}) {
  // 1. Profil oluştur
  await db.collection('users').doc(TESTER_USER).set({
    uid: TESTER_USER,
    username: 'AyarlarTester',
    email: 'tester_settings@test.firsatkolik.com',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // 2. Varsayılan cihaz kaydı (Her testten önce tekrar active=true yapılır)
  await db.collection('userDevices').doc(`device_${TESTER_USER}`).set({
    uid: TESTER_USER,
    deviceId: `device_${TESTER_USER}`,
    platform: 'android',
    fcmToken: `test_token_${TESTER_USER}`, // Test token'ı
    permissionStatus: 'granted',
    active: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // 3. Bildirim Tercihlerini Kur
  const defaultPrefs = {
    pushMasterEnabled: true,
    dealNotificationsEnabled: true,
    communityNotificationsEnabled: true,
    submissionStatusNotificationsEnabled: true,
    marketingNotificationsEnabled: true,
    categoryNotificationsEnabled: true,
    keywordNotificationsEnabled: true,
    quietHoursEnabled: false,
    quietHoursStart: '23:00',
    quietHoursEnd: '08:00',
    timezone: 'Europe/Istanbul',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('users').doc(TESTER_USER)
    .collection('notificationPreferences')
    .doc('main')
    .set({ ...defaultPrefs, ...prefsOverrides });
}

// ---------------------- TEST SENARYOLARI ----------------------

async function runSettingsTests() {
  try {
    await cleanupTestData();

    // ==========================================
    // SENARYO 1: Parametrik Karar Matrisi (Tüm Kanal ve Master Switch Kombinasyonları)
    // ==========================================
    console.log('🧪 [TEST 1] Parametrik Bildirim Tercihleri ve Karar Matrisi Testleri Başlatılıyor...');

    const testMatrix = [
      // A. Master Switch Kapalı, Alt Switch Açık Durumları (Bypass / Gönderim)
      {
        name: 'Master Switch Kapalı - Kategori Bildirimi (Açık)',
        prefs: { pushMasterEnabled: false, categoryNotificationsEnabled: true },
        notifData: { type: 'deal', reason: 'category', title: 'İndirim', body: 'Test' },
        expectedEligible: true,
        expectedStatus: 'failed'
      },
      {
        name: 'Master Switch Kapalı - Yazar Bildirimi (Açık)',
        prefs: { pushMasterEnabled: false, dealNotificationsEnabled: true },
        notifData: { type: 'deal', reason: 'author', title: 'Yazar Fırsatı', body: 'Test' },
        expectedEligible: true,
        expectedStatus: 'failed'
      },
      {
        name: 'Master Switch Kapalı - Topluluk Bildirimi (Açık)',
        prefs: { pushMasterEnabled: false, communityNotificationsEnabled: true },
        notifData: { type: 'comment_reply', title: 'Yorum', body: 'Test' },
        expectedEligible: true,
        expectedStatus: 'failed'
      },

      // B. Master Switch Kapalı, Alt Switch Kapalı Durumları (Master Switch nedeniyle engellenmeli)
      {
        name: 'Master Switch Kapalı - Kategori Bildirimi (Kapalı)',
        prefs: { pushMasterEnabled: false, categoryNotificationsEnabled: false },
        notifData: { type: 'deal', reason: 'category', title: 'İndirim', body: 'Test' },
        expectedEligible: false,
        expectedStatus: 'disabled_by_user_master_switch'
      },
      {
        name: 'Master Switch Kapalı - Yazar Bildirimi (Kapalı)',
        prefs: { pushMasterEnabled: false, dealNotificationsEnabled: false },
        notifData: { type: 'deal', reason: 'author', title: 'Yazar Fırsatı', body: 'Test' },
        expectedEligible: false,
        expectedStatus: 'disabled_by_user_master_switch'
      },
      {
        name: 'Master Switch Kapalı - Topluluk Bildirimi (Kapalı)',
        prefs: { pushMasterEnabled: false, communityNotificationsEnabled: false },
        notifData: { type: 'comment_reply', title: 'Yorum', body: 'Test' },
        expectedEligible: false,
        expectedStatus: 'disabled_by_user_master_switch'
      },

      // C. Master Switch Açık, Alt Switch Kapalı Durumları (Kanal bazında engellenmeli)
      {
        name: 'Kategori Switch Kapalı - Kategori Bildirimi',
        prefs: { pushMasterEnabled: true, categoryNotificationsEnabled: false },
        notifData: { type: 'deal', reason: 'category', title: 'Kategori Fırsatı', body: 'Test' },
        expectedEligible: false,
        expectedStatus: 'disabled_by_user_group_category'
      },
      {
        name: 'Anahtar Kelime Switch Kapalı - Kelime Bildirimi',
        prefs: { pushMasterEnabled: true, keywordNotificationsEnabled: false },
        notifData: { type: 'deal', reason: 'keyword', title: 'Kelime Eşleşmesi', body: 'Test' },
        expectedEligible: false,
        expectedStatus: 'disabled_by_user_group_keyword'
      },
      {
        name: 'Yazar Switch Kapalı - Yazar Bildirimi',
        prefs: { pushMasterEnabled: true, dealNotificationsEnabled: false },
        notifData: { type: 'deal', reason: 'author', title: 'Yazar Fırsatı', body: 'Test' },
        expectedEligible: false,
        expectedStatus: 'disabled_by_user_group_deal'
      },
      {
        name: 'Topluluk Switch Kapalı - Yorum Yanıt Bildirimi',
        prefs: { pushMasterEnabled: true, communityNotificationsEnabled: false },
        notifData: { type: 'comment_reply', title: 'Cevap Yazıldı', body: 'Test' },
        expectedEligible: false,
        expectedStatus: 'disabled_by_user_group_comment_reply'
      },
      {
        name: 'Paylaşım Durumu Switch Kapalı - Fırsat Onay Bildirimi',
        prefs: { pushMasterEnabled: true, submissionStatusNotificationsEnabled: false },
        notifData: { type: 'submission_status', title: 'Fırsat Durumu', body: 'Test' },
        expectedEligible: false,
        expectedStatus: 'disabled_permanently_for_submission_status'
      },
      {
        name: 'Kampanya Switch Kapalı - Kampanya Bildirimi',
        prefs: { pushMasterEnabled: true, marketingNotificationsEnabled: false },
        notifData: { type: 'marketing', title: 'Kampanya', body: 'Test' },
        expectedEligible: false,
        expectedStatus: 'disabled_by_user_group_marketing'
      },

      // D. Master Switch Açık, Alt Switch Açık Durumları (Bypass / Gönderim)
      {
        name: 'Kategori Switch Açık - Kategori Bildirimi',
        prefs: { pushMasterEnabled: true, categoryNotificationsEnabled: true },
        notifData: { type: 'deal', reason: 'category', title: 'Kategori Fırsatı', body: 'Test' },
        expectedEligible: true,
        expectedStatus: 'failed'
      },
      {
        name: 'Anahtar Kelime Switch Açık - Kelime Bildirimi',
        prefs: { pushMasterEnabled: true, keywordNotificationsEnabled: true },
        notifData: { type: 'deal', reason: 'keyword', title: 'Kelime Eşleşmesi', body: 'Test' },
        expectedEligible: true,
        expectedStatus: 'failed'
      },
      {
        name: 'Yazar Switch Açık - Yazar Bildirimi',
        prefs: { pushMasterEnabled: true, dealNotificationsEnabled: true },
        notifData: { type: 'deal', reason: 'author', title: 'Yazar Fırsatı', body: 'Test' },
        expectedEligible: true,
        expectedStatus: 'failed'
      },
      {
        name: 'Topluluk Switch Açık - Yorum Yanıt Bildirimi',
        prefs: { pushMasterEnabled: true, communityNotificationsEnabled: true },
        notifData: { type: 'comment_reply', title: 'Cevap Yazıldı', body: 'Test' },
        expectedEligible: true,
        expectedStatus: 'failed'
      },
      {
        name: 'Paylaşım Durumu Switch Açık - Fırsat Onay Bildirimi',
        prefs: { pushMasterEnabled: true, submissionStatusNotificationsEnabled: true },
        notifData: { type: 'submission_status', title: 'Fırsat Durumu', body: 'Test' },
        expectedEligible: false,
        expectedStatus: 'disabled_permanently_for_submission_status'
      },
      {
        name: 'Kampanya Switch Açık - Kampanya Bildirimi',
        prefs: { pushMasterEnabled: true, marketingNotificationsEnabled: true },
        notifData: { type: 'marketing', title: 'Kampanya', body: 'Test' },
        expectedEligible: true,
        expectedStatus: 'failed'
      }
    ];

    for (let i = 0; i < testMatrix.length; i++) {
      const tc = testMatrix[i];
      console.log(`   🔸 Alt Senaryo 1.${i + 1}: ${tc.name}...`);
      
      await setupTestEnvironment(tc.prefs);

      const notifRef = db.collection('users').doc(TESTER_USER).collection('notifications').doc(`test_matrix_notif_${i}`);
      await notifRef.set({
        ...tc.notifData,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      const doc = await waitForDocUpdate(notifRef);
      const data = doc.data();

      if (data.pushEligible === tc.expectedEligible && data.pushStatus === tc.expectedStatus) {
        const resultMsg = tc.expectedEligible 
          ? `filtreleri başarıyla aşarak gönderime ulaştı (${data.pushStatus})` 
          : `gönderimi başarıyla engelledi (${data.pushStatus})`;
        console.log(`      🎉 [BAŞARILI] ${tc.name} test edildi, ${resultMsg}!`);
      } else {
        console.error(`      ❌ [BAŞARISIZ] Beklenen (eligible: ${tc.expectedEligible}, status: ${tc.expectedStatus}), Alınan:`, data);
      }
    }
    console.log('--------------------------------------------------\n');


    // ==========================================
    // SENARYO 2: Sessiz Saatler Aktifken Fırsat Bildirimi Engellenmesi
    // ==========================================
    console.log('🧪 [TEST 2] Sessiz Saatler Filtresi Senaryosu...');
    
    // Şu anki yerel saati hesaplayıp, sessiz saatler kapsamına alalım
    const userTime = new Date().toLocaleTimeString('tr-TR', { timeZone: 'Europe/Istanbul', hour12: false });
    const currentHour = parseInt(userTime.substring(0, 2));
    
    // Sessiz saati şu anki saatten 1 saat önce başlatıp 1 saat sonra bitirelim
    const startHour = (currentHour - 1 + 24) % 24;
    const endHour = (currentHour + 1) % 24;
    const quietStart = `${String(startHour).padStart(2, '0')}:00`;
    const quietEnd = `${String(endHour).padStart(2, '0')}:00`;

    console.log(`   🔸 Şu anki yerel saat: ${userTime.substring(0, 5)}`);
    console.log(`   🔸 Sessiz saat aralığı kuruluyor: ${quietStart} - ${quietEnd}`);

    await setupTestEnvironment({
      pushMasterEnabled: true,
      quietHoursEnabled: true,
      quietHoursStart: quietStart,
      quietHoursEnd: quietEnd,
      timezone: 'Europe/Istanbul'
    });

    // Fırsat (deal) bildirimi ekle (Sessiz saatlerden ETKİLENİR)
    const notif3Ref = db.collection('users').doc(TESTER_USER).collection('notifications').doc('test_notif_3');
    await notif3Ref.set({
      type: 'deal',
      title: 'İndirim Fırsatı 3',
      body: 'Sessiz saatler testi için',
      reason: 'category',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   ⏳ Tetikleyicinin çalışması bekleniyor (polling)...');
    const doc3 = await waitForDocUpdate(notif3Ref);
    const data3 = doc3.data();
    console.log('      Filtre Sonucu - pushEligible:', data3.pushEligible);
    console.log('      Filtre Sonucu - pushStatus:', data3.pushStatus);

    if (data3.pushEligible === false && data3.pushStatus === 'skipped_quiet_hours') {
      console.log('   🎉 [BAŞARILI] Sessiz saatlerde indirim push bildirimi başarıyla atlandı!');
    } else {
      console.error('   ❌ [BAŞARISIZ] Hatalı durum:', data3);
    }
    console.log('--------------------------------------------------\n');


    // ==========================================
    // SENARYO 3: Sessiz Saatlerde Yorum Yanıtının Muaf Tutulması
    // ==========================================
    console.log('🧪 [TEST 3] Sessiz Saatlerde Yorum Yanıtının Muafiyeti Senaryosu...');
    // Sessiz saatler hâlâ aktif durumda kurulmuş durumda.
    // Ancak Yorum Yanıtı (comment_reply) acil/bireysel bir bildirim olduğu için sessiz saatlerden muaf olmalıdır!

    const notif4Ref = db.collection('users').doc(TESTER_USER).collection('notifications').doc('test_notif_4');
    await notif4Ref.set({
      type: 'comment_reply',
      title: 'Avci123 yorumunuza cevap verdi',
      body: 'Bu fiyata kesinlikle değer',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   ⏳ Tetikleyicinin çalışması bekleniyor (polling)...');
    const doc4 = await waitForDocUpdate(notif4Ref);
    const data4 = doc4.data();
    console.log('      Filtre Sonucu - pushEligible:', data4.pushEligible);
    console.log('      Filtre Sonucu - pushStatus:', data4.pushStatus);

    if (data4.pushStatus !== 'skipped_quiet_hours') {
      console.log('   🎉 [BAŞARILI] Yorum yanıt bildirimi sessiz saatlerden muaf tutularak işlendi!');
    } else {
      console.error('   ❌ [BAŞARISIZ] Yorum yanıt bildirimi sessiz saate takıldı!', data4);
    }
    console.log('--------------------------------------------------\n');


    // ==========================================
    // SENARYO 4: Kategori Hız Limitleri (Rate Limiting)
    // ==========================================
    console.log('🧪 [TEST 4] Kategori Hız Limitleri Senaryosu...');
    await setupTestEnvironment({ pushMasterEnabled: true });

    // Sistem limitini 1 saatte max 1 bildirim yapalım
    await db.collection('systemConfig').doc('notifications').set({
      enabled: true,
      categoryHourlyLimit: 1,
      categoryDailyLimit: 5,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   🔸 Kategori saatlik bildirim limiti 1 olarak ayarlandı.');

    // 1. Zaten başarıyla 'sent' edilmiş 1 adet kategori bildirimi simüle edelim
    const priorNotifRef = db.collection('users').doc(TESTER_USER).collection('notifications').doc('prior_notif');
    await priorNotifRef.set({
      type: 'deal',
      title: 'Önceden Gönderilmiş Fırsat',
      body: 'Limit dolduran bildirim',
      reason: 'category',
      pushEligible: true,
      pushStatus: 'sent',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   ⏳ Öncelikli bildirim yazıldı. Tetikleyicinin tamamlanması için 3 saniye bekleniyor...');
    await sleep(3000);

    console.log('   🔧 Bildirim durumu ve cihaz kaydı zorla sıfırlanıyor (sent & active: true)...');
    await priorNotifRef.update({ pushStatus: 'sent' });
    await db.collection('userDevices').doc(`device_${TESTER_USER}`).update({ active: true });

    // 2. Şimdi limit aşacak 2. bir kategori bildirimi tetikleyelim
    const notif5Ref = db.collection('users').doc(TESTER_USER).collection('notifications').doc('test_notif_5');
    await notif5Ref.set({
      type: 'deal',
      title: 'İndirim Fırsatı 5',
      body: 'Saatlik limiti aşacak olan bildirim',
      reason: 'category',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   ⏳ Tetikleyicinin çalışması bekleniyor (polling)...');
    const doc5 = await waitForDocUpdate(notif5Ref);
    const data5 = doc5.data();
    console.log('      Filtre Sonucu - pushEligible:', data5.pushEligible);
    console.log('      Filtre Sonucu - pushStatus:', data5.pushStatus);

    if (data5.pushEligible === false && data5.pushStatus === 'skipped_category_limit') {
      console.log('   🎉 [BAŞARILI] Hız limiti aşıldığından dolayı push başarıyla engellendi!');
    } else {
      console.error('   ❌ [BAŞARISIZ] Hatalı durum:', data5);
    }
    console.log('--------------------------------------------------\n');


    // ==========================================
    // SENARYO 5: Aktif Cihaz Yok (no_active_devices)
    // ==========================================
    console.log('🧪 [TEST 5] Aktif Cihaz Bulunmama Senaryosu...');
    
    // Hız limitlerini varsayılana çekelim ki limite takılmasın
    await db.collection('systemConfig').doc('notifications').set({
      enabled: true,
      categoryHourlyLimit: 3,
      categoryDailyLimit: 8,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await setupTestEnvironment({ pushMasterEnabled: true });

    // TESTER_USER'ın cihazlarını pasif yapalım
    const devicesSnap = await db.collection('userDevices').where('uid', '==', TESTER_USER).get();
    const batchDevs = db.batch();
    devicesSnap.forEach(doc => {
      batchDevs.update(doc.ref, { active: false });
    });
    await batchDevs.commit();
    console.log('   🔸 Cihaz kaydı active=false olarak güncellendi.');

    const notif6Ref = db.collection('users').doc(TESTER_USER).collection('notifications').doc('test_notif_6');
    await notif6Ref.set({
      type: 'deal',
      title: 'İndirim Fırsatı 6',
      body: 'Cihaz kontrolü testi için',
      reason: 'category',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   ⏳ Tetikleyicinin çalışması bekleniyor (polling)...');
    const doc6 = await waitForDocUpdate(notif6Ref);
    const data6 = doc6.data();
    console.log('      Filtre Sonucu - pushEligible:', data6.pushEligible);
    console.log('      Filtre Sonucu - pushStatus:', data6.pushStatus);

    if (data6.pushEligible === false && data6.pushStatus === 'no_active_devices') {
      console.log('   🎉 [BAŞARILI] Aktif cihaz bulunamadığı tespit edilerek atlandı!');
    } else {
      console.error('   ❌ [BAŞARISIZ] Hatalı durum:', data6);
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

runSettingsTests();
