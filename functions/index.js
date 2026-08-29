const functions = require('firebase-functions');
const admin = require('firebase-admin');
const https = require('https');
const http = require('http');

if (!admin.apps.length) {
  admin.initializeApp();
}

// Türkçe karakter temizleme fonksiyonu (Harf duyarsız normalize)
const normalize = (text = '') =>
  text
    .toString()
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

// Küfür ve uygunsuz içerik kontrolü
const profanityWords = [
  'sik', 'sike', 'siker', 'sikmek', 'sikti', 'siktir',
  'amk', 'amcik', 'amcık', 'orospu', 'orospu cocugu', 'orospu çocuğu',
  'pezevenk', 'pezeveng', 'kerhane', 'kerhaneci',
  'mal', 'malk', 'malak', 'got', 'göt', 'gotu', 'götü',
  'cuk', 'çük', 'cukmek', 'çükmek', 'bok', 'boka', 'boku',
  'aptal', 'salak', 'gerizekali', 'geri zekalı', 'pic', 'piç',
  'haysiyetsiz', 'serefsiz', 'şerefsiz', 'namussuz', 'namusuz',
  'porno', 'pornografi', 'seks', 'sex',
  'oldur', 'öldür', 'oldurmek', 'öldürmek', 'katlet', 'katletmek',
  'bomba', 'bombala', 'bombalamak', 'silah', 'silahla', 'silahlamak',
  'esrar', 'eroin', 'kokain', 'uyusturucu', 'uyuşturucu',
  'sarhos', 'sarhoş', 'alkolik',
];

// İçerik moderasyonu kontrolü
function containsProfanity(text) {
  if (!text || typeof text !== 'string') return false;

  const normalizedText = normalize(text);
  const words = normalizedText.split(/\s+/);

  for (const profanity of profanityWords) {
    const normalizedProfanity = normalize(profanity);

    // Kelime sınırları kontrolü (Regex ile tam kelime eşleşmesi)
    // Örnek: "sik" kelimesi "bulaşık" içinde geçmemeli, sadece "sik" olarak geçmeli
    const regex = new RegExp('\\b' + normalizedProfanity.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b');

    if (regex.test(normalizedText)) {
      functions.logger.warn('⚠️ Küfür tespit edildi:', profanity);
      return true;
    }

    // NOT: Substring kontrolü kaldırıldı çünkü "sik", "amk", "mal" gibi kelimeler 
    // normal kelimelerin içinde çok sık geçiyor (örn: eksik, bulaşık, normal, kemal/cemal vs.)
    // Sadece tam kelime eşleşmesi yeterli olacaktır.
  }

  return false;
}

// Admin mesajlarına moderasyon bildirimi ekle
async function createModerationMessage({ type, userId, userName, content, dealId, commentId, reason }) {
  try {
    const messageRef = admin.firestore().collection('adminMessages').doc();

    const messageData = {
      id: messageRef.id,
      type: type, // 'deal' veya 'comment'
      userId: userId,
      userName: userName,
      content: content,
      dealId: dealId || null,
      commentId: commentId || null,
      reason: reason || 'Uygunsuz içerik tespit edildi',
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await messageRef.set(messageData);
    functions.logger.info('✅ Moderasyon mesajı eklendi:', messageRef.id);
  } catch (error) {
    functions.logger.error('❌ Moderasyon mesajı ekleme hatası:', error);
  }
}

async function logErrorToFirestore(service, errorType, message, stack, severity = 'error') {
  try {
    await admin.firestore().collection('systemErrors').add({
      service,
      errorType,
      message,
      stack: stack || null,
      status: 'unresolved',
      severity,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    functions.logger.info(`💾 Log Firestore'a kaydedildi: [${service}] (${severity}) ${errorType}`);
  } catch (err) {
    functions.logger.error('❌ Log Firestore\'a kaydedilemedi:', err.message);
  }
}

// Higher-order function to wrap Firestore/PubSub trigger callbacks
function wrapTrigger(name, handler) {
  return async (arg1, arg2) => {
    try {
      return await handler(arg1, arg2);
    } catch (error) {
      functions.logger.error(`❌ [Trigger Error] ${name}:`, error.message);
      await logErrorToFirestore('functions', `${name} Trigger Error`, error.message, error.stack, 'error');
      throw error;
    }
  };
}

// Higher-order function to wrap HTTPS onRequest callbacks
function wrapRequest(name, handler) {
  return async (req, res) => {
    try {
      return await handler(req, res);
    } catch (error) {
      functions.logger.error(`❌ [Request Error] ${name}:`, error.message);
      await logErrorToFirestore('functions', `${name} Request Error`, error.message, error.stack, 'error');
      if (!res.headersSent) {
        res.status(500).json({ success: false, error: error.message });
      }
      throw error;
    }
  };
}

// Higher-order function to wrap HTTPS onCall callbacks
function wrapCall(name, handler) {
  return async (data, context) => {
    try {
      return await handler(data, context);
    } catch (error) {
      functions.logger.error(`❌ [Call Error] ${name}:`, error.message);
      // Skip if it's already an HttpsError we intentionally threw
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      await logErrorToFirestore('functions', `${name} Call Error`, error.message, error.stack, 'error');
      throw new functions.https.HttpsError('internal', error.message);
    }
  };
}

const cleanTopicName = (str) => {
  if (!str) return 'genel';
  return normalize(str).replace(/[^a-z0-9_]/g, '_');
};

// Telegram botunun kategori ID'lerini uygulama kategori ID'sine çevirir (bildirim topic'leri için)
// Uygulama category_elektronik, category_kitap_hobi vb. dinliyor; bot bilgisayar, mobil_cihazlar yazıyor
const BOT_TO_APP_CATEGORY = {
  bilgisayar: 'elektronik',
  mobil_cihazlar: 'elektronik',
  konsol_oyun: 'kitap_hobi',
  ev_elektronigi_yasam: 'ev_yasam',
  ag_yazilim: 'elektronik',
};
function normalizeCategoryForTopic(raw) {
  if (!raw || typeof raw !== 'string') return 'diger';
  const lower = normalize(raw.trim());
  if (BOT_TO_APP_CATEGORY[lower]) return BOT_TO_APP_CATEGORY[lower];
  // Zaten uygulama ID'si olabilir (elektronik, moda, ev_yasam, ...)
  const appIds = ['elektronik', 'moda', 'ev_yasam', 'anne_bebek', 'kozmetik', 'spor_outdoor', 'supermarket', 'yapi_oto', 'kitap_hobi', 'diger'];
  if (appIds.includes(lower)) return lower;
  return 'diger';
}

const findMatchedKeyword = (text, keywords) => {
  const normalizedText = normalize(text);
  for (const kw of keywords) {
    if (!kw) continue;
    const k = normalize(String(kw));
    if (k && normalizedText.includes(k)) return kw;
  }
  return '';
};

// Kullanıcının aktif tüm cihaz token'larını döndürür (Tekil FCM token de-duplication ile)
async function getUserDeviceTokens(userId) {
  const devicesSnap = await admin.firestore()
    .collection('userDevices')
    .where('uid', '==', userId)
    .where('active', '==', true)
    .get();

  const tokens = [];
  const seenTokens = new Set();

  const docs = devicesSnap.docs.slice();
  docs.sort((a, b) => {
    const timeA = a.data().updatedAt ? a.data().updatedAt.toMillis() : 0;
    const timeB = b.data().updatedAt ? b.data().updatedAt.toMillis() : 0;
    return timeB - timeA;
  });

  for (const doc of docs) {
    const data = doc.data();
    if (data.fcmToken && !seenTokens.has(data.fcmToken)) {
      seenTokens.add(data.fcmToken);
      tokens.push({
        id: doc.id,
        token: data.fcmToken
      });
    } else if (data.fcmToken && seenTokens.has(data.fcmToken)) {
      // Duplicate token under another deviceId - mark as inactive in background
      doc.ref.set({
        active: false,
        deactivatedReason: 'duplicate_token_cleanup',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true }).catch(() => { });
    }
  }
  return tokens;
}

// Cihaz bazlı başarısız gönderim durumunda token'ı pasife çeker
async function handleSendFailure(deviceId, error) {
  if (deviceId && (error.code === 'messaging/registration-token-not-registered' || error.code === 'messaging/invalid-argument')) {
    functions.logger.info(`🚫 FCM token is invalid/expired, marking device as inactive: ${deviceId}`);
    await admin.firestore().collection('userDevices').doc(deviceId).update({
      active: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
}

// Eşleşen kullanıcıları toplayıp tekil bildirim dokümanı üretir
async function matchAndCreateDealNotifications(deal, dealId) {
  const title = deal.title || '';
  const description = deal.description || '';
  const postedBy = deal.postedBy || '';
  const isUserSubmitted = deal.isUserSubmitted || false;

  // 1. Anahtar kelimeleri topla, N-gram (1'li, 2'li, 3'lü sözcük öbekleri) üret ve normalize et
  const text = `${title} ${description}`;
  const textWithSpaces = text
    .replace(/[\-\_]/g, ' ')
    .replace(/([a-zA-ZçğıöşüÇĞİÖŞÜ])([0-9])/g, '$1 $2')
    .replace(/([0-9])([a-zA-ZçğıöşüÇĞİÖŞÜ])/g, '$1 $2');

  const normalizedText = normalize(textWithSpaces);
  const words = normalizedText
    .split(/[\s,\.\!\?\(\)\[\]\{\}"'\\/:]+/)
    .filter(w => w && w.length >= 1);

  const stopWords = ['bir', 've', 'veya', 'ile', 'icin', 'cok', 'bu', 'su', 'o', 'daha', 'en', 'kadar', 'gibi', 'diye', 'yok', 'var', 'mi', 'mu', 'mü', 'ama', 'fakat', 'lakin', 'bile', 'ben', 'sen', 'biz', 'siz', 'onlar'];

  // Candidate keyword list (Unigrams, Bigrams, Trigrams)
  const candidateKeywords = new Set();

  // A. Unigrams (Tekil Kelimeler)
  words.forEach(w => {
    if (w.length >= 2 && !stopWords.includes(w)) {
      candidateKeywords.add(w);
    }
  });

  // B. Bigrams (İkili Kelime Öbekleri: "iphone 15", "playstation 5", "kahve makinesi")
  for (let i = 0; i < words.length - 1; i++) {
    const w1 = words[i];
    const w2 = words[i + 1];
    if (!stopWords.includes(w1) || !stopWords.includes(w2)) {
      candidateKeywords.add(`${w1} ${w2}`);
    }
  }

  // C. Trigrams (Üçlü Kelime Öbekleri: "iphone 15 pro", "playstation 5 slim")
  for (let i = 0; i < words.length - 2; i++) {
    const w1 = words[i];
    const w2 = words[i + 1];
    const w3 = words[i + 2];
    candidateKeywords.add(`${w1} ${w2} ${w3}`);
  }

  const uniqueKeywords = [...candidateKeywords];
  const matchedUsers = new Map(); // userId -> { reason: 'keyword'|'author'|'category', detail: String, reasons: {} }

  // A. Takip Edilen Yazarlar (zil açık)
  const authorTarget = (isUserSubmitted && postedBy) ? postedBy : ((!isUserSubmitted || !postedBy || postedBy === 'botkolik') ? 'botkolik' : postedBy);
  if (authorTarget) {
    try {
      const authorSubsSnap = await admin.firestore()
        .collection('notificationSubscriptions')
        .where('type', '==', 'author')
        .where('key', '==', authorTarget)
        .where('enabled', '==', true)
        .get();

      authorSubsSnap.forEach(doc => {
        const sub = doc.data();
        if (sub.uid !== postedBy) { // Kendi kendine bildirim gitmesin
          matchedUsers.set(sub.uid, {
            reason: 'author',
            detail: authorTarget,
            reasons: { author: authorTarget }
          });
        }
      });
    } catch (err) {
      functions.logger.error('⚠️ Takip edilen yazar abonelik sorgusu hatası:', err);
    }
  }

  // B. Kategori Abonelikleri
  const category = deal.category || 'genel';
  const categoriesToCheck = [category];
  if (category.includes(':')) {
    categoriesToCheck.push(category.split(':')[0]); // parent category
  }

  try {
    const catSubsSnap = await admin.firestore()
      .collection('notificationSubscriptions')
      .where('type', '==', 'category')
      .where('key', 'in', categoriesToCheck)
      .where('enabled', '==', true)
      .get();

    catSubsSnap.forEach(doc => {
      const sub = doc.data();
      if (sub.uid !== postedBy) {
        if (matchedUsers.has(sub.uid)) {
          matchedUsers.get(sub.uid).reasons.category = sub.key;
        } else {
          matchedUsers.set(sub.uid, {
            reason: 'category',
            detail: sub.key,
            reasons: { category: sub.key }
          });
        }
      }
    });
  } catch (err) {
    functions.logger.error('⚠️ Kategori abonelik sorgusu hatası:', err);
  }

  // C. Anahtar Kelime Abonelikleri (Sıkı Kelime Sınırı Doğrulamalı / Strict Word Boundary Check)
  if (uniqueKeywords.length > 0) {
    const chunks = [];
    for (let i = 0; i < uniqueKeywords.length; i += 30) {
      chunks.push(uniqueKeywords.slice(i, i + 30));
    }

    try {
      const promises = chunks.map(chunk =>
        admin.firestore()
          .collection('notificationSubscriptions')
          .where('type', '==', 'keyword')
          .where('key', 'in', chunk)
          .where('enabled', '==', true)
          .get()
      );
      const snapshots = await Promise.all(promises);

      for (const snap of snapshots) {
        snap.forEach(doc => {
          const sub = doc.data();
          if (sub.uid !== postedBy) {
            const subKey = sub.key || sub.displayValue || '';
            const normalizedSubKey = normalize(subKey);

            // A. SIKI DOĞRULAMA (Strict Word Boundary Regex Check)
            const escapedSubKey = normalizedSubKey.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const strictRegex = new RegExp(`(?:^|[^a-z0-9])${escapedSubKey}(?:$|[^a-z0-9])`, 'i');

            // B. ÇOK KELİMELİ TAKİP KONTROLÜ (Multi-Word Non-Contiguous Stem Search)
            // Örn: "sony kulaklik" takibinde metinde "Sony" ve "Kulaklık" ayrı yerlerde geçse bile tolere edilir!
            let isMultiWordMatch = false;
            const subWords = normalizedSubKey.split(/\s+/).filter(w => w && !stopWords.includes(w));
            if (subWords.length > 1) {
              isMultiWordMatch = subWords.every(word => {
                const escapedWord = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                // k -> g yumuşama toleransı (lastik -> lastiği)
                const stem = escapedWord.replace(/k$/, '(?:k|g)');
                const wordRegex = new RegExp(`(?:^|[^a-z0-9])${stem}[a-z0-9çğıöşü]*(?:$|[^a-z0-9çğıöşü])`, 'i');
                return wordRegex.test(normalizedText);
              });
            }

            // Orijinal Türkçe harf korumalı kontrol (Örn: 'mac' takibi yapan kullanıcıya 'maç' bileti bildirimi gitmesini engeller)
            let isNativeMatched = true;
            if (normalizedSubKey === 'mac') {
              const macRegex = /(?:^|[^a-z0-9çğıöşü])mac(?:$|[^a-z0-9çğıöşü])/i;
              isNativeMatched = macRegex.test(textWithSpaces.toLowerCase());
            }

            if (isNativeMatched && (strictRegex.test(normalizedText) || isMultiWordMatch)) {
              const displayVal = sub.displayValue || subKey;
              if (matchedUsers.has(sub.uid)) {
                const u = matchedUsers.get(sub.uid);
                // Anahtar kelime en yüksek önceliklidir!
                u.reason = 'keyword';
                u.detail = displayVal;
                u.reasons.keyword = displayVal;
              } else {
                matchedUsers.set(sub.uid, {
                  reason: 'keyword',
                  detail: displayVal,
                  reasons: { keyword: displayVal }
                });
              }
            } else {
              functions.logger.info(`🚫 Kısmi yalancı eşleşme engellendi: '${subKey}' in '${title}'`);
            }
          }
        });
      }
    } catch (err) {
      functions.logger.error('⚠️ Anahtar kelime abonelik sorgusu hatası:', err);
    }
  }

  functions.logger.info(`📊 Eşleşen kullanıcı sayısı: ${matchedUsers.size}`);

  // 2. Bildirim Dokümanlarını Oluştur
  let batch = admin.firestore().batch();
  let opCount = 0;

  for (const [userId, match] of matchedUsers) {
    const notifId = `deal_${dealId}_${userId}`;
    const notifRef = admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .doc(notifId);

    let notifTitle = '🎯 Yeni Fırsat!';
    let notifBody = `${deal.title}\n💰 ${deal.price} TL`;

    if (match.reason === 'keyword') {
      notifTitle = '🎯 İlginizi Çeken Kelime!';
      notifBody = `"${match.detail}" içeren yeni fırsat: ${deal.title}`;
    } else if (match.reason === 'author') {
      if (match.detail === 'botkolik') {
        notifTitle = '⚡ Botkolik Radarı!';
        notifBody = `Botkolik yeni bir fırsat yakaladı: ${deal.title}`;
      } else {
        notifTitle = '👤 Takip Ettiğiniz Kişi!';
        notifBody = `Takip ettiğiniz yazar yeni fırsat paylaştı: ${deal.title}`;
      }
    }

    batch.set(notifRef, {
      type: 'deal',
      dealId: dealId,
      dealTitle: deal.title,
      title: notifTitle,
      body: notifBody,
      reason: match.reason,
      reasonDetail: match.detail,
      reasons: match.reasons || {},
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    opCount++;
    if (opCount >= 400) {
      await batch.commit();
      batch = admin.firestore().batch();
      opCount = 0;
    }
  }

  if (opCount > 0) {
    await batch.commit();
  }

  functions.logger.info('✅ Fırsat bildirimleri başarıyla oluşturuldu.');
}

/**
 * 1. YENİ FIRSAT GELDİĞİNDE
 */
exports.onDealCreated = functions.firestore
  .document('deals/{dealId}')
  .onCreate(wrapTrigger('onDealCreated', async (snap, context) => {
    const deal = snap.data();
    const dealId = context.params.dealId;

    functions.logger.info('📦 Yeni fırsat eklendi:', dealId, deal.title, 'isApproved:', deal.isApproved);

    // Deal paylaşım durumu kontrolü (sadece normal kullanıcılar için, bot ve admin hariç)
    const isUserSubmitted = deal.isUserSubmitted || false;
    if (isUserSubmitted) {
      // Normal kullanıcı paylaşımı - dealSharingEnabled kontrolü yap
      try {
        const settingsDoc = await admin.firestore().collection('settings').doc('app').get();
        const dealSharingEnabled = settingsDoc.exists && settingsDoc.data()
          ? (settingsDoc.data().dealSharingEnabled !== false)
          : true;

        if (!dealSharingEnabled) {
          // Paylaşımlar durdurulmuş - deal'i sil
          functions.logger.warn('🚫 Kullanıcı paylaşımı durdurulmuş, deal siliniyor:', dealId);
          await admin.firestore().collection('deals').doc(dealId).delete();
          return null;
        }
      } catch (error) {
        functions.logger.error('❌ Deal paylaşım durumu kontrol hatası:', error);
        // Hata durumunda devam et (varsayılan olarak aktif)
      }
    }
    // Bot paylaşımları (isUserSubmitted false) her zaman devam eder

    // İçerik moderasyonu kontrolü (backend'de ek güvenlik)
    const title = deal.title || '';
    const description = deal.description || '';
    const combinedText = `${title} ${description}`;

    if (containsProfanity(combinedText)) {
      functions.logger.warn('🚫 Uygunsuz içerik tespit edildi (Deal):', dealId);
      // Deal'i sil veya isApproved: false yap
      try {
        await admin.firestore().collection('deals').doc(dealId).update({
          isApproved: false,
          moderationFlag: true,
          moderationReason: 'Uygunsuz içerik tespit edildi',
        });
        functions.logger.info('✅ Deal moderasyon ile işaretlendi ve onaylanmadı');

        // Admin mesajlarına bildirim ekle
        await createModerationMessage({
          type: 'deal',
          userId: deal.postedBy || 'unknown',
          userName: deal.postedBy || 'Bilinmeyen Kullanıcı',
          content: `${title} ${description}`.substring(0, 100),
          dealId: dealId,
          reason: 'Uygunsuz içerik tespit edildi',
        });
      } catch (error) {
        functions.logger.error('❌ Deal moderasyon hatası:', error);
      }

      // Admin'e "Moderasyona Takıldı" bildirimi gönder
      const adminNotifTitle = `🛡️ Fırsat Moderasyona Takıldı (${deal.postedBy || 'Bilinmeyen'})`;
      const adminNotifBody = `${title.substring(0, 50)}... (Uygunsuz İçerik)`;

      const adminPayload = {
        notification: {
          title: adminNotifTitle,
          body: adminNotifBody,
        },
        data: {
          type: 'admin_deal',
          dealId: dealId,
          isApproved: 'false',
          isSuspicious: 'true',
          moderationReason: 'Uygunsuz içerik tespit edildi',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          notification_title: adminNotifTitle,
          notification_body: adminNotifBody,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'admin_channel',
            sound: 'default',
            color: '#F44336', // Kırmızı renk
            tag: `moderation_${dealId}`,
          }
        }
      };

      try {
        await admin.messaging().send({
          ...adminPayload,
          topic: 'admin_deals'
        });
        functions.logger.info('✅ Admin moderasyon bildirimi gönderildi');
      } catch (e) {
        functions.logger.error('❌ Admin moderasyon bildirimi hatası:', e);
      }

      return null;
    }

    // Eğer fırsat zaten onaylı geldiyse, bildirimleri oluştur
    if (deal.isApproved === true) {
      functions.logger.info('✅ Fırsat onaylı, bildirimler oluşturuluyor...');
      await matchAndCreateDealNotifications(deal, dealId);
      return;
    }

    // Onaysız fırsat -> SADECE Admin'e bildirim (bot veya kullanıcı farketmez)
    const dealTitle = deal.title || 'Yeni Fırsat';
    const dealPrice = deal.price || 0;
    const shortTitle = dealTitle.length > 50 ? dealTitle.substring(0, 50) + "..." : dealTitle;
    const dealSource = isUserSubmitted ? '👤 Kullanıcı' : '🤖 Bot';

    const adminNotifTitle = `👮‍♂️ Yeni Onay Bekleyen Fırsat (${dealSource})`;
    const adminNotifBody = `${shortTitle}\n💰 ${dealPrice} TL`;
    const adminPayload = {
      notification: {
        title: adminNotifTitle,
        body: adminNotifBody,
      },
      data: {
        type: 'admin_deal',
        dealId: dealId,
        isApproved: 'false',
        isUserSubmitted: isUserSubmitted ? 'true' : 'false',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        notification_title: adminNotifTitle,
        notification_body: adminNotifBody,
      },
      android: {
        priority: 'high',
        ttl: 86400000, // 24 Saat boyunca teslim etmeyi dene
        notification: {
          channelId: 'admin_channel',
          sound: 'default',
          color: '#2196F3', // Mavi renk
          tag: `admin_deal_${dealId}`, // Benzersiz tag
          defaultSound: true,
          defaultVibrateTimings: true,
          priority: 'high', // Öncelik yüksek
          visibility: 'public', // Kilit ekranında göster
        }
      },
      apns: {
        headers: {
          'apns-priority': '10', // iOS Yüksek öncelik
          'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400), // 24 saat (STRING olmalı!)
        },
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'interruption-level': 'active', // iOS - 'critical' özel izin gerektirir
            category: 'ADMIN_NOTIFICATION',
          },
        },
      },
    };

    try {
      functions.logger.info(`📤 Admin bildirimi gönderiliyor (topic: admin_deals, isApproved: false, isUserSubmitted: ${isUserSubmitted})...`);
      const adminResponse = await admin.messaging().send({
        ...adminPayload,
        topic: 'admin_deals'
      });
      functions.logger.info('✅ Admin bildirimi başarıyla gönderildi:', adminResponse);
    } catch (error) {
      functions.logger.error('❌ Admin bildirimi hatası:', error);
    }
  }));

/**
 * 2. FIRSAT GÜNCELLENDİĞİNDE (Onaylandıysa Herkese Bildir + Anahtar Kelime)
 */
exports.onDealUpdated = functions.firestore
  .document('deals/{dealId}')
  .onUpdate(wrapTrigger('onDealUpdated', async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    const dealId = context.params.dealId;

    // Sadece onay durumu false -> true olduğunda çalış
    if (oldData.isApproved === false && newData.isApproved === true) {
      functions.logger.info('🎉 Fırsat onaylandı! Bildirimler oluşturuluyor:', dealId);
      await matchAndCreateDealNotifications(newData, dealId);
    }

    // Paylaşım Durumu Bildirimi: Kullanıcı tarafından yüklenen bir fırsat onaylandığında veya reddedildiğinde bildirim oluştur
    const isUserSubmitted = newData.isUserSubmitted || false;
    const postedBy = newData.postedBy || '';

    if (isUserSubmitted && postedBy) {
      // Onaylandı bildirmesi (isApproved: false -> true)
      if (oldData.isApproved === false && newData.isApproved === true) {
        functions.logger.info(`🔔 Paylaşılan fırsat onaylandı, yükleyen kullanıcıya bildirim gönderiliyor: ${postedBy}`);
        const notifId = `deal_status_approved_${dealId}`;
        const notifRef = admin.firestore()
          .collection('users')
          .doc(postedBy)
          .collection('notifications')
          .doc(notifId);

        await notifRef.set({
          type: 'submission_status',
          dealId: dealId,
          dealTitle: newData.title || 'Fırsatınız',
          title: '🎉 Fırsatınız Onaylandı!',
          body: `Paylaştığınız "${newData.title}" başlıklı fırsat onaylandı ve yayına alındı.`,
          status: 'approved',
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
      // Reddedildi bildirmesi (isRejected: false/undefined -> true)
      else if (oldData.isRejected !== true && newData.isRejected === true) {
        functions.logger.info(`🔔 Paylaşılan fırsat reddedildi, yükleyen kullanıcıya bildirim gönderiliyor: ${postedBy}`);
        const notifId = `deal_status_rejected_${dealId}`;
        const notifRef = admin.firestore()
          .collection('users')
          .doc(postedBy)
          .collection('notifications')
          .doc(notifId);

        await notifRef.set({
          type: 'submission_status',
          dealId: dealId,
          dealTitle: newData.title || 'Fırsatınız',
          title: '❌ Fırsatınız Reddedildi',
          body: `Paylaştığınız "${newData.title}" başlıklı fırsat kurallarımıza uymadığı için reddedildi.`,
          status: 'rejected',
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    }

    return null;
  }));

// Yorum moderasyonu - Collection group trigger
exports.onCommentCreated = functions.firestore
  .document('deals/{dealId}/comments/{commentId}')
  .onCreate(wrapTrigger('onCommentCreated', async (snap, context) => {
    const comment = snap.data();
    const commentId = context.params.commentId;
    const dealId = context.params.dealId;

    functions.logger.info('💬 Yeni yorum eklendi:', commentId, 'Deal:', dealId);

    // Yorum paylaşım durumu kontrolü (sadece normal kullanıcılar için, admin hariç)
    const userId = comment.userId || 'unknown';
    try {
      // Admin kontrolü
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      const isAdmin = userDoc.exists && userDoc.data()
        ? (userDoc.data().isAdmin === true || userDoc.data().isadmin === true || userDoc.data().isAdmin === 'true' || userDoc.data().isadmin === 'true')
        : false;

      // Admin değilse yorum paylaşım durumunu kontrol et
      if (!isAdmin) {
        const settingsDoc = await admin.firestore().collection('settings').doc('app').get();
        const commentSharingEnabled = settingsDoc.exists && settingsDoc.data()
          ? (settingsDoc.data().commentSharingEnabled !== false)
          : true;

        if (!commentSharingEnabled) {
          // Yorumlar durdurulmuş - yorumu sil
          functions.logger.warn('🚫 Yorum paylaşımı durdurulmuş, yorum siliniyor:', commentId);
          await admin.firestore()
            .collection('deals')
            .doc(dealId)
            .collection('comments')
            .doc(commentId)
            .delete();

          // Comment count'u azalt
          await admin.firestore().collection('deals').doc(dealId).update({
            commentCount: admin.firestore.FieldValue.increment(-1),
          });
          return null;
        }
      }
    } catch (error) {
      functions.logger.error('❌ Yorum paylaşım durumu kontrol hatası:', error);
      // Hata durumunda devam et (varsayılan olarak aktif)
    }

    // İçerik moderasyonu kontrolü
    const commentText = comment.text || '';

    if (containsProfanity(commentText)) {
      functions.logger.warn('🚫 Uygunsuz yorum tespit edildi:', commentId);
      // Yorumu sil
      try {
        await admin.firestore()
          .collection('deals')
          .doc(dealId)
          .collection('comments')
          .doc(commentId)
          .delete();

        // Comment count'u azalt
        await admin.firestore().collection('deals').doc(dealId).update({
          commentCount: admin.firestore.FieldValue.increment(-1),
        });

        functions.logger.info('✅ Uygunsuz yorum silindi');

        // Admin mesajlarına bildirim ekle
        await createModerationMessage({
          type: 'comment',
          userId: comment.userId || 'unknown',
          userName: comment.userName || 'Bilinmeyen Kullanıcı',
          content: commentText.substring(0, 100),
          dealId: dealId,
          commentId: commentId,
          reason: 'Uygunsuz yorum tespit edildi',
        });
      } catch (error) {
        functions.logger.error('❌ Yorum silme hatası:', error);
      }
      return null;
    }

    // Yanıt bildirimi gönder (eğer bu yorum başka bir yoruma cevap ise)
    const parentCommentId = comment.parentCommentId || null;
    if (parentCommentId) {
      try {
        const parentCommentDoc = await admin.firestore()
          .collection('deals')
          .doc(dealId)
          .collection('comments')
          .doc(parentCommentId)
          .get();

        if (parentCommentDoc.exists) {
          const parentComment = parentCommentDoc.data();
          const recipientUserId = parentComment.userId;
          const replierUserId = comment.userId;

          // Kendine yanıt verildiyse bildirim gitmesin
          if (recipientUserId && recipientUserId !== replierUserId) {
            // Fırsat başlığını çek
            const dealDoc = await admin.firestore().collection('deals').doc(dealId).get();
            const dealTitle = dealDoc.exists ? (dealDoc.data().title || 'Fırsat') : 'Fırsat';

            const notificationId = `reply_${commentId}_${recipientUserId}`;
            const notificationRef = admin.firestore()
              .collection('users')
              .doc(recipientUserId)
              .collection('notifications')
              .doc(notificationId);

            const replyUserName = comment.userName || 'Bir kullanıcı';
            const replyText = commentText;

            await notificationRef.set({
              type: 'comment_reply',
              title: `${replyUserName} yorumunuza cevap verdi`,
              body: replyText.length > 100 ? `${replyText.substring(0, 100)}...` : replyText,
              dealId: dealId,
              dealTitle: dealTitle,
              commentId: commentId,
              parentCommentId: parentCommentId,
              replyUserName: replyUserName,
              replyText: replyText.length > 100 ? `${replyText.substring(0, 100)}...` : replyText,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              read: false
            });

            functions.logger.info(`✅ Yorum yanıt bildirimi Firestore'a yazıldı: ${recipientUserId}`);
          }
        }
      } catch (err) {
        functions.logger.error('❌ Yorum yanıt bildirimi oluşturulamadı:', err);
      }
    }

    return null;
  }));

/**
 * 4. ADMIN MESAJI GÖNDERİLDİĞİNDE
 * adminToUserMessages koleksiyonuna doküman yazıldığında tetiklenir.
 * Sadece users/{uid}/notifications/ altına bildirim dokümanı oluşturur.
 * FCM push gönderimi onNotificationCreated birleşik motoruna bırakılır (Tek Sorumluluk).
 */
exports.onAdminMessageCreated = functions.firestore
  .document('adminToUserMessages/{messageId}')
  .onCreate(wrapTrigger('onAdminMessageCreated', async (snap, context) => {
    const message = snap.data();
    const messageId = context.params.messageId;
    const userId = message.userId;
    const title = message.title || 'Yeni Bildirim';
    const content = message.content || '';
    const adminName = message.adminName || 'FırsatKolik Yönetim';

    functions.logger.info('📨 Yeni admin mesajı oluşturuldu:', {
      messageId,
      userId,
      title,
      adminName
    });

    if (!userId) {
      functions.logger.warn('⚠️ Admin mesajında userId yok, bildirim gönderilemiyor');
      return null;
    }

    try {
      // Alıcının notifications koleksiyonuna doküman yaz
      // Bu doküman onNotificationCreated trigger'ını tetikleyecek ve FCM push oradan gönderilecek
      const notifRef = admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(`admin_msg_${messageId}`);

      await notifRef.set({
        id: `admin_msg_${messageId}`,
        type: 'admin_message',
        title: title,
        body: content,
        // FCM push için gerekli ek alanlar (onNotificationCreated tarafından kullanılacak)
        senderId: 'admin',
        senderName: adminName,
        messageId: messageId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      functions.logger.info(`✅ Admin mesaj bildirimi dokümanı oluşturuldu (push onNotificationCreated tarafından gönderilecek): ${userId}`);
      return null;
    } catch (error) {
      functions.logger.error('❌ Admin mesaj bildirimi dokümanı oluşturulamadı:', {
        messageId,
        userId,
        error: error.message,
        stack: error.stack
      });
      return null;
    }
  }));

/**
 * 5. KULLANICI MESAJI GÖNDERİLDİĞİNDE (User-to-User)
 * Flutter app 'messages' koleksiyonunu kullanıyor
 */
exports.onUserMessageCreated = functions.firestore
  .document('messages/{messageId}')
  .onCreate(wrapTrigger('onUserMessageCreated', async (snap, context) => {
    const message = snap.data();
    const messageId = context.params.messageId;

    // Mesaj verilerini al
    const senderId = message.senderId;
    const receiverId = message.receiverId;
    const content = message.text || message.content || 'Görsel'; // Metin veya görsel
    const senderName = message.senderName || 'Bir Kullanıcı';

    // Kendi kendine mesajsa bildirim gönderme
    if (senderId === receiverId) return null;

    functions.logger.info('📨 Yeni kullanıcı mesajı:', { messageId, senderId, receiverId });

    // Gönderenin profil resmini ve ismini al
    let senderImageUrl = message.senderImageUrl || '';
    let resolvedSenderName = senderName;

    if (senderId === 'admin') {
      resolvedSenderName = 'FırsatKolik Yönetim';
      senderImageUrl = 'assets/logo.webp';
    } else if (senderId === 'botkolik') {
      resolvedSenderName = 'Botkolik';
      senderImageUrl = 'assets/botkolik.webp';
    } else {
      try {
        const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
        if (senderDoc.exists) {
          senderImageUrl = senderDoc.data().profileImageUrl || senderDoc.data().photoURL || senderImageUrl;
          resolvedSenderName = senderDoc.data().username || senderDoc.data().displayName || resolvedSenderName;
        }
      } catch (imgErr) {
        functions.logger.warn('⚠️ Gönderen profil resmi alınamadı:', imgErr);
      }
    }
    try {
      const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
      if (receiverDoc.exists) {
        const receiverData = receiverDoc.data();
        const blockedUsers = receiverData?.blockedUsers || [];
        if (Array.isArray(blockedUsers) && blockedUsers.includes(senderId)) {
          functions.logger.info(`🚫 Alıcı (${receiverId}) göndereni (${senderId}) engellemiş, push bildirim iptal edildi.`);
          return null;
        }
      }
    } catch (blockErr) {
      functions.logger.warn('⚠️ Alıcı blok listesi kontrolü sırasında hata:', blockErr);
    }

    try {
      // Alıcının tüm aktif cihaz token'larını al
      const devices = await getUserDeviceTokens(receiverId);

      if (devices.length === 0) {
        functions.logger.warn('⚠️ Alıcı için aktif cihaz token\'ı bulunamadı:', receiverId);
        return null;
      }

      // Bildirim içeriği
      const notificationBody = content.length > 100 ? content.substring(0, 100) + '...' : content;

      functions.logger.info(`📤 Mesaj bildirimi ${devices.length} cihaza gönderiliyor...`);

      const promises = devices.map(async (device) => {
        // DATA-ONLY payload: notification alanı YOK
        // Böylece Flutter onMessage handler'ı activeChatUserId kontrolü yapabilir
        // ve kullanıcı zaten o sohbetteyse bildirimi bastırabilir.
        // Eğer notification alanı olsaydı, Android OS ön planda bile otomatik bildirim gösterirdi.
        const payload = {
          token: device.token,
          data: {
            type: 'message',
            messageId: messageId,
            senderId: senderId,
            senderName: resolvedSenderName,
            senderImageUrl: senderImageUrl,
            messageText: notificationBody,
            receiverId: receiverId,
            notification_title: `💬 ${resolvedSenderName}`,
            notification_body: notificationBody,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            ttl: 86400000, // 24 saat
            collapseKey: `msg_${senderId}`,
          },
          apns: {
            headers: {
              'apns-priority': '10',
              'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400),
              'apns-collapse-id': `msg_${senderId}`,
            },
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                'content-available': 1,
                'interruption-level': 'active',
                category: 'USER_MESSAGE',
                'thread-id': `conv_${senderId}`,
              },
            },
          },
        };

        try {
          await admin.messaging().send(payload);
          return { success: true };
        } catch (err) {
          functions.logger.error(`❌ FCM gönderim hatası (device: ${device.id}):`, err);
          if (device.id) {
            await handleSendFailure(device.id, err);
          }
          return { success: false, error: err };
        }
      });

      await Promise.all(promises);
      functions.logger.info('✅ Mesaj bildirimleri gönderimi tamamlandı:', receiverId);
      return null;
    } catch (error) {
      functions.logger.error('❌ Mesaj bildirimi hatası:', error);
      return null;
    }
  }));

/**
 * 6. BİRLEŞİK BİLDİRİM TETİKLEYİCİSİ - Push Notification Gönder
 * users/{userId}/notifications/{notificationId} koleksiyonunu dinler
 */
exports.onNotificationCreated = functions.firestore
  .document('users/{userId}/notifications/{notificationId}')
  .onCreate(wrapTrigger('onNotificationCreated', async (snap, context) => {
    const notification = snap.data();
    const userId = context.params.userId;
    const notificationId = context.params.notificationId;

    let title = notification.title || 'Yeni Bildirim';
    let body = notification.body || '';

    functions.logger.info('🔔 onNotificationCreated tetiklendi:', { userId, notificationId, type: notification.type });

    // 00. submission_status bildirimleri için push gönderilmez (sadece bildirim merkezinde saklanır)
    // NOT: admin_message artık bu motordan geçerek push gönderilir (Tek Sorumluluk Prensibi)
    if (notification.type === 'submission_status') {
      functions.logger.info(`🚫 ${notification.type} için push gönderilmez (sadece bildirim merkezinde saklanır).`);
      await snap.ref.set({
        pushEligible: false,
        pushStatus: 'disabled_permanently_for_submission_status',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      return null;
    }

    // 0. Check global Master Switch for push notifications
    try {
      const sysConfigDoc = await admin.firestore().collection('systemConfig').doc('notifications').get();
      if (sysConfigDoc.exists) {
        const sysConfig = sysConfigDoc.data();
        if (sysConfig.enabled === false) {
          functions.logger.info(`🚫 Global master notification switch is disabled. Skipping push for ${notificationId}`);
          await snap.ref.set({
            pushEligible: false,
            pushStatus: 'disabled_by_system_master_switch',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
          return null;
        }
      }
    } catch (sysErr) {
      functions.logger.error('⚠️ System config load error, continuing:', sysErr);
    }

    // 1. Kullanıcı Tercihleri ve Ayarlar
    let prefs = {
      pushMasterEnabled: true,
      dealNotificationsEnabled: true,
      communityNotificationsEnabled: true,
      submissionStatusNotificationsEnabled: true,
      marketingNotificationsEnabled: false,
      quietHoursEnabled: false,
      quietHoursStart: '23:00',
      quietHoursEnd: '08:00',
      timezone: 'Europe/Istanbul'
    };

    try {
      const prefsDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('notificationPreferences')
        .doc('main')
        .get();
      if (prefsDoc.exists) {
        prefs = { ...prefs, ...prefsDoc.data() };
      }
    } catch (e) {
      functions.logger.error('⚠️ Tercih yüklenirken hata, varsayılanlar kullanılacak:', e);
    }

    // 2. ADIM 2 - FİLTRE A: Sessiz Saatler kontrolü
    const isKeywordNotif = (notification.reason === 'keyword' || notification.type === 'keyword');
    const isCategoryNotif = (notification.reason === 'category');
    const type = notification.type || '';

    // Admin mesajları sessiz saatlere tabi değildir (resmi/acil bildirimler)
    if (prefs.quietHoursEnabled && (type === 'deal' || type === 'keyword' || type === 'marketing')) {
      const userTime = new Date().toLocaleTimeString('tr-TR', { timeZone: prefs.timezone, hour12: false });
      const currentHm = userTime.substring(0, 5); // "HH:MM"

      const start = prefs.quietHoursStart; // e.g. "23:00"
      const end = prefs.quietHoursEnd; // e.g. "08:00"

      let isQuiet = false;
      if (start <= end) {
        isQuiet = currentHm >= start && currentHm <= end;
      } else {
        isQuiet = currentHm >= start || currentHm <= end;
      }

      if (isQuiet) {
        functions.logger.info(`😴 Sessiz saatlerdeyiz (${currentHm} - ${start}/${end}). Push atlanıyor.`);
        await snap.ref.set({
          pushEligible: false,
          pushStatus: 'skipped_quiet_hours',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        return null;
      }
    }

    // 3. ADIM 2 - FİLTRE B: Kategori Limitleri kontrolü
    const reason = notification.reason || '';
    if (reason === 'category') {
      try {
        const sysConfigDoc = await admin.firestore().collection('systemConfig').doc('notifications').get();
        const sysConfig = sysConfigDoc.exists ? sysConfigDoc.data() : { categoryHourlyLimit: 3, categoryDailyLimit: 8 };

        const now = new Date();
        const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
        const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

        const hourlyCountSnap = await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('reason', '==', 'category')
          .where('pushStatus', '==', 'sent')
          .where('createdAt', '>=', oneHourAgo)
          .count()
          .get();

        const dailyCountSnap = await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('reason', '==', 'category')
          .where('pushStatus', '==', 'sent')
          .where('createdAt', '>=', oneDayAgo)
          .count()
          .get();

        const hourlyCount = hourlyCountSnap.data().count;
        const dailyCount = dailyCountSnap.data().count;

        if (hourlyCount >= sysConfig.categoryHourlyLimit || dailyCount >= sysConfig.categoryDailyLimit) {
          functions.logger.info(`⏳ Kategori limiti aşıldı (Saatlik: ${hourlyCount}/${sysConfig.categoryHourlyLimit}, Günlük: ${dailyCount}/${sysConfig.categoryDailyLimit}). Push atlanıyor.`);
          await snap.ref.set({
            pushEligible: false,
            pushStatus: 'skipped_category_limit',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
          return null;
        }
      } catch (limitErr) {
        functions.logger.error('⚠️ Limit kontrolü sırasında hata, devam ediliyor:', limitErr);
      }
    }

    // 4. ADIM 2 - FİLTRE C ve D: Alt Kanal ve Ana Şalter (Telefon Bildirimleri) Kontrolleri
    if (prefs.pushMasterEnabled === false) {
      functions.logger.info(`🚫 Kullanıcı ${userId} için Telefon Bildirimleri (Master Switch) kapalı. Status: disabled_by_user_master_switch`);
      await snap.ref.set({
        pushEligible: false,
        pushStatus: 'disabled_by_user_master_switch',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      return null;
    }

    let groupEnabled = true;
    let groupName = type || reason;
    const reasons = notification.reasons || {};
    const hasReasons = Object.keys(reasons).length > 0;

    const isKeywordPrefEnabled = prefs.keywordNotificationsEnabled !== false;
    const isDealPrefEnabled = prefs.dealNotificationsEnabled !== false;
    const isCategoryPrefEnabled = prefs.categoryNotificationsEnabled !== false;
    const isCommunityPrefEnabled = prefs.communityNotificationsEnabled !== false;
    const isSubmissionStatusPrefEnabled = prefs.submissionStatusNotificationsEnabled !== false;
    const isMarketingPrefEnabled = prefs.marketingNotificationsEnabled !== false;

    if (hasReasons) {
      // Hangi sebebin aktif olarak kullanılacağını belirleyelim.
      // Öncelik: Eğer belgenin orijinal nedeni kullanıcının tercihlerinde açık ise, onu koru.
      // Değilse, açık olan ilk eşleşen nedeni seç (Sıra: keyword > author > category).
      let activeReason = null;
      let activeDetail = '';

      const originalReason = notification.reason;
      let isOriginalReasonEnabled = false;
      if (originalReason === 'keyword' && isKeywordPrefEnabled) {
        isOriginalReasonEnabled = true;
      } else if (originalReason === 'author' && isDealPrefEnabled) {
        isOriginalReasonEnabled = true;
      } else if (originalReason === 'category' && isCategoryPrefEnabled) {
        isOriginalReasonEnabled = true;
      }

      if (isOriginalReasonEnabled) {
        activeReason = originalReason;
        activeDetail = notification.reasonDetail || '';
      } else {
        if (reasons.keyword && isKeywordPrefEnabled) {
          activeReason = 'keyword';
          activeDetail = reasons.keyword;
        } else if (reasons.author && isDealPrefEnabled) {
          activeReason = 'author';
          activeDetail = reasons.author;
        } else if (reasons.category && isCategoryPrefEnabled) {
          activeReason = 'category';
          activeDetail = reasons.category;
        }
      }

      if (activeReason) {
        groupEnabled = true;
        groupName = activeReason;

        // Eğer aktif olan sebep orijinal sebepten farklı ise bildirim başlığını ve içeriğini güncelle
        if (activeReason !== originalReason) {
          const dealTitle = notification.dealTitle || 'Fırsat';
          let newTitle = notification.title;
          let newBody = notification.body;

          if (activeReason === 'keyword') {
            newTitle = '🎯 İlginizi Çeken Kelime!';
            newBody = `"${activeDetail}" içeren yeni fırsat: ${dealTitle}`;
          } else if (activeReason === 'author') {
            newTitle = '👤 Takip Ettiğiniz Kişi!';
            newBody = `Takip ettiğiniz yazar yeni fırsat paylaştı: ${dealTitle}`;
          } else if (activeReason === 'category') {
            newTitle = '🎯 Yeni Fırsat!';
            newBody = `${dealTitle}`;
          }

          title = newTitle;
          body = newBody;

          // Veritabanını güncelle ki bildirim geçmişi de doğru gözüksün
          await snap.ref.set({
            reason: activeReason,
            reasonDetail: activeDetail,
            title: newTitle,
            body: newBody,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });

          functions.logger.info(`🔄 Bildirim başlığı ve içeriği güncellenen nedene göre dinamik olarak değiştirildi:`, {
            oldReason: originalReason,
            newReason: activeReason,
            newTitle,
            newBody
          });
        }
      } else {
        groupEnabled = false;
        groupName = originalReason || type || 'deal';
      }
    } else {
      if (isKeywordNotif) {
        groupName = 'keyword';
        groupEnabled = isKeywordPrefEnabled;
      } else if (isCategoryNotif) {
        groupName = 'category';
        groupEnabled = isCategoryPrefEnabled;
      } else if (type === 'deal') {
        groupName = 'deal';
        groupEnabled = isDealPrefEnabled;
      } else if (type === 'comment_reply' || type === 'comment') {
        groupName = 'comment_reply';
        groupEnabled = isCommunityPrefEnabled;
      } else if (type === 'submission_status') {
        groupName = 'submission_status';
        groupEnabled = isSubmissionStatusPrefEnabled;
      } else if (type === 'marketing') {
        groupName = 'marketing';
        groupEnabled = isMarketingPrefEnabled;
      } else if (type === 'admin_message') {
        // Admin mesajları her zaman push gönderilir (grup tercihi kontrolüne tabi değil)
        groupName = 'admin_message';
        groupEnabled = true;
      }
    }

    if (!groupEnabled) {
      const status = `disabled_by_user_group_${groupName}`;

      functions.logger.info(`🚫 Kullanıcı ${userId} için bu bildirim grubu kapalı: ${groupName} (Status: ${status})`);
      await snap.ref.set({
        pushEligible: false,
        pushStatus: status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      return null;
    }


    // 6. FCM Push Gönder
    const devices = await getUserDeviceTokens(userId);
    if (devices.length === 0) {
      functions.logger.info(`⚠️ Kullanıcı ${userId} için aktif cihaz token'ı bulunamadı.`);
      await snap.ref.set({
        pushEligible: false,
        pushStatus: 'no_active_devices',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      return null;
    }

    // title and body are already declared and resolved at the top of the function
    const dealId = notification.dealId || '';
    const clickAction = 'FLUTTER_NOTIFICATION_CLICK';

    let channelId = 'sicak_firsatlar_general_v2';
    let sound = 'default';
    let color = '#FF6B35';

    // Admin mesajları için başlığa 🛡️ emoji ekle ve özel kanal kullan
    if (type === 'admin_message') {
      channelId = 'admin_messages_channel_v3';
      color = '#FF5722';
      title = `🛡️ ${title}`;
    } else if (type === 'keyword' || reason === 'keyword') {
      channelId = 'keyword_alerts_channel';
      color = '#FF9800';
    } else if (type === 'comment_reply') {
      channelId = 'comment_replies_channel';
      color = '#2196F3';
    } else if (type === 'submission_status') {
      channelId = 'sicak_firsatlar_general_v2';
      color = '#4CAF50';
    }

    functions.logger.info(`📤 Push ${devices.length} cihaza gönderiliyor...`);

    const promises = devices.map(async (device) => {
      // FCM data payloads can only contain string values. Convert all non-string properties.
      const safeData = {
        type: String(type || ''),
        dealId: String(dealId || ''),
        reason: String(reason || ''),
        click_action: String(clickAction || ''),
        title: String(title || ''),
        body: String(body || ''),
        dealTitle: String(notification.dealTitle || ''),
        reasonDetail: String(notification.reasonDetail || ''),
        notificationId: String(notificationId || ''),
        read: String(notification.read ?? false),
        createdAt: notification.createdAt ? String(notification.createdAt) : '',
        reasons: JSON.stringify(notification.reasons || {}),
        notification_title: String(title || ''),
        notification_body: String(body || '')
      };

      // Admin mesajları için Flutter tarafının doğru yönlendirme yapabilmesi için ek alanlar
      if (type === 'admin_message') {
        safeData.messageId = String(notification.messageId || notificationId || '');
        safeData.senderId = String(notification.senderId || 'admin');
        safeData.senderName = String(notification.senderName || 'FırsatKolik Yönetim');
      }

      // Android notification tag: admin mesajları için messageId bazlı, diğerleri için type_dealId
      const androidTag = type === 'admin_message'
        ? `admin_msg_${notification.messageId || notificationId}`
        : (reason === 'keyword' ? `keyword_${dealId}` : `${type}_${dealId}`);

      // APNs kategori: admin mesajları için ADMIN_MESSAGE, diğerleri için yok
      const apnsCategory = type === 'admin_message' ? 'ADMIN_MESSAGE' : undefined;
      const apnsInterruptionLevel = type === 'admin_message' ? 'time-sensitive' : undefined;

      const payload = {
        token: device.token,
        notification: { title, body },
        data: safeData,
        android: {
          priority: 'high',
          notification: {
            channelId,
            sound,
            color,
            icon: '@mipmap/ic_launcher',
            tag: androidTag,
            defaultSound: true,
            defaultVibrateTimings: true,
          }
        },
        apns: {
          ...(type === 'admin_message' ? {
            headers: {
              'apns-priority': '10',
              'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400),
            }
          } : {}),
          payload: {
            aps: {
              sound,
              badge: 1,
              'content-available': 1,
              ...(apnsInterruptionLevel ? { 'interruption-level': apnsInterruptionLevel } : {}),
              ...(apnsCategory ? { category: apnsCategory } : {}),
            }
          }
        }
      };

      try {
        await admin.messaging().send(payload);
        return { success: true };
      } catch (err) {
        functions.logger.error(`❌ FCM gönderim hatası (device: ${device.id}):`, err);
        if (device.id) {
          await handleSendFailure(device.id, err);
        }
        return { success: false, error: err };
      }
    });

    const results = await Promise.all(promises);
    const successCount = results.filter(r => r.success).length;

    await snap.ref.set({
      pushEligible: true,
      pushStatus: successCount > 0 ? 'sent' : 'failed',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    functions.logger.info(`✅ Push gönderim süreci tamamlandı. Başarılı cihaz sayısı: ${successCount}/${devices.length}`);
    return null;
  }));

// Kısa linki gerçek URL'ye dönüştürme fonksiyonu
exports.resolveShortLink = functions.https.onRequest(wrapRequest('resolveShortLink', async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const shortUrl = req.query.url || req.body.url;

    if (!shortUrl) {
      res.status(400).json({
        error: 'URL parametresi gerekli',
        success: false
      });
      return;
    }

    functions.logger.info('🔗 Kısa link çözülüyor:', shortUrl);

    // Kısa linki çöz (redirect takibi)
    const resolvedUrl = await resolveRedirect(shortUrl);

    if (resolvedUrl) {
      functions.logger.info('✅ Kısa link çözüldü:', {
        original: shortUrl,
        resolved: resolvedUrl
      });

      res.status(200).json({
        success: true,
        originalUrl: shortUrl,
        resolvedUrl: resolvedUrl
      });
    } else {
      functions.logger.warn('⚠️ Kısa link çözülemedi:', shortUrl);
      res.status(404).json({
        success: false,
        error: 'Kısa link çözülemedi',
        originalUrl: shortUrl
      });
    }
  } catch (error) {
    functions.logger.error('❌ Kısa link çözme hatası:', {
      error: error.message,
      stack: error.stack
    });

    res.status(500).json({
      success: false,
      error: error.message
    });
  }
}));

// Redirect takibi yapan helper fonksiyon
function resolveRedirect(url) {
  return new Promise((resolve, reject) => {
    try {
      const initialUrlObj = new URL(url);
      const initialProtocol = initialUrlObj.protocol === 'https:' ? https : http;
      const maxRedirects = 10;
      let redirectCount = 0;
      let currentUrl = url;

      function followRedirect(location) {
        if (redirectCount >= maxRedirects) {
          reject(new Error('Maksimum redirect sayısına ulaşıldı'));
          return;
        }

        redirectCount++;
        currentUrl = location;

        // Eğer relative URL ise, base URL ile birleştir
        if (!location.startsWith('http://') && !location.startsWith('https://')) {
          const baseUrl = new URL(currentUrl);
          location = new URL(location, baseUrl.origin).toString();
        }

        const redirectUrlObj = new URL(location);
        const redirectProtocol = redirectUrlObj.protocol === 'https:' ? https : http;

        const options = {
          hostname: redirectUrlObj.hostname,
          port: redirectUrlObj.port || (redirectUrlObj.protocol === 'https:' ? 443 : 80),
          path: redirectUrlObj.pathname + redirectUrlObj.search,
          method: 'HEAD',
          followRedirect: false,
          timeout: 10000
        };

        const req = redirectProtocol.request(options, (res) => {
          if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
            // Redirect var, takip et
            followRedirect(res.headers.location);
          } else if (res.statusCode === 200 || res.statusCode === 301 || res.statusCode === 302) {
            // Final URL bulundu
            resolve(location);
          } else {
            // Final URL (redirect yok)
            resolve(location);
          }
        });

        req.on('error', (error) => {
          reject(error);
        });

        req.on('timeout', () => {
          req.destroy();
          reject(new Error('Request timeout'));
        });

        req.end();
      }

      // İlk request
      const firstUrlObj = new URL(currentUrl);
      const firstProtocol = firstUrlObj.protocol === 'https:' ? https : http;

      const options = {
        hostname: firstUrlObj.hostname,
        port: firstUrlObj.port || (firstUrlObj.protocol === 'https:' ? 443 : 80),
        path: firstUrlObj.pathname + firstUrlObj.search,
        method: 'HEAD',
        followRedirect: false,
        timeout: 10000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; AffiliateLinkResolver/1.0)'
        }
      };

      const req = firstProtocol.request(options, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          // Redirect var, takip et
          followRedirect(res.headers.location);
        } else {
          // Final URL (redirect yok veya final URL)
          resolve(currentUrl);
        }
      });

      req.on('error', (error) => {
        reject(error);
      });

      req.on('timeout', () => {
        req.destroy();
        reject(new Error('Request timeout'));
      });

      req.end();
    } catch (error) {
      reject(error);
    }
  });
}



/**
 * 📷 ESKİ GÖRSELLERİ TEMİZLE - Her gün gece yarısı çalışır
 * 30 günden eski sahipsiz/eski deal görsellerini Firebase Storage'dan siler
 */
exports.cleanupOldImages = functions
  .runWith({ timeoutSeconds: 300, memory: '512MB' })
  .pubsub.schedule('0 0 * * *') // Her gün gece 00:00'da çalışır
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('cleanupOldImages', async (context) => {
    functions.logger.info('🧹 Eski görsel temizleme başlıyor (30 Günlük)...');

    const bucket = admin.storage().bucket();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    let deletedCount = 0;
    let errorCount = 0;
    let skippedCount = 0;

    try {
      // deals/ klasöründeki tüm dosyaları listele
      const [files] = await bucket.getFiles({ prefix: 'deals/' });

      functions.logger.info(`📂 ${files.length} dosya bulundu`);

      for (const file of files) {
        try {
          // Dosya metadata'sını al
          const [metadata] = await file.getMetadata();
          const createdTime = new Date(metadata.timeCreated);

          // 30 günden eski mi kontrol et
          if (createdTime < thirtyDaysAgo) {
            await file.delete();
            deletedCount++;
            functions.logger.info(`🗑️ Silindi: ${file.name} (${createdTime.toISOString()})`);
          } else {
            skippedCount++;
          }
        } catch (fileError) {
          errorCount++;
          functions.logger.error(`❌ Dosya işleme hatası (${file.name}):`, fileError.message);
        }
      }

      functions.logger.info(`✅ Temizlik tamamlandı! Silinen: ${deletedCount}, Atlanan: ${skippedCount}, Hata: ${errorCount}`);

      // İstatistikleri kaydet
      await admin.firestore().collection('system').doc('cleanup_stats').set({
        lastRun: admin.firestore.FieldValue.serverTimestamp(),
        deletedCount,
        skippedCount,
        errorCount,
        totalFiles: files.length,
      }, { merge: true });

    } catch (error) {
      functions.logger.error('❌ Görsel temizleme genel hatası:', error);
    }

    return null;
  }));

/**
 * 📷 MANUEL GÖRSELLERİ TEMİZLE - HTTP ile tetiklenir (test için)
 * Kullanım: GET veya POST isteği at
 */
exports.cleanupOldImagesManual = functions
  .runWith({ timeoutSeconds: 300, memory: '512MB' })
  .https.onRequest(wrapRequest('cleanupOldImagesManual', async (req, res) => {
    functions.logger.info('🧹 Manuel görsel temizleme başlıyor (30 Günlük)...');

    const bucket = admin.storage().bucket();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    let deletedCount = 0;
    let errorCount = 0;
    let skippedCount = 0;
    const deletedFiles = [];

    try {
      const [files] = await bucket.getFiles({ prefix: 'deals/' });

      for (const file of files) {
        try {
          const [metadata] = await file.getMetadata();
          const createdTime = new Date(metadata.timeCreated);

          if (createdTime < thirtyDaysAgo) {
            await file.delete();
            deletedCount++;
            deletedFiles.push({ name: file.name, createdAt: createdTime.toISOString() });
          } else {
            skippedCount++;
          }
        } catch (fileError) {
          errorCount++;
        }
      }

      res.status(200).json({
        success: true,
        message: `Temizlik tamamlandı`,
        stats: {
          totalFiles: files.length,
          deletedCount,
          skippedCount,
          errorCount,
        },
        deletedFiles: deletedFiles.slice(0, 20),
        threshold: thirtyDaysAgo.toISOString(),
      });

    } catch (error) {
      functions.logger.error('❌ Manuel temizleme hatası:', error);
      res.status(500).json({ error: error.message });
    }
  }));

// Gemini AI Proxy Cloud Function
const { GoogleGenerativeAI } = require('@google/generative-ai');

exports.analyzeProductProxy = functions
  .runWith({ secrets: ['GEMINI_API_KEY'], timeoutSeconds: 60, memory: '256MB' })
  .https.onRequest(wrapRequest('analyzeProductProxy', async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, X-Firebase-AppCheck');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    // App Check doğrulaması
    const appCheckToken = req.header('X-Firebase-AppCheck');
    if (!appCheckToken) {
      functions.logger.warn('⚠️ Missing App Check token');
      res.status(401).json({ error: 'Unauthorized: Missing App Check token', success: false });
      return;
    }
    try {
      await admin.appCheck().verifyToken(appCheckToken);
    } catch (err) {
      functions.logger.error('❌ App Check verification failed:', err.message);
      res.status(401).json({ error: 'Unauthorized: Invalid App Check token', success: false });
      return;
    }

    let isError = false;
    let isJsonError = false;
    let estimatedCost = 0.0001; // default fallback cost
    let responseText = '';

    try {
      const { contents, generationConfig } = req.body;
      if (!contents) {
        res.status(400).json({ error: 'Missing contents in request body', success: false });
        return;
      }

      const geminiApiKey = process.env.GEMINI_API_KEY;
      if (!geminiApiKey) {
        res.status(500).json({ error: 'Gemini API Key is not configured on the server', success: false });
        return;
      }

      functions.logger.info('🤖 Calling Gemini API via proxy...');
      const genAI = new GoogleGenerativeAI(geminiApiKey);
      const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

      const result = await model.generateContent({
        contents: contents,
        generationConfig: generationConfig
      });

      const response = await result.response;
      responseText = response.text();

      // Estimate cost based on usageMetadata if available
      try {
        const usage = response.usageMetadata;
        if (usage) {
          const inputTokens = usage.promptTokenCount || 0;
          const outputTokens = usage.candidatesTokenCount || 0;
          estimatedCost = (inputTokens * 0.075 / 1000000) + (outputTokens * 0.30 / 1000000);
        }
      } catch (useErr) {
        functions.logger.warn('⚠️ Usage estimation error:', useErr.message);
      }

      // Check if valid JSON (if output format is JSON)
      if (generationConfig && generationConfig.responseMimeType === 'application/json') {
        try {
          JSON.parse(responseText.replace(/```json/g, '').replace(/```/g, '').trim());
        } catch (jsonErr) {
          isJsonError = true;
          functions.logger.warn('⚠️ Gemini output was not valid JSON:', jsonErr.message);
        }
      }

      res.status(200).json({
        success: true,
        text: responseText
      });
    } catch (error) {
      isError = true;
      throw error; // Re-throw to let wrapRequest log it to systemErrors!
    } finally {
      // Update FireStore settings/geminiStatus
      try {
        const todayStr = new Date().toISOString().split('T')[0];
        const statusRef = admin.firestore().collection('settings').doc('geminiStatus');

        await admin.firestore().runTransaction(async (transaction) => {
          const doc = await transaction.get(statusRef);
          if (doc.exists && doc.data().date === todayStr) {
            transaction.update(statusRef, {
              dailyRequests: admin.firestore.FieldValue.increment(1),
              dailyErrors: admin.firestore.FieldValue.increment(isError ? 1 : 0),
              dailyJsonErrors: admin.firestore.FieldValue.increment(isJsonError ? 1 : 0),
              dailyCost: admin.firestore.FieldValue.increment(isError ? 0 : estimatedCost),
              lastRequestAt: admin.firestore.FieldValue.serverTimestamp(),
              status: isError ? 'error' : 'online',
              model: 'Gemini 2.5/2.0 Flash'
            });
          } else {
            transaction.set(statusRef, {
              date: todayStr,
              dailyRequests: 1,
              dailyErrors: isError ? 1 : 0,
              dailyJsonErrors: isJsonError ? 1 : 0,
              dailyCost: isError ? 0 : estimatedCost,
              lastRequestAt: admin.firestore.FieldValue.serverTimestamp(),
              status: isError ? 'error' : 'online',
              model: 'Gemini 2.5/2.0 Flash'
            });
          }
        });
        functions.logger.info('🤖 Gemini Status updated successfully.');
      } catch (dbErr) {
        functions.logger.error('❌ Failed to update Gemini Status:', dbErr.message);
      }
    }
  }));

/**
 * 11. Manuel Bildirim Gönderimi (Callable) - FAZ 3
 */
exports.sendManualNotification = functions.https.onCall(wrapCall('sendManualNotification', async (data, context) => {
  // Admin yetki kontrolü
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
  }

  const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const isAdmin = userDoc.exists && (
    userDoc.data().isAdmin === true ||
    userDoc.data().isadmin === true ||
    userDoc.data().isAdmin === 'true' ||
    userDoc.data().isadmin === 'true'
  );

  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Bu işlem için yetkiniz yok.');
  }

  const { title, body, imageUrl, targetType, targetValue } = data;

  if (!title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Başlık ve mesaj içeriği zorunludur.');
  }

  // FCM Mesaj Gövdesi
  const message = {
    notification: {
      title: title,
      body: body
    },
    data: {
      type: 'manual_notification',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      title: title,
      body: body
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'sicak_firsatlar_general_v2',
        sound: 'default'
      }
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1
        }
      }
    }
  };

  if (imageUrl) {
    message.android.notification.imageUrl = imageUrl;
    message.apns.fcm_options = { image: imageUrl };
    message.data.imageUrl = imageUrl;
  }

  // Hedef Tanımlama ve Gönderim
  const logRef = admin.firestore().collection('notificationLogs').doc();
  const sentBy = context.auth.uid;
  const sentAt = admin.firestore.FieldValue.serverTimestamp();

  try {
    functions.logger.info(`🤖 Manuel bildirim gönderiliyor. Hedef: ${targetType}`);
    let responseId = 'written_to_notifications';

    if (targetType === 'all') {
      const usersSnap = await admin.firestore().collection('users').get();
      let batch = admin.firestore().batch();
      let opCount = 0;
      const notificationId = `manual_${logRef.id}`;

      for (const userDoc of usersSnap.docs) {
        const userId = userDoc.id;
        const notificationRef = admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId);

        batch.set(notificationRef, {
          type: 'admin_message',
          title: title,
          body: body,
          imageUrl: imageUrl || null,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        opCount++;
        if (opCount >= 400) {
          await batch.commit();
          batch = admin.firestore().batch();
          opCount = 0;
        }
      }
      if (opCount > 0) {
        await batch.commit();
      }
      responseId = `written_to_notifications_of_${usersSnap.size}_users`;

    } else if (targetType === 'token') {
      message.token = targetValue;
      responseId = await admin.messaging().send(message);

    } else if (targetType === 'uid') {
      const notificationId = `manual_${logRef.id}`;
      const notificationRef = admin.firestore()
        .collection('users')
        .doc(targetValue)
        .collection('notifications')
        .doc(notificationId);

      await notificationRef.set({
        type: 'admin_message',
        title: title,
        body: body,
        imageUrl: imageUrl || null,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      responseId = `written_to_notifications_of_${targetValue}`;

    } else {
      throw new functions.https.HttpsError('invalid-argument', 'Geçersiz hedef türü.');
    }

    // Başarılı log kaydet
    await logRef.set({
      id: logRef.id,
      title,
      body,
      imageUrl: imageUrl || null,
      targetType,
      targetValue: targetValue || null,
      sentAt,
      sentBy,
      status: 'success',
      responseId
    });

    // Günlük istatistik güncelle (çizgi grafik için)
    const todayStr = new Date().toISOString().split('T')[0];
    const statRef = admin.firestore().collection('notificationStats').doc(todayStr);
    await statRef.set({
      date: todayStr,
      count: admin.firestore.FieldValue.increment(1)
    }, { merge: true });

    return { success: true, responseId };
  } catch (error) {
    functions.logger.error('❌ Manuel bildirim gönderme hatası:', error.message);

    // Başarısız log kaydet
    await logRef.set({
      id: logRef.id,
      title,
      body,
      imageUrl: imageUrl || null,
      targetType,
      targetValue: targetValue || null,
      sentAt,
      sentBy,
      status: 'failed',
      error: error.message
    });

    throw error; // Re-throw to let wrapCall log it to systemErrors!
  }
}));

/**
 * 12. Geçersiz FCM Token'larının Temizleme (Callable) - FAZ 3
 */
exports.cleanupInvalidTokens = functions.https.onCall(wrapCall('cleanupInvalidTokens', async (data, context) => {
  // Admin yetki kontrolü
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
  }

  const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const isAdmin = userDoc.exists && (
    userDoc.data().isAdmin === true ||
    userDoc.data().isadmin === true ||
    userDoc.data().isAdmin === 'true' ||
    userDoc.data().isadmin === 'true'
  );

  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Bu işlem için yetkiniz yok.');
  }

  try {
    functions.logger.info('🤖 Geçersiz token temizleme işlemi başlatıldı (userDevices)...');

    const devicesSnap = await admin.firestore().collection('userDevices')
      .where('active', '==', true)
      .limit(500)
      .get();

    let checkedCount = 0;
    let cleanedCount = 0;

    const promises = devicesSnap.docs.map(async (doc) => {
      const data = doc.data();
      const fcmToken = data.fcmToken;
      if (!fcmToken) return;

      checkedCount++;
      try {
        // FCM Dry Run (Gerçek gönderme yapmaz, sadece doğrular)
        await admin.messaging().send({
          token: fcmToken,
          data: { dryRun: 'true' }
        }, true);
      } catch (error) {
        if (
          error.code === 'messaging/invalid-registration-token' ||
          error.code === 'messaging/registration-token-not-registered'
        ) {
          functions.logger.info(`🔥 Geçersiz token pasifleştiriliyor. Cihaz ID: ${doc.id}`);
          await doc.ref.update({
            active: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          cleanedCount++;
        }
      }
    });

    await Promise.all(promises);

    return {
      success: true,
      checkedCount,
      cleanedCount
    };
  } catch (error) {
    throw error; // Re-throw to let wrapCall log it to systemErrors!
  }
}));

/**
 * Storage'dan Fırsat Görselini Silen Yardımcı Fonksiyon
 */
async function deleteDealImage(imageUrl) {
  if (!imageUrl || !imageUrl.includes('firebasestorage.googleapis.com')) return;
  try {
    const match = imageUrl.match(/\/o\/([^?]+)/);
    if (match && match[1]) {
      const filePath = decodeURIComponent(match[1]);
      const bucket = admin.storage().bucket();
      const file = bucket.file(filePath);
      const [exists] = await file.exists();
      if (exists) {
        await file.delete();
        functions.logger.info(`🗑️ Storage'dan silindi: ${filePath}`);
      }
    }
  } catch (error) {
    functions.logger.error(`❌ Storage görsel silme hatası:`, error.message);
  }
}

/**
 * ⌛ 48 Saat Geçen Fırsatları Süresi Doldu (isExpired: true) Olarak İşaretler
 * Fırsatlar veritabanından SİLİNMEZ, 30 gün boyunca kullanıcının favorilerinde ve arşivde orijinal görseliyle kalır.
 */
exports.cleanupExpiredDeals = functions
  .runWith({ timeoutSeconds: 360, memory: '512MB' })
  .pubsub.schedule('0 3 * * *') // Her gün gece 03:00'da çalışır
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('cleanupExpiredDeals', async (context) => {
    functions.logger.info('⌛ 48 saatlik eski fırsatları süresi doldu olarak işaretleme görevi başladı...');

    const now = new Date();
    const fortyEightHoursAgo = new Date(now.getTime() - (48 * 60 * 60 * 1000));

    let expiredCount = 0;
    let errorCount = 0;

    try {
      const db = admin.firestore();
      const targetDocs = new Map();

      // 1. 48 saatten eski olup henüz isExpired=true yapılmamış fırsatları bul
      const snap1 = await db.collection('deals')
        .where('createdAt', '<', fortyEightHoursAgo)
        .where('isExpired', '==', false)
        .get();
      snap1.forEach(doc => targetDocs.set(doc.id, doc));

      const snap2 = await db.collection('deals')
        .where('timestamp', '<', fortyEightHoursAgo)
        .where('isExpired', '==', false)
        .get();
      snap2.forEach(doc => targetDocs.set(doc.id, doc));

      functions.logger.info(`🔍 Toplam süresi doldu işaretlenecek ${targetDocs.size} eski fırsat bulundu.`);

      const batchSize = 400;
      let batch = db.batch();
      let countInBatch = 0;

      for (const [dealId, doc] of targetDocs) {
        try {
          batch.update(doc.ref, {
            isExpired: true,
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          countInBatch++;
          expiredCount++;

          if (countInBatch >= batchSize) {
            await batch.commit();
            batch = db.batch();
            countInBatch = 0;
          }
        } catch (docError) {
          errorCount++;
          functions.logger.error(`❌ Fırsat süresi doldu işaretleme hatası (${dealId}):`, docError.message);
        }
      }

      if (countInBatch > 0) {
        await batch.commit();
      }

      functions.logger.info(`✅ 48 saatlik fırsat süresi doldu işaretlemesi bitti. İşaretlenen: ${expiredCount}, Hata: ${errorCount}`);
    } catch (error) {
      functions.logger.error('❌ Fırsat süresi doldu işaretleme genel hatası:', error);
    }

    return null;
  }));

/**
 * ⌛ MANUEL ESKİ FIRSATLARI SÜRESİ DOLDU YAP - HTTP ile tetiklenir (test için)
 * Kullanım: GET veya POST isteği at
 */
exports.cleanupExpiredDealsManual = functions
  .runWith({ timeoutSeconds: 360, memory: '512MB' })
  .https.onRequest(wrapRequest('cleanupExpiredDealsManual', async (req, res) => {
    functions.logger.info('⌛ Manuel 48 saatlik fırsat süresi doldu işaretleme başlıyor...');

    const now = new Date();
    const fortyEightHoursAgo = new Date(now.getTime() - (48 * 60 * 60 * 1000));

    let expiredCount = 0;
    let errorCount = 0;
    const updatedDeals = [];

    try {
      const db = admin.firestore();
      const targetDocs = new Map();

      const snap1 = await db.collection('deals')
        .where('createdAt', '<', fortyEightHoursAgo)
        .where('isExpired', '==', false)
        .get();
      snap1.forEach(doc => targetDocs.set(doc.id, doc));

      const snap2 = await db.collection('deals')
        .where('timestamp', '<', fortyEightHoursAgo)
        .where('isExpired', '==', false)
        .get();
      snap2.forEach(doc => targetDocs.set(doc.id, doc));

      const batchSize = 400;
      let batch = db.batch();
      let countInBatch = 0;

      for (const [dealId, doc] of targetDocs) {
        try {
          const deal = doc.data();
          batch.update(doc.ref, {
            isExpired: true,
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          countInBatch++;
          expiredCount++;
          updatedDeals.push({ id: dealId, title: deal.title });

          if (countInBatch >= batchSize) {
            await batch.commit();
            batch = db.batch();
            countInBatch = 0;
          }
        } catch (docError) {
          errorCount++;
        }
      }

      if (countInBatch > 0) {
        await batch.commit();
      }

      res.status(200).json({
        success: true,
        message: 'Fırsat süresi doldu işaretleme tamamlandı (Fırsatlar silinmedi, arşivlendi).',
        stats: {
          totalFound: targetDocs.size,
          expiredCount,
          errorCount
        },
        updatedDeals
      });
    } catch (error) {
      functions.logger.error('❌ Manuel süresi doldu işaretleme genel hatası:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  }));

/**
 * 🔥 30 GÜN GEÇMİŞ FIRSATLARI KALıCı OLARAK SİLER (Haftalık)
 * Deals dokümanı + subcollection'ları (votes, comments) + tüm kullanıcıların
 * favorites referansları + Storage görselleri dahil tüm izleri temizler.
 */
async function _purgeOldDealsCore() {
  const db = admin.firestore();
  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));

  let deletedCount = 0;
  let errorCount = 0;
  const deletedDeals = [];

  // 1. 30 günden eski deal'leri bul
  const targetDocIds = new Set();
  const docsToDelete = [];

  const snap1 = await db.collection('deals').where('createdAt', '<', thirtyDaysAgo).get();
  snap1.forEach(doc => {
    if (!targetDocIds.has(doc.id)) {
      targetDocIds.add(doc.id);
      docsToDelete.push(doc);
    }
  });

  const snap2 = await db.collection('deals').where('timestamp', '<', thirtyDaysAgo).get();
  snap2.forEach(doc => {
    if (!targetDocIds.has(doc.id)) {
      targetDocIds.add(doc.id);
      docsToDelete.push(doc);
    }
  });

  functions.logger.info(`🔍 30 günden eski ${docsToDelete.length} fırsat bulundu. Kalıcı silme başlıyor...`);

  for (const doc of docsToDelete) {
    try {
      const deal = doc.data();
      const dealId = doc.id;
      const dealRef = db.collection('deals').doc(dealId);

      // A. Subcollection: votes silme
      const votesSnap = await dealRef.collection('votes').get();
      if (!votesSnap.empty) {
        const batch = db.batch();
        votesSnap.docs.forEach(v => batch.delete(v.ref));
        await batch.commit();
      }

      // B. Subcollection: comments silme
      const commentsSnap = await dealRef.collection('comments').get();
      if (!commentsSnap.empty) {
        const batch = db.batch();
        commentsSnap.docs.forEach(c => batch.delete(c.ref));
        await batch.commit();
      }

      // C. Tüm kullanıcıların favorites'ından bu deal referansını sil
      const usersSnap = await db.collection('users').get();
      for (const userDoc of usersSnap.docs) {
        try {
          const favRef = userDoc.ref.collection('favorites').doc(dealId);
          const favDoc = await favRef.get();
          if (favDoc.exists) {
            await favRef.delete();
          }
        } catch (favErr) {
          // Sessizce devam et — kullanıcı bazında hata önemsiz
        }
      }

      // D. Storage görselini sil
      const url = deal.imageUrl || deal.image_url;
      if (url) {
        await deleteDealImage(url);
      }

      // E. Deal dokümanını sil
      await dealRef.delete();
      deletedCount++;
      deletedDeals.push({ id: dealId, title: deal.title || 'Başlıksız' });
      functions.logger.info(`🗑️ Kalıcı silindi: ${dealId} - ${deal.title}`);
    } catch (docError) {
      errorCount++;
      functions.logger.error(`❌ Deal kalıcı silme hatası (${doc.id}):`, docError.message);
    }
  }

  // F. 30 Günü Geçmiş Tüm Bildirimleri Temizle (Notification Center / users/{uid}/notifications)
  let deletedNotificationsCount = 0;
  try {
    const notifResult = await _purgeOldNotificationsCore(30);
    deletedNotificationsCount = notifResult.deletedNotificationsCount;
  } catch (notifErr) {
    functions.logger.error('❌ Eski bildirimleri silme sırasında hata:', notifErr.message);
  }

  functions.logger.info(`✅ 30 günlük derin temizlik bitti. Silinen Fırsat: ${deletedCount}, Silinen Bildirim: ${deletedNotificationsCount}, Hata: ${errorCount}`);
  return {
    totalFound: docsToDelete.length,
    deletedCount,
    deletedNotificationsCount,
    errorCount,
    deletedDeals
  };
}

/**
 * 🧹 30 GÜNÜ GEÇMİŞ TÜM BİLDİRİMLERİ SİLME (Core)
 * users/{userId}/notifications subcollection'larındaki 30 günden eski
 * tüm bildirim dokümanlarını (collectionGroup) batch halinde siler.
 */
async function _purgeOldNotificationsCore(days = 30) {
  const db = admin.firestore();
  const cutoffDate = new Date(Date.now() - (days * 24 * 60 * 60 * 1000));

  functions.logger.info(`🧹 ${days} günden eski bildirimleri temizleme başladı. Eşik tarihi: ${cutoffDate.toISOString()}`);

  let totalDeleted = 0;
  let hasMore = true;

  while (hasMore) {
    const snap = await db.collectionGroup('notifications')
      .where('createdAt', '<', cutoffDate)
      .limit(400)
      .get();

    if (snap.empty) {
      hasMore = false;
      break;
    }

    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    totalDeleted += snap.size;
    functions.logger.info(`🗑️ ${snap.size} adet eski bildirim silindi (Toplam: ${totalDeleted})`);

    if (snap.size < 400) {
      hasMore = false;
    }
  }

  functions.logger.info(`✅ Eski bildirim temizliği tamamlandı. Toplam silinen bildirim sayısı: ${totalDeleted}`);
  return { deletedNotificationsCount: totalDeleted };
}

exports.purgeOldDeals = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .pubsub.schedule('0 4 * * 0') // Her Pazar 04:00'da çalışır
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('purgeOldDeals', async (context) => {
    functions.logger.info('🔥 30 günlük fırsat ve bildirim kalıcı silme görevi başladı...');
    await _purgeOldDealsCore();
    return null;
  }));

exports.purgeOldDealsManual = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .https.onCall(wrapCall('purgeOldDealsManual', async (data, context) => {
    // Admin kontrolü
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Giriş yapmalısınız.');
    }
    const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const isCallerAdmin = callerDoc.exists && (
      callerDoc.data().isAdmin === true ||
      callerDoc.data().isadmin === true ||
      callerDoc.data().isAdmin === 'true' ||
      callerDoc.data().isadmin === 'true' ||
      callerDoc.data().role === 'admin'
    );
    if (!isCallerAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin yetkisi gerekli.');
    }

    functions.logger.info(`🔥 Admin ${context.auth.uid} tarafından manuel kalıcı silme tetiklendi.`);
    const result = await _purgeOldDealsCore();
    return {
      success: true,
      message: `${result.deletedCount} fırsat ve ${result.deletedNotificationsCount} eski bildirim kalıcı olarak silindi.`,
      stats: result
    };
  }));

exports.purgeOldNotificationsManual = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .https.onCall(wrapCall('purgeOldNotificationsManual', async (data, context) => {
    // Admin kontrolü
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Giriş yapmalısınız.');
    }
    const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const isCallerAdmin = callerDoc.exists && (
      callerDoc.data().isAdmin === true ||
      callerDoc.data().isadmin === true ||
      callerDoc.data().isAdmin === 'true' ||
      callerDoc.data().isadmin === 'true' ||
      callerDoc.data().role === 'admin'
    );
    if (!isCallerAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin yetkisi gerekli.');
    }

    const days = (data && data.days) ? parseInt(data.days, 10) : 30;
    functions.logger.info(`🔥 Admin ${context.auth.uid} tarafından manuel bildirim temizleme tetiklendi (${days} günlük).`);
    const result = await _purgeOldNotificationsCore(days);
    return {
      success: true,
      message: `${result.deletedNotificationsCount} adet ${days} günden eski bildirim kalıcı olarak silindi.`,
      stats: result
    };
  }));

/**
 * 14. KULLANICI AUTH HESABI SİLİNDİĞİNDE TETİKLENEN SİLME İŞLEMİ
 * Kullanıcıya ait Firestore'daki tüm verileri (profil, fırsatlar, cihazlar, abonelikler, yorumlar vb.) kalıcı olarak siler.
 */
exports.onUserDeleted = functions.auth.user().onDelete(wrapTrigger('onUserDeleted', async (user, context) => {
  const userId = user.uid;
  functions.logger.info(`🗑️ User deletion trigger started for user: ${userId}`);

  const db = admin.firestore();

  // Yardımcı Batch silme fonksiyonu
  async function deleteQueryBatch(query) {
    const snapshot = await query.get();
    if (snapshot.empty) return;
    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }

  // 1. Cihaz kayıtlarını sil (userDevices)
  try {
    const devicesQuery = db.collection('userDevices').where('uid', '==', userId);
    await deleteQueryBatch(devicesQuery);
    functions.logger.info(`✅ userDevices silindi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ userDevices silme hatası:`, err);
  }

  // 2. Bildirim aboneliklerini sil (notificationSubscriptions)
  try {
    const subsQuery = db.collection('notificationSubscriptions').where('uid', '==', userId);
    await deleteQueryBatch(subsQuery);
    functions.logger.info(`✅ notificationSubscriptions silindi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ notificationSubscriptions silme hatası:`, err);
  }

  // 3. Kullanıcının kendi fırsatlarını (ve bu fırsatların yorumlarını) sil
  try {
    const dealsSnap = await db.collection('deals').where('postedBy', '==', userId).get();
    for (const dealDoc of dealsSnap.docs) {
      // Önce fırsatın altındaki yorumları sil
      const commentsQuery = dealDoc.ref.collection('comments');
      await deleteQueryBatch(commentsQuery);
      // Fırsatı sil
      await dealDoc.ref.delete();
    }
    functions.logger.info(`✅ Kullanıcı fırsatları ve alt yorumları silindi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Fırsat silme hatası:`, err);
  }

  // 4. Kullanıcının diğer fırsatlara yazdığı yorumları sil (collectionGroup)
  try {
    const userCommentsQuery = db.collectionGroup('comments').where('userId', '==', userId);
    await deleteQueryBatch(userCommentsQuery);
    functions.logger.info(`✅ Kullanıcı tarafından yazılan yorumlar silindi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Yorum silme hatası:`, err);
  }

  // 5. Direkt mesajları sil (messages)
  try {
    const sentMsgQuery = db.collection('messages').where('senderId', '==', userId);
    await deleteQueryBatch(sentMsgQuery);
    const recvMsgQuery = db.collection('messages').where('receiverId', '==', userId);
    await deleteQueryBatch(recvMsgQuery);
    functions.logger.info(`✅ Mesajlar silindi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Mesaj silme hatası:`, err);
  }

  // 6. Raporları sil (reports)
  try {
    const sentRepQuery = db.collection('reports').where('reportedBy', '==', userId);
    await deleteQueryBatch(sentRepQuery);
    const recvRepQuery = db.collection('reports').where('reportedId', '==', userId);
    await deleteQueryBatch(recvRepQuery);
    functions.logger.info(`✅ Raporlar silindi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Rapor silme hatası:`, err);
  }

  // 7. Ban ve engelleme kayıtlarını sil
  try {
    await db.collection('blockedUsers').doc(userId).delete();
    await db.collection('commentBannedUsers').doc(userId).delete();
    await db.collection('dealBannedUsers').doc(userId).delete();
    functions.logger.info(`✅ Ban/Engel kayıtları temizlendi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Ban/Engel silme hatası:`, err);
  }

  // 8. Kullanıcının alt koleksiyonlarını sil (notifications, notificationPreferences, favorites)
  try {
    const userRef = db.collection('users').doc(userId);
    await deleteQueryBatch(userRef.collection('notifications'));
    await deleteQueryBatch(userRef.collection('notificationPreferences'));
    await deleteQueryBatch(userRef.collection('favorites'));
    // Kullanıcı ana dokümanını sil
    await userRef.delete();
    functions.logger.info(`✅ Kullanıcı profil dokümanı ve alt koleksiyonları silindi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Profil/alt koleksiyon silme hatası:`, err);
  }

  functions.logger.info(`🎉 User deletion trigger finished successfully for user: ${userId}`);
  return null;
}));

/**
 * 15. ADMİN TARAFINDAN KULLANICI HESABINI SİLME (Callable)
 * Sadece adminler tetikleyebilir. Firebase Auth'dan kullanıcıyı siler, bu da onUserDeleted trigger'ını çalıştırır.
 */
exports.adminDeleteUser = functions.https.onCall(wrapCall('adminDeleteUser', async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
  }

  const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const isCallerAdmin = callerDoc.exists && (
    callerDoc.data().isAdmin === true ||
    callerDoc.data().isadmin === true ||
    callerDoc.data().isAdmin === 'true' ||
    callerDoc.data().isadmin === 'true'
  );

  if (!isCallerAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Sadece adminler bu işlemi yapabilir.');
  }

  const targetUid = data.targetUid;
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'Hedef kullanıcı UID belirtilmedi.');
  }

  if (targetUid === context.auth.uid) {
    throw new functions.https.HttpsError('invalid-argument', 'Kendi kendinizi silemezsiniz.');
  }

  try {
    functions.logger.info(`👮 Admin ${context.auth.uid} tarafından kullanıcı siliniyor: ${targetUid}`);

    // Auth'dan siler (bu işlem otomatik olarak onUserDeleted Firestore tetikleyicisini çalıştıracaktır!)
    await admin.auth().deleteUser(targetUid);

    functions.logger.info(`✅ Kullanıcı Auth'dan başarıyla silindi: ${targetUid}`);
    return { success: true };
  } catch (error) {
    functions.logger.error(`❌ Admin kullanıcı silme hatası (${targetUid}):`, error);
    throw new functions.https.HttpsError('internal', `Kullanıcı silinemedi: ${error.message}`);
  }
}));

/**
 * 16. TEST DATA JENERATÖRÜ (Callable) - Sadece Adminler
 * Test kullanıcısı oluşturur, ilişkili cihazları, ayarları ve mock fırsatları ekler.
 */
exports.generateTestData = functions.https.onCall(wrapCall('generateTestData', async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
  }

  const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const isCallerAdmin = callerDoc.exists && (
    callerDoc.data().isAdmin === true ||
    callerDoc.data().isadmin === true ||
    callerDoc.data().isAdmin === 'true' ||
    callerDoc.data().isadmin === 'true'
  );

  if (!isCallerAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Sadece adminler bu işlemi yapabilir.');
  }

  const emailInput = data.email || 'testuser';
  const username = data.username || 'TestKullanici';
  const dealsCount = parseInt(data.dealsCount) || 3;

  // Güvenlik için e-postayı zorunlu olarak @test.firsatkolik.com uzantılı yapıyoruz
  const baseEmail = emailInput.split('@')[0];
  const cleanEmail = `${baseEmail}@test.firsatkolik.com`;

  try {
    functions.logger.info(`🧪 Test verisi oluşturma başladı. E-posta: ${cleanEmail}`);

    // 1. Eğer test kullanıcısı zaten varsa önce temizle (Auth ve Firestore)
    try {
      const existingUser = await admin.auth().getUserByEmail(cleanEmail);
      if (existingUser) {
        functions.logger.info(`🗑️ Eski test kullanıcısı bulundu, siliniyor: ${existingUser.uid}`);
        await admin.auth().deleteUser(existingUser.uid);
        // onUserDeleted tetiklenecek ve eski verileri temizleyecektir
        // Kısa bir gecikme verelim ki trigger işlemi tamamlasın
        await new Promise(resolve => setTimeout(resolve, 1500));
      }
    } catch (authErr) {
      // Bulunamadıysa hata vermeden devam et
    }

    // 2. Yeni Auth kullanıcısı oluştur
    const userRecord = await admin.auth().createUser({
      email: cleanEmail,
      password: 'password123',
      displayName: username
    });
    const uid = userRecord.uid;

    const db = admin.firestore();

    // 3. users/{uid} profilini oluştur
    await db.collection('users').doc(uid).set({
      uid: uid,
      username: username,
      nickname: `${username}_nick`,
      email: cleanEmail,
      points: 120,
      dealCount: dealsCount,
      totalLikes: 15,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      followedCategories: ['elektronik', 'supermarket'],
      watchKeywords: ['xiaomi', 'iphone']
    });

    // 4. Subcollection: notificationPreferences oluştur
    await db.collection('users').doc(uid).collection('notificationPreferences').doc('main').set({
      pushMasterEnabled: true,
      dealNotificationsEnabled: true,
      communityNotificationsEnabled: true,
      submissionStatusNotificationsEnabled: true,
      marketingNotificationsEnabled: false,
      quietHoursEnabled: false,
      quietHoursStart: '23:00',
      quietHoursEnd: '08:00',
      timezone: 'Europe/Istanbul',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      schemaVersion: 1
    });

    // 5. Cihaz kaydı oluştur (userDevices)
    await db.collection('userDevices').doc(`test_device_${uid}`).set({
      uid: uid,
      deviceId: `test_device_${uid}`,
      platform: 'android',
      fcmToken: `test_token_${uid}`,
      permissionStatus: 'authorized',
      active: true,
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 6. Abonelikleri kaydet (notificationSubscriptions)
    await db.collection('notificationSubscriptions').doc(`${uid}_category_elektronik`).set({
      uid: uid,
      type: 'category',
      key: 'elektronik',
      displayValue: 'Elektronik',
      normalizedValue: 'elektronik',
      includeDescendants: true,
      enabled: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await db.collection('notificationSubscriptions').doc(`${uid}_keyword_xiaomi`).set({
      uid: uid,
      type: 'keyword',
      key: 'xiaomi',
      displayValue: 'xiaomi',
      normalizedValue: 'xiaomi',
      includeDescendants: true,
      enabled: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 7. Mock Fırsatları (Deals) oluştur
    const createdDeals = [];
    for (let i = 1; i <= dealsCount; i++) {
      const price = Math.floor(Math.random() * 4000) + 1000; // 1000 - 5000 TL
      const originalPrice = Math.round(price * 1.25);
      const discountRate = Math.round(((originalPrice - price) / originalPrice) * 100);

      const dealRef = db.collection('deals').doc();
      const dealData = {
        title: `Test Fırsatı ${i} - Xiaomi Redmi Note 13 (${baseEmail})`,
        description: `Bu bir test fırsatıdır. Xiaomi Redmi Note 13 modelinde ${discountRate}% indirim sizleri bekliyor. Detaylar ve kupon kodları test verisindedir.`,
        price: price,
        originalPrice: originalPrice,
        discountRate: discountRate,
        store: 'Amazon',
        category: 'elektronik',
        subCategory: 'Telefon & Aksesuarları',
        url: `https://www.amazon.com.tr/dp/test_${uid}_${i}`,
        link: `https://www.amazon.com.tr/dp/test_${uid}_${i}`,
        imageUrl: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500',
        imageUrls: ['https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500'],
        hotVotes: 0,
        coldVotes: 0,
        expiredVotes: 0,
        commentCount: 0,
        postedBy: uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isApproved: false, // Onay bekliyor olarak başlasın ki onaylama adımı da test edilebilsin
        isRejected: false,
        isExpired: false,
        isUserSubmitted: true,
        isEditorPick: false,
        couponCode: `TESTKOD${i}`
      };

      await dealRef.set(dealData);
      createdDeals.push({ id: dealRef.id, title: dealData.title });
    }

    return {
      success: true,
      uid,
      email: cleanEmail,
      username,
      dealsCreated: createdDeals
    };
  } catch (error) {
    functions.logger.error('❌ Test verisi oluşturma hatası:', error);
    throw new functions.https.HttpsError('internal', `Test verisi oluşturulamadı: ${error.message}`);
  }
}));

/**
 * 17. TÜM TEST VERİLERİNİ TEMİZLEME (Callable) - Sadece Adminler
 * E-postası @test.firsatkolik.com ile biten tüm test kullanıcılarını bulup Auth'dan siler.
 * Auth'dan silinen kullanıcılar, onUserDeleted Firestore tetikleyicisi aracılığıyla veritabanındaki tüm ilişkili verilerini temizler.
 */
exports.cleanupTestData = functions.https.onCall(wrapCall('cleanupTestData', async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
  }

  const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const isCallerAdmin = callerDoc.exists && (
    callerDoc.data().isAdmin === true ||
    callerDoc.data().isadmin === true ||
    callerDoc.data().isAdmin === 'true' ||
    callerDoc.data().isadmin === 'true'
  );

  if (!isCallerAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Sadece adminler bu işlemi yapabilir.');
  }

  try {
    functions.logger.info('🧪 Test verileri toplu temizleme işlemi başlatıldı...');

    const db = admin.firestore();
    const testUsersSnap = await db.collection('users')
      .get();

    let cleanedCount = 0;
    const cleanPromises = [];

    for (const doc of testUsersSnap.docs) {
      const u = doc.data();
      const email = u.email || '';

      if (email.endsWith('@test.firsatkolik.com')) {
        functions.logger.info(`🔥 Test kullanıcısı temizleniyor: ${doc.id} (${email})`);

        // Auth'dan silme işlemini başlat (onUserDeleted trigger verileri temizleyecektir!)
        const promise = admin.auth().deleteUser(doc.id)
          .then(() => {
            cleanedCount++;
          })
          .catch(err => {
            functions.logger.error(`❌ Test kullanıcısı Auth silme hatası: ${doc.id}`, err);
          });
        cleanPromises.push(promise);
      }
    }

    await Promise.all(cleanPromises);
    return {
      success: true,
      cleanedCount
    };
  } catch (error) {
    functions.logger.error('❌ Test verileri temizleme hatası:', error);
    throw new functions.https.HttpsError('internal', `Test verileri temizlenemedi: ${error.message}`);
  }
}));
/**
 * 7. USER GÜNCELLEME TETİKLEYİCİSİ - Profil resmi veya kullanıcı adı değiştiğinde
 * tüm yorumlardaki ve mesajlardaki denormalized profil resmi ve kullanıcı adı verilerini senkronize eder.
 */
exports.onUserUpdated = functions.firestore
  .document('users/{userId}')
  .onUpdate(wrapTrigger('onUserUpdated', async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;

    const oldPhoto = before.profileImageUrl || before.photoURL || '';
    let newPhoto = after.profileImageUrl || after.photoURL || '';
    if (newPhoto.startsWith('assets/') && /\.(jpg|jpeg|png)$/i.test(newPhoto)) {
      newPhoto = newPhoto.replace(/\.(jpg|jpeg|png)$/i, '.webp');
    }
    const oldName = before.username || before.displayName || before.nickname || '';
    const newName = after.username || after.displayName || after.nickname || '';

    const photoChanged = oldPhoto !== newPhoto;
    const nameChanged = oldName !== newName;

    if (!photoChanged && !nameChanged) {
      functions.logger.info(`ℹ️ User ${userId} updated but profileImageUrl and username did not change. Skipping sync.`);
      return null;
    }

    functions.logger.info(`👤 User ${userId} updated. Syncing data: photoChanged=${photoChanged}, nameChanged=${nameChanged}`);

    const db = admin.firestore();
    let currentBatch = db.batch();
    let opCount = 0;

    const commitBatchIfNeeded = async () => {
      if (opCount >= 400) {
        functions.logger.info(`💾 Committing sync batch of ${opCount} operations...`);
        await currentBatch.commit();
        currentBatch = db.batch();
        opCount = 0;
      }
    };

    // 1. Yorumları Senkronize Et - Collection Group Query
    try {
      const commentsSnap = await db.collectionGroup('comments')
        .where('userId', '==', userId)
        .get();

      functions.logger.info(`💬 Found ${commentsSnap.size} comments for user ${userId} to sync.`);

      for (const doc of commentsSnap.docs) {
        const updateData = {};
        if (photoChanged) updateData.userProfileImageUrl = newPhoto;
        if (nameChanged) updateData.userName = newName;

        currentBatch.update(doc.ref, updateData);
        opCount++;
        await commitBatchIfNeeded();
      }
    } catch (commentErr) {
      functions.logger.error('❌ Comments sync error:', commentErr);
    }

    // 2. Mesajları Senkronize Et (Gönderilen Mesajlar)
    try {
      const sentMsgSnap = await db.collection('messages')
        .where('senderId', '==', userId)
        .get();

      functions.logger.info(`✉️ Found ${sentMsgSnap.size} sent messages for user ${userId} to sync.`);

      for (const doc of sentMsgSnap.docs) {
        const updateData = {};
        if (photoChanged) updateData.senderImageUrl = newPhoto;
        if (nameChanged) updateData.senderName = newName;

        currentBatch.update(doc.ref, updateData);
        opCount++;
        await commitBatchIfNeeded();
      }
    } catch (msgErr) {
      functions.logger.error('❌ Sent messages sync error:', msgErr);
    }

    // 3. Mesajları Senkronize Et (Alınan Mesajlar)
    try {
      const receivedMsgSnap = await db.collection('messages')
        .where('receiverId', '==', userId)
        .get();

      functions.logger.info(`✉️ Found ${receivedMsgSnap.size} received messages for user ${userId} to sync.`);

      for (const doc of receivedMsgSnap.docs) {
        const updateData = {};
        if (photoChanged) updateData.receiverImageUrl = newPhoto;
        if (nameChanged) updateData.receiverName = newName;

        currentBatch.update(doc.ref, updateData);
        opCount++;
        await commitBatchIfNeeded();
      }
    } catch (msgErr) {
      functions.logger.error('❌ Received messages sync error:', msgErr);
    }

    // 4. Fırsatları Senkronize Et (Deals)
    try {
      const userDealsSnap = await db.collection('deals')
        .where('postedBy', '==', userId)
        .get();

      functions.logger.info(`🔥 Found ${userDealsSnap.size} deals for user ${userId} to sync.`);

      for (const doc of userDealsSnap.docs) {
        const updateData = {};
        if (photoChanged) updateData.postedByAvatar = newPhoto;
        if (nameChanged) updateData.postedByName = newName;

        currentBatch.update(doc.ref, updateData);
        opCount++;
        await commitBatchIfNeeded();
      }
    } catch (dealErr) {
      functions.logger.error('❌ Deals sync error:', dealErr);
    }

    // Commit any remaining operations
    if (opCount > 0) {
      functions.logger.info(`💾 Committing final sync batch of ${opCount} operations...`);
      await currentBatch.commit();
    }
    functions.logger.info(`🎉 Sync completed successfully for user ${userId}.`);
    return null;
  }));

/**
 * 16. KUPON KAZIMA VE KAYDETME - MANUEL (Callable)
 * Sadece adminler tetikleyebilir.
 */
exports.scrapeCouponsManual = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .https.onCall(wrapCall('scrapeCouponsManual', async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
    }

    const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const isCallerAdmin = callerDoc.exists && (
      callerDoc.data().isAdmin === true ||
      callerDoc.data().isadmin === true ||
      callerDoc.data().isAdmin === 'true' ||
      callerDoc.data().isadmin === 'true'
    );

    if (!isCallerAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Sadece adminler bu işlemi yapabilir.');
    }

    functions.logger.info('👥 Manual coupon scraping triggered by admin:', context.auth.uid);
    const { scrapeAndSaveCoupons } = require('./coupon_scraper');
    return await scrapeAndSaveCoupons();
  }));

/**
 * 17. KUPON KAZIMA VE KAYDETME - ZAMANLANMIŞ (Scheduled)
 * Her gün gece 04:00'da otomatik çalışır.
 */
exports.scrapeCouponsScheduled = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .pubsub.schedule('0 4 * * *')
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('scrapeCouponsScheduled', async (context) => {
    functions.logger.info('⏰ Scheduled coupon scraping triggered...');
    const { scrapeAndSaveCoupons } = require('./coupon_scraper');
    const result = await scrapeAndSaveCoupons();
    functions.logger.info('⏰ Scheduled coupon scraping finished:', result);
    return null;
  }));

/**
 * 18. AKTÜEL KATALOG KAZIMA VE KAYDETME - MANUEL (Callable)
 * Sadece adminler tetikleyebilir.
 */
exports.scrapeCatalogsManual = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .https.onCall(wrapCall('scrapeCatalogsManual', async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
    }

    const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const isCallerAdmin = callerDoc.exists && (
      callerDoc.data().isAdmin === true ||
      callerDoc.data().isadmin === true ||
      callerDoc.data().isAdmin === 'true' ||
      callerDoc.data().isadmin === 'true'
    );

    if (!isCallerAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Sadece adminler bu işlemi yapabilir.');
    }

    functions.logger.info('👥 Manual catalog scraping triggered by admin:', context.auth.uid);
    const { scrapeAndSaveCatalogs } = require('./catalog_scraper');
    return await scrapeAndSaveCatalogs();
  }));

/**
 * 19. AKTÜEL KATALOG KAZIMA VE KAYDETME - ZAMANLANMIŞ (Scheduled)
 * Her gün gece 03:00'da otomatik çalışır. (v2026.07.28 - Google Translate Proxy)
 */
exports.scrapeCatalogsScheduled = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .pubsub.schedule('0 3 * * *')
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('scrapeCatalogsScheduled', async (context) => {
    functions.logger.info('⏰ Scheduled catalog scraping triggered (v2026.07.28)...');
    const { scrapeAndSaveCatalogs } = require('./catalog_scraper');
    const result = await scrapeAndSaveCatalogs();
    functions.logger.info('⏰ Scheduled catalog scraping finished:', result);
    return null;
  }));

