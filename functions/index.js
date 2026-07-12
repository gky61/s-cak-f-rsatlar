const functions = require('firebase-functions');
const admin = require('firebase-admin');
const https = require('https');
const http = require('http');

if (!admin.apps.length) {
  admin.initializeApp();
}

// Türkçe karakter temizleme fonksiyonu
const normalize = (text = '') =>
  text
    .toLowerCase()
    .replace(/ç/g, 'c')
    .replace(/ğ/g, 'g')
    .replace(/ı/g, 'i')
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

// Kullanıcının aktif tüm cihaz token'larını döndürür
async function getUserDeviceTokens(userId) {
  const devicesSnap = await admin.firestore()
    .collection('userDevices')
    .where('uid', '==', userId)
    .where('active', '==', true)
    .get();
  
  const tokens = [];
  devicesSnap.forEach(doc => {
    const data = doc.data();
    if (data.fcmToken) {
      tokens.push({
        id: doc.id,
        token: data.fcmToken
      });
    }
  });
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

  functions.logger.info('🎯 matchAndCreateDealNotifications başlatılıyor:', { dealId, title });

  // 1. Anahtar kelimeleri topla ve normalize et
  const text = `${title} ${description}`;
  const normalizedText = normalize(text);
  const allWords = normalizedText.split(/[\s,\.\!\?\(\)\[\]\{\}"']+/);
  const stopWords = ['bir', 've', 'veya', 'ile', 'icin', 'cok', 'bu', 'su', 'o', 'daha', 'en', 'kadar', 'gibi', 'diye', 'yok', 'var', 'mi', 'mu', 'mü', 'ama', 'fakat', 'lakin', 'bile', 'ben', 'sen', 'biz', 'siz', 'onlar'];
  const uniqueKeywords = [...new Set(allWords)]
    .filter(w => w && w.length >= 3 && !stopWords.includes(w));

  const matchedUsers = new Map(); // userId -> { reason: 'keyword'|'author'|'category', detail: String, reasons: {} }

  // A. Takip Edilen Yazarlar (zil açık)
  if (isUserSubmitted && postedBy) {
    try {
      const authorSubsSnap = await admin.firestore()
        .collection('notificationSubscriptions')
        .where('type', '==', 'author')
        .where('key', '==', postedBy)
        .where('enabled', '==', true)
        .get();
      
      authorSubsSnap.forEach(doc => {
        const sub = doc.data();
        if (sub.uid !== postedBy) { // Kendi kendine bildirim gitmesin
          matchedUsers.set(sub.uid, {
            reason: 'author',
            detail: postedBy,
            reasons: { author: postedBy }
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

  // C. Anahtar Kelime Abonelikleri
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
            if (matchedUsers.has(sub.uid)) {
              const u = matchedUsers.get(sub.uid);
              // Anahtar kelime en yüksek önceliklidir!
              u.reason = 'keyword';
              u.detail = sub.displayValue;
              u.reasons.keyword = sub.displayValue;
            } else {
              matchedUsers.set(sub.uid, {
                reason: 'keyword',
                detail: sub.displayValue,
                reasons: { keyword: sub.displayValue }
              });
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
  const batch = admin.firestore().batch();
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
      notifTitle = '👤 Takip Ettiğiniz Kişi!';
      notifBody = `Takip ettiğiniz yazar yeni fırsat paylaştı: ${deal.title}`;
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
 * 4. ADMIN MESAJI GÖNDERİLDİĞİNDE - Kullanıcıya Push Notification Gönder
 */
exports.onAdminMessageCreated = functions.firestore
  .document('adminToUserMessages/{messageId}')
  .onCreate(wrapTrigger('onAdminMessageCreated', async (snap, context) => {
    const message = snap.data();
    const messageId = context.params.messageId;
    const userId = message.userId;
    const title = message.title || 'Yeni Bildirim';
    const content = message.content || '';
    const adminName = message.adminName || 'Admin';

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
      // Alıcının tüm aktif cihaz token'larını al
      const devices = await getUserDeviceTokens(userId);

      if (devices.length === 0) {
        functions.logger.warn('⚠️ Alıcı için aktif cihaz token\'ı bulunamadı:', userId);
        return null;
      }

      // Bildirim içeriğini hazırla
      const notificationTitle = title.length > 50 ? title.substring(0, 50) + '...' : title;
      const notificationBody = content.length > 100 ? content.substring(0, 100) + '...' : content;

      functions.logger.info(`📤 Admin bildirim ${devices.length} cihaza gönderiliyor...`);

      const promises = devices.map(async (device) => {
        const messagePayload = {
          token: device.token,
          notification: {
            title: `📬 ${notificationTitle}`,
            body: notificationBody,
          },
          data: {
            type: 'admin_message',
            messageId: messageId,
            userId: userId,
            title: title,
            notification_title: `📬 ${notificationTitle}`,
            notification_body: notificationBody,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            ttl: 86400000,
            notification: {
              channelId: 'admin_messages_channel_v3',
              sound: 'default',
              color: '#2196F3',
              tag: `admin_msg_${messageId}`,
              defaultSound: true,
              defaultVibrateTimings: true,
              icon: '@mipmap/ic_launcher',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                'interruption-level': 'active',
                category: 'ADMIN_MESSAGE',
              },
            },
          },
        };

        try {
          const response = await admin.messaging().send(messagePayload);
          functions.logger.info(`✅ Cihaza admin bildirim gönderildi. Token: ${device.token.substring(0, 8)}..., Response: ${response}`);
        } catch (err) {
          functions.logger.error(`❌ Cihaza admin bildirim gönderilemedi: ${device.id}`, err);
          if (device.id) {
            await handleSendFailure(device.id, err);
          }
        }
      });

      await Promise.all(promises);
      return null;
    } catch (error) {
      functions.logger.error('❌ Admin mesaj bildirimi hatası:', {
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
        const payload = {
          token: device.token,
          notification: {
            title: `💬 ${senderName}`,
            body: notificationBody,
          },
          data: {
            type: 'message',
            messageId: messageId,
            senderId: senderId,
            receiverId: receiverId,
            notification_title: `💬 ${senderName}`,
            notification_body: notificationBody,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            ttl: 86400000, // 24 saat
            notification: {
              channelId: 'messages_channel_v3',
              sound: 'default',
              color: '#4CAF50',
              tag: `msg_${senderId}_${receiverId}`,
              icon: '@mipmap/ic_launcher',
              defaultSound: true,
              defaultVibrateTimings: true,
            },
          },
          apns: {
            headers: {
              'apns-priority': '10',
              'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400),
            },
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                'interruption-level': 'active',
                category: 'USER_MESSAGE',
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

    // 0. Check global Master Switch for push notifications
    try {
      const sysConfigDoc = await admin.firestore().collection('systemConfig').doc('notifications').get();
      if (sysConfigDoc.exists) {
        const sysConfig = sysConfigDoc.data();
        if (sysConfig.enabled === false) {
          functions.logger.info(`🚫 Global master notification switch is disabled. Skipping push for ${notificationId}`);
          await snap.ref.update({
            pushEligible: false,
            pushStatus: 'disabled_by_system_master_switch',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
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
        await snap.ref.update({
          pushEligible: false,
          pushStatus: 'skipped_quiet_hours',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
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
          await snap.ref.update({
            pushEligible: false,
            pushStatus: 'skipped_category_limit',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          return null;
        }
      } catch (limitErr) {
        functions.logger.error('⚠️ Limit kontrolü sırasında hata, devam ediliyor:', limitErr);
      }
    }

    // 4. ADIM 2 - FİLTRE C: Ana Şalter (Telefon Bildirimleri) kontrolü
    if (!prefs.pushMasterEnabled) {
      functions.logger.info(`🚫 Kullanıcı ${userId} için tüm push bildirimleri kapalı.`);
      await snap.ref.update({
        pushEligible: false,
        pushStatus: 'disabled_by_user_master_switch',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      return null;
    }

    // 5. ADIM 2 - FİLTRE D: Alt Kanal kontrolü
    let groupEnabled = true;
    const reasons = notification.reasons || {};
    const hasReasons = Object.keys(reasons).length > 0;

    if (hasReasons) {
      // Hangi sebebin aktif olarak kullanılacağını belirleyelim.
      // Öncelik: Eğer belgenin orijinal nedeni kullanıcının tercihlerinde açık ise, onu koru.
      // Değilse, açık olan ilk eşleşen nedeni seç (Sıra: keyword > author > category).
      let activeReason = null;
      let activeDetail = '';

      const originalReason = notification.reason;
      let isOriginalReasonEnabled = false;
      if (originalReason === 'keyword' && prefs.keywordNotificationsEnabled !== false) {
        isOriginalReasonEnabled = true;
      } else if (originalReason === 'author' && prefs.dealNotificationsEnabled !== false) {
        isOriginalReasonEnabled = true;
      } else if (originalReason === 'category' && prefs.categoryNotificationsEnabled !== false) {
        isOriginalReasonEnabled = true;
      }

      if (isOriginalReasonEnabled) {
        activeReason = originalReason;
        activeDetail = notification.reasonDetail || '';
      } else {
        if (reasons.keyword && prefs.keywordNotificationsEnabled !== false) {
          activeReason = 'keyword';
          activeDetail = reasons.keyword;
        } else if (reasons.author && prefs.dealNotificationsEnabled !== false) {
          activeReason = 'author';
          activeDetail = reasons.author;
        } else if (reasons.category && prefs.categoryNotificationsEnabled !== false) {
          activeReason = 'category';
          activeDetail = reasons.category;
        }
      }

      if (activeReason) {
        groupEnabled = true;

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
          await snap.ref.update({
            reason: activeReason,
            reasonDetail: activeDetail,
            title: newTitle,
            body: newBody,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });

          functions.logger.info(`🔄 Bildirim başlığı ve içeriği güncellenen nedene göre dinamik olarak değiştirildi:`, {
            oldReason: originalReason,
            newReason: activeReason,
            newTitle,
            newBody
          });
        }
      } else {
        groupEnabled = false;
      }
    } else {
      if (isKeywordNotif) {
        groupEnabled = prefs.keywordNotificationsEnabled !== false;
      } else if (isCategoryNotif) {
        groupEnabled = prefs.categoryNotificationsEnabled !== false;
      } else if (type === 'deal') {
        groupEnabled = prefs.dealNotificationsEnabled !== false;
      } else if (type === 'comment_reply' || type === 'comment') {
        groupEnabled = prefs.communityNotificationsEnabled !== false;
      } else if (type === 'submission_status') {
        groupEnabled = prefs.submissionStatusNotificationsEnabled !== false;
      } else if (type === 'marketing') {
        groupEnabled = prefs.marketingNotificationsEnabled !== false;
      }
    }

    if (!groupEnabled) {
      functions.logger.info(`🚫 Kullanıcı ${userId} için bu bildirim grubu kapalı: ${type || reason}`);
      await snap.ref.update({
        pushEligible: false,
        pushStatus: `disabled_by_user_group_${type || reason}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      return null;
    }

    // 6. FCM Push Gönder
    const devices = await getUserDeviceTokens(userId);
    if (devices.length === 0) {
      functions.logger.info(`⚠️ Kullanıcı ${userId} için aktif cihaz token'ı bulunamadı.`);
      await snap.ref.update({
        pushEligible: false,
        pushStatus: 'no_active_devices',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      return null;
    }

    // title and body are already declared and resolved at the top of the function
    const dealId = notification.dealId || '';
    const clickAction = 'FLUTTER_NOTIFICATION_CLICK';

    let channelId = 'sicak_firsatlar_general_v2';
    let sound = 'default';
    let color = '#FF6B35';

    if (type === 'keyword') {
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
            tag: `${type}_${dealId}`,
            defaultSound: true,
            defaultVibrateTimings: true,
          }
        },
        apns: {
          payload: {
            aps: {
              sound,
              badge: 1,
              'content-available': 1,
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

    await snap.ref.update({
      pushEligible: true,
      pushStatus: successCount > 0 ? 'sent' : 'failed',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

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
 * 7 günden eski deal görsellerini Firebase Storage'dan siler
 */
exports.cleanupOldImages = functions
  .runWith({ timeoutSeconds: 300, memory: '512MB' })
  .pubsub.schedule('0 0 * * *') // Her gün gece 00:00'da çalışır
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('cleanupOldImages', async (context) => {
    functions.logger.info('🧹 Eski görsel temizleme başlıyor...');

    const bucketName = 'sicak-firsatlar-e6eae.firebasestorage.app';
    const bucket = admin.storage().bucket(bucketName);
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

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

          // 7 günden eski mi kontrol et
          if (createdTime < sevenDaysAgo) {
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

      // İstatistikleri kaydet (opsiyonel)
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
    functions.logger.info('🧹 Manuel görsel temizleme başlıyor...');

    const bucketName = 'sicak-firsatlar-e6eae.firebasestorage.app';
    const bucket = admin.storage().bucket(bucketName);
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

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

          if (createdTime < sevenDaysAgo) {
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
        deletedFiles: deletedFiles.slice(0, 20), // İlk 20'yi göster
        threshold: sevenDaysAgo.toISOString(),
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
          type: 'marketing',
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
        type: 'marketing',
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
 * 48 Saat Geçen Fırsatları Firestore ve Storage'dan Siler
 */
exports.cleanupExpiredDeals = functions
  .runWith({ timeoutSeconds: 360, memory: '512MB' })
  .pubsub.schedule('0 3 * * *') // Her gün gece 03:00'da çalışır
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('cleanupExpiredDeals', async (context) => {
    functions.logger.info('🧹 48 saatlik eski fırsatları temizleme görevi başladı...');
    
    const now = new Date();
    const fortyEightHoursAgo = new Date(now.getTime() - (48 * 60 * 60 * 1000));
    
    let deletedCount = 0;
    let errorCount = 0;
    
    try {
      const db = admin.firestore();
      const targetDocIds = new Set();
      const docsToDelete = [];
      
      // 1. Query by 'createdAt'
      const snap1 = await db.collection('deals').where('createdAt', '<', fortyEightHoursAgo).get();
      snap1.forEach(doc => {
        if (!targetDocIds.has(doc.id)) {
          targetDocIds.add(doc.id);
          docsToDelete.push(doc);
        }
      });
      
      // 2. Query by 'timestamp'
      const snap2 = await db.collection('deals').where('timestamp', '<', fortyEightHoursAgo).get();
      snap2.forEach(doc => {
        if (!targetDocIds.has(doc.id)) {
          targetDocIds.add(doc.id);
          docsToDelete.push(doc);
        }
      });
      
      functions.logger.info(`🔍 Toplam temizlenecek ${docsToDelete.length} eski fırsat bulundu.`);
      
      for (const doc of docsToDelete) {
        try {
          const deal = doc.data();
          const dealId = doc.id;
          
          // Storage görselini temizle
          const url = deal.imageUrl || deal.image_url;
          if (url) {
            await deleteDealImage(url);
          }
          
          // Firestore belgesini sil
          await db.collection('deals').doc(dealId).delete();
          deletedCount++;
          functions.logger.info(`🗑️ Firestore'dan silindi: ${dealId} - ${deal.title}`);
        } catch (docError) {
          errorCount++;
          functions.logger.error(`❌ Fırsat silme hatası (doc.id: ${doc.id}):`, docError.message);
        }
      }
      
      functions.logger.info(`✅ 48 saatlik fırsat temizliği bitti. Silinen: ${deletedCount}, Hata: ${errorCount}`);
    } catch (error) {
      functions.logger.error('❌ Fırsat temizliği genel hatası:', error);
    }
    
    return null;
  }));

/**
 * 🧹 MANUEL ESKİ FIRSATLARI TEMİZLE - HTTP ile tetiklenir (test için)
 * Kullanım: GET veya POST isteği at
 */
exports.cleanupExpiredDealsManual = functions
  .runWith({ timeoutSeconds: 360, memory: '512MB' })
  .https.onRequest(wrapRequest('cleanupExpiredDealsManual', async (req, res) => {
    functions.logger.info('🧹 Manuel 48 saatlik fırsat temizliği başlıyor...');
    
    const now = new Date();
    const fortyEightHoursAgo = new Date(now.getTime() - (48 * 60 * 60 * 1000));
    
    let deletedCount = 0;
    let errorCount = 0;
    const deletedDeals = [];
    
    try {
      const db = admin.firestore();
      const targetDocIds = new Set();
      const docsToDelete = [];
      
      const snap1 = await db.collection('deals').where('createdAt', '<', fortyEightHoursAgo).get();
      snap1.forEach(doc => {
        if (!targetDocIds.has(doc.id)) {
          targetDocIds.add(doc.id);
          docsToDelete.push(doc);
        }
      });
      
      const snap2 = await db.collection('deals').where('timestamp', '<', fortyEightHoursAgo).get();
      snap2.forEach(doc => {
        if (!targetDocIds.has(doc.id)) {
          targetDocIds.add(doc.id);
          docsToDelete.push(doc);
        }
      });
      
      for (const doc of docsToDelete) {
        try {
          const deal = doc.data();
          const dealId = doc.id;
          
          const url = deal.imageUrl || deal.image_url;
          if (url) {
            await deleteDealImage(url);
          }
          
          await db.collection('deals').doc(dealId).delete();
          deletedCount++;
          deletedDeals.push({ id: dealId, title: deal.title });
        } catch (docError) {
          errorCount++;
        }
      }
      
      res.status(200).json({
        success: true,
        message: 'Fırsat temizliği tamamlandı',
        stats: {
          totalFound: docsToDelete.length,
          deletedCount,
          errorCount
        },
        deletedDeals
      });
    } catch (error) {
      functions.logger.error('❌ Manuel temizlik genel hatası:', error);
      res.status(500).json({ success: false, error: error.message });
    }
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
        shipping: 'free',
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



