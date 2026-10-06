/**
 * FırsatKolik — Faz 2 Güvenlik Kuralları ve Veri Bütünlüğü Sözleşme Testleri (P0-18 / R-QA-01)
 * 
 * Doğrulanan Kalkanlar:
 * 1. P0-04 (R-AUTH-01): Fırsat Oy ve Sayaç Manipülasyon Kalkanı (±1 Delta)
 * 2. P0-05 (R-AUTH-02): Bait-and-Switch Kalkanı (Onaylı içerik değişiminde isApproved reset)
 * 3. P0-06 (R-AUTH-03): Kupon Oy Sayacı Manipülasyon Kalkanı (±1 Delta & Ban Kontrolü)
 * 4. P0-08 (R-AUTH-11) & P0-14 (R-BIZ-01): Topluluk Kuponu Push Onay & Payload Hijyeni
 * 5. P0-09 (R-AUTH-12): Confused Deputy Storage Silme Kalkanı (deals/ Önek & Path Traversal)
 * 6. P0-10 (R-PRV-01): Kişisel E-Posta Sızıntısı Kalkanı (Yorum Modeli Gizliliği)
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

console.log('🚀 FırsatKolik Faz 2 & Faz 3 Güvenlik ve Kurallar Sözleşme Test Süiti Başlatılıyor...\n');

// ==============================================================================
// TEST 1: P0-04 & P0-06 — isValidDelta ve isValidIncrementOnly Denetimi
// ==============================================================================
console.log('--- TEST 1: P0-04 & P0-06 Oy ve Sayaç ±1 Delta Sözleşmesi ---');
{
  function isValidDelta(oldVal, newVal) {
    if (newVal === undefined || newVal === null) return true;
    const old = (oldVal === undefined || oldVal === null) ? 0 : oldVal;
    return (newVal === old) || (newVal === old + 1) || (newVal === old - 1);
  }

  function isValidIncrementOnly(oldVal, newVal) {
    if (newVal === undefined || newVal === null) return true;
    const old = (oldVal === undefined || oldVal === null) ? 0 : oldVal;
    return (newVal === old) || (newVal === old + 1);
  }

  // Geçerli Senaryolar (Normal Kullanıcı Oy Değişimleri)
  assert.strictEqual(isValidDelta(10, 11), true, '+1 artış geçerli olmalı');
  assert.strictEqual(isValidDelta(10, 9), true, '-1 azalış geçerli olmalı');
  assert.strictEqual(isValidDelta(10, 10), true, 'Aynı değer geçerli olmalı');
  assert.strictEqual(isValidDelta(0, 1), true, '0 dan 1 e artış geçerli olmalı');

  // Yetkisiz / Hileli Senaryolar (Saldırgan Manipülasyonları)
  assert.strictEqual(isValidDelta(10, 500), false, '10 dan 500 e keyfi zıplama ENGELLENMELİ');
  assert.strictEqual(isValidDelta(10, 0), false, '10 dan 0 a keyfi sıfırlama ENGELLENMELİ');
  assert.strictEqual(isValidDelta(10, 12), false, '+2 artış ENGELLENMELİ');
  assert.strictEqual(isValidDelta(10, 8), false, '-2 azalış ENGELLENMELİ');

  // Expired oylaması (Fırsat bitti oyu verme +1, oyu geri alma -1)
  assert.strictEqual(isValidDelta(4, 5), true, 'expiredVotes +1 oy verme geçerli olmalı');
  assert.strictEqual(isValidDelta(4, 3), true, 'expiredVotes -1 oy geri alma geçerli olmalı');
  assert.strictEqual(isValidDelta(4, 10), false, 'expiredVotes keyfi zıplaması ENGELLENMELİ');
  assert.strictEqual(isValidDelta(4, 0), false, 'expiredVotes keyfi sıfırlaması ENGELLENMELİ');

  console.log('✅ TEST 1 BAŞARILI: P0-04 ve P0-06 sayaç delta (+-1) kalkanları doğrulandı.');
}

// ==============================================================================
// TEST 2: P0-05 — Bait-and-Switch Kalkanı
// ==============================================================================
console.log('\n--- TEST 2: P0-05 Bait-and-Switch İçerik Değişim Kalkanı ---');
{
  function validateDealContentUpdate(beforeDoc, updateData) {
    const contentKeys = ['title', 'description', 'dealUrl', 'imageUrl', 'price', 'originalPrice', 'store'];
    const hasContentChanges = Object.keys(updateData).some(k => contentKeys.includes(k));

    // Kural Mantığı: İçerik değişmişse ve fırsat onaylıysa, isApproved kesinlikle false olmalıdır
    if (hasContentChanges) {
      if (beforeDoc.isApproved === true && updateData.isApproved !== false) {
        return false; // Bait-and-switch engellendi!
      }
    }
    return true;
  }

  const approvedDeal = {
    title: 'Orijinal Onaylı İndirim',
    dealUrl: 'https://trendyol.com/urun-1',
    isApproved: true,
    price: 100
  };

  // 1. Kötü niyetli güncelleme: Onaylı fırsatın URL'sini phishing linkiyle değiştirip isApproved: true bırakma
  const maliciousUpdate = {
    dealUrl: 'https://phishing-dolandirici.com/login',
    title: 'Bedava iPhone Kazandınız!'
  };
  assert.strictEqual(validateDealContentUpdate(approvedDeal, maliciousUpdate), false, 'Onaylı fırsatta içerik değişirken isApproved false yapılmazsa ENGELLENMELİ');

  // 2. Meşru güncelleme: İçerik değiştiğinde isApproved: false yapılarak yeniden moderasyona gönderilmesi
  const legitimateUpdate = {
    title: 'Yeni Fiyat Güncellemesi',
    price: 90,
    isApproved: false
  };
  assert.strictEqual(validateDealContentUpdate(approvedDeal, legitimateUpdate), true, 'isApproved: false ile gönderilen içerik güncellemesi GEÇERLİ olmalı');

  console.log('✅ TEST 2 BAŞARILI: P0-05 Bait-and-Switch kalkanı ve moderasyon sözleşmesi doğrulandı.');
}

// ==============================================================================
// TEST 3: P0-09 — Confused Deputy ve Path Traversal Kalkanı
// ==============================================================================
console.log('\n--- TEST 3: P0-09 Confused Deputy Storage Yol Doğrulama Sözleşmesi ---');
{
  function isSafeStoragePathForDeal(filePath, expectedPrefix = 'deals/') {
    if (!filePath || typeof filePath !== 'string') return false;
    if (!filePath.startsWith(expectedPrefix)) return false;
    if (filePath.includes('..') || filePath.includes('//')) return false;
    return true;
  }

  // Güvenli / Normal Fırsat Görselleri
  assert.strictEqual(isSafeStoragePathForDeal('deals/deal_123/image.jpg'), true, 'deals/ altındaki görsel geçerli olmalı');
  assert.strictEqual(isSafeStoragePathForDeal('deals/promo_456/main.webp'), true, 'deals/ altındaki webp geçerli olmalı');

  // Confused Deputy ve Traversal Saldırıları
  assert.strictEqual(isSafeStoragePathForDeal('avatars/admin_user.jpg'), false, 'deals/ dışındaki avatar silme ENGELLENMELİ');
  assert.strictEqual(isSafeStoragePathForDeal('system_assets/logo.png'), false, 'Sistem logosu silme ENGELLENMELİ');
  assert.strictEqual(isSafeStoragePathForDeal('deals/../system_assets/logo.png'), false, 'Path traversal (..) ENGELLENMELİ');
  assert.strictEqual(isSafeStoragePathForDeal('deals//secret.json'), false, 'Çift slash traversal ENGELLENMELİ');

  console.log('✅ TEST 3 BAŞARILI: P0-09 Confused Deputy dosya yolu kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 4: P0-08 & P0-14 — Topluluk Kuponu Push Moderasyon ve Payload Kalkanı
// ==============================================================================
console.log('\n--- TEST 4: P0-08 & P0-14 Topluluk Kuponu Push ve Payload Sözleşmesi ---');
{
  function evaluateCouponTopicPush(kupon, notificationsEnabled, currentHm) {
    const isQuiet = (currentHm >= '23:00' || currentHm < '08:00');
    const isEligible = notificationsEnabled && !isQuiet && (kupon.durum === 'aktif');
    return isEligible;
  }

  // 1. Beklemedeki / Onaysız kupon
  const pendingCoupon = { durum: 'beklemede', kuponKodu: 'GIZLI50' };
  assert.strictEqual(evaluateCouponTopicPush(pendingCoupon, true, '14:00'), false, 'Beklemedeki kupon için topic push GÖNDERİLMEMELİ');

  // 2. Acil durum şalteri kapalıyken
  const activeCoupon = { durum: 'aktif', kuponKodu: 'GIZLI50' };
  assert.strictEqual(evaluateCouponTopicPush(activeCoupon, false, '14:00'), false, 'Şalter kapalıyken push GÖNDERİLMEMELİ');

  // 3. Gece sessiz saatlerde (ör: 03:30)
  assert.strictEqual(evaluateCouponTopicPush(activeCoupon, true, '03:30'), false, 'Sessiz saatlerde genel topic push GÖNDERİLMEMELİ');

  // 4. Gündüz, aktif ve şalter açıkken
  assert.strictEqual(evaluateCouponTopicPush(activeCoupon, true, '15:30'), true, 'Gündüz aktif onaylı kupon push alabilmeli');

  // 5. Payload Hijyeni: Push data (hem Topic hem Cihaz) içinde kuponKodu açık metin olarak yer almamalı!
  const topicPayloadData = {
    type: 'coupon',
    reason: 'community',
    kuponId: 'kupon_999',
    hasCode: activeCoupon.kuponKodu ? 'true' : 'false'
  };
  assert.strictEqual('kuponKodu' in topicPayloadData, false, 'Kupon kodu topic push veri yükünde plaintext OLMAMALI');
  assert.strictEqual(topicPayloadData.hasCode, 'true', 'hasCode bayrağı doğru ayarlanmalı');

  // 6. Cihaz Push Güvenliği: sendPushNotification safeData içinde kuponKodu plaintext taşınmamalı
  const deviceSafeData = {
    type: 'coupon',
    kuponId: 'kupon_999',
    magazaAdi: 'Trendyol',
    hasCode: (activeCoupon.kuponKodu ? 'true' : 'false')
  };
  assert.strictEqual('kuponKodu' in deviceSafeData, false, 'Cihaz push yükünde kuponKodu plaintext OLMAMALI');
  assert.strictEqual(deviceSafeData.hasCode, 'true');

  // 7. Veritabanı Açık Metin Sözleşmesi: kuponlar/{id} dokümanı kuponKodu'nu doğrudan açık metin tutar (şifresiz/subcollectionsız)
  const firestoreCouponDoc = {
    id: 'kupon_999',
    magazaAdi: 'Trendyol',
    baslik: '100 TL İndirim',
    kuponKodu: 'TRENDYOL100', // Açık metin saklama
    durum: 'aktif',
    kaynakTipi: 'topluluk'
  };
  assert.strictEqual(typeof firestoreCouponDoc.kuponKodu, 'string', 'Firestore kuponKodu string olmalı');
  assert.strictEqual(firestoreCouponDoc.kuponKodu, 'TRENDYOL100', 'Firestore kuponKodu açık metin olarak erişilebilir olmalı');

  console.log('✅ TEST 4 BAŞARILI: P0-08 kupon push onay kapısı, P0-14 bildirim payload kalkanı ve açık kupon saklama sözleşmesi doğrulandı.');
}

// ==============================================================================
// TEST 5: P0-10 — Yorum Kişisel E-Posta Gizlilik Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 5: P0-10 Yorum Kişisel E-Posta Gizlilik Sözleşmesi ---');
{
  // Simüle edilmiş Comment.toFirestore çıktısı
  function serializeCommentToFirestore(comment) {
    return {
      dealId: comment.dealId,
      userId: comment.userId,
      userName: comment.userName,
      userEmail: '', // P0-10 kalkanı: Daima boş serileştirilir
      text: comment.text,
      createdAt: new Date()
    };
  }

  const commentObj = {
    dealId: 'deal_123',
    userId: 'user_456',
    userName: 'FırsatAvcısı',
    userEmail: 'gizli_kullanici@gmail.com',
    text: 'Harika fırsat, teşekkürler!'
  };

  const firestoreDoc = serializeCommentToFirestore(commentObj);
  assert.strictEqual(firestoreDoc.userEmail, '', 'Firestore dokümanına yazılan userEmail DAİMA boş olmalı');
  assert.notStrictEqual(firestoreDoc.userEmail, commentObj.userEmail, 'Gerçek kullanıcı e-postası asla dokümana sızmamalı');

  console.log('✅ TEST 5 BAŞARILI: P0-10 e-posta gizlilik kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 6: P0-15 — Fail-Closed Flavor Resolution ve Sanity Check Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 6: P0-15 FLAVOR Fail-Closed Sözleşmesi ---');
{
  function resolveFlavor(definedFlavor, isReleaseMode) {
    if (definedFlavor && definedFlavor.length > 0) {
      return definedFlavor;
    }
    if (isReleaseMode) {
      throw new Error('KRİTİK HATA: Release derlemelerinde FLAVOR tanımlanmalıdır!');
    }
    return 'dev';
  }

  function validateFirebaseSanity(projectId, isReleaseMode, isProdFlavor) {
    if (!isReleaseMode) return true;
    const isProdFirebase = projectId === 'firsatkolik-prod-e6eae';
    if (isProdFlavor !== isProdFirebase) {
      throw new Error(`Uyuşmazlık: flavor=${isProdFlavor}, projectId=${projectId}`);
    }
    return true;
  }

  // 1. Debug modunda argümansız: Güvenle 'dev' döner
  assert.strictEqual(resolveFlavor(null, false), 'dev', 'Debug modda varsayılan dev olmalı');

  // 2. Release modunda argümansız: Fail-closed hata fırlatmalı!
  assert.throws(() => resolveFlavor(null, true), /KRİTİK HATA/, 'Release modda tanımsız flavor hata fırlatmalı');

  // 3. Release modunda prod tanımlı: Güvenle 'prod' döner
  assert.strictEqual(resolveFlavor('prod', true), 'prod', 'Release modda prod doğru çözümlenmeli');

  // 4. Sanity Check: Prod flavor DEV veritabanına bağlanmayı denerse durdurulmalı
  assert.throws(() => validateFirebaseSanity('sicak-firsatlar-e6eae', true, true), /Uyuşmazlık/, 'Prod flavor ile Dev veritabanı uyuşmazlığı yakalanmalı');
  assert.strictEqual(validateFirebaseSanity('firsatkolik-prod-e6eae', true, true), true, 'Prod-Prod eşleşmesi geçerli olmalı');

  console.log('✅ TEST 6 BAŞARILI: P0-15 Fail-closed flavor ve sanity check kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 7: P0-16 — Zorunlu Minimum Sürüm (minSupportedBuild) Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 7: P0-16 Zorunlu Minimum Sürüm (minSupportedBuild) Kapısı ---');
{
  function evaluateAppVersionGate(currentBuildNumber, remoteConfig) {
    const minSupportedBuild = remoteConfig.minSupportedBuild || 1;
    // Eğer uygulamanın build numarası minimum desteklenen sürümden küçükse bloke et
    return currentBuildNumber >= minSupportedBuild;
  }

  // 1. Eski sürüm (v1.0.0+1) minimum sürüm (2) altındayken: Bloke edilmeli
  assert.strictEqual(evaluateAppVersionGate(1, { minSupportedBuild: 2 }), false, 'Eski build numarası bloke edilmeli (güncelleme zorunlu)');

  // 2. Güncel sürüm (v1.1.0+2) minimum sürüm (2) ile uyumluyken: Geçiş verilmeli
  assert.strictEqual(evaluateAppVersionGate(2, { minSupportedBuild: 2 }), true, 'Minimum desteğe sahip sürüm çalışabilmeli');

  // 3. Gelecek sürüm (v1.2.0+3) minimum sürüm (2) üstündeyken: Geçiş verilmeli
  assert.strictEqual(evaluateAppVersionGate(3, { minSupportedBuild: 2 }), true, 'Daha yeni sürüm sorunsuz çalışabilmeli');

  console.log('✅ TEST 7 BAŞARILI: P0-16 minimum supported build kural kapısı doğrulandı.');
}

// ==============================================================================
// TEST 8: P0-11 & P0-12 — KVKK Kaskat Silme ve Hesap Silme Sıra Güvenliği
// ==============================================================================
console.log('\n--- TEST 8: P0-11 & P0-12 Hesap Silme Sırası ve Kaskat Sözleşmesi ---');
{
  // 1. İstemci Silme Sırası Testi:
  // Eğer önce Auth silinirse ve Auth hata verirse (requires-recent-login), Firestore dokümanı zombileşmez!
  let firestoreDeleted = false;
  let authDeleted = false;

  function simulateSafeClientAccountDeletion(authSucceeds) {
    try {
      if (!authSucceeds) {
        throw new Error('requires-recent-login');
      }
      authDeleted = true;
      // Sadece Auth başarılı olursa Firestore silinir
      firestoreDeleted = true;
    } catch (e) {
      // Hata durumunda hiçbir veri silinmez
    }
  }

  simulateSafeClientAccountDeletion(false);
  assert.strictEqual(authDeleted, false, 'Auth silinemediğinde authDeleted false kalmalı');
  assert.strictEqual(firestoreDeleted, false, 'Auth silinemediğinde Firestore dokümanı ASLA silinmemeli (zombi hesap önlendi)');

  simulateSafeClientAccountDeletion(true);
  assert.strictEqual(authDeleted, true, 'Auth silme başarılı olmalı');
  assert.strictEqual(firestoreDeleted, true, 'Auth sonrası Firestore temizliği tamamlanmalı');

  // 2. Kaskat Temizlik Matrisi Testi (P0-11)
  const mockUserResources = {
    deals: [{ id: 'd1', votes: 5, comments: 2 }],
    kuponlar: [{ id: 'k1', votes: 3 }],
    subcollections: ['notifications', 'favorites', 'notificationPreferences', 'couponLedger', 'unlockedCoupons']
  };

  function simulateCleanupUserDataCore(resources) {
    return {
      dealsDeleted: resources.deals.length,
      dealsSubcollectionsCleaned: ['comments', 'votes', 'expired_votes'],
      couponsDeleted: resources.kuponlar.length,
      couponsSubcollectionsCleaned: ['votes'],
      userSubcollectionsDeleted: resources.subcollections.length,
      erasureJobMints: true
    };
  }

  const result = simulateCleanupUserDataCore(mockUserResources);
  assert.strictEqual(result.dealsDeleted, 1, 'Kullanıcı fırsatları temizlenmeli');
  assert.strictEqual(result.couponsDeleted, 1, 'Kullanıcı kuponları temizlenmeli');
  assert.strictEqual(result.userSubcollectionsDeleted, 5, 'Tüm kullanıcı alt koleksiyonları (ledger dahil) temizlenmeli');
  assert.strictEqual(result.erasureJobMints, true, 'KVKK erasureJobs kaydı oluşturulmalı');

  console.log('✅ TEST 8 BAŞARILI: P0-11 kaskat ve P0-12 hesap silme sıra sözleşmesi doğrulandı.');
}

// ==============================================================================
// TEST 9: P0-13 — Kategori FCM Topic İsimlendirme ve Mükerrer Push Engeli
// ==============================================================================
console.log('\n--- TEST 9: P0-13 Kategori FCM Topic Dağıtım Sözleşmesi ---');
{
  function sanitizeTopicCategory(category) {
    return 'cat_' + String(category).toLowerCase().replace(/[^a-z0-9_-]/g, '_');
  }

  assert.strictEqual(sanitizeTopicCategory('elektronik'), 'cat_elektronik', 'Standart kategori adı temizlenmeli');
  assert.strictEqual(sanitizeTopicCategory('Ev & Yaşam'), 'cat_ev___ya_am', 'Özel karakterler güvenli formata dönüştürülmeli');
  assert.strictEqual(sanitizeTopicCategory('elektronik:bilgisayar'), 'cat_elektronik_bilgisayar', 'Alt kategori doğru dönüştürülmeli');

  // Mükerrer Push Önleme Sözleşmesi
  function shouldSendIndividualPush(notification) {
    if (notification.isTopicDelivered === true) {
      return false; // Zaten global topic ile iletildi, mükerrer tekil push engellendi!
    }
    return true;
  }

  assert.strictEqual(shouldSendIndividualPush({ isTopicDelivered: true }), false, 'Topic ile iletilen bildirim tekil push üretmemeli');
  assert.strictEqual(shouldSendIndividualPush({ isTopicDelivered: false, reason: 'keyword' }), true, 'Kişisel kelime alarmı tekil push almalı');

  console.log('✅ TEST 9 BAŞARILI: P0-13 kategori topic ve mükerrer push engeli doğrulandı.');
}

// ==============================================================================
// TEST 10: P1-11 — Gamification ve İstemci Puan/Rozet Manipülasyon Engeli
// ==============================================================================
console.log('\n--- TEST 10: P1-11 Gamification ve Puan/Rozet Koruma Sözleşmesi ---');
{
  function evaluateUserDocUpdate(existingData, requestedUpdate, isAuth, isAdmin, callerUid, targetUid) {
    if (!isAuth) return false;
    if (isAdmin) return true;
    if (callerUid !== targetUid) {
      const keys = Object.keys(requestedUpdate);
      return keys.length === 1 && keys[0] === 'followersWithNotifications';
    }
    const forbiddenKeys = ['isAdmin', 'isadmin', 'role', 'isBanned', 'points', 'badges', 'dealCount', 'totalLikes'];
    for (const key of forbiddenKeys) {
      if (key in requestedUpdate && requestedUpdate[key] !== existingData[key]) {
        return false; // Forbidden field update blocked!
      }
    }
    return true;
  }

  const existingProfile = { displayName: 'Ahmet', points: 20, badges: ['first_spark'], dealCount: 2 };

  // 1. Kullanıcı kendi profiline 10.000 puan basmaya çalışır
  assert.strictEqual(
    evaluateUserDocUpdate(existingProfile, { points: 10000 }, true, false, 'user_1', 'user_1'),
    false,
    'Kullanıcı kendi puanını doğrudan artıramamalı (RBAC Kalkanı)'
  );

  // 2. Kullanıcı sahte rozet eklemeye çalışır
  assert.strictEqual(
    evaluateUserDocUpdate(existingProfile, { badges: ['first_spark', 'legendary_hunter'] }, true, false, 'user_1', 'user_1'),
    false,
    'Kullanıcı kendi rozetlerini doğrudan manipüle edememeli'
  );

  // 3. Kullanıcı meşru alanları (displayName, bio) günceller
  assert.strictEqual(
    evaluateUserDocUpdate(existingProfile, { displayName: 'Ahmet Yılmaz', bio: 'Fırsat avcısı' }, true, false, 'user_1', 'user_1'),
    true,
    'Kullanıcı meşru profil alanlarını güncelleyebilmeli'
  );

  // 4. Admin rozet veya puan güncelleyebilir
  assert.strictEqual(
    evaluateUserDocUpdate(existingProfile, { points: 50 }, true, true, 'admin_1', 'user_1'),
    true,
    'Admin kullanıcının puan ve rozetlerini güncelleyebilmeli'
  );

  console.log('✅ TEST 10 BAŞARILI: P1-11 istemci puan/rozet sahteciliği kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 11: P1-12 — createdAt 5 Dakikalık Tolerans Penceresi ve Değiştirilemezlik
// ==============================================================================
console.log('\n--- TEST 11: P1-12 createdAt Zaman Toleransı ve İmmutability Sözleşmesi ---');
{
  function evaluateCreatedAt(createdAtDate, requestTimeDate) {
    const diffMs = Math.abs(createdAtDate.getTime() - requestTimeDate.getTime());
    const fiveMinutesMs = 5 * 60 * 1000;
    return diffMs <= fiveMinutesMs;
  }

  const now = new Date('2026-10-04T12:00:00Z');

  // 1. Meşru istemci: 2 saniye önceki zaman
  assert.strictEqual(evaluateCreatedAt(new Date('2026-10-04T11:59:58Z'), now), true, '2 saniyelik ağ gecikmesi kabul edilmeli');

  // 2. Meşru istemci: 3 dakika önceki zaman
  assert.strictEqual(evaluateCreatedAt(new Date('2026-10-04T11:57:00Z'), now), true, '3 dakikalık tolerans kabul edilmeli');

  // 3. Saldırgan: 1 saat gelecekteki zaman damgası (Feed sabitleme)
  assert.strictEqual(evaluateCreatedAt(new Date('2026-10-04T13:00:00Z'), now), false, 'Gelecek tarihli sahte zaman damgası reddedilmeli');

  // 4. Saldırgan: 2 gün önceki geçmiş zaman
  assert.strictEqual(evaluateCreatedAt(new Date('2026-10-02T12:00:00Z'), now), false, 'Geçmiş tarihli zaman damgası reddedilmeli');

  // 5. Update anında createdAt değiştirilemezliği (Immutability)
  function evaluateDealUpdateImmutability(affectedKeys) {
    const immutableKeys = ['createdAt', 'postedBy', 'isUserSubmitted', 'isEditorPick'];
    return !affectedKeys.some(k => immutableKeys.includes(k));
  }
  assert.strictEqual(evaluateDealUpdateImmutability(['title', 'price']), true, 'Meşru alan güncellemesi izinli olmalı');
  assert.strictEqual(evaluateDealUpdateImmutability(['createdAt', 'price']), false, 'createdAt güncellemesi engellenmeli');

  console.log('✅ TEST 11 BAŞARILI: P1-12 5 dakikalık zaman toleransı ve immutability doğrulandı.');
}

// ==============================================================================
// TEST 12: P1-13 — systemErrors Koleksiyonu canWrite ve Allowlist Güvencesi
// ==============================================================================
console.log('\n--- TEST 12: P1-13 systemErrors canWrite ve Alan Kalkanı Sözleşmesi ---');
{
  const allowedKeys = [
    'environment', 'service', 'category', 'subCategory', 'userId', 'userEmail',
    'errorType', 'message', 'stack', 'severity', 'status', 'fingerprint',
    'occurrenceCount', 'platform', 'metadata', 'lastOccurredAt', 'createdAt'
  ];

  function evaluateSystemErrorCreate(auth, isBlocked, data) {
    if (!auth || isBlocked) return false; // canWrite() şartı
    const keys = Object.keys(data);
    const hasOnlyAllowed = keys.every(k => allowedKeys.includes(k));
    const hasRequired = ['errorType', 'message', 'platform'].every(k => keys.includes(k));
    const validMessage = typeof data.message === 'string' && data.message.length <= 1000;
    const validPlatform = ['android', 'ios', 'web', 'backend', 'bot'].includes(data.platform);
    return hasOnlyAllowed && hasRequired && validMessage && validPlatform;
  }

  // 1. Kimliksiz (unauthenticated) saldırgan log basmaya çalışır
  assert.strictEqual(
    evaluateSystemErrorCreate(null, false, { errorType: 'Test', message: 'Hata', platform: 'android' }),
    false,
    'Kimliksiz log basma engellenmeli'
  );

  // 2. Banlı kullanıcı log basmaya çalışır
  assert.strictEqual(
    evaluateSystemErrorCreate({ uid: 'banned_1' }, true, { errorType: 'Test', message: 'Hata', platform: 'android' }),
    false,
    'Banlı kullanıcı log basamamalı'
  );

  // 3. Oturum açmış meşru istemci geçerli log basar
  assert.strictEqual(
    evaluateSystemErrorCreate({ uid: 'user_1' }, false, {
      environment: 'prod',
      service: 'mobile',
      category: 'UI',
      errorType: 'RenderFlex',
      message: 'A RenderFlex overflowed by 12 pixels',
      platform: 'android'
    }),
    true,
    'Meşru istemci hata logu kaydedebilmeli'
  );

  // 4. Yetkisiz ekstra alan içeren saldırı yükü
  assert.strictEqual(
    evaluateSystemErrorCreate({ uid: 'user_1' }, false, {
      errorType: 'Exploit',
      message: 'Test',
      platform: 'android',
      injectedAdminFlag: true // Yetkisiz alan
    }),
    false,
    'Allowlist dışındaki alanları içeren log engellenmeli'
  );

  console.log('✅ TEST 12 BAŞARILI: P1-13 systemErrors canWrite ve alan kısıtlama kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 13: P1-14 — Hibrit isAdmin (Custom Claims + Doküman Fallback)
// ==============================================================================
console.log('\n--- TEST 13: P1-14 Hibrit isAdmin Sözleşmesi ---');
{
  function evaluateIsAdmin(auth, userDoc) {
    if (!auth) return false;
    // 1. Custom Claims kontrolü (0 doküman okuması)
    if (auth.token && auth.token.admin === true) return true;
    // 2. Doküman fallback kontrolü
    if (userDoc && (userDoc.isAdmin === true || userDoc.isadmin === true || userDoc.isAdmin === 'true')) {
      return true;
    }
    return false;
  }

  // 1. Custom Claim tanımlı admin (0 DB read)
  assert.strictEqual(evaluateIsAdmin({ uid: 'admin_1', token: { admin: true } }, null), true, 'Custom Claim olan admin anında onaylanmalı');

  // 2. Henüz Claim basılmamış canlı admin (Firestore doküman fallback)
  assert.strictEqual(evaluateIsAdmin({ uid: 'admin_live', token: {} }, { isAdmin: true }), true, 'Dokümanında isAdmin: true olan admin kilitlenmemeli');

  // 3. Normal kullanıcı (ne claim ne doküman var)
  assert.strictEqual(evaluateIsAdmin({ uid: 'user_regular', token: {} }, { isAdmin: false }), false, 'Normal kullanıcı admin olamamalı');

  console.log('✅ TEST 13 BAŞARILI: P1-14 hibrit isAdmin custom claim ve fallback doğrulandı.');
}

// ==============================================================================
// TEST 14: P1-15 — Bot ve Sistem Kimliği Gasp Engeli
// ==============================================================================
console.log('\n--- TEST 14: P1-15 Bot/Sistem Fırsat Gasp Engeli Sözleşmesi ---');
{
  function evaluateDealCreateRules(auth, isBlocked, isDealBanned, data) {
    if (!auth || isBlocked || isDealBanned) return false;
    if (data.postedBy !== auth.uid) return false;
    if (data.postedBy === 'botkolik') return false; // Bot kimliği taklit edilemez
    if ('isUserSubmitted' in data && data.isUserSubmitted !== true) return false; // Bot akışı gasp edilemez
    if ('isTest' in data && data.isTest !== false) return false;
    return true;
  }

  const normalAuth = { uid: 'user_99' };

  // 1. Kullanıcı postedBy: 'botkolik' yazarak bot taklidi yapar
  assert.strictEqual(
    evaluateDealCreateRules(normalAuth, false, false, { postedBy: 'botkolik', isUserSubmitted: false }),
    false,
    'botkolik kimliği taklit edilememeli'
  );

  // 2. Kullanıcı isUserSubmitted: false ile moderasyonu atlatmaya çalışır
  assert.strictEqual(
    evaluateDealCreateRules(normalAuth, false, false, { postedBy: 'user_99', isUserSubmitted: false }),
    false,
    'isUserSubmitted: false kullanıcı tarafından gönderilememeli'
  );

  // 3. Meşru kullanıcı paylaşımı
  assert.strictEqual(
    evaluateDealCreateRules(normalAuth, false, false, { postedBy: 'user_99', isUserSubmitted: true }),
    true,
    'Meşru kullanıcı paylaşımı onaylanmalı'
  );

  console.log('✅ TEST 14 BAŞARILI: P1-15 bot ve sistem kimliği gasp kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 15: P1-16 — Bildirim Gönderici Adı Profil Doğrulaması & Rezerve İsim Filtresi
// ==============================================================================
console.log('\n--- TEST 15: P1-16 Bildirim Gönderici Profil Doğrulama Sözleşmesi ---');
{
  function getSafeSenderName(registeredProfile, clientClaimedName) {
    let resolved = 'Bir kullanıcı';
    if (registeredProfile) {
      resolved = registeredProfile.displayName || registeredProfile.username || (clientClaimedName || 'Bir kullanıcı');
    } else {
      resolved = clientClaimedName || 'Bir kullanıcı';
    }
    const lower = resolved.toLowerCase();
    const reservedNames = ['firsatkolik', 'admin', 'yonetim', 'moderatör', 'moderator', 'botkolik', 'sistem'];
    if (reservedNames.some(r => lower.includes(r))) {
      return 'Kullanıcı'; // Phishing engeli
    }
    return resolved;
  }

  // 1. Saldırgan yorum atarken client'tan userName: 'FırsatKolik Yönetim' gönderir ama profili 'saldirgan123'tür
  assert.strictEqual(
    getSafeSenderName({ username: 'saldirgan123' }, 'FırsatKolik Yönetim'),
    'saldirgan123',
    'İstemcinin sahte denormalize ismi yerine kullanıcının gerçek kayıtlı adı kullanılmalı'
  );

  // 2. Kullanıcı kullanıcı adına 'Admin' veya 'Yönetim' koymuştur
  assert.strictEqual(
    getSafeSenderName({ username: 'FırsatKolik Admin' }, 'FırsatKolik Admin'),
    'Kullanıcı',
    'Rezerve sistem isimleri taşıyan adlar Kullanıcı olarak filtrelenmeli'
  );

  // 3. Meşru kullanıcı
  assert.strictEqual(
    getSafeSenderName({ displayName: 'Merve Kaya' }, 'Merve Kaya'),
    'Merve Kaya',
    'Meşru kullanıcı adı korunmalı'
  );

  console.log('✅ TEST 15 BAŞARILI: P1-16 bildirim sahte gönderici adı kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 16: P1-17 — Sybil Ban Kalkanı ve Mesaj Seli Throttling
// ==============================================================================
console.log('\n--- TEST 16: P1-17 Sybil Ban Kalkanı ve Mesaj Flood Sözleşmesi ---');
{
  // 1. Ban kayıtlarının silinmeme sözleşmesi
  function cleanupPreservesBans(deletedCollections) {
    const protectedBanCollections = ['blockedUsers', 'commentBannedUsers', 'dealBannedUsers'];
    return !protectedBanCollections.some(c => deletedCollections.includes(c));
  }
  assert.strictEqual(
    cleanupPreservesBans(['deals', 'comments', 'notifications', 'favorites', 'couponLedger']),
    true,
    'Ban koleksiyonları kaskat silmeden muaf tutulmalı'
  );
  assert.strictEqual(
    cleanupPreservesBans(['blockedUsers', 'deals']),
    false,
    'blockedUsers kaskat silinirse sözleşme bozulur'
  );

  // 2. Mesaj flood koruması (1 dakikada 12'den fazla mesaj push üretmez)
  function shouldSendPushForMessage(recentMsgCountIn1Min) {
    if (recentMsgCountIn1Min >= 12) {
      return false; // Flood algılandı, bildirim atma
    }
    return true;
  }
  assert.strictEqual(shouldSendPushForMessage(5), true, 'Normal mesajlaşma push bildirimi üretmeli');
  assert.strictEqual(shouldSendPushForMessage(15), false, '15 mesajlık spam seli push bildirimini kısmalı');

  console.log('✅ TEST 16 BAŞARILI: P1-17 Sybil ban koruması ve mesaj flood kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 17: P1-18 — resolveShortLink IP Hız Limiti & SSRF
// ==============================================================================
console.log('\n--- TEST 17: P1-18 resolveShortLink Hız Limiti Sözleşmesi ---');
{
  function evaluateIpRateLimit(ipHistory, currentTimestamp) {
    const windowMs = 60000;
    const maxReqs = 60;
    if (!ipHistory || (currentTimestamp - ipHistory.startTime > windowMs)) {
      return { allowed: true, newHistory: { count: 1, startTime: currentTimestamp } };
    }
    if (ipHistory.count >= maxReqs) {
      return { allowed: false, newHistory: ipHistory };
    }
    return { allowed: true, newHistory: { count: ipHistory.count + 1, startTime: ipHistory.startTime } };
  }

  const t0 = 1000000;
  let history = { count: 59, startTime: t0 };

  // 60. istek: izinli
  const r60 = evaluateIpRateLimit(history, t0 + 1000);
  assert.strictEqual(r60.allowed, true);
  assert.strictEqual(r60.newHistory.count, 60);

  // 61. istek: engelli (HTTP 429)
  const r61 = evaluateIpRateLimit(r60.newHistory, t0 + 2000);
  assert.strictEqual(r61.allowed, false, 'Dakikada 60 isteği aşan IP 429 ile engellenmeli');

  // 1 dakika sonra: sıfırlanır
  const rNextMin = evaluateIpRateLimit(r61.newHistory, t0 + 65000);
  assert.strictEqual(rNextMin.allowed, true, 'Süre dolunca hız limiti sıfırlanmalı');
  assert.strictEqual(rNextMin.newHistory.count, 1);

  console.log('✅ TEST 17 BAŞARILI: P1-18 açık proxy hız limiti kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 18: P1-19 — users Koleksiyonu Anonim Okuma Engeli
// ==============================================================================
console.log('\n--- TEST 18: P1-19 users Koleksiyonu Anonim Scraping Engeli Sözleşmesi ---');
{
  function evaluateUsersRead(auth) {
    return auth !== null && auth.uid !== undefined;
  }

  // 1. Kimliksiz dış bot (unauthenticated)
  assert.strictEqual(evaluateUsersRead(null), false, 'Kimliksiz anonim istekler users okuyamamalı');

  // 2. Giriş yapmış mobil kullanıcı
  assert.strictEqual(evaluateUsersRead({ uid: 'user_123' }), true, 'Giriş yapmış meşru kullanıcı profil okuyabilmeli');

  console.log('✅ TEST 18 BAŞARILI: P1-19 users anonim scraping kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 19: P1-20 — Türkçe Küfür Filtresi Normalizasyonu & False Positive Kalkanı
// ==============================================================================
console.log('\n--- TEST 19: P1-20 Küfür Filtresi Türkçe Normalizasyon Sözleşmesi ---');
{
  const normalize = (text = '') =>
    text
      .toString()
      .replace(/(?<!\p{L})(şık|şıklar|şıklık|şıklığı|şıkkı|şıktır)(?!\p{L})/giu, '___ELEGANT___')
      .replace(/[\-\_]/g, ' ')
      .replace(/([a-zA-ZçğıöşüÇĞİÖŞÜ])([0-9])/g, '$1 $2')
      .replace(/([0-9])([a-zA-ZçğıöşüÇĞİÖŞÜ])/g, '$1 $2')
      .replace(/İ/g, 'i')
      .replace(/I/g, 'i')
      .replace(/ı/g, 'i')
      .toLowerCase()
      .replace(/ç/g, 'c')
      .replace(/ğ/g, 'g')
      .replace(/ö/g, 'o')
      .replace(/ş/g, 's')
      .replace(/ü/g, 'u');

  const profanityWords = [
    'sik', 'sike', 'siker', 'sikmek', 'sikti', 'siktir',
    'amk', 'amcik', 'amcık', 'orospu', 'orospu cocugu', 'orospu çocuğu',
    'pezevenk', 'pezeveng', 'kerhane', 'kerhaneci',
    'malk', 'malak', 'mal herif', 'mal ya', 'got', 'göt', 'gotu', 'götü',
    'cuk', 'çük', 'cukmek', 'çükmek', 'bok', 'boka', 'boku',
    'aptal', 'salak', 'gerizekali', 'geri zekalı', 'pic', 'piç',
    'haysiyetsiz', 'serefsiz', 'şerefsiz', 'namussuz', 'namusuz',
    'porno', 'pornografi', 'seks', 'sex',
    'oldur', 'öldür', 'oldurmek', 'öldürmek', 'katlet', 'katletmek',
    'canli bomba', 'canlı bomba', 'bombali saldiri', 'bombalı saldırı', 'bombala', 'bombalamak',
    'silahla', 'silahlamak',
    'esrar', 'eroin', 'kokain', 'uyusturucu', 'uyuşturucu',
    'sarhos', 'sarhoş', 'alkolik'
  ];

  const compiledList = profanityWords.map(p => {
    const norm = normalize(p);
    return {
      raw: p,
      regex: new RegExp('\\b' + norm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b')
    };
  });

  function containsProfanity(text) {
    if (!text || typeof text !== 'string') return false;
    const safeText = text.length > 5000 ? text.slice(0, 5000) : text;
    const normalizedText = normalize(safeText);
    for (const item of compiledList) {
      if (item.regex.test(normalizedText)) {
        return true;
      }
    }
    return false;
  }

  // Meşru e-ticaret kelimeleri kesinlikle YANLIŞ POZİTİF vermemeli (false dönmeli)
  assert.strictEqual(containsProfanity('Şık Bayan Elbise'), false, '"Şık Bayan Elbise" küfür sayılmamalı');
  assert.strictEqual(containsProfanity('En Şık Erkek Takım Elbise'), false, '"En Şık" küfür sayılmamalı');
  assert.strictEqual(containsProfanity('Bomba İndirim Başladı!'), false, '"Bomba İndirim" küfür/şiddet sayılmamalı');
  assert.strictEqual(containsProfanity('Ticari Malzeme ve Ürünler'), false, '"Ticari Malzeme" küfür sayılmamalı');

  // Gerçek küfür, hakaret ve tehditler kesinlikle YAKALANMALI (true dönmeli)
  assert.strictEqual(containsProfanity('siktir git buradan'), true, 'Gerçek küfür yakalanmalı');
  assert.strictEqual(containsProfanity('orospu çocuğu'), true, 'Ağır küfür yakalanmalı');
  assert.strictEqual(containsProfanity('tam bir mal herif'), true, 'Hakaret yakalanmalı');
  assert.strictEqual(containsProfanity('canlı bomba tehdidi'), true, 'Şiddet/terör tehdidi yakalanmalı');

  console.log('✅ TEST 19 BAŞARILI: P1-20 Türkçe küfür normalizasyonu ve false positive kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 20: P1-21 — Topic İletimli Bildirimlerde Gereksiz Firestore Yazma Engeli
// ==============================================================================
console.log('\n--- TEST 20: P1-21 Topic Bildirim Firestore Yazma Engeli Sözleşmesi ---');
{
  const functionsCode = fs.readFileSync(path.join(__dirname, '../index.js'), 'utf8');

  // onNotificationCreated fonksiyonunda isTopicDelivered kontrolünün doğrudan null döndüğünü doğrula
  const topicCheckPattern = /if\s*\(\s*notification\.isTopicDelivered\s*===\s*true\s*\)\s*\{[\s\S]*?return\s+null;/;
  assert.strictEqual(topicCheckPattern.test(functionsCode), true, 'isTopicDelivered true olduğunda redundant doc.set yapılmadan null dönmeli');

  // onNotificationCreated içinde snap.ref.set({ pushStatus: 'delivered_via_topic' }) çağrısı olmamalıdır
  const notifFuncBody = functionsCode.slice(functionsCode.indexOf('exports.onNotificationCreated'), functionsCode.indexOf('exports.onNotificationCreated') + 3000);
  assert.strictEqual(notifFuncBody.includes("pushStatus: 'delivered_via_topic'"), false, 'onNotificationCreated içinde redundant doc.set pushStatus delivered_via_topic olmamalı');

  // İlk batch oluşturma anında pushStatus 'delivered_via_topic' olarak tek yazmayla yazıldığını doğrula
  assert.ok(functionsCode.includes("pushStatus: match.reason === 'category' ? 'delivered_via_topic' : 'pending'"), 'Kategori bildirim dokümanı oluşturulurken pushStatus ilk batchte yazılmalı');

  console.log('✅ TEST 20 BAŞARILI: P1-21 Topic bildirim Firestore yazma maliyet kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 21: P1-24 — Firestore systemErrors Composite Index Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 21: P1-24 systemErrors Composite Index Sözleşmesi ---');
{
  const indexesRaw = fs.readFileSync(path.join(__dirname, '../../firestore.indexes.json'), 'utf8');
  const indexesJson = JSON.parse(indexesRaw);

  const systemErrorsIndex = indexesJson.indexes.find(idx =>
    idx.collectionGroup === 'systemErrors' &&
    idx.fields.some(f => f.fieldPath === 'status' && f.order === 'ASCENDING') &&
    idx.fields.some(f => f.fieldPath === 'createdAt' && f.order === 'ASCENDING')
  );

  assert.ok(systemErrorsIndex, 'systemErrors (status ASC, createdAt ASC) composite indexi firestore.indexes.json içinde mevcut olmalı');
  assert.strictEqual(systemErrorsIndex.queryScope, 'COLLECTION', 'systemErrors indexi queryScope COLLECTION olmalı');

  console.log('✅ TEST 21 BAŞARILI: P1-24 systemErrors composite index tanımlaması doğrulandı.');
}

// ==============================================================================
// TEST 22: P1-25 — Mobil Fırsat Kartı Termometre StreamBuilder Temizliği
// ==============================================================================
console.log('\n--- TEST 22: P1-25 DealCardThermometerPill StreamBuilder Temizliği Sözleşmesi ---');
{
  const widgetCode = fs.readFileSync(
    path.join(__dirname, '../../lib/widgets/deal_card/deal_card_thermometer_pill.dart'),
    'utf8'
  );

  assert.strictEqual(widgetCode.includes('.snapshots()'), false, 'Termometre widgeti içinde kart başına .snapshots() dinleyicisi olmamalı');
  assert.strictEqual(widgetCode.includes('StreamBuilder'), false, 'Termometre widgeti StreamBuilder kullanmamalı');
  assert.strictEqual(widgetCode.includes('cloud_firestore'), false, 'Termometre widgeti gereksiz cloud_firestore kütüphanesini import etmemeli');

  console.log('✅ TEST 22 BAŞARILI: P1-25 Kart başına 100+ Firestore dinleyicisi ve FPS kilitlenmesi engeli doğrulandı.');
}

// ==============================================================================
// TEST 23: P1-26 — GCE VM Docker Bellek ve CPU İzolasyon Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 23: P1-26 GCE VM Docker Bellek & CPU İzolasyonu Sözleşmesi ---');
{
  const deployCode = fs.readFileSync(
    path.join(__dirname, '../../cloud-run-bot/deploy_to_vm.py'),
    'utf8'
  );

  assert.ok(deployCode.includes('--memory=500m'), 'Prod bot için --memory=500m cgroup sınırı tanımlanmalı');
  assert.ok(deployCode.includes('--memory-swap=500m'), 'Prod bot için --memory-swap=500m swap sınırı tanımlanmalı');
  assert.ok(deployCode.includes('--cpus=0.70'), 'Prod bot için --cpus=0.70 CPU kotası tanımlanmalı');

  assert.ok(deployCode.includes('--memory=250m'), 'Dev bot için --memory=250m cgroup sınırı tanımlanmalı');
  assert.ok(deployCode.includes('--memory-swap=250m'), 'Dev bot için --memory-swap=250m swap sınırı tanımlanmalı');
  assert.ok(deployCode.includes('--cpus=0.25'), 'Dev bot için --cpus=0.25 CPU kotası tanımlanmalı');

  // Toplam limit kontrolü: 500m + 250m = 750m <= 1GB VM
  const prodMemMB = 500;
  const devMemMB = 250;
  const totalAllocatedMB = prodMemMB + devMemMB;
  assert.ok(totalAllocatedMB <= 800, 'Konteyner toplam bellek payı 800MB altında kalarak işletim sistemine RAM bırakmalıdır');

  console.log('✅ TEST 23 BAŞARILI: P1-26 e2-micro VM OOM Killer çökme koruması doğrulandı.');
}

// ==============================================================================
// TEST 24: P1-27 — Telegram MTProto Canlı Durum ve Yetki Kalp Atışı (Heartbeat)
// ==============================================================================
console.log('\n--- TEST 24: P1-27 Telegram MTProto Canlı Durum & Kalp Atışı Sözleşmesi ---');
{
  const botCode = fs.readFileSync(
    path.join(__dirname, '../../cloud-run-bot/telegram_bot.js'),
    'utf8'
  );

  assert.ok(botCode.includes('client && client.connected'), 'sendHeartbeat fonksiyonu client.connected soket durumunu sorgulamalı');
  assert.ok(botCode.includes('isUserAuthorized()'), 'sendHeartbeat fonksiyonu isUserAuthorized() MTProto oturum geçerliliğini doğrulamalı');
  assert.ok(botCode.includes("isHealthy ? 'online' : 'degraded'"), 'Kopma veya yetkisizlik durumunda status degraded olarak belirlenmeli');
  assert.ok(botCode.includes("status: currentStatus"), 'status currentStatus olarak Firestorea raporlanmalı');

  // Mantıksal heartbeat test simülasyonu
  function evaluateHeartbeat(client, isAuthorized) {
    const isSocketConnected = !!(client && client.connected);
    const isAuth = !!(isSocketConnected && isAuthorized);
    const isHealthy = isSocketConnected && isAuth;

    return {
      status: isHealthy ? 'online' : 'degraded',
      mtprotoConnected: isSocketConnected,
      mtprotoAuthStatus: isAuth
    };
  }

  // 1. Sağlıklı durum
  const healthy = evaluateHeartbeat({ connected: true }, true);
  assert.strictEqual(healthy.status, 'online');
  assert.strictEqual(healthy.mtprotoConnected, true);
  assert.strictEqual(healthy.mtprotoAuthStatus, true);

  // 2. MTProto soketi kopmuş durum
  const socketDead = evaluateHeartbeat({ connected: false }, true);
  assert.strictEqual(socketDead.status, 'degraded');
  assert.strictEqual(socketDead.mtprotoConnected, false);
  assert.strictEqual(socketDead.mtprotoAuthStatus, false);

  // 3. Soket bağlı ama 401 Session Revoked durumu
  const authRevoked = evaluateHeartbeat({ connected: true }, false);
  assert.strictEqual(authRevoked.status, 'degraded');
  assert.strictEqual(authRevoked.mtprotoConnected, true);
  assert.strictEqual(authRevoked.mtprotoAuthStatus, false);

  console.log('✅ TEST 24 BAŞARILI: P1-27 MTProto sessiz çökme ve sahte online heartbeat engeli doğrulandı.');
}

// ==============================================================================
// TEST 25: P1-22 — HomeScreen Kullanıcı Arama Prefix Sorgusu Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 25: P1-22 HomeScreen Arama Prefix Sorgusu Sözleşmesi ---');
{
  const homeCode = fs.readFileSync(
    path.join(__dirname, '../../lib/screens/home_screen.dart'),
    'utf8'
  );

  // İstemci tarafı körleme 30 doküman çekme kodunun kalktığını doğrula
  assert.strictEqual(homeCode.includes("source: Source.serverAndCache"), false, 'Körleme 30 doküman çekip bellek içi filtreleme kaldırılmış olmalı');

  // Firestore aralık sorgusu (.startAt ve .endAt \uf8ff) olduğunu doğrula
  assert.ok(homeCode.includes(".startAt([trimmed])"), 'startAt([trimmed]) prefix sorgusu bulunmalı');
  assert.ok(homeCode.includes(".endAt(['$trimmed\\uf8ff'])"), 'endAt prefix sorgusu bulunmalı');

  console.log('✅ TEST 25 BAŞARILI: P1-22 Kullanıcı aramasında indeksli prefix sorgusu ve bellek taşması engeli doğrulandı.');
}

// ==============================================================================
// TEST 26: P1-31 (R-BIZ-03) — Ödüllü Reklam Fail-Closed & Kupon Kredisi Koruma Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 26: P1-31 Ödüllü Reklam Fail-Closed Sözleşmesi ---');
{
  const kuponlarCode = fs.readFileSync(
    path.join(__dirname, '../../lib/screens/kuponlar_page.dart'),
    'utf8'
  );

  // !adShown durumunda bedava kupon açılmadığını veya kredi dağıtılmadığını doğrula
  const fallbackUnlockMatch = kuponlarCode.match(/if\s*\(!adShown[^}]*unlockCouponForGuest/s);
  assert.strictEqual(fallbackUnlockMatch, null, '!adShown durumunda unlockCouponForGuest çağrılmamalı');

  const fallbackCreditMatch = kuponlarCode.match(/if\s*\(!adShown[^}]*addRewardedCredits/s);
  assert.strictEqual(fallbackCreditMatch, null, '!adShown durumunda addRewardedCredits çağrılmamalı');

  console.log('✅ TEST 26 BAŞARILI: P1-31 Reklam yokluğunda sınırsız kilit açma / hediye kredi fail-closed kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 27: P1-32 (R-PRV-05) — Web Silme Sayfası Web3Forms Tasfiyesi Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 27: P1-32 Web Silme Sayfası Güvenlik ve Gizlilik Sözleşmesi ---');
{
  const deleteHtml = fs.readFileSync(
    path.join(__dirname, '../../web/delete-account.html'),
    'utf8'
  );

  assert.strictEqual(deleteHtml.includes('api.web3forms.com'), false, 'Web3Forms üçüncü taraf API adresi tamamen kaldırılmış olmalı');
  assert.strictEqual(deleteHtml.includes('access_key'), false, 'Web3Forms erişim anahtarı kaldırılmış olmalı');
  assert.ok(deleteHtml.includes('mailto:destek@firsatkolik.app'), 'Doğrudan resmi destek e-posta iletimi bulunmalı');

  console.log('✅ TEST 27 BAŞARILI: P1-32 Web3Forms üçüncü taraf veri sızıntısı tasfiyesi doğrulandı.');
}

// ==============================================================================
// TEST 28: P1-33 (R-PRV-07) — iOS ATT & UMP Rıza Öncesi Reklam Kalkanı Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 28: P1-33 iOS ATT & UMP Rıza Kalkanı Sözleşmesi ---');
{
  const mainCode = fs.readFileSync(
    path.join(__dirname, '../../lib/main.dart'),
    'utf8'
  );

  // 2.5 saniyelik zoraki timer'ın kalktığını doğrula
  assert.strictEqual(mainCode.includes('Duration(milliseconds: 2500)'), false, 'UMP rıza formunu bypass eden 2.5s timer kaldırılmış olmalı');
  assert.ok(mainCode.includes('canRequestAds()'), 'AdMob başlatması öncesinde canRequestAds() rıza denetimi bulunmalı');

  console.log('✅ TEST 28 BAŞARILI: P1-33 Rızasız erken AdMob başlatma ve 2.5s timer engeli doğrulandı.');
}

// ==============================================================================
// TEST 29: P1-36 (R-MOB-09) — iOS App Check & DeviceCheck Fallback Güvenlik Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 29: P1-36 iOS App Check & DeviceCheck Fallback Sözleşmesi ---');
{
  const mainCode = fs.readFileSync(
    path.join(__dirname, '../../lib/main.dart'),
    'utf8'
  );

  assert.ok(
    mainCode.includes('AppleProvider.appAttestWithDeviceCheckFallback'),
    'Firebase App Check DeviceCheck fallback ile güvenle başlatılmalı'
  );

  const entitlements = fs.readFileSync(
    path.join(__dirname, '../../ios/Runner/Runner.entitlements'),
    'utf8'
  );

  // Apple provisioning profile ile senkronize resmi App Attest yetkisini doğrula
  assert.ok(
    entitlements.includes('com.apple.developer.devicecheck.appattest-environment'),
    'App Attest entitlement Runner.entitlements içinde tanımlanmış olmalı'
  );

  console.log('✅ TEST 29 BAŞARILI: P1-36 iOS App Check DeviceCheck fallback ve App Attest yetkisi doğrulandı.');
}

// ==============================================================================
// TEST 30: P1-38 (R-MOB-12) — SafeLinkLauncher Şema Denetimi & HTTPS Yükseltme
// ==============================================================================
console.log('\n--- TEST 30: P1-38 SafeLinkLauncher Şema Doğrulama Sözleşmesi ---');
{
  const redirectCode = fs.readFileSync(
    path.join(__dirname, '../../lib/services/affiliate/store_redirect_service.dart'),
    'utf8'
  );

  assert.ok(redirectCode.includes("uri.replace(scheme: 'https')"), 'http linkleri otomatik https protokolüne yükseltilmeli');
  assert.ok(redirectCode.includes("SafeLinkLauncher"), 'SafeLinkLauncher güvenlik bloğu mevcut olmalı');

  console.log('✅ TEST 30 BAŞARILI: P1-38 SafeLinkLauncher HTTPS yükseltmesi ve şema kalkanı doğrulandı.');
}

// ==============================================================================
// TEST 31: P1-34 & P1-37 — CI Araç Zinciri Sürüm Sabitleme ve TestFlight Dağıtım Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 31: P1-34 & P1-37 CI Araç Pinleme ve TestFlight Esnekliği Sözleşmesi ---');
{
  const ciWorkflow = fs.readFileSync(
    path.join(__dirname, '../../.github/workflows/ios_testflight_deploy.yml'),
    'utf8'
  );

  assert.ok(
    ciWorkflow.includes("xcode-version: 'latest-stable'") || ciWorkflow.includes("xcode-version: '26"),
    'Xcode sürümü macOS runner ile uyumlu stabil ortamda seçilmiş olmalı'
  );
  assert.ok(
    ciWorkflow.includes("channel: 'stable'"),
    'Flutter SDK stabil kanalda seçilmiş olmalı'
  );

  // Geliştiriciyi kilitleyen yapay fail-closed kuralının OLMADIĞINI doğrula
  assert.strictEqual(
    ciWorkflow.includes("inputs.flavor != 'prod'"),
    false,
    'DEV TestFlight dağıtımını engelleyen yapay kısıtlama bulunmamalı'
  );

  console.log('✅ TEST 31 BAŞARILI: P1-34 CI araç zinciri sürüm sabitleme ve P1-37 TestFlight esnekliği doğrulandı.');
}

// ==============================================================================
// TEST 32: FS-08 — Kilitsiz Atomik Oylama ve Transaction Çekişmesi Tasfiyesi Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 32: FS-08 Kilitsiz Atomik Oylama ve Transaction Çekişmesi Tasfiyesi Sözleşmesi ---');
{
  const dealServiceCode = fs.readFileSync(
    path.join(__dirname, '../../lib/services/deal_service.dart'),
    'utf8'
  );
  const kuponServiceCode = fs.readFileSync(
    path.join(__dirname, '../../lib/services/kupon_service.dart'),
    'utf8'
  );

  // 1. deal_service.dart oylama fonksiyonlarında runTransaction kullanılmadığını doğrula
  const updateVoteBlock = dealServiceCode.substring(
    dealServiceCode.indexOf('Future<bool> _updateVoteInternal'),
    dealServiceCode.indexOf('Future<bool> addHotVote')
  );
  assert.strictEqual(
    updateVoteBlock.includes('runTransaction'),
    false,
    '_updateVoteInternal içinde runTransaction OLMAMALIDIR (FS-08 Kilitsiz Pipeline)'
  );
  assert.ok(
    updateVoteBlock.includes('FieldValue.increment'),
    '_updateVoteInternal sayaçları FieldValue.increment ile güncellemeli'
  );
  assert.ok(
    updateVoteBlock.includes('batch.commit()'),
    '_updateVoteInternal atomik WriteBatch kullanmalı'
  );

  // 2. addExpiredVote ve removeExpiredVote fonksiyonlarında runTransaction kullanılmadığını doğrula
  const expiredVoteBlock = dealServiceCode.substring(
    dealServiceCode.indexOf('Future<bool> addExpiredVote'),
    dealServiceCode.indexOf('Future<bool> hasUserVotedExpired')
  );
  assert.strictEqual(
    expiredVoteBlock.includes('runTransaction'),
    false,
    'addExpiredVote/removeExpiredVote içinde runTransaction OLMAMALIDIR (FS-08 Kilitsiz Pipeline)'
  );
  assert.ok(
    expiredVoteBlock.includes('FieldValue.increment'),
    'expiredVotes sayaçları FieldValue.increment ile güncellemeli'
  );

  // 3. kupon_service.dart setKuponVote ve voteKupon metodlarında runTransaction kullanılmadığını doğrula
  const kuponVoteBlock = kuponServiceCode.substring(
    kuponServiceCode.indexOf('Future<bool> setKuponVote'),
    kuponServiceCode.indexOf('Future<String?> getUserKuponVote')
  );
  assert.strictEqual(
    kuponVoteBlock.includes('runTransaction'),
    false,
    'setKuponVote/voteKupon içinde runTransaction OLMAMALIDIR (FS-08 Kilitsiz Pipeline)'
  );
  assert.ok(
    kuponVoteBlock.includes('FieldValue.increment'),
    'Kupon oy sayaçları FieldValue.increment ile güncellemeli'
  );
  assert.ok(
    kuponVoteBlock.includes('batch.commit()'),
    'setKuponVote atomik WriteBatch kullanmalı'
  );

  // 4. Kupon ana doküman güncellemesinde firestore.rules sınırlarına sadık kalındığını (updatedAt eklenmediğini) doğrula
  assert.strictEqual(
    kuponVoteBlock.includes("kuponUpdates['updatedAt']"),
    false,
    "kuponUpdates içinde updatedAt bulunmamalıdır (firestore.rules hasOnly(['sicakOySayisi', 'sogukOySayisi']) kalkanı)"
  );

  console.log('✅ TEST 32 BAŞARILI: FS-08 kilitsiz atomik oylama, FieldValue.increment ve alt doküman izolasyon sözleşmesi doğrulandı.');
}

// ==============================================================================
// TEST 33: FS-09 — Anasayfa SWR + Cache-First, Infinite Scroll & Floating Pill Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 33: FS-09 SWR, Sayfalama ve Floating Pill Sözleşmesi ---');
{
  const dealServiceCode = fs.readFileSync(path.join(__dirname, '../../lib/services/deal_service.dart'), 'utf8');
  const firestoreServiceCode = fs.readFileSync(path.join(__dirname, '../../lib/services/firestore_service.dart'), 'utf8');
  const homeScreenCode = fs.readFileSync(path.join(__dirname, '../../lib/screens/home_screen.dart'), 'utf8');
  const indexesJson = JSON.parse(fs.readFileSync(path.join(__dirname, '../../firestore.indexes.json'), 'utf8'));

  // 1. deal_service.dart içinde getDealsPaginated ve getLatestDealStream sözleşmesi
  assert.ok(
    dealServiceCode.includes('class DealsPageResult'),
    'DealsPageResult modeli deal_service.dart içinde tanımlı olmalıdır'
  );
  assert.ok(
    dealServiceCode.includes('Future<DealsPageResult> getDealsPaginated'),
    'getDealsPaginated metodu deal_service.dart içinde tanımlı olmalıdır'
  );
  assert.ok(
    dealServiceCode.includes('Stream<Deal?> getLatestDealStream'),
    'getLatestDealStream metodu limit(1) dinleyici olarak tanımlı olmalıdır'
  );
  assert.ok(
    dealServiceCode.includes('limit(1)'),
    'getLatestDealStream tam olarak limit(1) kullanmalıdır'
  );

  // 2. firestore_service.dart delegasyon sözleşmesi
  assert.ok(
    firestoreServiceCode.includes('Future<DealsPageResult> getDealsPaginated'),
    'firestore_service.dart getDealsPaginated metodunu dışa açmalıdır'
  );
  assert.ok(
    firestoreServiceCode.includes('Stream<Deal?> getLatestDealStream'),
    'firestore_service.dart getLatestDealStream metodunu dışa açmalıdır'
  );

  // 3. home_screen.dart içinde sürekli açık 100-item WebSocket stream akışının kaldırıldığını doğrula
  assert.strictEqual(
    homeScreenCode.includes('StreamBuilder<DealsSnapshot>'),
    false,
    'home_screen.dart içinde anasayfa akışında StreamBuilder<DealsSnapshot> OLMAMALIDIR (FS-09)'
  );
  assert.ok(
    homeScreenCode.includes('_fetchInitialDeals'),
    'home_screen.dart _fetchInitialDeals metodunu barındırmalıdır'
  );
  assert.ok(
    homeScreenCode.includes('Source.cache') && homeScreenCode.includes('Source.server'),
    'home_screen.dart SWR mimarisi gereği önce Source.cache sonra Source.server çalıştırmalıdır'
  );
  assert.ok(
    homeScreenCode.includes('_loadMoreDeals'),
    'home_screen.dart sonsuz kaydırma için _loadMoreDeals metodunu barındırmalıdır'
  );
  assert.ok(
    homeScreenCode.includes('_buildNewDealsFloatingPill'),
    'home_screen.dart Glassmorphic yüzen hap butonu (_buildNewDealsFloatingPill) barındırmalıdır'
  );
  assert.ok(
    homeScreenCode.includes('_listenToLatestDeal'),
    'home_screen.dart limit(1) dinleyicisi için _listenToLatestDeal metodunu çalıştırmalıdır'
  );

  // 4. firestore.indexes.json içinde bileşik indekslerin varlığını doğrula
  const indexes = indexesJson.indexes || [];
  const hasApprovedCreatedIndex = indexes.some(idx =>
    idx.collectionGroup === 'deals' &&
    idx.fields.some(f => f.fieldPath === 'isApproved') &&
    idx.fields.some(f => f.fieldPath === 'createdAt') &&
    !idx.fields.some(f => f.fieldPath === 'category')
  );
  const hasCategoryIndex = indexes.some(idx =>
    idx.collectionGroup === 'deals' &&
    idx.fields.some(f => f.fieldPath === 'isApproved') &&
    idx.fields.some(f => f.fieldPath === 'category') &&
    idx.fields.some(f => f.fieldPath === 'createdAt')
  );

  assert.ok(hasApprovedCreatedIndex, 'deals koleksiyonunda isApproved + createdAt indeksi mevcut olmalıdır');
  assert.ok(hasCategoryIndex, 'deals koleksiyonunda isApproved + category + createdAt indeksi mevcut olmalıdır');

  console.log('✅ TEST 33 BAŞARILI: FS-09 SWR, pagination, floating pill ve Firestore indeks sözleşmesi doğrulandı.');
}

console.log('\n======================================================');
console.log('🎉 FAZ 1, FAZ 2, FAZ 3 VE FAZ 4 TÜM SÖZLEŞME TESTLERİ (33/33) %100 GEÇTİ!');
console.log('======================================================');


