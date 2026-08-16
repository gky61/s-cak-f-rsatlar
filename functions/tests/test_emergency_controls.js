/**
 * FırsatKolik — Acil Durum Kontrolleri Entegrasyon Testi
 * 
 * Bu betik, admin panelindeki "Acil Durum Kontrolleri" altındaki ayarların (paylaşım, yorum, bot ve global push bildirimleri)
 * veritabanı durumlarını ve bunların backend tetikleyicileri üzerindeki etkilerini test eder.
 * 
 * Çalıştırmak için: node functions/tests/test_emergency_controls.js
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

// Test ID'leri
const TEST_USER_ID = 'test_emergency_user_id';
const NOTIF_ID_1 = 'test_emergency_push_notif_disabled';
const NOTIF_ID_2 = 'test_emergency_push_notif_enabled';

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

// Global push bildirim tetikleyicisini izlemek için genel bekleme
async function waitForDocUpdate(docRef, timeoutMs = 15000, intervalMs = 1000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const doc = await docRef.get();
    if (doc.exists && doc.data().pushStatus !== 'pending') {
      return doc.data();
    }
    await sleep(intervalMs);
  }
  return null;
}

async function runTests() {
  console.log('🧪 Acil Durum Kontrolleri Entegrasyon Testleri Başlatılıyor...\n');

  // Orijinal durumları sakla (Test sonunda geri yüklemek için)
  let originalAppConfig = {};
  let originalBotConfig = {};
  let originalNotificationsConfig = {};

  try {
    // 1. Mevcut ayarları yedekle
    const appSnap = await db.collection('settings').doc('app').get();
    if (appSnap.exists) originalAppConfig = appSnap.data();

    const botSnap = await db.collection('settings').doc('telegramBot').get();
    if (botSnap.exists) originalBotConfig = botSnap.data();

    const notifSnap = await db.collection('systemConfig').doc('notifications').get();
    if (notifSnap.exists) originalNotificationsConfig = notifSnap.data();

    console.log('📦 Mevcut sistem ayarları başarıyla yedeklendi.');

    // Temizlik
    await db.collection('users').doc(TEST_USER_ID).collection('notifications').doc(NOTIF_ID_1).delete().catch(() => {});
    await db.collection('users').doc(TEST_USER_ID).collection('notifications').doc(NOTIF_ID_2).delete().catch(() => {});
    await db.collection('users').doc(TEST_USER_ID).delete().catch(() => {});

    // Test kullanıcısı oluştur (Bildirim testi için gerekli)
    await db.collection('users').doc(TEST_USER_ID).set({
      username: 'EmergencyTester',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // ========================================================
    // TEST 1: Fırsat Paylaşımı Engelleme (dealSharingEnabled)
    // ========================================================
    console.log('\n--- TEST 1: Fırsat Paylaşımı Engelleme (`dealSharingEnabled`) ---');
    
    // Kapat
    await db.collection('settings').doc('app').set({ dealSharingEnabled: false }, { merge: true });
    let doc = await db.collection('settings').doc('app').get();
    console.log('   ❌ dealSharingEnabled = false olarak ayarlandı.');
    if (doc.data().dealSharingEnabled !== false) throw new Error('dealSharingEnabled kapatılamadı!');
    console.log('   🎉 [BAŞARILI] Fırsat paylaşımı veritabanında başarıyla kapatıldı.');

    // Aç
    await db.collection('settings').doc('app').set({ dealSharingEnabled: true }, { merge: true });
    doc = await db.collection('settings').doc('app').get();
    console.log('   ✅ dealSharingEnabled = true olarak ayarlandı.');
    if (doc.data().dealSharingEnabled !== true) throw new Error('dealSharingEnabled açılamadı!');
    console.log('   🎉 [BAŞARILI] Fırsat paylaşımı veritabanında başarıyla açıldı.');

    // ========================================================
    // TEST 2: Yorum Yazmayı Durdurma (commentSharingEnabled)
    // ========================================================
    console.log('\n--- TEST 2: Yorum Yazmayı Durdurma (`commentSharingEnabled`) ---');
    
    // Kapat
    await db.collection('settings').doc('app').set({ commentSharingEnabled: false }, { merge: true });
    doc = await db.collection('settings').doc('app').get();
    console.log('   ❌ commentSharingEnabled = false olarak ayarlandı.');
    if (doc.data().commentSharingEnabled !== false) throw new Error('commentSharingEnabled kapatılamadı!');
    console.log('   🎉 [BAŞARILI] Yorum yazma veritabanında başarıyla kapatıldı.');

    // Aç
    await db.collection('settings').doc('app').set({ commentSharingEnabled: true }, { merge: true });
    doc = await db.collection('settings').doc('app').get();
    console.log('   ✅ commentSharingEnabled = true olarak ayarlandı.');
    if (doc.data().commentSharingEnabled !== true) throw new Error('commentSharingEnabled açılamadı!');
    console.log('   🎉 [BAŞARILI] Yorum yazma veritabanında başarıyla açıldı.');

    // ========================================================
    // TEST 3: Telegram Botu Çalıştırma (botEnabled)
    // ========================================================
    console.log('\n--- TEST 3: Telegram Botu Çalıştırma (`botEnabled`) ---');
    
    // Kapat
    await db.collection('settings').doc('telegramBot').set({ botEnabled: false }, { merge: true });
    doc = await db.collection('settings').doc('telegramBot').get();
    console.log('   ❌ botEnabled = false olarak ayarlandı.');
    if (doc.data().botEnabled !== false) throw new Error('botEnabled kapatılamadı!');
    console.log('   🎉 [BAŞARILI] Telegram Botu veritabanında başarıyla kapatıldı.');

    // Aç
    await db.collection('settings').doc('telegramBot').set({ botEnabled: true }, { merge: true });
    doc = await db.collection('settings').doc('telegramBot').get();
    console.log('   ✅ botEnabled = true olarak ayarlandı.');
    if (doc.data().botEnabled !== true) throw new Error('botEnabled açılamadı!');
    console.log('   🎉 [BAŞARILI] Telegram Botu veritabanında başarıyla açıldı.');

    // ========================================================
    // TEST 4: Global Push Bildirim Durdurma (enabled)
    // ========================================================
    console.log('\n--- TEST 4: Global Push Bildirim Engeli Tetikleyici Kontrolü ---');

    // 4.1. Global push bildirimlerini kapat
    console.log('   ❌ Global push bildirim anahtarı kapatılıyor...');
    await db.collection('systemConfig').doc('notifications').set({ enabled: false }, { merge: true });
    
    // Test bildirim belgesi oluştur (onNotificationCreated Cloud Function tetiklenecek)
    const notifRef1 = db.collection('users').doc(TEST_USER_ID).collection('notifications').doc(NOTIF_ID_1);
    await notifRef1.set({
      type: 'deal',
      reason: 'category',
      title: 'Acil Durum Test Bildirimi',
      body: 'Bu bildirim push engeline takılmalı.',
      pushEligible: true,
      pushStatus: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   ⏳ Bildirim belgesi oluşturuldu. Cloud Function tetikleyicisi bekleniyor...');

    // Bekle
    const triggeredNotif1 = await waitForFieldValue(notifRef1, 'pushStatus', 'disabled_by_system_master_switch');
    if (triggeredNotif1) {
      console.log('   🎉 [BAŞARILI] Cloud Function global engeli algıladı ve push gönderimini durdurdu!');
      console.log(`      └─ pushEligible: ${triggeredNotif1.pushEligible}, pushStatus: '${triggeredNotif1.pushStatus}'`);
    } else {
      const currentSnap = await notifRef1.get();
      throw new Error(`Global push engeli çalışmadı! Alınan durum: ${JSON.stringify(currentSnap.data())}`);
    }

    // 4.2. Global push bildirimlerini tekrar aç
    console.log('   ✅ Global push bildirim anahtarı açılıyor...');
    await db.collection('systemConfig').doc('notifications').set({ enabled: true }, { merge: true });

    // İkinci test bildirim belgesini oluştur
    const notifRef2 = db.collection('users').doc(TEST_USER_ID).collection('notifications').doc(NOTIF_ID_2);
    await notifRef2.set({
      type: 'deal',
      reason: 'category',
      title: 'Acil Durum Test Bildirimi 2',
      body: 'Bu bildirim push engeline takılmamalı.',
      pushEligible: true,
      pushStatus: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('   ⏳ İkinci bildirim belgesi oluşturuldu. Cloud Function bekleniyor...');

    // Tetikleyicinin çalışmasını bekle
    const triggeredNotif2 = await waitForDocUpdate(notifRef2);
    if (triggeredNotif2 && triggeredNotif2.pushStatus !== 'disabled_by_system_master_switch') {
      console.log('   🎉 [BAŞARILI] Cloud Function global engeli aşarak bildirimi işledi!');
      console.log(`      └─ pushStatus: '${triggeredNotif2.pushStatus}'`);
    } else {
      const currentSnap = await notifRef2.get();
      throw new Error(`Global push engeli hatalı şekilde devreye girdi! Alınan durum: ${JSON.stringify(currentSnap.data())}`);
    }

    // ========================================================
    // TEST 5: Admin Onay Bypass (dealApprovalRequired)
    // ========================================================
    console.log('\n--- TEST 5: Admin Onay Bypass (`dealApprovalRequired`) ---');

    // Onay bypass'ı aktif et (Admin Onayı Kapatılsın -> dealApprovalRequired = false)
    console.log('   🚫 Admin onayı devre dışı bırakılıyor (dealApprovalRequired = false)...');
    await db.collection('settings').doc('app').set({ dealApprovalRequired: false }, { merge: true });

    // Simüle edilen fırsat ekleme işlemi (Onay gerekmediği için isApproved true olmalı)
    let appSettings = await db.collection('settings').doc('app').get();
    let approvalRequired = appSettings.data().dealApprovalRequired !== false;
    let computedApproved = !approvalRequired;
    console.log(`      └─ Ayar Değeri: dealApprovalRequired = ${approvalRequired}`);
    console.log(`      └─ Simüle Edilen Fırsat Durumu: isApproved = ${computedApproved}`);
    if (computedApproved !== true) throw new Error('Bypass aktifken fırsat onaylı olarak işaretlenmedi!');
    console.log('   🎉 [BAŞARILI] Onay bypassı açıkken fırsat doğrudan onaylı olarak işaretleniyor.');

    // Onay gereksinimini tekrar aç (dealApprovalRequired = true)
    console.log('   ✅ Admin onayı tekrar aktifleştiriliyor (dealApprovalRequired = true)...');
    await db.collection('settings').doc('app').set({ dealApprovalRequired: true }, { merge: true });
    
    appSettings = await db.collection('settings').doc('app').get();
    approvalRequired = appSettings.data().dealApprovalRequired !== false;
    computedApproved = !approvalRequired;
    console.log(`      └─ Ayar Değeri: dealApprovalRequired = ${approvalRequired}`);
    console.log(`      └─ Simüle Edilen Fırsat Durumu: isApproved = ${computedApproved}`);
    if (computedApproved !== false) throw new Error('Onay gerekirken fırsat onaysız olarak işaretlenmedi!');
    console.log('   🎉 [BAŞARILI] Onay gereksinimi aktifken fırsat onay bekliyor olarak işaretleniyor.');

    // ========================================================
    // TEST 6: Botkolik Mesajlaşma Kontrolü (botkolikChatEnabled)
    // ========================================================
    console.log('\n--- TEST 6: Botkolik Mesajlaşma Kontrolü (`botkolikChatEnabled`) ---');

    // Kapat
    await db.collection('settings').doc('app').set({ botkolikChatEnabled: false }, { merge: true });
    doc = await db.collection('settings').doc('app').get();
    console.log('   ❌ botkolikChatEnabled = false olarak ayarlandı.');
    if (doc.data().botkolikChatEnabled !== false) throw new Error('botkolikChatEnabled kapatılamadı!');
    console.log('   🎉 [BAŞARILI] Botkolik mesajlaşması veritabanında başarıyla kapatıldı.');

    // Aç
    await db.collection('settings').doc('app').set({ botkolikChatEnabled: true }, { merge: true });
    doc = await db.collection('settings').doc('app').get();
    console.log('   ✅ botkolikChatEnabled = true olarak ayarlandı.');
    if (doc.data().botkolikChatEnabled !== true) throw new Error('botkolikChatEnabled açılamadı!');
    console.log('   🎉 [BAŞARILI] Botkolik mesajlaşması veritabanında başarıyla açıldı.');

    console.log('\n🌟 TÜM MEVCUT ACİL DURUM KONTROLLERİ VE YENİ BOTKOLİK MESAJLAŞMA AYARI BAŞARIYLA DOĞRULANDI!');

  } catch (err) {
    console.error('\n❌ TEST BAŞARISIZ:', err.message);
    process.exit(1);
  } finally {
    console.log('\n🔄 Orijinal sistem ayarları geri yükleniyor...');
    
    // Geri yükleme
    if (Object.keys(originalAppConfig).length > 0) {
      await db.collection('settings').doc('app').set(originalAppConfig);
    }
    if (originalBotConfig.hasOwnProperty('botEnabled')) {
      await db.collection('settings').doc('telegramBot').set(originalBotConfig);
    }
    if (originalNotificationsConfig.hasOwnProperty('enabled')) {
      await db.collection('systemConfig').doc('notifications').set(originalNotificationsConfig);
    }

    // Temizlik
    await db.collection('users').doc(TEST_USER_ID).collection('notifications').doc(NOTIF_ID_1).delete().catch(() => {});
    await db.collection('users').doc(TEST_USER_ID).collection('notifications').doc(NOTIF_ID_2).delete().catch(() => {});
    await db.collection('users').doc(TEST_USER_ID).delete().catch(() => {});

    console.log('✅ Temizlik ve geri yükleme tamamlandı.');
    process.exit(0);
  }
}

runTests();
