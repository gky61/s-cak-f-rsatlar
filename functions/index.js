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

// Eşleşen anahtar kelimeyi döndürür (ilk eşleşme)
const findMatchedKeyword = (text, keywords) => {
  const normalizedText = normalize(text);
  for (const kw of keywords) {
    if (!kw) continue;
    const k = normalize(String(kw));
    if (k && normalizedText.includes(k)) return kw;
  }
  return '';
};

// Anahtar kelime bildirimleri gönder - OPTİMİZE EDİLMİŞ VERSİYON
// Sadece ilgili kelimeleri takip eden kullanıcıları çeker (Firestore Query)
async function sendKeywordNotifications(dealId, title, description) {
  functions.logger.info('🔍 Anahtar kelime kontrolü başlıyor (Optimize):', title);

  const text = `${title} ${description}`;
  const normalizedText = normalize(text);

  // Kelimeleri ayır ve temizle
  const allWords = normalizedText.split(/[\s,\.\!\?\(\)\[\]\{\}"']+/);

  // Anlamsız/kısa kelimeleri ve stop words'ü filtrele
  const stopWords = ['bir', 've', 'veya', 'ile', 'icin', 'cok', 'bu', 'su', 'o', 'daha', 'en', 'kadar', 'gibi', 'diye', 'yok', 'var', 'mi', 'mu', 'mü', 'ama', 'fakat', 'lakin', 'bile', 'bile', 'bile', 'ben', 'sen', 'biz', 'siz', 'onlar'];

  // Benzersiz, anlamlı kelimeler (en az 3 harf)
  const uniqueKeywords = [...new Set(allWords)]
    .filter(w => w && w.length >= 3 && !stopWords.includes(w));

  if (uniqueKeywords.length === 0) {
    functions.logger.info('❌ Yeterli uzunlukta anahtar kelime bulunamadı');
    return;
  }

  functions.logger.info(`📝 Çıkarılan kelimeler (${uniqueKeywords.length}):`, uniqueKeywords);

  // Firestore 'array-contains-any' limiti: 10
  // Kelimeleri 10'arlı gruplara böl
  const chunks = [];
  for (let i = 0; i < uniqueKeywords.length; i += 10) {
    chunks.push(uniqueKeywords.slice(i, i + 10));
  }

  const relevantUsers = new Map(); // userId -> { token, matchedKeyword }

  try {
    // Her chunk için paralel sorgu at
    // 1. watchKeywords alanını kontrol et
    const watchPromises = chunks.map(chunk =>
      admin.firestore().collection('users')
        .where('watchKeywords', 'array-contains-any', chunk)
        .get()
    );

    // 2. notificationKeywords alanını kontrol et (Eski versiyon uyumluluğu için)
    const notificationPromises = chunks.map(chunk =>
      admin.firestore().collection('users')
        .where('notificationKeywords', 'array-contains-any', chunk)
        .get()
    );

    const allsnapshots = await Promise.all([...watchPromises, ...notificationPromises]);

    // Sonuçları birleştir
    for (const snap of allsnapshots) {
      for (const doc of snap.docs) {
        if (relevantUsers.has(doc.id)) continue;

        const data = doc.data();
        if (!data.fcmToken) continue;

        // Kullanıcının hangi kelimesi eşleşti bul
        const userKeywords = [
          ...(Array.isArray(data.watchKeywords) ? data.watchKeywords : []),
          ...(Array.isArray(data.notificationKeywords) ? data.notificationKeywords : [])
        ];

        // Eşleşen İLK kelimeyi bul (bildirimde göstermek için)
        // Not: uniqueKeywords içindeki kelimeler deal'dan gelenler
        // userKeywords içindeki kelimeler kullanıcının takip ettikleri
        const matched = userKeywords.find(uk => {
          const nuk = normalize(uk || '');
          return uniqueKeywords.includes(nuk); // uniqueKeywords zaten normalize edilmiş dealing kelimeleri
        });

        if (matched) {
          relevantUsers.set(doc.id, {
            token: data.fcmToken,
            keyword: matched
          });
        }
      }
    }
  } catch (error) {
    functions.logger.error('❌ Firestore sorgu hatası:', error);
    return;
  }

  if (relevantUsers.size === 0) {
    functions.logger.info('❌ Hiçbir eşleşme bulunamadı');
    return;
  }

  functions.logger.info(`✅ Toplam ${relevantUsers.size} kullanıcıya bildirim gönderilecek`);

  const messages = [];

  for (const [userId, userData] of relevantUsers) {
    messages.push({
      token: userData.token,
      notification: {
        title: '🎯 İlginizi Çeken Bir Fırsat Bulundu!',
        body: `"${userData.keyword}" kelimesi içeren yeni bir fırsat paylaşıldı. Hemen inceleyin!`,
      },
      data: {
        dealId,
        type: 'keyword',
        keyword: userData.keyword,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'keyword_alerts_channel',
          color: '#FF9800',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            'thread-id': 'keyword_alerts_channel',
            'interruption-level': 'time-sensitive',
            'relevance-score': 1.0,
          },
        },
      },
    });
  }

  // FCM sendEach: 500 limit
  const batches = [];
  const size = 300;
  for (let i = 0; i < messages.length; i += size) {
    batches.push(messages.slice(i, i + size));
  }

  for (const batch of batches) {
    try {
      const resp = await admin.messaging().sendEach(batch);
      functions.logger.info('✅ Bildirim gönderildi', {
        success: resp.successCount,
        failure: resp.failureCount,
      });
    } catch (error) {
      functions.logger.error('❌ Bildirim hatası:', error);
    }
  }
}

// Genel kullanıcı bildirimleri gönder (topic bazlı)
async function sendUserNotifications(deal, dealId) {
  const title = "🔥 Yeni Sıcak Fırsat!";
  const body = `${deal.title}\n💰 ${deal.price} TL`;
  const imageUrl = deal.imageUrl || null;

  const payload = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      type: 'deal',
      dealId: dealId,
      category: deal.category || 'genel',
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'sicak_firsatlar_general_v2', // App side channel ID
        sound: 'default',
        imageUrl: imageUrl
      }
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          mutableContent: 1
        }
      },
      fcm_options: {
        image: imageUrl
      }
    }
  };

  // Gönderilecek Topic'ler
  const topics = ['all_deals']; // Herkese gönder

  // Kategori Topic'i (bot ID'lerini uygulama ID'sine çevir ki aboneler eşleşsin)
  const categoryForTopic = normalizeCategoryForTopic(deal.category);
  if (categoryForTopic && categoryForTopic !== 'diger') {
    topics.push(`category_${cleanTopicName(categoryForTopic)}`);
  }

  // Bildirimleri Gönder
  const promises = topics.map(topic => {
    return admin.messaging().send({
      ...payload,
      topic: topic
    }).then(() => functions.logger.info(`Bildirim gönderildi (${topic})`))
      .catch(e => functions.logger.error(`Hata (${topic}):`, e));
  });

  await Promise.all(promises);
}

// Takip bildirimleri gönder - SADECE kullanıcı tarafından paylaşılan deal'ler için
async function sendFollowNotifications(deal, dealId) {
  functions.logger.info('🔍 sendFollowNotifications çağrıldı:', { dealId, isUserSubmitted: deal.isUserSubmitted, postedBy: deal.postedBy });

  // Sadece kullanıcı tarafından paylaşılan deal'ler için
  if (!deal.isUserSubmitted || !deal.postedBy) {
    functions.logger.info('❌ Takip bildirimi gönderilmeyecek (bot deal veya postedBy yok)', {
      isUserSubmitted: deal.isUserSubmitted,
      postedBy: deal.postedBy
    });
    return;
  }

  const followingUserId = deal.postedBy;

  try {
    // Takip edilen kullanıcının bilgilerini al
    const followingDoc = await admin.firestore().collection('users').doc(followingUserId).get();

    if (!followingDoc.exists) {
      functions.logger.warn('❌ Takip edilen kullanıcı bulunamadı:', followingUserId);
      return;
    }

    const followingData = followingDoc.data();
    const username = followingData?.username || 'Kullanıcı';
    const followersWithNotifications = followingData?.followersWithNotifications || [];

    functions.logger.info('📋 Takip edilen kullanıcı bilgileri:', {
      userId: followingUserId,
      username: username,
      followersWithNotificationsCount: Array.isArray(followersWithNotifications) ? followersWithNotifications.length : 0,
      followersWithNotifications: followersWithNotifications,
      // Tüm doküman verisini de logla (debug için)
      allDataKeys: Object.keys(followingData || {})
    });

    // Debug: following listesini de kontrol et
    const following = followingData?.following || [];
    functions.logger.info('🔍 Debug - following listesi:', {
      followingCount: Array.isArray(following) ? following.length : 0,
      following: following
    });

    if (!Array.isArray(followersWithNotifications) || followersWithNotifications.length === 0) {
      functions.logger.warn('⚠️ Bildirim almak isteyen takipçi yok:', {
        userId: followingUserId,
        username: username,
        followersWithNotificationsType: typeof followersWithNotifications,
        followersWithNotificationsValue: followersWithNotifications,
        followingListExists: Array.isArray(following) && following.length > 0,
        followingListCount: Array.isArray(following) ? following.length : 0
      });
      return;
    }

    functions.logger.info(`📢 ${followersWithNotifications.length} takipçiye bildirim gönderiliyor:`, followingUserId);

    // Takipçilerin FCM token'larını al
    const followerDocs = await Promise.all(
      followersWithNotifications.map(followerId =>
        admin.firestore().collection('users').doc(followerId).get()
      )
    );

    const messages = [];

    followerDocs.forEach((followerDoc, index) => {
      const followerId = followersWithNotifications[index];

      if (!followerDoc.exists) {
        functions.logger.warn(`⚠️ Takipçi dokümanı bulunamadı: ${followerId}`);
        return;
      }

      const followerData = followerDoc.data();
      const fcmToken = followerData?.fcmToken;

      if (!fcmToken) {
        functions.logger.warn(`⚠️ Takipçinin FCM token'ı yok: ${followerId}`);
        return;
      }

      functions.logger.info(`✅ Takipçi için bildirim hazırlanıyor: ${followerId} (token: ${fcmToken.substring(0, 20)}...)`);

      const dealTitle = deal.title || 'Yeni Fırsat';
      const body = dealTitle.length > 50 ? dealTitle.substring(0, 50) + "..." : dealTitle;

      messages.push({
        token: fcmToken,
        notification: {
          title: `👤 ${username} Yeni Bir Fırsat Paylaştı`,
          body: `Takip ettiğiniz ${username} yeni bir fırsat paylaştı: ${body}`,
        },
        data: {
          type: 'follow',
          dealId: dealId,
          followingUserId: followingUserId,
          username: username,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'follow_channel',
            sound: 'default',
            color: '#4CAF50', // Yeşil renk (takip bildirimleri için)
            tag: `follow_${dealId}`, // Benzersiz tag
            // Bildirimi daha belirgin yapmak için
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              'interruption-level': 'active',
              category: 'FOLLOW_NOTIFICATION', // iOS için kategori
            },
          },
        },
      });
    });

    if (messages.length === 0) {
      functions.logger.info('Gönderilecek bildirim yok');
      return;
    }

    // FCM sendEach: 500 limit, 300 batch size
    const batches = [];
    const size = 300;
    for (let i = 0; i < messages.length; i += size) {
      batches.push(messages.slice(i, i + size));
    }

    for (const batch of batches) {
      try {
        functions.logger.info(`📤 ${batch.length} bildirim gönderiliyor...`);
        const resp = await admin.messaging().sendEach(batch);
        functions.logger.info('✅ Takip bildirimleri gönderildi', {
          success: resp.successCount,
          failure: resp.failureCount,
          total: batch.length
        });

        if (resp.failureCount > 0) {
          resp.responses.forEach((response, index) => {
            if (!response.success) {
              functions.logger.error(`❌ Bildirim gönderme hatası (${index}):`, response.error);
            }
          });
        }
      } catch (error) {
        functions.logger.error('❌ Takip bildirim hatası:', error);
      }
    }
  } catch (error) {
    functions.logger.error('❌ Takip bildirim genel hatası:', error);
  }
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

    // Eğer fırsat zaten onaylı geldiyse, sadece genel kullanıcı bildirimlerini gönder
    if (deal.isApproved === true) {
      functions.logger.info('✅ Fırsat onaylı, genel bildirimler gönderiliyor...');

      // Genel bildirimler
      await sendUserNotifications(deal, dealId);

      // Anahtar kelime bildirimleri - HERKESİN aldığı kelimeler kontrol edilir
      await sendKeywordNotifications(dealId, deal.title || '', deal.description || '');

      // Takip bildirimleri - SADECE kullanıcı tarafından paylaşılan deal'ler için
      await sendFollowNotifications(deal, dealId);
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
      functions.logger.info('🎉 Fırsat onaylandı! Bildirimler gönderiliyor:', dealId);

      // Genel bildirimler
      await sendUserNotifications(newData, dealId);

      // Anahtar kelime bildirimleri - HERKESİN aldığı kelimeler kontrol edilir
      await sendKeywordNotifications(dealId, newData.title || '', newData.description || '');

      // Takip bildirimleri - SADECE kullanıcı tarafından paylaşılan deal'ler için
      await sendFollowNotifications(newData, dealId);
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
      // Kullanıcının FCM token'ını al
      const userDoc = await admin.firestore().collection('users').doc(userId).get();

      if (!userDoc.exists) {
        functions.logger.warn('⚠️ Kullanıcı bulunamadı:', userId);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;

      if (!fcmToken) {
        functions.logger.warn('⚠️ Kullanıcının FCM token\'ı yok:', userId);
        return null;
      }

      // Bildirim içeriğini hazırla
      const notificationTitle = title.length > 50 ? title.substring(0, 50) + '...' : title;
      const notificationBody = content.length > 100 ? content.substring(0, 100) + '...' : content;

      const messagePayload = {
        token: fcmToken,
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
            channelId: 'admin_messages_channel_v3', // App side channel ID matches
            sound: 'default',
            color: '#2196F3', // Mavi renk (admin bildirimleri için)
            tag: `admin_msg_${messageId}`, // Benzersiz tag
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

      // Push notification gönder
      const response = await admin.messaging().send(messagePayload);
      functions.logger.info('✅ Admin mesaj bildirimi gönderildi:', {
        messageId,
        userId,
        response
      });

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
      // Alıcının bilgilerini ve FCM token'ını al
      const userDoc = await admin.firestore().collection('users').doc(receiverId).get();

      if (!userDoc.exists) {
        functions.logger.warn('⚠️ Alıcı kullanıcı bulunamadı:', receiverId);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;

      // Bildirim ayarını kontrol et (opsiyonel)
      // const notificationsEnabled = userData?.messageNotificationsEnabled ?? true;
      // if (!notificationsEnabled) return null;

      if (!fcmToken) {
        functions.logger.warn('⚠️ Alıcının FCM token\'ı yok:', receiverId);
        return null;
      }

      // Bildirim içeriği
      const notificationBody = content.length > 100 ? content.substring(0, 100) + '...' : content;

      const payload = {
        token: fcmToken,
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
            channelId: 'messages_channel',
            sound: 'default',
            color: '#4CAF50', // Yeşil renk
            tag: `msg_${senderId}_${receiverId}`, // Sohbet başına gruplama
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

      // Gönder
      await admin.messaging().send(payload);
      functions.logger.info('✅ Mesaj bildirimi gönderildi:', receiverId);

      return null;
    } catch (error) {
      functions.logger.error('❌ Mesaj bildirimi hatası:', error);
      return null;
    }
  }));

/**
 * 6. YORUM CEVABI BİLDİRİMİ - Push Notification Gönder
 */
exports.onCommentReplyNotificationCreated = functions.firestore
  .document('users/{userId}/notifications/{notificationId}')
  .onCreate(wrapTrigger('onCommentReplyNotificationCreated', async (snap, context) => {
    const notification = snap.data();
    const userId = context.params.userId;
    const notificationId = context.params.notificationId;

    // Sadece comment_reply tipindeki bildirimleri işle
    if (notification.type !== 'comment_reply') {
      return null;
    }

    functions.logger.info('💬 Yorum cevabı bildirimi oluşturuldu:', {
      notificationId,
      userId,
      dealId: notification.dealId,
      replyUserName: notification.replyUserName
    });

    try {
      // Kullanıcı bilgilerini al
      const userDoc = await admin.firestore().collection('users').doc(userId).get();

      if (!userDoc.exists) {
        functions.logger.warn('⚠️ Kullanıcı bulunamadı:', userId);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;

      // Bildirim tercihi kontrolü
      const commentReplyNotificationsEnabled = userData?.commentReplyNotificationsEnabled !== false;

      if (!commentReplyNotificationsEnabled) {
        functions.logger.info('ℹ️ Kullanıcı yorum cevabı bildirimlerini kapatmış:', userId);
        return null;
      }

      if (!fcmToken) {
        functions.logger.warn('⚠️ Kullanıcının FCM token\'ı yok:', userId);
        return null;
      }

      // Bildirim içeriği
      const replyUserName = notification.replyUserName || 'Birisi';
      const dealTitle = notification.dealTitle || 'Fırsat';
      const replyText = notification.replyText || '';
      const dealId = notification.dealId || '';
      const commentId = notification.commentId || '';

      const notificationTitle = `💬 ${replyUserName} yorumunuza cevap verdi`;
      const notificationBody = replyText.length > 100
        ? `${replyText.substring(0, 100)}...`
        : replyText;

      const payload = {
        token: fcmToken,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          type: 'comment_reply',
          dealId: dealId,
          commentId: commentId,
          notificationId: notificationId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          notification_title: notificationTitle,
          notification_body: notificationBody,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'sicak_firsatlar_general_v2',
            sound: 'default',
            icon: '@mipmap/ic_launcher',
            color: '#2196F3',
            tag: `comment_reply_${dealId}_${commentId}`,
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400),
          },
          payload: {
            aps: {
              alert: {
                title: notificationTitle,
                body: notificationBody,
              },
              sound: 'default',
              badge: 1,
              'content-available': 1,
            },
          },
        },
      };

      await admin.messaging().send(payload);
      functions.logger.info('✅ Yorum cevabı push bildirimi gönderildi:', userId);

      return null;
    } catch (error) {
      functions.logger.error('❌ Yorum cevabı bildirimi hatası:', error);
      return null;
    }
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

  // Hedef Tanımlama
  if (targetType === 'all') {
    message.topic = 'all_deals';
  } else if (targetType === 'uid') {
    const targetUserDoc = await admin.firestore().collection('users').doc(targetValue).get();
    if (!targetUserDoc.exists || !targetUserDoc.data().fcmToken) {
      throw new functions.https.HttpsError('not-found', 'Belirtilen kullanıcının bildirim token\'ı bulunamadı.');
    }
    message.token = targetUserDoc.data().fcmToken;
  } else if (targetType === 'token') {
    message.token = targetValue;
  } else {
    throw new functions.https.HttpsError('invalid-argument', 'Geçersiz hedef türü.');
  }

  const logRef = admin.firestore().collection('notificationLogs').doc();
  const sentBy = context.auth.uid;
  const sentAt = admin.firestore.FieldValue.serverTimestamp();

  try {
    functions.logger.info(`🤖 Manuel bildirim gönderiliyor. Hedef: ${targetType}`);
    const responseId = await admin.messaging().send(message);

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
    functions.logger.info('🤖 Geçersiz token temizleme işlemi başlatıldı...');
    
    const usersSnap = await admin.firestore().collection('users')
      .where('fcmToken', '>=', '')
      .limit(500)
      .get();

    let checkedCount = 0;
    let cleanedCount = 0;

    const promises = usersSnap.docs.map(async (doc) => {
      const fcmToken = doc.data().fcmToken;
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
          functions.logger.info(`🔥 Geçersiz token siliniyor. Kullanıcı: ${doc.id}`);
          await doc.ref.update({
            fcmToken: admin.firestore.FieldValue.delete()
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
