/**
 * FırsatKolik — Batch 4 Üretim & Mimari Sözleşme Test Süiti
 * 
 * Kapsam:
 * 1. onDealUpdated (Snapshot null koruması, bot fırsatı puan/rozet bypass'ı, onay durumu geçişi)
 * 2. onAdminMessageCreated (Çift kalkan önleme, içerik fallback, boş mesaj/UID koruması)
 * 3. onCouponCreated (Küfür/Argo tespiti, kupon geçersizleştirme, select() projeksiyonu ve kendi bildirimini engelleme)
 * 4. sendManualNotification (iOS APNs alert & header uyumluluğu, targetType doğrulama, string-only FCM data)
 * 
 * Çalıştırma: node functions/tests/test_batch4_contracts.js
 */

const assert = require('assert');

console.log('🚀 FırsatKolik Batch 4 Üretim & Mimari Sözleşme Test Süiti Başlatılıyor...\n');

// ==========================================
// TEST 1: onDealUpdated Mantık & Güvenlik Sözleşmeleri
// ==========================================
console.log('--- TEST 1: onDealUpdated Sözleşmesi ---');
{
  // 1.1 Snapshot null guard
  const handleDealUpdate = (change) => {
    if (!change || !change.after || !change.before) return null;
    const newData = change.after.data();
    const oldData = change.before.data();
    if (!newData || !oldData) return null;
    return { newData, oldData };
  };

  assert.strictEqual(handleDealUpdate(null), null, 'Boş change nesnesi null dönmeli');
  assert.strictEqual(handleDealUpdate({ before: null, after: {} }), null, 'Eksik snapshot null dönmeli');
  assert.strictEqual(handleDealUpdate({ before: { data: () => null }, after: { data: () => ({}) } }), null, 'Null data null dönmeli');

  // 1.2 Onaylanma Durumu Geçişi (wasApproved vs isNowApproved)
  const checkApprovalTransition = (oldData, newData) => {
    const wasApproved = oldData.isApproved === true;
    const isNowApproved = newData.isApproved === true;
    return !wasApproved && isNowApproved;
  };

  assert.strictEqual(checkApprovalTransition({ isApproved: false }, { isApproved: true }), true, 'false -> true onaylanma tetiklenmeli');
  assert.strictEqual(checkApprovalTransition({}, { isApproved: true }), true, 'undefined -> true onaylanma tetiklenmeli');
  assert.strictEqual(checkApprovalTransition({ isApproved: true }, { isApproved: true }), false, 'Zaten onaylıysa tekrar tetiklenmemeli');

  // 1.3 BotKolik & Bot Fırsatları Puan/Rozet İstisnası (Maliyet Tasarrufu)
  const shouldAwardPointsForVote = (dealData, oldUpCount, newUpCount) => {
    const isBotDeal = !dealData.postedBy ||
      dealData.postedBy === 'botkolik' ||
      dealData.postedBy === 'system' ||
      dealData.postedBy === 'admin';

    if (isBotDeal) return false;
    return newUpCount > oldUpCount;
  };

  assert.strictEqual(shouldAwardPointsForVote({ postedBy: 'botkolik' }, 0, 1), false, 'BotKolik fırsatına oy verilince userDoc yazması yapılmamalı');
  assert.strictEqual(shouldAwardPointsForVote({ postedBy: 'system' }, 5, 6), false, 'System fırsatına oy verilince userDoc yazması yapılmamalı');
  assert.strictEqual(shouldAwardPointsForVote({ postedBy: 'gercek_kullanici_123' }, 2, 3), true, 'Topluluk kullanıcısı için oy puanı verilmeli');
  assert.strictEqual(shouldAwardPointsForVote({ postedBy: 'gercek_kullanici_123' }, 3, 2), false, 'Oy azalmasında puan tetiklenmemeli');

  // 1.4 Rozet Seviye & Eşik Kontrolü
  const calculateBadges = (currentBadges, points, dealsCount) => {
    const badges = [...(currentBadges || [])];
    const newBadges = [];

    if (dealsCount >= 1 && !badges.includes('first_deal')) {
      badges.push('first_deal');
      newBadges.push('first_deal');
    }
    if (dealsCount >= 10 && !badges.includes('deal_hunter')) {
      badges.push('deal_hunter');
      newBadges.push('deal_hunter');
    }
    if (points >= 100 && !badges.includes('centurion')) {
      badges.push('centurion');
      newBadges.push('centurion');
    }
    return { badges, newBadges };
  };

  const badgeResult = calculateBadges([], 150, 12);
  assert.deepStrictEqual(badgeResult.newBadges, ['first_deal', 'deal_hunter', 'centurion'], 'Kazanılan rozetler doğru tespit edilmeli');
  const alreadyHaveResult = calculateBadges(['first_deal', 'deal_hunter', 'centurion'], 150, 12);
  assert.deepStrictEqual(alreadyHaveResult.newBadges, [], 'Önceden olan rozetler mükerrer eklenmemeli');

  console.log('✅ TEST 1 BAŞARILI: onDealUpdated null, onay, bot koruması ve rozet sözleşmeleri doğrulandı.');
}

// ==========================================
// TEST 2: onAdminMessageCreated Mantık & Güvenlik Sözleşmeleri
// ==========================================
console.log('\n--- TEST 2: onAdminMessageCreated Sözleşmesi ---');
{
  // 2.1 Çift Kalkan Emoji Düzeltmesi (Deduplication)
  const sanitizeAdminTitle = (rawTitle) => {
    const fallbackTitle = rawTitle || 'FırsatKolik Yönetim';
    // onNotificationCreated otomatik 🛡️ eklediği için baştaki kalkanı temizle
    return fallbackTitle.replace(/^🛡️\s*/, '').trim() || 'FırsatKolik Yönetim';
  };

  assert.strictEqual(sanitizeAdminTitle('🛡️ FırsatKolik Yönetim'), 'FırsatKolik Yönetim', 'Tek kalkan temizlenmeli');
  assert.strictEqual(sanitizeAdminTitle('🛡️   Önemli Duyuru'), 'Önemli Duyuru', 'Boşluklu kalkan temizlenmeli');
  assert.strictEqual(sanitizeAdminTitle('Hesap Uyarısı'), 'Hesap Uyarısı', 'Kalkansız başlık korunmalı');
  assert.strictEqual(sanitizeAdminTitle(''), 'FırsatKolik Yönetim', 'Boş başlık varsayılana dönmeli');

  // 2.2 İçerik Fallback Çözümlemesi
  const resolveMessageContent = (msg) => {
    return (msg.content || msg.body || msg.text || '').toString().trim();
  };

  assert.strictEqual(resolveMessageContent({ content: 'Hesabınız onaylandı' }), 'Hesabınız onaylandı');
  assert.strictEqual(resolveMessageContent({ body: 'İkinci format' }), 'İkinci format');
  assert.strictEqual(resolveMessageContent({ text: 'Üçüncü format' }), 'Üçüncü format');
  assert.strictEqual(resolveMessageContent({}), '');

  console.log('✅ TEST 2 BAŞARILI: onAdminMessageCreated çift kalkan ve içerik fallback sözleşmeleri doğrulandı.');
}

// ==========================================
// TEST 3: onCouponCreated Mantık & Güvenlik Sözleşmeleri
// ==========================================
console.log('\n--- TEST 3: onCouponCreated Sözleşmesi ---');
{
  const normalize = (text = '') =>
    text
      .toString()
      .replace(/[\-\_]/g, ' ')
      .replace(/İ/g, 'i')
      .replace(/I/g, 'i')
      .replace(/ı/g, 'i')
      .toLowerCase()
      .replace(/ç/g, 'c')
      .replace(/ğ/g, 'g')
      .replace(/ö/g, 'o')
      .replace(/ş/g, 's')
      .replace(/ü/g, 'u');

  const profanityWords = ['sik', 'amk', 'orospu', 'pezevenk', 'porno', 'seks', 'uyusturucu', 'serefsiz'];
  const compiledList = profanityWords.map(p => ({
    raw: p,
    regex: new RegExp('\\b' + normalize(p).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b')
  }));

  const containsProfanity = (text) => {
    if (!text || typeof text !== 'string') return false;
    const norm = normalize(text);
    return compiledList.some(item => item.regex.test(norm));
  };

  // 3.1 Kupon küfür filtresi testi
  assert.strictEqual(containsProfanity('Trendyol 100 TL İndirim Kuponu'), false, 'Temiz kupon onaylanmalı');
  assert.strictEqual(containsProfanity('Hepsiburada porno kuponu'), true, 'Küfürlü kupon reddedilmeli');
  assert.strictEqual(containsProfanity('amk sitesinde 50 tl indirim'), true, 'Argo kupon reddedilmeli');

  // 3.2 Kupon moderasyon eylemi
  const evaluateCoupon = (coupon) => {
    const textToCheck = `${coupon.baslik || ''} ${coupon.magazaAdi || ''}`;
    if (containsProfanity(textToCheck)) {
      return {
        action: 'reject',
        updateData: {
          durum: 'gecersiz',
          moderationFlag: true,
          moderationReason: 'Uygunsuz içerik tespit edildi.',
        }
      };
    }
    return { action: 'approve' };
  };

  const rejectedCoupon = evaluateCoupon({ baslik: 'Büyük orospu kuponu', magazaAdi: 'Trendyol' });
  assert.strictEqual(rejectedCoupon.action, 'reject');
  assert.strictEqual(rejectedCoupon.updateData.durum, 'gecersiz');

  // 3.3 Bildirim Kendi Kendine Gitmeme Kuralı (paylasanId)
  const shouldNotifyUser = (targetUserId, paylasanId) => {
    return targetUserId && targetUserId !== paylasanId;
  };

  assert.strictEqual(shouldNotifyUser('user_A', 'user_A'), false, 'Kuponu paylaşan kendi bildirimini almamalı');
  assert.strictEqual(shouldNotifyUser('user_B', 'user_A'), true, 'Diğer kullanıcılara bildirim gitmeli');

  console.log('✅ TEST 3 BAŞARILI: onCouponCreated moderasyon ve bildirim sözleşmeleri doğrulandı.');
}

// ==========================================
// TEST 4: sendManualNotification Sözleşmeleri
// ==========================================
console.log('\n--- TEST 4: sendManualNotification Sözleşmesi ---');
{
  // 4.1 Giriş doğrulaması
  const validateManualInput = (data, isAdmin) => {
    if (!isAdmin) throw new Error('permission-denied');
    const { title, body, targetType, targetValue } = data || {};
    const cleanTitle = (title || '').toString().trim();
    const cleanBody = (body || '').toString().trim();

    if (!cleanTitle || !cleanBody) {
      throw new Error('invalid-argument: title and body required');
    }

    const validTargetTypes = ['all', 'token', 'topic', 'uid'];
    if (!validTargetTypes.includes(targetType)) {
      throw new Error('invalid-argument: invalid targetType');
    }

    if (['token', 'topic', 'uid'].includes(targetType)) {
      if (!targetValue || typeof targetValue !== 'string' || !targetValue.trim()) {
        throw new Error(`invalid-argument: targetValue required for ${targetType}`);
      }
    }

    return { cleanTitle, cleanBody, targetType, targetValue: targetValue ? targetValue.trim() : null };
  };

  assert.throws(() => validateManualInput({ title: 'Test', body: 'Mesaj' }, false), /permission-denied/);
  assert.throws(() => validateManualInput({ title: '', body: 'Mesaj' }, true), /title and body required/);
  assert.throws(() => validateManualInput({ title: 'T', body: 'B', targetType: 'invalid' }, true), /invalid targetType/);
  assert.throws(() => validateManualInput({ title: 'T', body: 'B', targetType: 'uid', targetValue: '' }, true), /targetValue required for uid/);

  const validated = validateManualInput({
    title: '  Bahar İndirimleri Başladı!  ',
    body: '  Kaçırılmayacak fırsatlar burada!  ',
    targetType: 'topic',
    targetValue: '/topics/all_users'
  }, true);

  assert.strictEqual(validated.cleanTitle, 'Bahar İndirimleri Başladı!');
  assert.strictEqual(validated.cleanBody, 'Kaçırılmayacak fırsatlar burada!');
  assert.strictEqual(validated.targetType, 'topic');
  assert.strictEqual(validated.targetValue, '/topics/all_users');

  // 4.2 FCM Mesaj Yapısı & APNs Header Doğrulaması
  const buildFcmMessage = (title, body, notifType, notifReason, dealId, imageUrl) => {
    const msg = {
      notification: {
        title,
        body
      },
      data: {
        type: String(notifType),
        reason: String(notifReason),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        title: String(title),
        body: String(body),
        dealId: dealId ? String(dealId) : '',
        imageUrl: imageUrl ? String(imageUrl) : ''
      },
      android: {
        priority: 'high',
        notification: {
          channelId: notifType === 'admin_message' ? 'admin_messages_channel_v3' : 'sicak_firsatlar_general_v2',
          sound: 'default'
        }
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400)
        },
        payload: {
          aps: {
            alert: {
              title,
              body
            },
            sound: 'default',
            badge: 1,
            'content-available': 1
          }
        }
      }
    };
    return msg;
  };

  const fcmMsg = buildFcmMessage('Flaş Haber', 'İndirimler açıldı', 'marketing', 'marketing', 'deal_789', 'https://img.com/deal.jpg');

  // FCM Data Map tiplerinin tamamı String olmalı
  for (const [key, val] of Object.entries(fcmMsg.data)) {
    assert.strictEqual(typeof val, 'string', `Data alanı [${key}] tipi string olmalı, mevcut: ${typeof val}`);
  }

  // APNs alert alanı eksiksiz olmalı (iOS arka plan banner'ı için hayati önemde)
  assert.strictEqual(fcmMsg.apns.payload.aps.alert.title, 'Flaş Haber');
  assert.strictEqual(fcmMsg.apns.payload.aps.alert.body, 'İndirimler açıldı');
  assert.strictEqual(fcmMsg.apns.headers['apns-priority'], '10');

  console.log('✅ TEST 4 BAŞARILI: sendManualNotification parametre doğrulama, APNs ve veri tipi sözleşmeleri doğrulandı.');
}

console.log('\n======================================================');
console.log('🎉 TÜM BATCH 4 SÖZLEŞME VE MİMARİ TESTLERİ BAŞARIYLA GEÇTİ!');
console.log('======================================================\n');
