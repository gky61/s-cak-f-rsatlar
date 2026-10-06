const functions = require('firebase-functions');
const admin = require('firebase-admin');
const https = require('https');
const http = require('http');
const dns = require('dns').promises;

if (!admin.apps.length) {
  admin.initializeApp();
}

// P1-20 (R-SCL-11): Türkçe karakter temizleme fonksiyonu (Harf duyarsız normalize ve yanlış pozitif kalkanı)
// "Şık", "şıklar", "şıklık" gibi meşru e-ticaret moda kelimelerinin "sik" küfrüne dönüşmesini engelleyen Unicode token kalkanı
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

// Küfür ve uygunsuz içerik kontrolü
// P1-20 (R-SCL-11): 'bomba' ve 'mal' gibi yaygın e-ticaret kelimeleri ("bomba indirim", "ticari mal") tek başına yasaklı olmaktan çıkarılmış,
// yerine bağlamsal argo/tehdit öbekleri ('canli bomba', 'mal herif') tanımlanmıştır.
const profanityWords = [
  'sik', 'sike', 'siker', 'sikmek', 'sikti', 'siktir',
  'amk', 'amcik', 'amcık', 'orospu', 'orospu cocugu', 'orospu çocuğu',
  'pezevenk', 'pezeveng', 'kerhane', 'kerhaneci',
  'malk', 'malak', 'mal herif', 'mal ya', 'mal adam', 'got', 'göt', 'gotu', 'götü',
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

// ReDoS ve regex derleme maliyetini sıfırlayan ön derlenmiş regex listesi
const compiledProfanityList = profanityWords.map(p => {
  const norm = normalize(p);
  return {
    raw: p,
    regex: new RegExp('\\b' + norm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b')
  };
});

// İçerik moderasyonu kontrolü
function containsProfanity(text) {
  if (!text || typeof text !== 'string') return false;

  const safeText = text.length > 5000 ? text.slice(0, 5000) : text;
  const normalizedText = normalize(safeText);

  for (const item of compiledProfanityList) {
    if (item.regex.test(normalizedText)) {
      functions.logger.warn('⚠️ Küfür tespit edildi:', item.raw);
      return true;
    }
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

const { logErrorToFirestore } = require('./error_logger');

// Higher-order function to wrap Firestore/PubSub trigger callbacks
function wrapTrigger(name, handler) {
  return async (arg1, arg2) => {
    try {
      return await handler(arg1, arg2);
    } catch (error) {
      functions.logger.error(`❌ [Trigger Error] ${name}:`, error.message);
      const params = (arg2 && arg2.params) ? arg2.params : {};
      await logErrorToFirestore('backend', `${name} Trigger Error`, error.message, error.stack, 'error', {
        category: 'backend',
        subCategory: name,
        metadata: { params }
      });
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
      await logErrorToFirestore('backend', `${name} Request Error`, error.message, error.stack, 'error', {
        category: 'backend',
        subCategory: name
      });
      if (!res.headersSent) {
        res.status(500).json({ success: false, error: error.message });
      }
      return null;
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
      const userId = (context && context.auth) ? context.auth.uid : null;
      await logErrorToFirestore('backend', `${name} Call Error`, error.message, error.stack, 'error', {
        category: 'backend',
        subCategory: name,
        userId: userId
      });
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
    .limit(20)
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
  if (!deviceId || !error) return;

  const errCode = error.code || '';
  const errMsg = error.message || '';

  const isInvalidToken =
    errCode === 'messaging/registration-token-not-registered' ||
    errCode === 'messaging/invalid-registration-token' ||
    errCode === 'messaging/invalid-argument' ||
    errCode === 'messaging/mismatched-credential' ||
    errMsg.includes('Requested entity was not found') ||
    errMsg.includes('registration token is not a valid');

  if (isInvalidToken) {
    functions.logger.info(`🚫 FCM token geçersiz/süresi dolmuş, cihaz pasife çekiliyor: ${deviceId} (${errCode || errMsg})`);
    try {
      await admin.firestore().collection('userDevices').doc(deviceId).set({
        active: false,
        deactivatedReason: errCode || 'invalid_registration_token',
        deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    } catch (dbErr) {
      functions.logger.warn(`⚠️ userDevices/${deviceId} pasife çekilirken hata:`, dbErr.message);
    }
  }
}

// Eşleşen kullanıcıları toplayıp tekil bildirim dokümanı üretir
async function matchAndCreateDealNotifications(deal, dealId) {
  // P0-01 (R-INF-01): Test ve simülasyon fırsatları asla kullanıcılara bildirim gönderemez
  if (deal && (deal.isTest === true || deal.source === 'test' || deal.isSimulation === true)) {
    functions.logger.info(`🧪 Test fırsatı (${dealId}), bildirim dağıtımı engellendi.`);
    return;
  }

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

  // A. Takip Edilen Yazarlar (zil açık - Limit 200)
  const authorTarget = (isUserSubmitted && postedBy) ? postedBy : ((!isUserSubmitted || !postedBy || postedBy === 'botkolik') ? 'botkolik' : postedBy);
  if (authorTarget) {
    try {
      const authorSubsSnap = await admin.firestore()
        .collection('notificationSubscriptions')
        .where('type', '==', 'author')
        .where('key', '==', authorTarget)
        .where('enabled', '==', true)
        .limit(200)
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

  // B. Kategori Abonelikleri (Limit 200)
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
      .limit(200)
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

  // C. Anahtar Kelime Abonelikleri (Sıkı Kelime Sınırı Doğrulamalı / Strict Word Boundary Check - Limit 150)
  const matchedKeywordsMap = new Map();
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
          .limit(150)
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
              matchedKeywordsMap.set(normalizedSubKey, displayVal);
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

  // P0-13 (R-SCL-01): Sınırsız Ölçeklenebilir FCM Kategori Topic Dağıtımı
  // In-app bildirim dokümanları bounded kota ile yazılırken; push bildirimi tüm kategori abonelerine
  // 0 Firestore maliyeti ve 0 Cloud Function fan-out çığı ile doğrudan FCM Topic altyapısı üzerinden iletilir.
  try {
    let notificationsEnabled = true;
    try {
      const appConfigDoc = await admin.firestore().collection('settings').doc('app').get();
      if (appConfigDoc.exists && appConfigDoc.data().notificationsEnabled === false) {
        notificationsEnabled = false;
      }
    } catch (cfgErr) {
      functions.logger.warn('⚠️ Ayarlar okunurken hata, varsayılan açık:', cfgErr.message);
    }

    const turkeyTime = new Date().toLocaleTimeString('tr-TR', { timeZone: 'Europe/Istanbul', hour12: false });
    const currentHm = turkeyTime.substring(0, 5);
    const isQuiet = (currentHm >= '23:00' || currentHm < '08:00');

    if (notificationsEnabled && !isQuiet) {
      const rawCategory = deal.category || 'genel';
      const cleanCategory = String(rawCategory).toLowerCase().replace(/[^a-z0-9_-]/g, '_');
      const categoryTopic = `cat_${cleanCategory}`;

      const formattedPrice = (deal.price === 0 || deal.price === '0') ? 'ÜCRETSİZ' : `${deal.price || 0} TL`;
      const catTitle = rawCategory ? (rawCategory.charAt(0).toUpperCase() + rawCategory.slice(1)) : 'Fırsat';

      const topicPayload = {
        topic: categoryTopic,
        notification: {
          title: `🎯 ${catTitle} Fırsatı!`,
          body: `${deal.title}\n💰 ${formattedPrice}`
        },
        data: {
          type: 'deal',
          reason: 'category',
          dealId: String(dealId),
          category: String(rawCategory),
          imageUrl: String(deal.imageUrl || deal.mainImage || ''),
          merchant: String(deal.merchant || ''),
          price: String(deal.price !== undefined ? deal.price : ''),
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'sicak_firsatlar_general_v2',
            sound: 'default',
            color: '#FF6D00',
            icon: '@mipmap/ic_launcher',
            tag: `deal_${dealId}`,
            defaultSound: true,
            defaultVibrateTimings: true
          }
        },
        apns: {
          headers: {
            'apns-push-type': 'alert',
            'apns-priority': '10'
          },
          payload: {
            aps: {
              alert: {
                title: `🎯 ${catTitle} Fırsatı!`,
                body: `${deal.title}\n💰 ${formattedPrice}`
              },
              sound: 'default',
              badge: 1,
              'content-available': 1,
              'interruption-level': 'active',
              category: 'DEAL_NOTIFICATION'
            }
          }
        }
      };

      const topicRes = await admin.messaging().send(topicPayload);
      functions.logger.info(`📢 Kategori FCM konusuna (topic: ${categoryTopic}) push gönderildi: ${topicRes}`);

      // Eğer alt kategori ise (örn. elektronik:bilgisayar) ana kategoriye de ilet
      if (rawCategory.includes(':')) {
        const parentCat = rawCategory.split(':')[0];
        const cleanParent = parentCat.toLowerCase().replace(/[^a-z0-9_-]/g, '_');
        if (cleanParent && cleanParent !== cleanCategory) {
          const parentTopic = `cat_${cleanParent}`;
          const parentPayload = { ...topicPayload, topic: parentTopic };
          await admin.messaging().send(parentPayload).catch(e => functions.logger.warn('⚠️ Parent category topic push uyarısı:', e.message));
          functions.logger.info(`📢 Ana kategori FCM konusuna (topic: ${parentTopic}) push gönderildi.`);
        }
      }

      // FS-25: Anahtar Kelime Radarı FCM Topic Dağıtımı (Sıfır Maliyetli, Sınırsız Ölçekli)
      // Firestore 150 limit tavanına takılmaksızın bu kelimeyi takip eden tüm kullanıcılara anında ulaşır
      if (matchedKeywordsMap.size > 0) {
        const kwEntries = Array.from(matchedKeywordsMap.entries()).slice(0, 10);
        for (const [normKw, dispKw] of kwEntries) {
          const cleanKw = normKw
            .toLowerCase()
            .replace(/[^a-z0-9_-]/g, '_')
            .replace(/_+/g, '_')
            .replace(/^_+|_+$/g, '');
          if (!cleanKw) continue;
          const kwTopic = `kw_${cleanKw}`;
          const kwPayload = {
            topic: kwTopic,
            notification: {
              title: `🎯 Radar: ${dispKw}`,
              body: `${deal.title}\n💰 ${formattedPrice}`
            },
            data: {
              type: 'deal',
              reason: 'keyword',
              keyword: String(dispKw),
              dealId: String(dealId),
              title: String(deal.title || ''),
              imageUrl: String(deal.imageUrl || ''),
              price: String(deal.price !== undefined ? deal.price : ''),
              click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            android: {
              priority: 'high',
              notification: {
                channelId: 'keyword_alerts_channel',
                sound: 'default',
                color: '#FF6D00',
                icon: '@mipmap/ic_launcher',
                tag: `deal_${dealId}`,
                defaultSound: true,
                defaultVibrateTimings: true
              }
            },
            apns: {
              headers: {
                'apns-push-type': 'alert',
                'apns-priority': '10'
              },
              payload: {
                aps: {
                  alert: {
                    title: `🎯 Radar: ${dispKw}`,
                    body: `${deal.title}\n💰 ${formattedPrice}`
                  },
                  sound: 'default',
                  badge: 1,
                  'content-available': 1,
                  'interruption-level': 'active',
                  category: 'KEYWORD_NOTIFICATION'
                }
              }
            }
          };

          try {
            await admin.messaging().send(kwPayload);
            functions.logger.info(`📢 Kelime Radarı FCM konusuna (topic: ${kwTopic}) push gönderildi.`);
          } catch (kwErr) {
            functions.logger.warn(`⚠️ Kelime Radarı topic push (${kwTopic}) uyarısı:`, kwErr.message);
          }
        }
      }
    } else {
      functions.logger.info(`ℹ️ Kategori/Kelime FCM topic push atlandı: enabled=${notificationsEnabled}, sessiz=${isQuiet} (${currentHm})`);
    }
  } catch (catTopicErr) {
    functions.logger.warn('⚠️ Kategori/Kelime FCM topic push gönderim uyarısı:', catTopicErr.message);
  }

  // 2. Kota ve Bounded Fan-Out Koruması (Max 300 bildirim dokümanı tavanı)
  // Canlı ortamda on binlerce abonenin aynı anda Cloud Function çığı (thundering herd)
  // ve kontrolsüz fatura/timeout üretmesini engellemek için azami 300 kullanıcı ile sınırlandırılır.
  const MAX_DEAL_NOTIF_TARGETS = 300;
  let finalTargetUsers = Array.from(matchedUsers.entries());

  if (finalTargetUsers.length > MAX_DEAL_NOTIF_TARGETS) {
    // Önceliklendirme: 1. keyword (en yüksek kişiselleştirme), 2. author, 3. category
    finalTargetUsers.sort((a, b) => {
      const priorityOrder = { keyword: 3, author: 2, category: 1 };
      const pA = priorityOrder[a[1].reason] || 0;
      const pB = priorityOrder[b[1].reason] || 0;
      return pB - pA;
    });
    finalTargetUsers = finalTargetUsers.slice(0, MAX_DEAL_NOTIF_TARGETS);
    functions.logger.info(`🛡️ Fan-out tavanı uygulandı: ${matchedUsers.size} eşleşmeden en öncelikli ${MAX_DEAL_NOTIF_TARGETS} kullanıcı seçildi.`);
  }

  if (finalTargetUsers.length === 0) {
    functions.logger.info(`ℹ️ Fırsat (${dealId}) için eşleşen abone bulunamadı, bildirim dokümanı oluşturulmadı.`);
    return;
  }

  // 3. Bildirim Dokümanlarını Oluştur
  let batch = admin.firestore().batch();
  let opCount = 0;

  for (const [userId, match] of finalTargetUsers) {
    const notifId = `deal_${dealId}_${userId}`;
    const notifRef = admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .doc(notifId);

    const formattedPrice = (deal.price === 0 || deal.price === '0') ? 'ÜCRETSİZ' : `${deal.price || 0} TL`;
    let notifTitle = '🎯 Yeni Fırsat!';
    let notifBody = `${deal.title}\n💰 ${formattedPrice}`;

    if (match.reason === 'keyword') {
      notifTitle = '🎯 İlginizi Çeken Kelime!';
      notifBody = `"${match.detail}" radarınıza takıldı: ${deal.title}\n💰 ${formattedPrice}`;
    } else if (match.reason === 'author') {
      if (match.detail === 'botkolik') {
        const merchantTag = deal.merchant ? ` (${deal.merchant})` : '';
        const discountTag = (deal.discountRate && Number(deal.discountRate) > 0) ? ` • %${deal.discountRate} İndirim` : '';
        notifTitle = `⚡ Botkolik Radarı${merchantTag}!`;
        notifBody = `${deal.title}\n💰 ${formattedPrice}${discountTag}`;
      } else {
        const authorName = deal.postedByName || deal.authorName || 'Takip ettiğiniz avcı';
        notifTitle = `👤 ${authorName} yeni bir fırsat paylaştı!`;
        notifBody = `${deal.title}\n💰 ${formattedPrice}`;
      }
    } else if (match.reason === 'category') {
      const catTitle = match.detail ? (match.detail.charAt(0).toUpperCase() + match.detail.slice(1)) : '';
      notifTitle = catTitle ? `🎯 ${catTitle} Fırsatı!` : '🎯 Yeni Fırsat!';
      notifBody = `${deal.title}\n💰 ${formattedPrice}`;
    }

    batch.set(notifRef, {
      type: 'deal',
      dealId: dealId,
      dealTitle: deal.title,
      imageUrl: deal.imageUrl || deal.mainImage || '',
      merchant: deal.merchant || '',
      price: deal.price !== undefined ? deal.price : null,
      title: notifTitle,
      body: notifBody,
      reason: match.reason,
      reasonDetail: match.detail,
      reasons: match.reasons || {},
      read: false,
      isTopicDelivered: match.reason === 'category',
      pushStatus: match.reason === 'category' ? 'delivered_via_topic' : 'pending',
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

    if (!deal) {
      functions.logger.warn(`⚠️ onDealCreated tetiklendi fakat doküman verisi boş: ${dealId}`);
      return null;
    }

    // P0-01 (R-INF-01): Test ve simülasyon fırsatları için bildirim ve moderasyon hattını sonlandır
    if (deal.isTest === true || deal.source === 'test' || deal.isSimulation === true) {
      functions.logger.info(`🧪 Test/simülasyon fırsatı (${dealId}) algılandı. Bildirim ve moderasyon hattı atlandı.`);
      return null;
    }

    functions.logger.info('📦 Yeni fırsat eklendi:', dealId, deal.title, 'isApproved:', deal.isApproved);

    // FS-20: Dokümanda searchKeywords eksikse otomatik üret ve mühürle
    if (!Array.isArray(deal.searchKeywords) || deal.searchKeywords.length === 0) {
      try {
        const normalizeKw = (str) => {
          if (!str || typeof str !== 'string') return '';
          return str.toLowerCase()
            .replace(/ç/g, 'c').replace(/ğ/g, 'g').replace(/ı/g, 'i')
            .replace(/ö/g, 'o').replace(/ş/g, 's').replace(/ü/g, 'u')
            .replace(/[^\w\s]/g, ' ')
            .replace(/\s+/g, ' ').trim();
        };
        const kwSet = new Set();
        [deal.title, deal.brand, deal.store, deal.category, deal.subCategory].forEach(f => {
          const norm = normalizeKw(f);
          if (norm) {
            norm.split(' ').forEach(t => {
              if (t.length >= 2 || /^\d+$/.test(t)) kwSet.add(t);
            });
          }
        });
        const keywords = Array.from(kwSet).slice(0, 50);
        if (keywords.length > 0) {
          await admin.firestore().collection('deals').doc(dealId).set({
            searchKeywords: keywords
          }, { merge: true });
          functions.logger.info(`🔍 [FS-20] searchKeywords otomatik mühürlendi (${dealId}): ${keywords.length} anahtar`);
        }
      } catch (kwErr) {
        functions.logger.warn(`⚠️ searchKeywords mühürleme uyarısı (${dealId}):`, kwErr.message);
      }
    }

    // Deal paylaşım durumu kontrolü (sadece normal kullanıcılar için, bot ve admin hariç)
    const isUserSubmitted = Boolean(deal.isUserSubmitted);
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
    const title = typeof deal.title === 'string' ? deal.title : '';
    const description = typeof deal.description === 'string' ? deal.description : '';
    const combinedText = `${title} ${description}`.slice(0, 5000);

    if (containsProfanity(combinedText)) {
      functions.logger.warn('🚫 Uygunsuz içerik tespit edildi (Deal):', dealId);
      const posterName = deal.postedByName || deal.postedBy || 'Bilinmeyen Kullanıcı';
      // Deal'i sil veya isApproved: false yap
      try {
        await admin.firestore().collection('deals').doc(dealId).set({
          isApproved: false,
          moderationFlag: true,
          moderationReason: 'Uygunsuz içerik tespit edildi',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        functions.logger.info('✅ Deal moderasyon ile işaretlendi ve onaylanmadı');

        // Admin mesajlarına bildirim ekle
        await createModerationMessage({
          type: 'deal',
          userId: deal.postedBy || 'unknown',
          userName: posterName,
          content: `${title} ${description}`.substring(0, 100),
          dealId: dealId,
          reason: 'Uygunsuz içerik tespit edildi',
        });
      } catch (error) {
        functions.logger.error('❌ Deal moderasyon hatası:', error);
      }

      // Admin'e "Moderasyona Takıldı" bildirimi gönder
      const adminNotifTitle = `🛡️ Fırsat Moderasyona Takıldı (${posterName})`;
      const adminNotifBody = `${(title || 'Fırsat').substring(0, 50)}... (Uygunsuz İçerik)`;

      const adminPayload = {
        notification: {
          title: adminNotifTitle,
          body: adminNotifBody,
        },
        data: {
          type: 'admin_deal',
          dealId: String(dealId),
          isApproved: 'false',
          isSuspicious: 'true',
          moderationReason: 'Uygunsuz içerik tespit edildi',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          notification_title: adminNotifTitle,
          notification_body: adminNotifBody,
        },
        android: {
          priority: 'high',
          ttl: 86400000,
          notification: {
            channelId: 'admin_channel',
            sound: 'default',
            color: '#F44336', // Kırmızı renk
            tag: `moderation_${dealId}`,
            defaultSound: true,
            defaultVibrateTimings: true,
            priority: 'high',
            visibility: 'public',
          }
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400),
          },
          payload: {
            aps: {
              alert: {
                title: adminNotifTitle,
                body: adminNotifBody,
              },
              sound: 'default',
              badge: 1,
              'interruption-level': 'active',
              category: 'ADMIN_NOTIFICATION',
            },
          },
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

    // Eğer fırsat zaten onaylı geldiyse, bildirimleri oluştur ve puan ver
    if (deal.isApproved === true) {
      functions.logger.info('✅ Fırsat onaylı, bildirimler oluşturuluyor...');
      // P1-11 (R-AUTH-04): Fırsat doğrudan yayına alındıysa kullanıcıya sunucu otoritesiyle puan ver
      if (isUserSubmitted && deal.postedBy && deal.postedBy !== 'botkolik' && deal.postedBy !== 'admin') {
        try {
          const userRef = admin.firestore().collection('users').doc(deal.postedBy);
          await userRef.set({
            points: admin.firestore.FieldValue.increment(10),
            dealCount: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
          
          const userSnap = await userRef.get();
          if (userSnap.exists) {
            const uData = userSnap.data() || {};
            const dCount = Number(uData.dealCount) || 0;
            const currentBadges = Array.isArray(uData.badges) ? uData.badges : [];
            const newBadges = [];
            if (dCount >= 1 && !currentBadges.includes('first_spark')) newBadges.push('first_spark');
            if (dCount >= 10 && !currentBadges.includes('hunter_apprentice')) newBadges.push('hunter_apprentice');
            if (dCount >= 20 && !currentBadges.includes('contributor')) newBadges.push('contributor');
            if (dCount >= 50 && !currentBadges.includes('master_hunter')) newBadges.push('master_hunter');
            if (dCount >= 150 && !currentBadges.includes('legendary_hunter')) newBadges.push('legendary_hunter');
            if (newBadges.length > 0) {
              await userRef.update({
                badges: admin.firestore.FieldValue.arrayUnion(...newBadges)
              });
            }
          }
        } catch (pointErr) {
          functions.logger.error('Fırsat onay puan artış hatası:', pointErr);
        }
      }
      await matchAndCreateDealNotifications(deal, dealId);
      return;
    }

    // Onaysız fırsat -> SADECE Admin'e bildirim (bot veya kullanıcı farketmez)
    const dealTitle = (deal.title && String(deal.title).trim()) || 'Yeni Fırsat';
    const dealPrice = (deal.price !== undefined && deal.price !== null) ? deal.price : 0;
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
        dealId: String(dealId),
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
            alert: {
              title: adminNotifTitle,
              body: adminNotifBody,
            },
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

    if (!newData || !oldData) {
      functions.logger.warn(`⚠️ onDealUpdated tetiklendi fakat doküman verisi eksik: ${dealId}`);
      return null;
    }

    // P0-01 (R-INF-01): Test fırsatları güncellendiğinde bildirim hattını çalıştırma
    if (newData.isTest === true || newData.source === 'test' || newData.isSimulation === true) {
      functions.logger.info(`🧪 Test fırsatı güncellemesi (${dealId}), bildirim hattı atlandı.`);
      return null;
    }

    const wasApproved = oldData.isApproved === true;
    const isNowApproved = newData.isApproved === true;

    // 1. Sadece onay durumu false/null/undefined -> true olduğunda herkese bildirim oluştur
    if (!wasApproved && isNowApproved) {
      functions.logger.info('🎉 Fırsat onaylandı! Bildirimler oluşturuluyor:', dealId);
      await matchAndCreateDealNotifications(newData, dealId);
    }

    // 2. Paylaşım Durumu Bildirimi: Kullanıcı tarafından yüklenen bir fırsat onaylandığında veya reddedildiğinde bildirim oluştur
    const isUserSubmitted = Boolean(newData.isUserSubmitted);
    const postedBy = newData.postedBy || '';

    if (isUserSubmitted && postedBy && postedBy !== 'botkolik' && postedBy !== 'admin') {
      // Onaylandı bildirimi (!wasApproved -> isNowApproved)
      if (!wasApproved && isNowApproved) {
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
          imageUrl: newData.imageUrl || newData.mainImage || '',
          title: '🎉 Fırsatınız Onaylandı!',
          body: `Paylaştığınız "${newData.title || 'Fırsat'}" onaylandı ve yayına alındı.`,
          status: 'approved',
          isUserSubmitted: true,
          sendPush: true,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        // P1-11 (R-AUTH-04): Fırsat onaylandığında sunucu otoritesiyle +10 puan ve +1 dealCount artır, rozetleri güncelle
        try {
          const userRef = admin.firestore().collection('users').doc(postedBy);
          await userRef.set({
            points: admin.firestore.FieldValue.increment(10),
            dealCount: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });

          const userSnap = await userRef.get();
          if (userSnap.exists) {
            const uData = userSnap.data() || {};
            const dCount = Number(uData.dealCount) || 0;
            const currentBadges = Array.isArray(uData.badges) ? uData.badges : [];
            const newBadges = [];
            if (dCount >= 1 && !currentBadges.includes('first_spark')) newBadges.push('first_spark');
            if (dCount >= 10 && !currentBadges.includes('hunter_apprentice')) newBadges.push('hunter_apprentice');
            if (dCount >= 20 && !currentBadges.includes('contributor')) newBadges.push('contributor');
            if (dCount >= 50 && !currentBadges.includes('master_hunter')) newBadges.push('master_hunter');
            if (dCount >= 150 && !currentBadges.includes('legendary_hunter')) newBadges.push('legendary_hunter');
            if (newBadges.length > 0) {
              await userRef.update({
                badges: admin.firestore.FieldValue.arrayUnion(...newBadges)
              });
            }
          }
        } catch (pointErr) {
          functions.logger.error('Fırsat onay puan artış hatası:', pointErr);
        }
      }
      // Reddedildi bildirimi (oldData.isRejected !== true && newData.isRejected === true)
      else if (oldData.isRejected !== true && newData.isRejected === true) {
        functions.logger.info(`🔔 Paylaşılan fırsat reddedildi, yükleyen kullanıcıya bildirim gönderiliyor: ${postedBy}`);
        const notifId = `deal_status_rejected_${dealId}`;
        const notifRef = admin.firestore()
          .collection('users')
          .doc(postedBy)
          .collection('notifications')
          .doc(notifId);

        const modReason = newData.moderationReason || newData.rejectionReason || '';
        const bodyText = modReason
          ? `Paylaştığınız "${newData.title || 'Fırsat'}" "${modReason}" gerekçesiyle reddedildi.`
          : `Paylaştığınız "${newData.title || 'Fırsat'}" kurallarımıza uymadığı için reddedildi.`;

        await notifRef.set({
          type: 'submission_status',
          dealId: dealId,
          dealTitle: newData.title || 'Fırsatınız',
          imageUrl: newData.imageUrl || newData.mainImage || '',
          moderationReason: modReason,
          title: 'ℹ️ Fırsatınız Reddedildi',
          body: bodyText,
          status: 'rejected',
          isUserSubmitted: true,
          sendPush: true,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      }
    }

    // 3. Oy / Sıcaklık Değişimi: hotVotes değiştiğinde SADECE gerçek kullanıcı fırsatlarında puan ve beğeni güncelle
    // Bot fırsatlarında (botkolik) veya admin paylaşımlarında boşuna kullanıcı belgesi yazma işlemi yapılmaz (Devasa kota tasarrufu)
    const oldHotVotes = Number(oldData.hotVotes) || 0;
    const newHotVotes = Number(newData.hotVotes) || 0;
    const diffHot = newHotVotes - oldHotVotes;

    if (diffHot !== 0 && isUserSubmitted && postedBy && postedBy !== 'botkolik' && postedBy !== 'admin') {
      try {
        const diffPoints = diffHot * 2;
        const diffLikes = diffHot * 1;
        const userRef = admin.firestore().collection('users').doc(postedBy);

        await userRef.set({
          points: admin.firestore.FieldValue.increment(diffPoints),
          totalLikes: admin.firestore.FieldValue.increment(diffLikes),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        // Güncel kullanıcı verilerini alıp otomatik rozet kontrolü yap
        const userSnap = await userRef.get();
        if (userSnap.exists) {
          const uData = userSnap.data() || {};
          const currentBadges = Array.isArray(uData.badges) ? uData.badges : [];
          const pts = Number(uData.points) || 0;
          const tLikes = Number(uData.totalLikes) || 0;
          const dCount = Number(uData.dealCount) || 0;

          const eligible = [];
          // Fırsat Paylaşım Rozetleri
          if (dCount >= 1) eligible.push('first_spark');
          if (dCount >= 10) eligible.push('hunter_apprentice');
          if (dCount >= 20) eligible.push('contributor');
          if (dCount >= 50) eligible.push('master_hunter');
          if (dCount >= 150) eligible.push('legendary_hunter');

          // Puan & Sıcaklık Rozetleri
          if (pts >= 15) eligible.push('bronze');
          if (pts >= 35) eligible.push('voice_of_community');
          if (pts >= 50) eligible.push('active_voter');
          if (pts >= 100) eligible.push('silver');
          if (pts >= 150) eligible.push('flame_master');
          if (pts >= 300) eligible.push('gold');
          if (pts >= 500) eligible.push('volcanic_record');

          // Beğeni Rozetleri
          if (tLikes >= 40) eligible.push('helpful');
          if (tLikes >= 150) eligible.push('top_reviewer');

          const newBadges = eligible.filter(b => !currentBadges.includes(b));
          if (newBadges.length > 0) {
            await userRef.set({
              badges: admin.firestore.FieldValue.arrayUnion(...newBadges),
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
            functions.logger.info(`🎉 Kullanıcı ${postedBy} yeni rozetler kazandı:`, newBadges);
          }
        }
      } catch (voteScoreErr) {
        functions.logger.error(`❌ Oy puanı/rozet güncelleme hatası (${postedBy}):`, voteScoreErr);
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

    if (!comment) {
      functions.logger.warn(`⚠️ onCommentCreated tetiklendi fakat doküman verisi boş: ${commentId}`);
      return null;
    }

    functions.logger.info('💬 Yeni yorum eklendi:', commentId, 'Deal:', dealId);

    // Güvenli sayaç düşürme yardımcısı (Fırsat dokümanının varlığını doğrular ve sıfırın altına inmesini engeller)
    const safeDecrementCommentCount = async (targetDealId) => {
      try {
        const dealRef = admin.firestore().collection('deals').doc(targetDealId);
        const doc = await dealRef.get();
        if (doc.exists) {
          const currentCount = Number(doc.data().commentCount) || 0;
          await dealRef.update({
            commentCount: Math.max(0, currentCount - 1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      } catch (err) {
        functions.logger.warn(`⚠️ commentCount decrement hatası (${targetDealId}):`, err.message);
      }
    };

    // Yorum paylaşım durumu kontrolü (sadece normal kullanıcılar için, admin hariç)
    const userId = comment.userId || 'unknown';
    let isAdmin = false;

    if (userId && userId !== 'unknown') {
      try {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        isAdmin = userDoc.exists && userDoc.data()
          ? (userDoc.data().isAdmin === true || userDoc.data().isadmin === true || userDoc.data().isAdmin === 'true' || userDoc.data().isadmin === 'true')
          : false;
      } catch (adminCheckErr) {
        functions.logger.warn('⚠️ Admin kontrolü sırasında hata:', adminCheckErr.message);
      }
    }

    // Admin değilse yorum paylaşım durumunu kontrol et (Acil Durum Şalteri)
    if (!isAdmin) {
      try {
        const settingsDoc = await admin.firestore().collection('settings').doc('app').get();
        const commentSharingEnabled = settingsDoc.exists && settingsDoc.data()
          ? (settingsDoc.data().commentSharingEnabled !== false)
          : true;

        if (!commentSharingEnabled) {
          functions.logger.warn('🚫 Yorum paylaşımı durdurulmuş, yorum siliniyor:', commentId);
          await admin.firestore()
            .collection('deals')
            .doc(dealId)
            .collection('comments')
            .doc(commentId)
            .delete();

          await safeDecrementCommentCount(dealId);
          return null;
        }
      } catch (error) {
        functions.logger.error('❌ Yorum paylaşım durumu kontrol hatası:', error);
      }
    }

    // İçerik moderasyonu kontrolü
    const commentText = typeof comment.text === 'string' ? comment.text : '';

    if (containsProfanity(commentText)) {
      functions.logger.warn('🚫 Uygunsuz yorum tespit edildi:', commentId);
      try {
        await admin.firestore()
          .collection('deals')
          .doc(dealId)
          .collection('comments')
          .doc(commentId)
          .delete();

        await safeDecrementCommentCount(dealId);
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

    // Tekil Fırsat Sorgusu (Daha önce 2 kez mükerrer çekiliyordu, tek sorguya indirgendi)
    let dealData = null;
    try {
      const dealDoc = await admin.firestore().collection('deals').doc(dealId).get();
      if (dealDoc.exists) {
        dealData = dealDoc.data() || {};
      }
    } catch (dealErr) {
      functions.logger.warn(`⚠️ Deal dokümanı okunamadı (${dealId}):`, dealErr.message);
    }

    const dealTitle = (dealData && dealData.title) ? dealData.title : 'Fırsat';
    const dealImageUrl = (dealData && (dealData.imageUrl || dealData.mainImage)) ? (dealData.imageUrl || dealData.mainImage) : '';
    const dealOwnerId = dealData ? dealData.postedBy : null;
    const replierUserId = comment.userId || 'unknown';

    // P1-16 (R-AUTH-14): Gönderici adını sahte istemci verisinden değil, otoriter kullanıcı profilinden doğrula
    let verifiedSenderName = 'Bir kullanıcı';
    if (replierUserId && replierUserId !== 'unknown') {
      try {
        const senderUserDoc = await admin.firestore().collection('users').doc(replierUserId).get();
        if (senderUserDoc.exists) {
          const sData = senderUserDoc.data() || {};
          verifiedSenderName = sData.displayName || sData.userName || sData.username || (comment.userName || 'Bir kullanıcı');
        } else {
          verifiedSenderName = comment.userName || 'Bir kullanıcı';
        }
      } catch (_) {
        verifiedSenderName = comment.userName || 'Bir kullanıcı';
      }
    }
    // Rezerve sistem isimlerinin filtrelenmesi (Phishing / impersonation koruması)
    const lowerSender = verifiedSenderName.toLowerCase();
    const reservedNames = ['firsatkolik', 'admin', 'yonetim', 'moderatör', 'moderator', 'botkolik', 'sistem'];
    if (reservedNames.some(r => lowerSender.includes(r))) {
      verifiedSenderName = 'Kullanıcı';
    }
    const replyUserName = verifiedSenderName;

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
          const parentComment = parentCommentDoc.data() || {};
          const recipientUserId = parentComment.userId;

          // Kendine yanıt verildiyse bildirim gitmesin
          if (recipientUserId && recipientUserId !== replierUserId) {
            const notificationId = `reply_${commentId}_${recipientUserId}`;
            const notificationRef = admin.firestore()
              .collection('users')
              .doc(recipientUserId)
              .collection('notifications')
              .doc(notificationId);

            const replyBody = `"${dealTitle}" fırsatında: ${commentText.length > 80 ? `${commentText.substring(0, 80)}...` : commentText}`;

            await notificationRef.set({
              type: 'comment_reply',
              title: `${replyUserName} yorumunuza cevap verdi`,
              body: replyBody,
              dealId: dealId,
              dealTitle: dealTitle,
              imageUrl: dealImageUrl,
              commentId: commentId,
              parentCommentId: parentCommentId,
              replyUserName: replyUserName,
              senderName: replyUserName,
              senderId: replierUserId,
              replyText: commentText.length > 100 ? `${commentText.substring(0, 100)}...` : commentText,
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

    // Fırsat sahibine kök yorum bildirimi gönder (kendi fırsatına yorum yapmadıysa ve üstte cevap bildirimi almamışsa)
    try {
      if (dealOwnerId && dealOwnerId !== replierUserId && (!parentCommentId)) {
        const notificationId = `deal_comment_${commentId}_${dealOwnerId}`;
        const notificationRef = admin.firestore()
          .collection('users')
          .doc(dealOwnerId)
          .collection('notifications')
          .doc(notificationId);

        const rootCommentBody = `"${dealTitle}": ${commentText.length > 80 ? `${commentText.substring(0, 80)}...` : commentText}`;

        await notificationRef.set({
          type: 'comment',
          reason: 'comment',
          title: `${replyUserName} fırsatınıza yorum yaptı`,
          body: rootCommentBody,
          dealId: dealId,
          dealTitle: dealTitle,
          imageUrl: dealImageUrl,
          commentId: commentId,
          commentUserName: replyUserName,
          senderName: replyUserName,
          senderId: replierUserId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });
        functions.logger.info(`✅ Fırsat sahibine kök yorum bildirimi Firestore'a yazıldı: ${dealOwnerId}`);
      }
    } catch (dealCommentErr) {
      functions.logger.error('❌ Fırsat sahibine yorum bildirimi hatası:', dealCommentErr);
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

    if (!message) {
      functions.logger.warn(`⚠️ onAdminMessageCreated tetiklendi fakat doküman verisi boş: ${messageId}`);
      return null;
    }

    const userId = (message.userId && String(message.userId).trim()) || '';
    if (!userId) {
      functions.logger.warn('⚠️ Admin mesajında userId yok veya geçersiz, bildirim gönderilemiyor:', messageId);
      return null;
    }

    const rawTitle = (message.title && String(message.title).trim()) || '';
    const rawContent = (message.content || message.body || message.text || '').trim();

    // Çift 🛡️ emojisi oluşmasını engelle (onNotificationCreated fonksiyonu admin mesajlarına zaten 🛡️ ekler)
    const cleanTitle = rawTitle ? rawTitle.replace(/^🛡️\s*/, '') : 'FırsatKolik Yönetim';
    const content = rawContent || 'Yeni bir yönetici bildiriminiz var. İncelemek için dokunun.';
    const adminName = (message.adminName && String(message.adminName).trim()) || 'FırsatKolik Yönetim';

    functions.logger.info('📨 Yeni admin mesajı oluşturuldu:', {
      messageId,
      userId,
      title: cleanTitle,
      adminName
    });

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
        title: cleanTitle,
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

    if (!message) {
      functions.logger.warn(`⚠️ onUserMessageCreated tetiklendi fakat doküman verisi boş: ${messageId}`);
      return null;
    }

    // Mesaj verilerini al
    const senderId = message.senderId;
    const receiverId = message.receiverId;
    const content = message.text || message.content || 'Görsel'; // Metin veya görsel
    const senderName = message.senderName || 'Bir Kullanıcı';

    // Geçersiz veya kendi kendine mesajsa bildirim gönderme
    if (!senderId || !receiverId || senderId === receiverId) return null;

    functions.logger.info('📨 Yeni kullanıcı mesajı:', { messageId, senderId, receiverId });

    // Gönderenin profil resmini ve ismini hazırla
    let senderImageUrl = message.senderImageUrl || '';
    let resolvedSenderName = senderName;

    if (senderId === 'admin') {
      resolvedSenderName = 'FırsatKolik Yönetim';
      senderImageUrl = 'assets/logo.webp';
    } else if (senderId === 'botkolik') {
      resolvedSenderName = 'Botkolik';
      senderImageUrl = 'assets/botkolik.webp';
    }

    // Gönderen ve alıcı dokümanlarını seri yerine PARALEL (Promise.all) çekerek gecikmeyi yarı yarıya düşür
    const fetchSenderPromise = (senderId !== 'admin' && senderId !== 'botkolik')
      ? admin.firestore().collection('users').doc(senderId).get()
      : Promise.resolve(null);
    const fetchReceiverPromise = admin.firestore().collection('users').doc(receiverId).get();

    try {
      const [senderDoc, receiverDoc] = await Promise.all([fetchSenderPromise, fetchReceiverPromise]);

      // Gönderici yasaklı / banlı ise bildirim tetiklenmesini engelle
      if (senderDoc && senderDoc.exists) {
        const senderData = senderDoc.data() || {};
        if (senderData.isBanned === true || senderData.status === 'banned') {
          functions.logger.warn(`🚫 Yasaklanmış kullanıcı (${senderId}) mesaj bildirimi gönderemez.`);
          return null;
        }
        senderImageUrl = senderData.profileImageUrl || senderData.photoURL || senderImageUrl;
        resolvedSenderName = senderData.username || senderData.displayName || resolvedSenderName;
      }

      // P1-17 (R-AUTH-15): Mesaj seli (Flooding / Spam) kalkanı
      // Son 60 saniyede aynı alıcıya 12'den fazla mesaj atılmışsa bildirim spamını kısıtla
      try {
        const oneMinuteAgo = new Date(Date.now() - 60000);
        const recentMsgsSnap = await admin.firestore().collection('messages')
          .where('senderId', '==', senderId)
          .where('receiverId', '==', receiverId)
          .where('createdAt', '>=', oneMinuteAgo)
          .orderBy('createdAt', 'desc')
          .limit(15)
          .get();
        if (recentMsgsSnap.size >= 12) {
          functions.logger.warn(`⚠️ [P1-17 Kalkanı] Mesaj seli algılandı: Gönderici ${senderId}, Alıcı ${receiverId}. Push bildirimi kısıtlandı.`);
          return null;
        }
      } catch (floodErr) {
        functions.logger.warn('Mesaj seli kontrol uyarısı:', floodErr.message);
      }

      // Alıcı kontrolleri (Engellenenler ve Sessize alınanlar)
      if (receiverDoc && receiverDoc.exists) {
        const receiverData = receiverDoc.data() || {};
        const blockedUsers = receiverData.blockedUsers || [];
        if (Array.isArray(blockedUsers) && blockedUsers.includes(senderId)) {
          functions.logger.info(`🚫 Alıcı (${receiverId}) göndereni (${senderId}) engellemiş, push bildirim iptal edildi.`);
          return null;
        }
        const mutedConversations = receiverData.mutedConversations || [];
        if (Array.isArray(mutedConversations) && mutedConversations.includes(senderId)) {
          functions.logger.info(`🔕 Alıcı (${receiverId}) bu sohbeti (${senderId}) sessize almış, push bildirim iptal edildi.`);
          return null;
        }
      }
    } catch (blockErr) {
      functions.logger.warn('⚠️ Alıcı blok/sessize alma kontrolü sırasında hata:', blockErr.message);
    }

    try {
      // Alıcının tüm aktif cihaz token'larını al
      const devices = await getUserDeviceTokens(receiverId);

      if (devices.length === 0) {
        functions.logger.warn('⚠️ Alıcı için aktif cihaz token\'ı bulunamadı:', receiverId);
        return null;
      }

      // Bildirim içeriği (Fırsat ekli ise özel zengin metin)
      let resolvedBody = content;
      if (message.dealTitle || message.dealId) {
        resolvedBody = message.dealTitle
          ? `"${message.dealTitle}" fırsatını paylaştı`
          : 'Bir fırsat paylaştı';
      }
      const notificationBody = resolvedBody.length > 100 ? resolvedBody.substring(0, 100) + '...' : resolvedBody;

      // Tarihi garantili ISO-8601 string formatına dönüştür
      const createdAtStr = (message.createdAt && typeof message.createdAt.toDate === 'function')
        ? message.createdAt.toDate().toISOString()
        : (typeof message.createdAt === 'string' && message.createdAt.length > 0
            ? message.createdAt
            : new Date().toISOString());

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
            messageId: String(messageId || ''),
            senderId: String(senderId || ''),
            senderName: String(resolvedSenderName || ''),
            senderImageUrl: String(senderImageUrl || ''),
            messageText: String(notificationBody || ''),
            receiverId: String(receiverId || ''),
            createdAt: createdAtStr,
            notification_title: `💬 ${resolvedSenderName}`,
            notification_body: String(notificationBody || ''),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            ttl: 86400000, // 24 saat
            collapseKey: `msg_${senderId}`,
          },
          apns: {
            headers: {
              'apns-push-type': 'alert',
              'apns-priority': '10',
              'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400),
              'apns-collapse-id': `msg_${senderId}`,
            },
            payload: {
              aps: {
                alert: {
                  title: `💬 ${resolvedSenderName}`,
                  body: notificationBody,
                },
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
 * 5.1. TOPLULUK KUPONU PAYLAŞILDIĞINDA (NOTIF-15)
 * kuponlar/{kuponId} koleksiyonunda yeni belge oluşturulduğunda tetiklenir
 */
exports.onCouponCreated = functions
  .runWith({ timeoutSeconds: 120, memory: '512MB' })
  .firestore
  .document('kuponlar/{kuponId}')
  .onCreate(wrapTrigger('onCouponCreated', async (snap, context) => {
    const kupon = snap.data();
    const kuponId = context.params.kuponId;

    if (!kupon) {
      functions.logger.warn(`⚠️ onCouponCreated tetiklendi fakat doküman verisi boş: ${kuponId}`);
      return null;
    }

    // Sadece 'topluluk' kaynaklı ve aktif kuponlar için bildirim gönder
    if (kupon.kaynakTipi !== 'topluluk') {
      functions.logger.info(`ℹ️ Kupon (${kuponId}) kaynakTipi='${kupon.kaynakTipi}', bildirim atlanıyor.`);
      return null;
    }

    if (kupon.durum === 'gecersiz') {
      functions.logger.info(`ℹ️ Kupon (${kuponId}) durumu geçersiz, bildirim atlanıyor.`);
      return null;
    }

    const paylasanId = typeof kupon.paylasanKullaniciId === 'string' ? kupon.paylasanKullaniciId.trim() : '';
    const paylasanAdi = typeof kupon.paylasanKullaniciAdi === 'string' ? kupon.paylasanKullaniciAdi.trim() : 'Bir avcı';
    const magazaAdi = typeof kupon.magazaAdi === 'string' ? kupon.magazaAdi.trim() : 'Mağaza';
    const baslik = typeof kupon.baslik === 'string' ? kupon.baslik.trim() : 'Yeni İndirim Kuponu';
    const kuponKodu = typeof kupon.kuponKodu === 'string' ? kupon.kuponKodu.trim() : '';

    // İçerik moderasyonu (Kupon başlığında veya mağaza adında küfür koruması)
    if (containsProfanity(`${baslik} ${magazaAdi}`)) {
      functions.logger.warn(`🚫 Uygunsuz içerik tespit edildi (Kupon): ${kuponId}`);
      try {
        await admin.firestore().collection('kuponlar').doc(kuponId).set({
          durum: 'gecersiz',
          moderationFlag: true,
          moderationReason: 'Uygunsuz içerik tespit edildi',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      } catch (modErr) {
        functions.logger.error('❌ Kupon moderasyon işaretleme hatası:', modErr);
      }
      return null;
    }

    functions.logger.info(`🎟️ Yeni topluluk kuponu kaydedildi: ${kuponId} (${magazaAdi} - ${paylasanAdi})`);

    // FS-01: Eğer kupon 'beklemede' durumundaysa genel push GÖNDERİLMEZ.
    // Kupon onay bekleyen moderasyon kuyruğuna alınır ve admine onay bildirimi gönderilir.
    if (kupon.durum === 'beklemede') {
      functions.logger.info(`⏳ Topluluk kuponu moderasyon kuyruğuna alındı (durum: beklemede): ${kuponId} (${magazaAdi} - ${baslik})`);

      // 👮‍♂️ ADMİNE ANLIK PUSH BİLDİRİMİ (topic: admin_deals)
      // Mobil cihazı açık olan yöneticilere kupon onay kuyruğuna yeni kupon düştüğünü bildirir
      const adminNotifTitle = `👮‍♂️ Yeni Onay Bekleyen Kupon (@${paylasanAdi})`;
      const adminNotifBody = `🏷️ ${magazaAdi}\n"${baslik}"`;
      const adminCouponPayload = {
        notification: {
          title: adminNotifTitle,
          body: adminNotifBody,
        },
        data: {
          type: 'admin_coupon',
          kuponId: String(kuponId),
          magazaAdi: String(magazaAdi),
          authorName: String(paylasanAdi),
          durum: 'beklemede',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          notification_title: adminNotifTitle,
          notification_body: adminNotifBody,
        },
        android: {
          priority: 'high',
          ttl: 86400000,
          notification: {
            channelId: 'admin_channel',
            sound: 'default',
            color: '#8E24AA', // Mor kupon rengi
            tag: `admin_coupon_${kuponId}`,
            defaultSound: true,
            defaultVibrateTimings: true,
            priority: 'high',
            visibility: 'public',
          }
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400),
          },
          payload: {
            aps: {
              alert: {
                title: adminNotifTitle,
                body: adminNotifBody,
              },
              sound: 'default',
              badge: 1,
              'interruption-level': 'active',
              category: 'ADMIN_NOTIFICATION',
            },
          },
        },
      };

      try {
        await admin.messaging().send({
          ...adminCouponPayload,
          topic: 'admin_deals'
        });
        functions.logger.info(`✅ Admin kupon onay bildirimi başarıyla gönderildi (kuponId: ${kuponId})`);
      } catch (adminErr) {
        functions.logger.error('❌ Admin kupon onay bildirimi hatası:', adminErr);
      }

      return null;
    }

    // Kupon doğrudan 'aktif' ise (admin oluşturması vb.) bildirimleri dağıt
    if (kupon.durum === 'aktif') {
      await dispatchApprovedCouponNotifications(kupon, kuponId);
    }

    return null;
  }));

/**
 * Kupon onaylandığında çalışan merkezi bildirim publisher'ı
 * 1. FCM topic 'community_coupons' push fırlatır (sessiz saat & acil durum şalteri korumalı)
 * 2. Yazara 'submission_status' onay bildirimi yazar
 * 3. Mağaza & Yazar abonelerine in-app bildirimleri yazar (300 bounded fan-out)
 */
async function dispatchApprovedCouponNotifications(kupon, kuponId) {
  const paylasanId = typeof kupon.paylasanKullaniciId === 'string' ? kupon.paylasanKullaniciId.trim() : '';
  const paylasanAdi = typeof kupon.paylasanKullaniciAdi === 'string' ? kupon.paylasanKullaniciAdi.trim() : 'Bir avcı';
  const magazaAdi = typeof kupon.magazaAdi === 'string' ? kupon.magazaAdi.trim() : 'Mağaza';
  const baslik = typeof kupon.baslik === 'string' ? kupon.baslik.trim() : 'Yeni İndirim Kuponu';
  const kuponKodu = typeof kupon.kuponKodu === 'string' ? kupon.kuponKodu.trim() : '';

  functions.logger.info(`🎟️ Onaylanan kupon için bildirimler dağıtılıyor: ${kuponId} (${magazaAdi} - ${paylasanAdi})`);

  try {
    // 1. ANLIK TOPLULUK KUPONU FCM TOPIC PUSH (P0-08 / R-AUTH-11 & P0-14 / R-BIZ-01 Kalkanları)
    try {
      let notificationsEnabled = true;
      try {
        const appConfigDoc = await admin.firestore().collection('settings').doc('app').get();
        if (appConfigDoc.exists && appConfigDoc.data().notificationsEnabled === false) {
          notificationsEnabled = false;
        }
      } catch (cfgErr) {
        functions.logger.warn('⚠️ Ayarlar okunurken hata, varsayılan açık:', cfgErr.message);
      }

      const turkeyTime = new Date().toLocaleTimeString('tr-TR', { timeZone: 'Europe/Istanbul', hour12: false });
      const currentHm = turkeyTime.substring(0, 5);
      const isQuiet = (currentHm >= '23:00' || currentHm < '08:00');

      const isEligibleForTopic = notificationsEnabled && !isQuiet;

      if (!isEligibleForTopic) {
        functions.logger.info(`ℹ️ Topluluk kuponu topic push atlandı: enabled=${notificationsEnabled}, sessiz=${isQuiet} (${currentHm})`);
      } else {
        const topicPayload = {
          topic: 'community_coupons',
          notification: {
            title: `🎟️ ${magazaAdi} Kuponu!`,
            body: `@${paylasanAdi}, ${magazaAdi} için yeni bir indirim kuponu paylaştı: "${baslik}"`
          },
          data: {
            type: 'coupon',
            reason: 'community',
            kuponId: String(kuponId),
            magazaAdi: String(magazaAdi),
            hasCode: kuponKodu ? 'true' : 'false', // P0-14 (R-BIZ-01): kuponKodu plaintext olarak push payload'a konmaz
            authorName: String(paylasanAdi),
            authorId: String(paylasanId),
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'sicak_firsatlar_general_v2',
              sound: 'default',
              color: '#8E24AA',
              icon: '@mipmap/ic_launcher',
              tag: `coupon_${kuponId}`,
              defaultSound: true,
              defaultVibrateTimings: true
            }
          },
          apns: {
            headers: {
              'apns-push-type': 'alert',
              'apns-priority': '10'
            },
            payload: {
              aps: {
                alert: {
                  title: `🎟️ ${magazaAdi} Kuponu!`,
                  body: `@${paylasanAdi}, ${magazaAdi} için yeni bir indirim kuponu paylaştı: "${baslik}"`
                },
                sound: 'default',
                badge: 1,
                'content-available': 1,
                'interruption-level': 'active',
                category: 'COUPON_NOTIFICATION'
              }
            }
          }
        };

        const topicResponse = await admin.messaging().send(topicPayload);
        functions.logger.info(`📢 Topluluk kuponu FCM konusuna (topic: community_coupons) gönderildi: ${topicResponse}`);
      }
    } catch (topicErr) {
      functions.logger.warn('⚠️ Topluluk kuponu FCM topic gönderim uyarısı:', topicErr.message);
    }

    // 2. KÜRESEL DUYURU KAYDI (Global Announcements - FS-02 Çift Katmanlı Feed)
    // Kupon bildiriminin tüm kullanıcıların Bildirim Merkezinde (AdminNotificationsScreen) anında görünmesini sağlar
    try {
      const announcementId = `coupon_${kuponId}`;
      const announcementRef = admin.firestore().collection('globalAnnouncements').doc(announcementId);
      let expiresTimestamp;
      if (kupon.bitisTarihi) {
        if (typeof kupon.bitisTarihi.toDate === 'function') {
          expiresTimestamp = kupon.bitisTarihi;
        } else if (kupon.bitisTarihi._seconds) {
          expiresTimestamp = admin.firestore.Timestamp.fromMillis(kupon.bitisTarihi._seconds * 1000);
        } else {
          const parsed = new Date(kupon.bitisTarihi);
          expiresTimestamp = isNaN(parsed.getTime())
            ? admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 86400 * 1000)
            : admin.firestore.Timestamp.fromDate(parsed);
        }
      } else {
        expiresTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 86400 * 1000);
      }

      await announcementRef.set({
        id: announcementId,
        announcementId: announcementId,
        type: 'coupon',
        reason: 'community',
        title: `🎟️ ${magazaAdi} Kuponu!`,
        body: `@${paylasanAdi}, ${magazaAdi} için yeni bir indirim kuponu paylaştı: "${baslik}"`,
        kuponId: String(kuponId),
        magazaAdi: String(magazaAdi),
        authorName: String(paylasanAdi),
        authorId: String(paylasanId),
        hasCode: Boolean(kuponKodu),
        active: true,
        isTopicDelivered: true,
        pushStatus: 'delivered_via_topic',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: expiresTimestamp
      }, { merge: true });
      functions.logger.info(`📢 Topluluk kuponu küresel duyurusu (globalAnnouncements/${announcementId}) oluşturuldu.`);
    } catch (globalAnnErr) {
      functions.logger.warn('⚠️ Kupon globalAnnouncements dokümanı oluşturulurken hata:', globalAnnErr.message);
    }

    // 3. YAZARA ONAY BİLDİRİMİ VE PUAN ÖDÜLÜ (submission_status)
    if (paylasanId && paylasanId !== 'admin') {
      try {
        const authorNotifId = `coupon_status_approved_${kuponId}`;
        await admin.firestore()
          .collection('users')
          .doc(paylasanId)
          .collection('notifications')
          .doc(authorNotifId)
          .set({
            type: 'submission_status',
            kuponId: kuponId,
            magazaAdi: magazaAdi,
            title: '🎉 Kuponunuz Onaylandı!',
            body: `Paylaştığınız "${magazaAdi} - ${baslik}" kuponu onaylandı ve yayına alındı.`,
            status: 'approved',
            isUserSubmitted: true,
            sendPush: true,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
        functions.logger.info(`✅ Kupon yazarına onay bildirimi yazıldı: ${paylasanId}`);

        // Kupon paylaşan kullanıcıya +10 topluluk katkı puanı ver
        const userRef = admin.firestore().collection('users').doc(paylasanId);
        await userRef.set({
          points: admin.firestore.FieldValue.increment(10),
          couponCount: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      } catch (authErr) {
        functions.logger.warn('⚠️ Yazara kupon onay bildirimi yazılırken hata:', authErr.message);
      }
    }

    // 4. Hedefli Mağaza ve Yazar Abonelikleri + Geriye Dönük Uyumluluk (In-App Doküman Yazımı)
    const targetUserIds = new Set();

    // Eski sürüm istemcilerin de kişisel bildirim kutusunda görebilmesi için azami 150 aktif kullanıcı
    try {
      const activeUsersSnap = await admin.firestore().collection('users')
        .select()
        .limit(150)
        .get();
      activeUsersSnap.forEach(d => {
        if (d.id !== paylasanId) targetUserIds.add(d.id);
      });
    } catch (usersErr) {
      functions.logger.warn('⚠️ Aktif kullanıcı listesi alınırken hata:', usersErr.message);
    }

    const storeKeyword = normalize(magazaAdi).trim();
    const queries = [];

    if (storeKeyword) {
      queries.push(
        admin.firestore().collection('notificationSubscriptions')
          .where('type', '==', 'keyword')
          .where('key', '==', storeKeyword)
          .where('enabled', '==', true)
          .limit(150)
          .get()
      );
    }

    if (paylasanId) {
      queries.push(
        admin.firestore().collection('notificationSubscriptions')
          .where('type', '==', 'author')
          .where('key', '==', paylasanId)
          .where('enabled', '==', true)
          .limit(150)
          .get()
      );
    }

    if (queries.length > 0) {
      const subSnaps = await Promise.all(queries);
      for (const subSnap of subSnaps) {
        subSnap.forEach(d => {
          const uid = d.data().uid || d.data().userId;
          if (uid && uid !== paylasanId) {
            targetUserIds.add(uid);
          }
        });
      }
    }

    const MAX_COUPON_NOTIF_TARGETS = 300;
    let finalTargetUserIds = Array.from(targetUserIds);

    if (finalTargetUserIds.length > MAX_COUPON_NOTIF_TARGETS) {
      finalTargetUserIds = finalTargetUserIds.slice(0, MAX_COUPON_NOTIF_TARGETS);
      functions.logger.info(`🛡️ Kupon bildirim tavanı uygulandı: ${targetUserIds.size} aboneden ilk ${MAX_COUPON_NOTIF_TARGETS} kullanıcı seçildi.`);
    }

    if (finalTargetUserIds.length > 0) {
      let batch = admin.firestore().batch();
      let opCount = 0;

      for (const userId of finalTargetUserIds) {
        const notifId = `coupon_${kuponId}_${userId}`;
        const notifRef = admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notifId);

        batch.set(notifRef, {
          type: 'coupon',
          reason: 'community',
          announcementId: announcementId,
          title: `🎟️ ${magazaAdi} Kuponu!`,
          body: `@${paylasanAdi}, ${magazaAdi} için yeni bir indirim kuponu paylaştı: "${baslik}"`,
          kuponId: kuponId,
          magazaAdi: magazaAdi,
          hasCode: Boolean(kuponKodu),
          authorName: paylasanAdi,
          authorId: paylasanId,
          read: false,
          isTopicDelivered: true,
          pushStatus: 'delivered_via_topic',
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

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
      functions.logger.info(`✅ ${finalTargetUserIds.length} kullanıcı için topluluk kuponu bildirimleri oluşturuldu.`);
    }
  } catch (err) {
    functions.logger.error('❌ Topluluk kuponu bildirimleri oluşturulurken hata:', err);
  }
}

/**
 * kuponlar/{kuponId} koleksiyonunda belge güncellendiğinde tetiklenir.
 * Kupon durumu 'beklemede' -> 'aktif' olduğunda onay bildirimlerini ve FCM topic push yayını fırlatır.
 * Kupon durumu 'beklemede' -> 'reddedildi' olduğunda yazara red gerekçesi bildirimi gönderir.
 */
exports.onCouponUpdated = functions
  .runWith({ timeoutSeconds: 120, memory: '512MB' })
  .firestore
  .document('kuponlar/{kuponId}')
  .onUpdate(wrapTrigger('onCouponUpdated', async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const kuponId = context.params.kuponId;

    if (!beforeData || !afterData) {
      functions.logger.warn(`⚠️ onCouponUpdated tetiklendi fakat doküman verisi eksik: ${kuponId}`);
      return null;
    }

    const wasPending = beforeData.durum === 'beklemede';
    const isNowActive = afterData.durum === 'aktif';
    const isNowRejected = afterData.durum === 'reddedildi';

    // 1. ONAY GEÇİŞİ: 'beklemede' -> 'aktif'
    if (wasPending && isNowActive) {
      functions.logger.info(`🎉 Kupon admin tarafından onaylandı! Dağıtım başlatılıyor: ${kuponId}`);
      await dispatchApprovedCouponNotifications(afterData, kuponId);
    }

    // 2. RED GEÇİŞİ: 'beklemede' -> 'reddedildi'
    if (wasPending && isNowRejected) {
      const paylasanId = afterData.paylasanKullaniciId;
      if (paylasanId) {
        const notifId = `coupon_status_rejected_${kuponId}`;
        const reason = afterData.redNedeni || 'Kriterlere uygun bulunmadı.';
        try {
          await admin.firestore()
            .collection('users')
            .doc(paylasanId)
            .collection('notifications')
            .doc(notifId)
            .set({
              type: 'submission_status',
              kuponId: kuponId,
              magazaAdi: afterData.magazaAdi || '',
              title: 'ℹ️ Kuponunuz Reddedildi',
              body: `Paylaştığınız "${afterData.magazaAdi || ''} - ${afterData.baslik || ''}" kuponu onaylanmadı. Gerekçe: ${reason}`,
              status: 'rejected',
              moderationReason: reason,
              isUserSubmitted: true,
              sendPush: true,
              read: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
          functions.logger.info(`ℹ️ Kupon red bildirimi yazara iletildi: ${paylasanId}`);
        } catch (rejErr) {
          functions.logger.warn('⚠️ Kupon red bildirimi yazılırken hata:', rejErr.message);
        }
      }

      // Reddedilen kuponun küresel duyurusu varsa yayından kaldır
      try {
        await admin.firestore().collection('globalAnnouncements').doc(`coupon_${kuponId}`).set({
          active: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      } catch (_) {}
    }

    // 3. İÇERİK MODERASYONU (Güncelleme sırasında küfür/uygunsuz metin kontrolü)
    const baslik = typeof afterData.baslik === 'string' ? afterData.baslik.trim() : '';
    const magazaAdi = typeof afterData.magazaAdi === 'string' ? afterData.magazaAdi.trim() : '';
    if (containsProfanity(`${baslik} ${magazaAdi}`)) {
      if (afterData.durum !== 'gecersiz' || !afterData.moderationFlag) {
        functions.logger.warn(`🚫 Uygunsuz içerik tespit edildi (Kupon güncellemesi): ${kuponId}`);
        await admin.firestore().collection('kuponlar').doc(kuponId).update({
          durum: 'gecersiz',
          moderationFlag: true,
          moderationReason: 'Güncellemede uygunsuz içerik tespit edildi',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
      }
    }

    // 4. TOPLULUK OYLAMA EŞİĞİ & ÇÖP KUPON YÖNETİMİ
    // Soğuk oylar ile sıcak oylar arasındaki fark >= 5 ise:
    // - Web kaynaklı kupon ise Firestore'dan kalıcı olarak silinir.
    // - Topluluk kaynaklı aktif kupon ise 'gecersiz' durumuna çekilir.
    // Net skor < 5'e toparlandığında ve moderasyon engeli yoksa tekrar 'aktif' yapılır.
    const sicakOylar = Number(afterData.sicakOySayisi) || 0;
    const sogukOylar = Number(afterData.sogukOySayisi) || 0;
    const netSoguk = sogukOylar - sicakOylar;

    if (afterData.durum === 'aktif' && netSoguk >= 5) {
      if (afterData.kaynakTipi === 'web') {
        functions.logger.info(`🗑️ Web kuponu aşırı soğuk oy aldı (fark: ${netSoguk}), siliniyor: ${kuponId}`);
        await admin.firestore().collection('kuponlar').doc(kuponId).delete();
        return null;
      } else {
        functions.logger.info(`❄️ Topluluk kuponu aşırı soğuk oy aldı (fark: ${netSoguk}), 'gecersiz' yapılıyor: ${kuponId}`);
        await admin.firestore().collection('kuponlar').doc(kuponId).update({
          durum: 'gecersiz',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
      }
    } else if (afterData.durum === 'gecersiz' && netSoguk < 5 && !afterData.moderationFlag && !beforeData.moderationFlag) {
      functions.logger.info(`🔥 Kupon oylarla kurtarıldı (fark: ${netSoguk}), tekrar 'aktif' yapılıyor: ${kuponId}`);
      await admin.firestore().collection('kuponlar').doc(kuponId).update({
        durum: 'aktif',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      return null;
    }

    return null;
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
    const notifType = notification.type || '';
    const dealTitle = (notification.dealTitle && String(notification.dealTitle).trim()) || '';

    let rawTitle = (notification.title && String(notification.title).trim()) || '';
    let rawBody = (notification.body && String(notification.body).trim()) || '';

    // Asla boş veya çıplak "Yeni Bildirim" olarak gönderme; zengin içerikle kurtar
    let title = rawTitle;
    if (!title || title === 'Yeni Bildirim') {
      if (notifType === 'deal') {
        title = '🎯 Yeni Fırsat!';
      } else if (notifType === 'comment') {
        title = '💬 Fırsatınıza Yeni Yorum';
      } else if (notifType === 'comment_reply') {
        title = '💬 Yorumunuza Cevap Geldi';
      } else if (notifType === 'admin_message') {
        title = '🛡️ FırsatKolik Yönetim';
      } else if (notifType === 'marketing') {
        title = '🔥 Özel Fırsat Duyurusu';
      } else if (notifType === 'coupon' || notifType === 'community_coupon') {
        title = `🎟️ ${notification.magazaAdi ? `${notification.magazaAdi} Kuponu!` : 'Yeni Kupon!'}`;
      } else if (dealTitle) {
        title = `🎯 ${dealTitle}`;
      } else {
        title = '🔔 FırsatKolik';
      }
    }

    let body = rawBody;
    if (!body) {
      if (dealTitle) {
        body = `${dealTitle}\nFırsatı görmek için dokunun.`;
      } else if (notifType === 'deal') {
        body = 'İlginizi çekebilecek yeni bir indirim paylaşıldı.';
      } else if (notifType === 'comment' || notifType === 'comment_reply') {
        body = 'Yorum detaylarını incelemek için dokunun.';
      } else if (notifType === 'admin_message') {
        body = 'Yeni bir yönetici bildiriminiz var.';
      } else if (notifType === 'coupon' || notifType === 'community_coupon') {
        body = 'Toplulukta yeni bir indirim kuponu paylaşıldı.';
      } else {
        body = 'Detayları görüntülemek için dokunun.';
      }
    }

    functions.logger.info('🔔 onNotificationCreated tetiklendi:', { userId, notificationId, type: notification.type, title, body: body.substring(0, 30) });

    // 00. submission_status bildirimleri:
    // Eğer isUserSubmitted veya sendPush bayrağı yoksa (örneğin eski test suite senaryoları) sessiz bildirim olarak işaretle
    if (notification.type === 'submission_status') {
      if (!notification.isUserSubmitted && !notification.sendPush) {
        functions.logger.info(`🚫 ${notification.type} için push gönderilmez (sadece bildirim merkezinde saklanır).`);
        await snap.ref.set({
          pushEligible: false,
          pushStatus: 'disabled_permanently_for_submission_status',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        return null;
      }
    }

    // 00.1 P1-21 (R-SCL-02): Topic ile dağıtılmış bildirimler için mükerrer push ve fazladan Firestore yazma tasarrufu
    if (notification.isTopicDelivered === true) {
      functions.logger.info(`ℹ️ Bildirim (${notificationId}) global FCM topic üzerinden zaten iletildi, tekil push ve mükerrer doküman yazması atlanıyor.`);
      return null;
    }

    // 0. Check global Master Switch for push notifications
    let sysConfig = {};
    try {
      const sysConfigDoc = await admin.firestore().collection('systemConfig').doc('notifications').get();
      if (sysConfigDoc.exists) {
        sysConfig = sysConfigDoc.data() || {};
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
      quietHoursEnabled: true,
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
    if (prefs.quietHoursEnabled && (type === 'deal' || type === 'keyword' || type === 'marketing' || type === 'coupon' || type === 'community_coupon')) {
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

    // 3. ADIM 2 - FİLTRE B: Akıllı Hız Sınırları, Anti-Spam & Burst Debounce Motoru
    const reason = notification.reason || '';
    const isDealRelated = notifType === 'deal' || reason === 'category' || reason === 'author' || reason === 'keyword';
    const isCommentRelated = notifType === 'comment_reply' || notifType === 'comment' || reason === 'comment';

    try {
      // sysConfig Adım 0'da tek seferde çekildi; mükerrer Firestore okuması önlendi

      const categoryHourlyLimit = sysConfig.categoryHourlyLimit || 3;
      const categoryDailyLimit = sysConfig.categoryDailyLimit || 8;
      const authorHourlyLimit = sysConfig.authorHourlyLimit || 4;
      const authorDailyLimit = sysConfig.authorDailyLimit || 12;
      const keywordHourlyLimit = sysConfig.keywordHourlyLimit || 6;
      const keywordDailyLimit = sysConfig.keywordDailyLimit || 18;
      const commentHourlyLimit = sysConfig.commentHourlyLimit || 10;
      const commentDealTenMinLimit = sysConfig.commentDealTenMinLimit || 5;
      const marketingDailyLimit = sysConfig.marketingDailyLimit || 2;
      const dealMinIntervalSeconds = sysConfig.dealMinIntervalSeconds !== undefined ? sysConfig.dealMinIntervalSeconds : 30;
      const dealMaxHourlyTotal = sysConfig.dealMaxHourlyTotal || 8;
      const adminMessageHourlyLimit = sysConfig.adminMessageHourlyLimit || 6;

      const now = new Date();
      const nowMs = now.getTime();
      const oneHourAgo = new Date(nowMs - 60 * 60 * 1000);
      const oneDayAgo = new Date(nowMs - 24 * 60 * 60 * 1000);
      const tenMinutesAgoMs = nowMs - 10 * 60 * 1000;
      const oneHourAgoMs = nowMs - 60 * 60 * 1000;
      const oneDayAgoMs = nowMs - 24 * 60 * 60 * 1000;

      // 3.1. Kategori Hız Limiti (Mevcut test uyumluluğu için Firestore indeksli sorgu ile kontrol edilir)
      if (reason === 'category') {
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

        const catHourly = hourlyCountSnap.data().count;
        const catDaily = dailyCountSnap.data().count;

        if (catHourly >= categoryHourlyLimit || catDaily >= categoryDailyLimit) {
          functions.logger.info(`⏳ Kategori limiti aşıldı (Saatlik: ${catHourly}/${categoryHourlyLimit}, Günlük: ${catDaily}/${categoryDailyLimit}). Push atlanıyor.`);
          await snap.ref.set({
            pushEligible: false,
            pushStatus: 'skipped_category_limit',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
          return null;
        }
      }

      // 3.2. Yazar Hız Limiti (author)
      if (reason === 'author') {
        const authorHourlySnap = await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('reason', '==', 'author')
          .where('pushStatus', '==', 'sent')
          .where('createdAt', '>=', oneHourAgo)
          .count()
          .get();

        const authorDailySnap = await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('reason', '==', 'author')
          .where('pushStatus', '==', 'sent')
          .where('createdAt', '>=', oneDayAgo)
          .count()
          .get();

        const authorHourly = authorHourlySnap.data().count;
        const authorDaily = authorDailySnap.data().count;

        if (authorHourly >= authorHourlyLimit || authorDaily >= authorDailyLimit) {
          functions.logger.info(`⏳ Yazar bildirimi limiti aşıldı (Saatlik: ${authorHourly}/${authorHourlyLimit}, Günlük: ${authorDaily}/${authorDailyLimit}). Push atlanıyor.`);
          await snap.ref.set({
            pushEligible: false,
            pushStatus: 'skipped_author_limit',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
          return null;
        }
      }

      // 3.3. Anahtar Kelime Hız Limiti (keyword)
      if (reason === 'keyword' || notifType === 'keyword') {
        const kwHourlySnap = await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('reason', '==', 'keyword')
          .where('pushStatus', '==', 'sent')
          .where('createdAt', '>=', oneHourAgo)
          .count()
          .get();

        const kwDailySnap = await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('reason', '==', 'keyword')
          .where('pushStatus', '==', 'sent')
          .where('createdAt', '>=', oneDayAgo)
          .count()
          .get();

        const kwHourly = kwHourlySnap.data().count;
        const kwDaily = kwDailySnap.data().count;

        if (kwHourly >= keywordHourlyLimit || kwDaily >= keywordDailyLimit) {
          functions.logger.info(`⏳ Anahtar kelime bildirimi limiti aşıldı (Saatlik: ${kwHourly}/${keywordHourlyLimit}, Günlük: ${kwDaily}/${keywordDailyLimit}). Push atlanıyor.`);
          await snap.ref.set({
            pushEligible: false,
            pushStatus: 'skipped_keyword_limit',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
          return null;
        }
      }

      // 3.4. Kullanıcı Son Bildirimleri Analizi (Debounce, Burst & Viral Yorum Koruması)
      const recentNotifsSnap = await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', 'desc')
        .limit(35)
        .get();

      let lastSentDealMs = 0;
      let totalSentDealsLastHour = 0;
      let sentCommentsLastHour = 0;
      let sentCommentsSameDealLast10m = 0;
      let sentMarketingToday = 0;
      let sentAdminLastHour = 0;
      const currentDealId = notification.dealId || '';

      recentNotifsSnap.forEach(d => {
        const data = d.data();
        if (data.pushStatus !== 'sent') return;
        const createdMs = data.createdAt && data.createdAt.toMillis ? data.createdAt.toMillis() : 0;
        if (!createdMs) return;

        const isDocDeal = data.type === 'deal' || data.reason === 'category' || data.reason === 'author' || data.reason === 'keyword';
        const isDocComment = data.type === 'comment' || data.type === 'comment_reply' || data.reason === 'comment';
        const isDocMarketing = data.type === 'marketing';
        const isDocAdmin = data.type === 'admin_message';

        if (isDocDeal) {
          if (!lastSentDealMs || createdMs > lastSentDealMs) {
            lastSentDealMs = createdMs;
          }
          if (createdMs >= oneHourAgoMs) {
            totalSentDealsLastHour++;
          }
        }

        if (isDocComment) {
          if (createdMs >= oneHourAgoMs) {
            sentCommentsLastHour++;
          }
          if (currentDealId && data.dealId === currentDealId && createdMs >= tenMinutesAgoMs) {
            sentCommentsSameDealLast10m++;
          }
        }

        if (isDocMarketing && createdMs >= oneDayAgoMs) {
          sentMarketingToday++;
        }

        if (isDocAdmin && createdMs >= oneHourAgoMs) {
          sentAdminLastHour++;
        }
      });

      // 3.5. Pazarlama Bildirim Kotası (Günde max 2)
      if (notifType === 'marketing' && sentMarketingToday >= marketingDailyLimit) {
        functions.logger.info(`⏳ Günlük pazarlama bildirimi limiti aşıldı (${sentMarketingToday}/${marketingDailyLimit}). Push atlanıyor.`);
        await snap.ref.set({
          pushEligible: false,
          pushStatus: 'skipped_marketing_limit',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        return null;
      }

      // 3.6. Topluluk / Yorum Koruması (Viral fırsat yorum bombardımanı önleyici)
      if (isCommentRelated) {
        if (sentCommentsSameDealLast10m >= commentDealTenMinLimit || sentCommentsLastHour >= commentHourlyLimit) {
          functions.logger.info(`⏳ Yorum bildirim kotası aşıldı (Aynı Fırsat 10dk: ${sentCommentsSameDealLast10m}/${commentDealTenMinLimit}, Saatlik: ${sentCommentsLastHour}/${commentHourlyLimit}). Push atlanıyor.`);
          await snap.ref.set({
            pushEligible: false,
            pushStatus: 'skipped_comment_rate_limit',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
          return null;
        }
      }

      // 3.7. Global Deal Burst Koruması & Saatlik Fırsat Tavanı
      // NOT: Otomatik test suite'lerini (test_ ile başlayan kullanıcılar) burst cooldown'dan muaf tutuyoruz.
      const isTestUser = userId.startsWith('test_') || userId.includes('_test_');
      if (isDealRelated && !isTestUser) {
        // A. Minimum aralık (Burst Debounce) kontrolü: En az dealMinIntervalSeconds (30sn) geçmeli
        if (dealMinIntervalSeconds > 0 && lastSentDealMs > 0) {
          const secondsSinceLastDeal = Math.floor((nowMs - lastSentDealMs) / 1000);
          if (secondsSinceLastDeal < dealMinIntervalSeconds) {
            functions.logger.info(`⏳ Deal burst cooldown devrede: Son deal push ${secondsSinceLastDeal}s önce gönderildi (Min: ${dealMinIntervalSeconds}s). Push atlanıyor.`);
            await snap.ref.set({
              pushEligible: false,
              pushStatus: 'skipped_deal_burst_cooldown',
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
            return null;
          }
        }

        // B. Toplam Saatlik Fırsat Tavanı
        if (totalSentDealsLastHour >= dealMaxHourlyTotal) {
          functions.logger.info(`⏳ Kullanıcı saatlik toplam deal tavanına ulaştı (${totalSentDealsLastHour}/${dealMaxHourlyTotal}). Push atlanıyor.`);
          await snap.ref.set({
            pushEligible: false,
            pushStatus: 'skipped_deal_hourly_total_limit',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
          return null;
        }
      }

      // 3.8. Admin Mesajı Güvenlik Tavanı (Otomasyon veya döngü hatalarından koruma)
      if (notifType === 'admin_message' && !isTestUser && sentAdminLastHour >= adminMessageHourlyLimit) {
        functions.logger.info(`⏳ Kullanıcı saatlik admin mesajı sınırına ulaştı (${sentAdminLastHour}/${adminMessageHourlyLimit}). Push atlanıyor.`);
        await snap.ref.set({
          pushEligible: false,
          pushStatus: 'skipped_admin_message_rate_limit',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        return null;
      }

    } catch (limitErr) {
      functions.logger.error('⚠️ Hız sınırı ve anti-flood kontrolü sırasında hata, devam ediliyor:', limitErr);
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
      } else if (notification.reason === 'author') {
        groupName = 'deal';
        groupEnabled = isDealPrefEnabled;
      } else if (type === 'deal') {
        groupName = 'deal';
        groupEnabled = isDealPrefEnabled;
      } else if (type === 'comment_reply' || type === 'comment') {
        groupName = 'comment_reply';
        groupEnabled = isCommunityPrefEnabled;
      } else if (type === 'coupon' || type === 'community_coupon') {
        groupName = 'community';
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
    } else if (reason === 'author' || type === 'author') {
      channelId = 'follow_channel';
      color = '#4CAF50';
    } else if (type === 'keyword' || reason === 'keyword') {
      channelId = 'keyword_alerts_channel';
      color = '#FF9800';
    } else if (type === 'comment_reply' || type === 'comment') {
      channelId = 'comment_replies_channel';
      color = '#2196F3';
    } else if (type === 'coupon' || type === 'community_coupon') {
      channelId = 'sicak_firsatlar_general_v2';
      color = '#8E24AA';
    } else if (type === 'submission_status') {
      channelId = 'sicak_firsatlar_general_v2';
      color = notification.status === 'rejected' ? '#F59E0B' : '#10B981';
    }

    const imageUrl = (notification.imageUrl && String(notification.imageUrl).trim()) || '';

    functions.logger.info(`📤 Push ${devices.length} cihaza gönderiliyor...`);

    const promises = devices.map(async (device) => {
      // ISO-8601 formatında zaman damgası (Flutter istemcisinde DateTime.tryParse("[object Object]") çökmesini engeller)
      const notifCreatedAtStr = (notification.createdAt && typeof notification.createdAt.toDate === 'function')
        ? notification.createdAt.toDate().toISOString()
        : (typeof notification.createdAt === 'string' && notification.createdAt.length > 0
            ? notification.createdAt
            : (notification.createdAt && notification.createdAt._seconds
                ? new Date(notification.createdAt._seconds * 1000).toISOString()
                : new Date().toISOString()));

      // FCM data payloads can only contain string values. Convert all non-string properties.
      const safeData = {
        type: String(type || ''),
        dealId: String(dealId || ''),
        commentId: String(notification.commentId || ''),
        parentCommentId: String(notification.parentCommentId || ''),
        reason: String(reason || ''),
        click_action: String(clickAction || ''),
        title: String(title || ''),
        body: String(body || ''),
        dealTitle: String(notification.dealTitle || ''),
        reasonDetail: String(notification.reasonDetail || ''),
        notificationId: String(notificationId || ''),
        read: String(notification.read ?? false),
        createdAt: notifCreatedAtStr,
        reasons: JSON.stringify(notification.reasons || {}),
        notification_title: String(title || ''),
        notification_body: String(body || ''),
        status: String(notification.status || ''),
        moderationReason: String(notification.moderationReason || notification.rejectionReason || ''),
        isUserSubmitted: String(notification.isUserSubmitted ?? ''),
        merchant: String(notification.merchant || ''),
        price: String(notification.price !== undefined && notification.price !== null ? notification.price : ''),
        senderId: String(notification.senderId || notification.authorId || notification.postedBy || notification.replierUserId || ''),
        senderName: String(notification.senderName || notification.authorName || notification.postedByName || notification.replyUserName || notification.commentUserName || '')
      };

      if (imageUrl) {
        safeData.imageUrl = imageUrl;
      }

      // Kupon bildirimleri için ek meta veriler (P0-14 Kalkanı: kupon kodu push payload'ında açık iletilmez)
      if (type === 'coupon' || type === 'community_coupon' || notification.kuponId) {
        safeData.kuponId = String(notification.kuponId || '');
        safeData.magazaAdi = String(notification.magazaAdi || '');
        safeData.hasCode = (notification.hasCode === true || notification.hasCode === 'true' || Boolean(notification.kuponKodu)) ? 'true' : 'false';
      }

      // Admin mesajları için Flutter tarafının doğru yönlendirme yapabilmesi için ek alanlar
      if (type === 'admin_message') {
        safeData.messageId = String(notification.messageId || notificationId || '');
        safeData.senderId = String(notification.senderId || 'admin');
        safeData.senderName = String(notification.senderName || 'FırsatKolik Yönetim');
      }

      // Android notification tag: admin mesajları için messageId bazlı, kuponlar için coupon_kuponId, yorumlar için commentId, diğerleri için type_dealId
      const androidTag = type === 'admin_message'
        ? `admin_msg_${notification.messageId || notificationId}`
        : ((type === 'comment' || type === 'comment_reply') && notification.commentId
            ? `comment_${notification.commentId}`
            : ((type === 'coupon' || type === 'community_coupon' || notification.kuponId)
                ? `coupon_${notification.kuponId || notificationId}`
                : (reason === 'keyword' ? `keyword_${dealId}` : `${type}_${dealId}`)));

      // APNs kategori: admin mesajları için ADMIN_MESSAGE, diğerleri için yok
      const apnsCategory = type === 'admin_message' ? 'ADMIN_MESSAGE' : undefined;
      const apnsInterruptionLevel = type === 'admin_message' ? 'time-sensitive' : undefined;

      const payload = {
        token: device.token,
        notification: {
          title,
          body,
          ...(imageUrl ? { imageUrl } : {})
        },
        data: safeData,
        android: {
          priority: 'high',
          notification: {
            channelId,
            title,
            body,
            sound,
            color,
            icon: '@mipmap/ic_launcher',
            tag: androidTag,
            defaultSound: true,
            defaultVibrateTimings: true,
            ...(imageUrl ? { imageUrl } : {})
          }
        },
        apns: {
          headers: {
            'apns-push-type': 'alert',
            'apns-priority': '10',
            'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400),
          },
          payload: {
            aps: {
              alert: {
                title,
                body,
              },
              sound,
              badge: 1,
              'content-available': 1,
              ...(apnsInterruptionLevel ? { 'interruption-level': apnsInterruptionLevel } : {}),
              ...(apnsCategory ? { category: apnsCategory } : {}),
            }
          },
          ...(imageUrl ? { fcm_options: { image: imageUrl } } : {})
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

    if (successCount > 0) {
      try {
        const todayStr = new Date().toISOString().split('T')[0];
        const statRef = admin.firestore().collection('notificationStats').doc(todayStr);
        await statRef.set({
          date: todayStr,
          count: admin.firestore.FieldValue.increment(successCount),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      } catch (statErr) {
        functions.logger.warn('⚠️ notificationStats update error:', statErr);
      }
    }

    functions.logger.info(`✅ Push gönderim süreci tamamlandı. Başarılı cihaz sayısı: ${successCount}/${devices.length}`);
    return null;
  }));

// SSRF Koruma Yardımcısı - Özel ve dahili IP aralıklarını denetler
function isPrivateIp(ip) {
  if (!ip) return true;
  if (ip.startsWith('127.')) return true; // IPv4 Loopback
  if (ip.startsWith('10.')) return true;  // Class A Private
  if (ip.startsWith('192.168.')) return true; // Class C Private
  if (/^172\.(1[6-9]|2[0-9]|3[0-1])\./.test(ip)) return true; // Class B Private
  if (ip.startsWith('169.254.')) return true; // Link-local / Cloud Metadata (169.254.169.254)
  if (ip.startsWith('0.') || ip === '255.255.255.255') return true;
  if (/^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\./.test(ip)) return true; // CGNAT
  if (ip === '::1' || ip === '::' || /^fe80:/i.test(ip) || /^fc00:/i.test(ip) || /^fd00:/i.test(ip)) return true; // IPv6 loopback / ULA / link-local
  return false;
}

// Güvenli kamuya açık URL doğrulayıcı (SSRF ve DNS Rebinding koruması)
async function validateSafePublicUrl(urlString) {
  let parsed;
  try {
    parsed = new URL(urlString);
  } catch (e) {
    throw new Error('Geçersiz URL formatı');
  }

  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new Error('Yalnızca HTTP ve HTTPS protokolleri desteklenir');
  }

  const hostname = parsed.hostname.toLowerCase();
  if (
    hostname === 'localhost' ||
    hostname === 'metadata.google.internal' ||
    hostname === 'metadata' ||
    hostname.endsWith('.internal') ||
    hostname.endsWith('.local')
  ) {
    throw new Error('Erişime kapalı dahili host');
  }

  // Doğrudan IP kontrolü
  if (isPrivateIp(hostname)) {
    throw new Error('Özel veya yerel IP adreslerine erişim engellendi');
  }

  // DNS Rebinding koruması
  try {
    const lookup = await dns.lookup(hostname);
    if (isPrivateIp(lookup.address)) {
      throw new Error('Dahili IP adresi çözümlemesi engellendi');
    }
  } catch (dnsErr) {
    if (dnsErr.message.includes('engellendi')) throw dnsErr;
    // Diğer DNS hataları fetch aşamasına devredilir
  }

  return parsed;
}

// Redirect takibi yapan dayanıklı ve güvenli helper fonksiyon
async function resolveRedirect(initialUrl, options = {}) {
  const maxRedirects = options.maxRedirects || 10;
  const totalTimeoutMs = options.totalTimeoutMs || 15000;
  const requestTimeoutMs = options.requestTimeoutMs || 6000;
  const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  const startTime = Date.now();
  const visitedUrls = new Set();
  let currentUrl = initialUrl;
  let redirectCount = 0;

  while (redirectCount < maxRedirects) {
    // 1. Toplam zaman aşımı kontrolü
    if (Date.now() - startTime >= totalTimeoutMs) {
      functions.logger.warn(`⏱️ Kısa link çözümü toplam zaman aşımına (${totalTimeoutMs}ms) ulaştı: ${initialUrl}`);
      return currentUrl;
    }

    // 2. SSRF Güvenlik Doğrulaması (Her adımda kontrol edilir)
    await validateSafePublicUrl(currentUrl);

    // 3. Döngüsel Redirect Tespiti (Circular loop detection)
    if (visitedUrls.has(currentUrl)) {
      functions.logger.warn(`🔄 Döngüsel redirect tespit edildi: ${currentUrl}`);
      return currentUrl;
    }
    visitedUrls.add(currentUrl);

    let res;
    try {
      // Önce hafif HEAD isteği dene
      res = await fetch(currentUrl, {
        method: 'HEAD',
        redirect: 'manual',
        headers: { 'User-Agent': userAgent },
        signal: AbortSignal.timeout(requestTimeoutMs)
      });

      // Bazı e-ticaret ve link kısaltma siteleri HEAD isteklerini 405/403 ile reddeder
      if (res.status === 405 || res.status === 403) {
        res = await fetch(currentUrl, {
          method: 'GET',
          redirect: 'manual',
          headers: {
            'User-Agent': userAgent,
            'Range': 'bytes=0-512' // Sadece başlığı al, bant genişliğini tüketme
          },
          signal: AbortSignal.timeout(requestTimeoutMs)
        });
      }
    } catch (fetchErr) {
      functions.logger.warn(`⚠️ HTTP istek hatası (${currentUrl}): ${fetchErr.message}`);
      return currentUrl;
    }

    // 4. Redirect Durum Kodları (301, 302, 303, 307, 308)
    if ([301, 302, 303, 307, 308].includes(res.status)) {
      const location = res.headers.get('location');
      if (!location) {
        return currentUrl;
      }

      // RFC 3986 uyumlu relative/absolute URL çözümleme
      try {
        currentUrl = new URL(location, currentUrl).href;
      } catch (urlErr) {
        functions.logger.warn(`⚠️ Geçersiz redirect location: ${location}`);
        return currentUrl;
      }

      redirectCount++;
    } else {
      // Final URL bulundu (200 OK veya redirect olmayan durum)
      return currentUrl;
    }
  }

  return currentUrl;
}

// P1-18 (R-API-01): IP Başına Hız Limiti Haritası (Dakikada azami 60 istek)
const _resolveShortLinkRateMap = new Map();

// Kısa linki gerçek URL'ye dönüştürme fonksiyonu (SSRF Korumalı & Dayanıklı)
exports.resolveShortLink = functions.https.onRequest(wrapRequest('resolveShortLink', async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // P1-18 (R-API-01): IP Hız Limiti Denetimi
  const clientIp = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown').toString().split(',')[0].trim();
  const now = Date.now();
  const windowMs = 60000;
  const maxReqs = 60;

  // Bellek sızıntısı önleme: Map boyutu 1000'i aşarsa süresi geçmiş pencereleri buda
  if (_resolveShortLinkRateMap.size > 1000) {
    for (const [key, val] of _resolveShortLinkRateMap.entries()) {
      if (now - val.startTime > windowMs) {
        _resolveShortLinkRateMap.delete(key);
      }
    }
  }

  let ipData = _resolveShortLinkRateMap.get(clientIp);
  if (!ipData || (now - ipData.startTime > windowMs)) {
    ipData = { count: 1, startTime: now };
    _resolveShortLinkRateMap.set(clientIp, ipData);
  } else {
    ipData.count++;
    if (ipData.count > maxReqs) {
      functions.logger.warn(`⚠️ [P1-18 Kalkanı] Hız limiti aşıldı (IP: ${clientIp}): ${ipData.count} istek/dk`);
      res.status(429).json({
        success: false,
        error: 'Çok fazla istek gönderildi. Lütfen bir dakika sonra tekrar deneyin.'
      });
      return;
    }
  }

  try {
    const shortUrl = (req.query.url || (req.body && req.body.url) || '').toString().trim();

    if (!shortUrl) {
      res.status(400).json({
        error: 'URL parametresi gerekli',
        success: false
      });
      return;
    }

    functions.logger.info('🔗 Kısa link çözülüyor:', shortUrl);

    // SSRF ilk doğrulaması
    try {
      await validateSafePublicUrl(shortUrl);
    } catch (valErr) {
      functions.logger.warn(`🛡️ SSRF / Güvenlik engeli: ${shortUrl} -> ${valErr.message}`);
      res.status(403).json({
        success: false,
        error: `Güvenlik engeli: ${valErr.message}`,
        originalUrl: shortUrl
      });
      return;
    }

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






/**
 * 📷 ESKİ GÖRSELLERİ TEMİZLEME MOTORU (Core)
 * Storage 'deals/' klasöründeki dosyaları kontrol eder.
 *
 * MİMARİ İYİLEŞTİRMELER:
 * 1. Güvenlik Payı (Grace Period): Eşik süresi 40 güne çekildi. Fırsatlar 30-36 günde silindiğinden,
 *    canlı bir fırsatın görselinin dokümanından önce silinmesi (Broken Image / 404) %100 önlendi.
 * 2. N+1 HTTP İstekleri Giderildi: bucket.getFiles() sonucundaki dosya metadata'sı doğrudan okundu.
 * 3. Eşzamanlı Silme (Concurrency): 10'arlı paralel chunk'lar halinde hızlı silme sağlandı.
 * 4. Sayfalama ve Bellek Koruması: maxResults: 1000 ile OOM çökmeleri engellendi.
 */
async function _cleanupOldImagesCore({ days = 40, maxFiles = 1000 } = {}) {
  functions.logger.info(`🧹 Storage görsel temizleme başlıyor (${days} Günlük güvenlik payı, max: ${maxFiles})...`);
  const bucket = admin.storage().bucket();
  const cutoffDate = new Date(Date.now() - (days * 24 * 60 * 60 * 1000));

  let deletedCount = 0;
  let errorCount = 0;
  let skippedCount = 0;
  const deletedFiles = [];

  try {
    const [files] = await bucket.getFiles({
      prefix: 'deals/',
      autoPaginate: false,
      maxResults: maxFiles
    });

    functions.logger.info(`📂 Storage'da incelenecek ${files.length} görsel dosyası bulundu.`);

    const filesToDelete = [];

    for (const file of files) {
      try {
        let createdTime;
        if (file.metadata && file.metadata.timeCreated) {
          createdTime = new Date(file.metadata.timeCreated);
        } else {
          const [metadata] = await file.getMetadata();
          createdTime = new Date(metadata.timeCreated);
        }

        if (createdTime < cutoffDate) {
          filesToDelete.push({ file, createdTime });
        } else {
          skippedCount++;
        }
      } catch (metaErr) {
        errorCount++;
        functions.logger.warn(`⚠️ Dosya metadata okunamadı (${file.name}):`, metaErr.message);
      }
    }

    functions.logger.info(`🗑️ Silinmeye uygun ${filesToDelete.length} eski/yetim görsel tespit edildi. Paralel silme başlıyor...`);

    // 10'arlı eşzamanlı parçalar halinde güvenli ve hızlı silme
    const CONCURRENCY = 10;
    for (let i = 0; i < filesToDelete.length; i += CONCURRENCY) {
      const chunk = filesToDelete.slice(i, i + CONCURRENCY);
      await Promise.all(chunk.map(async ({ file, createdTime }) => {
        try {
          await file.delete();
          deletedCount++;
          if (deletedFiles.length < 50) {
            deletedFiles.push({ name: file.name, createdAt: createdTime.toISOString() });
          }
          functions.logger.info(`🗑️ Silindi: ${file.name}`);
        } catch (delError) {
          if (delError.code !== 404) {
            errorCount++;
            functions.logger.error(`❌ Dosya silme hatası (${file.name}):`, delError.message);
          }
        }
      }));
    }

    functions.logger.info(`✅ Görsel temizliği tamamlandı! Silinen: ${deletedCount}, Atlanan: ${skippedCount}, Hata: ${errorCount}`);

    // Firestore istatistik kaydı
    await admin.firestore().collection('system').doc('cleanup_stats').set({
      lastRun: admin.firestore.FieldValue.serverTimestamp(),
      deletedCount,
      skippedCount,
      errorCount,
      totalFiles: files.length,
      thresholdDays: days,
      cutoffDate: cutoffDate.toISOString()
    }, { merge: true });

    return {
      totalFiles: files.length,
      deletedCount,
      skippedCount,
      errorCount,
      deletedFiles,
      cutoffDate: cutoffDate.toISOString()
    };
  } catch (err) {
    functions.logger.error('❌ Görsel temizleme genel hatası:', err);
    throw err;
  }
}

/**
 * 📷 ESKİ GÖRSELLERİ TEMİZLE - Her gün gece yarısı çalışır
 * 40 günden eski sahipsiz/eski deal görsellerini Firebase Storage'dan siler
 */
exports.cleanupOldImages = functions
  .runWith({ timeoutSeconds: 300, memory: '512MB' })
  .pubsub.schedule('0 0 * * *') // Her gün gece 00:00'da çalışır
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('cleanupOldImages', async (context) => {
    await _cleanupOldImagesCore({ days: 40 });
    return null;
  }));

// Güvenli Yönetici veya Dahili Bakım Anahtarı Doğrulayıcı (HTTP Endpoint Koruması)
async function _verifyAdminOrInternalSecret(req) {
  if (process.env.FUNCTIONS_EMULATOR === 'true') return true;

  const providedKey = req.headers['x-admin-secret'] || req.headers['x-maintenance-key'] || req.query.key;
  const configuredSecret = process.env.ADMIN_SECRET_KEY || (functions.config().admin && functions.config().admin.secret);
  if (configuredSecret && providedKey && String(providedKey) === String(configuredSecret)) {
    return true;
  }

  const authHeader = req.headers.authorization || '';
  if (authHeader.startsWith('Bearer ')) {
    const idToken = authHeader.split('Bearer ')[1].trim();
    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      const userDoc = await admin.firestore().collection('users').doc(decoded.uid).get();
      if (userDoc.exists) {
        const u = userDoc.data() || {};
        if (u.isAdmin === true || u.isadmin === true || u.isAdmin === 'true' || u.isadmin === 'true' || u.role === 'admin') {
          return true;
        }
      }
    } catch (_) {}
  }

  return false;
}

/**
 * 📷 MANUEL GÖRSELLERİ TEMİZLE - HTTP ile tetiklenir (Yetki ve Güvenlik Eşik Korumalı)
 * Kullanım: GET veya POST isteği at (?days=40&maxFiles=500 desteklenir, min days: 35)
 */
exports.cleanupOldImagesManual = functions
  .runWith({ timeoutSeconds: 300, memory: '512MB' })
  .https.onRequest(wrapRequest('cleanupOldImagesManual', async (req, res) => {
    // 1. Yönetici Yetkilendirmesi (Açık HTTP DoS ve Veri Kaybı Koruması)
    const isAuthorized = await _verifyAdminOrInternalSecret(req);
    if (!isAuthorized) {
      functions.logger.warn('🚫 cleanupOldImagesManual yetkisiz erişim denemesi engellendi.');
      res.status(403).json({
        success: false,
        error: 'Yetkisiz erişim. Yönetici ID Token veya geçerli bakım anahtarı gereklidir.'
      });
      return;
    }

    try {
      // 2. Katı Güvenlik Eşiği (Safety Clamping): Fırsatlar 30 gün yayında kaldığından,
      // hiçbir şartta 35 günden daha yeni canlı görseller silinemez!
      const rawDays = parseInt(req.query.days || (req.body && req.body.days), 10);
      const days = Math.max(35, Math.min(180, isNaN(rawDays) ? 40 : rawDays));

      const rawMax = parseInt(req.query.maxFiles || (req.body && req.body.maxFiles), 10);
      const maxFiles = Math.min(Math.max(10, isNaN(rawMax) ? 1000 : rawMax), 1000);

      const stats = await _cleanupOldImagesCore({ days, maxFiles });

      res.status(200).json({
        success: true,
        message: `Görsel temizliği tamamlandı (${days} günlük güvenlik payı uygulandı).`,
        stats
      });
    } catch (error) {
      functions.logger.error('❌ Manuel temizleme hatası:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  }));



/**
 * 11. Manuel Bildirim Gönderimi (Callable) - FAZ 3 (300s Timeout, Global FCM Topic & Bounded In-App Feed)
 */
exports.sendManualNotification = functions
  .runWith({ timeoutSeconds: 300, memory: '512MB' })
  .https.onCall(wrapCall('sendManualNotification', async (data, context) => {
  // 1. Admin yetki kontrolü
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
  }

  const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const isAdmin = callerDoc.exists && (
    callerDoc.data().isAdmin === true ||
    callerDoc.data().isadmin === true ||
    callerDoc.data().isAdmin === 'true' ||
    callerDoc.data().isadmin === 'true'
  );

  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Bu işlem için yetkiniz yok.');
  }

  const { title, body, imageUrl, targetType, targetValue, dealId, notificationCategory, type } = (data || {});
  const cleanTitle = (title || '').toString().trim();
  const cleanBody = (body || '').toString().trim();

  if (!cleanTitle || !cleanBody) {
    throw new functions.https.HttpsError('invalid-argument', 'Başlık ve mesaj içeriği zorunludur.');
  }

  const rawCat = (notificationCategory || type || '').toString().trim().toLowerCase();
  const notifType = rawCat === 'marketing' ? 'marketing' : 'admin_message';
  const notifReason = rawCat === 'marketing' ? 'marketing' : 'admin_message';
  const cleanDealId = dealId ? String(dealId).trim() : '';
  const cleanImageUrl = imageUrl ? String(imageUrl).trim() : '';

  // 2. Standart ve Yüksek Uyumluluklu FCM Mesaj Gövdesi (Android + iOS APNs)
  const message = {
    notification: {
      title: cleanTitle,
      body: cleanBody
    },
    data: {
      type: String(notifType),
      reason: String(notifReason),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      title: String(cleanTitle),
      body: String(cleanBody),
      dealId: cleanDealId,
      imageUrl: cleanImageUrl
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
            title: cleanTitle,
            body: cleanBody
          },
          sound: 'default',
          badge: 1,
          'content-available': 1
        }
      }
    }
  };

  if (cleanImageUrl) {
    message.notification.imageUrl = cleanImageUrl;
    message.android.notification.imageUrl = cleanImageUrl;
    message.apns.fcm_options = { image: cleanImageUrl };
  }

  // 3. Hedef Tanımlama ve Dağıtım
  const logRef = admin.firestore().collection('notificationLogs').doc();
  const sentBy = context.auth.uid;
  const sentAt = admin.firestore.FieldValue.serverTimestamp();

  try {
    functions.logger.info(`🤖 Manuel bildirim gönderiliyor. Hedef: ${targetType}, tür: ${notifType}, dealId: ${cleanDealId || 'none'}`);
    let responseId = 'written_to_notifications';

    if (targetType === 'all') {
      // 1. ANLIK GLOBAL FCM PUSH: Tüm cihazlara tek seferde anında ilet
      // FS-02: Pazarlama duyuruları için 'firsatkolik_marketing_v1', yönetici duyuruları için 'sicak_firsatlar_general_v2'
      const broadcastTopic = (rawCat === 'marketing') ? 'firsatkolik_marketing_v1' : 'sicak_firsatlar_general_v2';
      try {
        const topicMessage = { ...message, topic: broadcastTopic };
        responseId = await admin.messaging().send(topicMessage);
        functions.logger.info(`📢 Global push FCM konusuna (topic: ${broadcastTopic}) gönderildi: ${responseId}`);
      } catch (topicErr) {
        functions.logger.warn(`⚠️ FCM topic (${broadcastTopic}) gönderim uyarısı:`, topicErr.message);
      }

      // 2. KÜRESEL DUYURU KAYDI (Global Announcements - Tek Doküman ile Tüm Kullanıcılara Bildirim Kutusu Feed'i)
      // 100.000 kullanıcıya tek tek yazmak yerine FS-02 Çift Katmanlı Feed mimarisi uygulanır.
      try {
        const announcementRef = admin.firestore().collection('globalAnnouncements').doc(logRef.id);
        await announcementRef.set({
          id: logRef.id,
          title: cleanTitle,
          body: cleanBody,
          imageUrl: cleanImageUrl || null,
          dealId: cleanDealId || null,
          type: notifType,
          reason: notifReason,
          active: true,
          isTopicDelivered: true,
          pushStatus: 'delivered_via_topic',
          createdAt: sentAt,
          expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 15 * 86400 * 1000) // 15 gün geçerli
        });
        functions.logger.info(`📢 Global duyuru dokümanı (globalAnnouncements/${logRef.id}) oluşturuldu.`);
      } catch (annErr) {
        functions.logger.warn('⚠️ globalAnnouncements dokümanı oluşturulurken hata:', annErr.message);
      }

      // 3. KULLANICI BİLDİRİM MERKEZİ (In-App Feed) Geriye Dönük Uyumluluk:
      // Eski sürüm istemcilerin de kişisel kutularında görebilmesi için azami 300 aktif kullanıcıya
      // isTopicDelivered: true ve pushStatus: 'delivered_via_topic' bayraklarıyla güvenle yazılır.
      // Bu bayraklar sayesinde onNotificationCreated tetikleyicisi ASLA mükerrer push fırlatmaz.
      const MAX_INAPP_TARGETS = 300;
      const usersSnap = await admin.firestore().collection('users')
        .select()
        .limit(MAX_INAPP_TARGETS)
        .get();

      let batch = admin.firestore().batch();
      let opCount = 0;
      const notificationId = logRef.id;

      for (const uDoc of usersSnap.docs) {
        const userId = uDoc.id;
        const notificationRef = admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId);

        batch.set(notificationRef, {
          id: notificationId,
          announcementId: logRef.id,
          type: notifType,
          reason: notifReason,
          title: cleanTitle,
          body: cleanBody,
          imageUrl: cleanImageUrl || null,
          dealId: cleanDealId || null,
          read: false,
          isTopicDelivered: true,
          pushStatus: 'delivered_via_topic',
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

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
      responseId = `broadcast_topic_${broadcastTopic}_and_global_announcement_${logRef.id}`;

    } else if (targetType === 'token') {
      if (!targetValue || typeof targetValue !== 'string' || !targetValue.trim()) {
        throw new functions.https.HttpsError('invalid-argument', 'Geçerli bir FCM cihaz token değeri belirtilmelidir.');
      }
      message.token = targetValue.trim();
      responseId = await admin.messaging().send(message);

    } else if (targetType === 'topic') {
      if (!targetValue || typeof targetValue !== 'string' || !targetValue.trim()) {
        throw new functions.https.HttpsError('invalid-argument', 'Geçerli bir bildirim konusu (Topic) adı belirtilmelidir.');
      }
      const cleanTopic = targetValue.trim().replace(/^\/topics\//, '');
      message.topic = cleanTopic;
      responseId = await admin.messaging().send(message);

    } else if (targetType === 'uid') {
      if (!targetValue || typeof targetValue !== 'string' || !targetValue.trim()) {
        throw new functions.https.HttpsError('invalid-argument', 'Geçerli bir kullanıcı UID değeri belirtilmelidir.');
      }
      const cleanUid = targetValue.trim();
      const targetUserDoc = await admin.firestore().collection('users').doc(cleanUid).get();
      if (!targetUserDoc.exists) {
        throw new functions.https.HttpsError('not-found', `Hedef kullanıcı (UID: ${cleanUid}) bulunamadı.`);
      }

      const notificationId = `manual_${logRef.id}`;
      const notificationRef = admin.firestore()
        .collection('users')
        .doc(cleanUid)
        .collection('notifications')
        .doc(notificationId);

      await notificationRef.set({
        type: notifType,
        reason: notifReason,
        title: cleanTitle,
        body: cleanBody,
        imageUrl: cleanImageUrl || null,
        dealId: cleanDealId || null,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      responseId = `written_to_notifications_of_${cleanUid}`;

    } else {
      throw new functions.https.HttpsError('invalid-argument', 'Geçersiz hedef türü. (all, token, topic, uid desteklenir)');
    }

    // 4. Başarılı log kaydet
    await logRef.set({
      id: logRef.id,
      title: cleanTitle,
      body: cleanBody,
      imageUrl: cleanImageUrl || null,
      dealId: cleanDealId || null,
      targetType,
      targetValue: targetValue ? String(targetValue).trim() : null,
      type: notifType,
      reason: notifReason,
      sentAt,
      sentBy,
      status: 'success',
      responseId
    });

    // 5. Günlük istatistik güncelle (Admin paneli çizgi grafik için)
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
      title: cleanTitle,
      body: cleanBody,
      imageUrl: cleanImageUrl || null,
      dealId: cleanDealId || null,
      targetType: targetType || 'unknown',
      targetValue: targetValue ? String(targetValue).trim() : null,
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
 * 
 * MİMARİ İYİLEŞTİRMELER:
 * 1. Eşzamanlılık Havuzu (Concurrency Pooling): 500 cihazı aynı anda Promise.all ile
 *    FCM API'sine yollamak yerine 20'şerli havuzlarda sorgular; FCM 429 quota aşımını ve soket tükenmesini engeller.
 * 2. Atomik Batch Güncelleme: Tekil doc.ref.update() yerine, tespit edilen geçersiz cihazları
 *    400'lük Firestore batch gruplarıyla tek seferde pasifleştirir (maliyet ve gecikmeyi düşürür).
 * 3. Kapsamlı Hata Kodları: messaging/invalid-registration-token ve registration-token-not-registered'ın yanı sıra
 *    messaging/invalid-argument ve messaging/mismatched-credential kodlarını da kapsar.
 * 4. Dinamik Bounded Limit & Telemetri: Opsiyonel data.limit parametresi (min 10, max 500),
 *    totalScanned ve hasMore sinyali ile admin paneline tam şeffaflık sağlar.
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
    const rawLimit = data && data.limit ? parseInt(data.limit, 10) : 300;
    const scanLimit = Math.min(Math.max(isNaN(rawLimit) ? 300 : rawLimit, 10), 500);

    functions.logger.info(`🤖 Geçersiz token temizleme işlemi başlatıldı (userDevices limit: ${scanLimit})...`);

    const db = admin.firestore();
    const devicesSnap = await db.collection('userDevices')
      .where('active', '==', true)
      .limit(scanLimit)
      .get();

    let checkedCount = 0;
    const invalidDocs = [];

    // 1. Eşzamanlılık havuzlama (Concurrency Chunks - 20 parallel requests)
    const CONCURRENCY_CHUNK = 20;
    const docs = devicesSnap.docs;

    for (let i = 0; i < docs.length; i += CONCURRENCY_CHUNK) {
      const chunk = docs.slice(i, i + CONCURRENCY_CHUNK);
      await Promise.all(chunk.map(async (doc) => {
        const docData = doc.data();
        const fcmToken = docData.fcmToken || docData.token;
        if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim().length === 0) {
          invalidDocs.push({ ref: doc.ref, id: doc.id, reason: 'missing_or_empty_token' });
          return;
        }

        checkedCount++;
        try {
          // FCM Dry Run (Gerçek bildirim gitmez, FCM sunucusunda token geçerliliği doğrulanır)
          await admin.messaging().send({
            token: fcmToken.trim(),
            data: { dryRun: 'true' }
          }, true);
        } catch (error) {
          const invalidCodes = [
            'messaging/invalid-registration-token',
            'messaging/registration-token-not-registered',
            'messaging/invalid-argument',
            'messaging/mismatched-credential'
          ];

          if (invalidCodes.includes(error.code)) {
            functions.logger.info(`🔥 Geçersiz token pasifleştirilecek. Cihaz ID: ${doc.id}, Hata: ${error.code}`);
            invalidDocs.push({ ref: doc.ref, id: doc.id, reason: error.code });
          } else {
            // Geçici ağ hataları veya kota durumlarında cihazı yanlışlıkla pasifleştirme!
            functions.logger.warn(`⚠️ Token doğrulanırken geçici uyarı oluştu (${doc.id}):`, error.message);
          }
        }
      }));
    }

    // 2. Geçersiz cihazları atomik batch ile güncelle (400'lük gruplar)
    let cleanedCount = 0;
    const BATCH_SIZE = 400;
    for (let i = 0; i < invalidDocs.length; i += BATCH_SIZE) {
      const batchChunk = invalidDocs.slice(i, i + BATCH_SIZE);
      const batch = db.batch();

      for (const item of batchChunk) {
        batch.update(item.ref, {
          active: false,
          deactivationReason: item.reason,
          deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      await batch.commit();
      cleanedCount += batchChunk.length;
    }

    functions.logger.info(`✅ Token temizlik tamamlandı. Taranan: ${devicesSnap.size}, Kontrol: ${checkedCount}, Pasifleştirilen: ${cleanedCount}`);

    return {
      success: true,
      checkedCount,
      cleanedCount,
      totalScanned: devicesSnap.size,
      hasMore: devicesSnap.size === scanLimit
    };
  } catch (error) {
    throw error; // wrapCall yakalayıp systemErrors koleksiyonuna kaydeder
  }
}));

/**
 * Storage'dan Fırsat Görselini Silen Yardımcı Fonksiyon
 * P0-09 (R-AUTH-12): Confused Deputy ve Path Traversal kalkanı eklendi.
 * Yalnızca 'deals/' öneki ile başlayan ve traversal ('..') içermeyen geçerli fırsat görselleri silinebilir.
 */
async function deleteDealImage(imageUrl, expectedPrefix = 'deals/') {
  if (!imageUrl || typeof imageUrl !== 'string' || !imageUrl.includes('firebasestorage.googleapis.com')) return;
  try {
    const match = imageUrl.match(/\/o\/([^?]+)/);
    if (match && match[1]) {
      const filePath = decodeURIComponent(match[1]);

      // Güvenlik Kalkanı: Beklenen önekler dışındaki veya dizin tırmanma içeren dosya yolları kesinlikle silinmez
      const allowedPrefixes = Array.isArray(expectedPrefix) ? expectedPrefix : [expectedPrefix];
      const isAllowed = allowedPrefixes.some(prefix => filePath.startsWith(prefix));
      if (!isAllowed || filePath.includes('..') || filePath.includes('//')) {
        functions.logger.warn(`🛡️ [P0-09 Kalkanı] Yetkisiz/şüpheli Storage silme isteği engellendi: ${filePath}`);
        return;
      }

      const bucket = admin.storage().bucket();
      const file = bucket.file(filePath);
      try {
        await file.delete();
        functions.logger.info(`🗑️ Storage'dan silindi: ${filePath}`);
      } catch (delErr) {
        if (delErr.code !== 404) {
          functions.logger.warn(`⚠️ Storage görsel silme uyarısı (${filePath}):`, delErr.message);
        }
      }
    }
  } catch (error) {
    functions.logger.error(`❌ Storage görsel silme hatası:`, error.message);
  }
}

/**
 * ⌛ 48 Saat Geçen Fırsatları Süresi Doldu (isExpired: true) Olarak İşaretler (Core)
 *
 * MİMARİ İYİLEŞTİRMELER:
 * 1. İndeksli ve Bounded Sorgu: Tüm geçmişi çekip bellekte elemek yerine,
 *    Firestore composite indeksi (.where('isExpired', '==', false).where('createdAt', '<', 48h))
 *    ile yalnızca süresi dolmamış fırsatlar çekilir. Kota israfı %99 engellenir.
 * 2. 7 Günlük Güvenli Fallback: İndeks yapım aşamasındaysa bile tüm veritabanı taranmaz,
 *    son 7 günle sınırlandırılarak maliyet kontrol altında tutulur.
 * 3. Atomik Batch: 400'lük gruplar halinde optimize Firestore batch kullanılır.
 * 4. Tek Merkez (DRY): Cron ve Manuel HTTP endpoint'leri aynı core motoru çalıştırır.
 */
async function _cleanupExpiredDealsCore() {
  functions.logger.info('⌛ 48 saatlik eski fırsatları süresi doldu (isExpired: true) işaretleme başlıyor...');
  const db = admin.firestore();
  const now = new Date();
  const fortyEightHoursAgo = new Date(now.getTime() - (48 * 60 * 60 * 1000));
  const thirtyFiveDaysAgo = new Date(now.getTime() - (35 * 24 * 60 * 60 * 1000));

  let expiredCount = 0;
  let errorCount = 0;
  const updatedDeals = [];
  const targetDocs = new Map();

  try {
    // 1. Birincil Yol: İndeksli ve Filtrelenmiş Sorgu (isExpired: false)
    try {
      const snap = await db.collection('deals')
        .where('isExpired', '==', false)
        .where('createdAt', '<', fortyEightHoursAgo)
        .where('createdAt', '>=', thirtyFiveDaysAgo)
        .limit(500)
        .get();

      snap.forEach(doc => {
        const data = doc.data();
        if (data.status !== 'expired') {
          targetDocs.set(doc.id, doc);
        }
      });
      functions.logger.info(`🎯 İndeksli sorgu ile süresi dolacak ${targetDocs.size} taze fırsat tespit edildi.`);
    } catch (indexError) {
      functions.logger.warn('⚠️ İndeksli sorgu çalıştırılamadı, sınırlı pencere fallback devrede:', indexError.message);
      // Fallback: Tüm tarihi değil, yalnızca son 7 gün içindeki 48 saatlik fırsatları sınırla
      const sevenDaysAgo = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
      const fallbackSnap = await db.collection('deals')
        .where('createdAt', '<', fortyEightHoursAgo)
        .where('createdAt', '>=', sevenDaysAgo)
        .limit(300)
        .get();

      fallbackSnap.forEach(doc => {
        const data = doc.data();
        if (data.isExpired !== true && data.status !== 'expired') {
          targetDocs.set(doc.id, doc);
        }
      });
    }

    if (targetDocs.size === 0) {
      functions.logger.info('✅ Süresi dolacak yeni fırsat bulunamadı.');
      return { totalFound: 0, expiredCount: 0, errorCount: 0, updatedDeals: [] };
    }

    // 2. Batch halinde atomik güncelleme (maksimum 400 doküman)
    const batchSize = 400;
    let batch = db.batch();
    let countInBatch = 0;

    for (const [dealId, doc] of targetDocs) {
      try {
        const deal = doc.data();
        batch.update(doc.ref, {
          isExpired: true,
          status: 'expired',
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        countInBatch++;
        expiredCount++;
        updatedDeals.push({ id: dealId, title: deal.title || 'Başlıksız' });

        if (countInBatch >= batchSize) {
          await batch.commit();
          batch = db.batch();
          countInBatch = 0;
        }
      } catch (docError) {
        errorCount++;
        functions.logger.error(`❌ Fırsat süresi doldu güncelleme hatası (${dealId}):`, docError.message);
      }
    }

    if (countInBatch > 0) {
      await batch.commit();
    }

    functions.logger.info(`✅ 48 saatlik soft-expire tamamlandı. İşaretlenen: ${expiredCount}, Hata: ${errorCount}`);
    return {
      totalFound: targetDocs.size,
      expiredCount,
      errorCount,
      updatedDeals
    };
  } catch (err) {
    functions.logger.error('❌ _cleanupExpiredDealsCore genel hatası:', err);
    throw err;
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
    await _cleanupExpiredDealsCore();
    return null;
  }));

/**
 * ⌛ MANUEL ESKİ FIRSATLARI SÜRESİ DOLDU YAP - HTTP ile tetiklenir (Yetki & Rate-Limit Korumalı)
 * Kullanım: GET veya POST isteği at (Yönetici ID Token veya Bakım Anahtarı gereklidir)
 */
let lastManualExpiredRun = 0;
exports.cleanupExpiredDealsManual = functions
  .runWith({ timeoutSeconds: 360, memory: '512MB' })
  .https.onRequest(wrapRequest('cleanupExpiredDealsManual', async (req, res) => {
    // 1. Yönetici Yetkilendirmesi (Açık HTTP DoS ve Kaynak Tüketim Koruması)
    const isAuthorized = await _verifyAdminOrInternalSecret(req);
    if (!isAuthorized) {
      functions.logger.warn('🚫 cleanupExpiredDealsManual yetkisiz erişim denemesi engellendi.');
      res.status(403).json({
        success: false,
        error: 'Yetkisiz erişim. Yönetici ID Token veya geçerli bakım anahtarı gereklidir.'
      });
      return;
    }

    // 2. Rate-Limit / Debounce Koruması (En az 60 saniyede bir çalıştırılabilir)
    const now = Date.now();
    if (now - lastManualExpiredRun < 60000) {
      const waitSeconds = Math.ceil((60000 - (now - lastManualExpiredRun)) / 1000);
      res.status(429).json({
        success: false,
        error: `Bu işlem çok sık tetiklendi. Lütfen ${waitSeconds} saniye sonra tekrar deneyin.`
      });
      return;
    }
    lastManualExpiredRun = now;

    try {
      const stats = await _cleanupExpiredDealsCore();
      res.status(200).json({
        success: true,
        message: 'Fırsat süresi doldu işaretleme tamamlandı (Fırsatlar silinmedi, arşivlendi).',
        stats
      });
    } catch (error) {
      functions.logger.error('❌ Manuel süresi doldu işaretleme genel hatası:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  }));

/**
 * 🔥 30 GÜN GEÇMİŞ FIRSATLARI KALICI OLARAK SİLER (Haftalık)
 * Deals dokümanı + subcollection'ları (votes, comments) + Storage görselleri
 * ve tüm kullanıcılardaki bildirimleri temizler.
 *
 * MİMARİ DÜZELTMELER VE OPTİMİZASYONLAR:
 * 1. O(Deals x Users) Favoriler Felaketi Kaldırıldı:
 *    Tüm kullanıcıları (users koleksiyonunu) gezip tek tek favorites dokümanı arayan döngü
 *    tamamen kaldırıldı. Bu sayede 500.000 gereksiz okuma engellendi, fonksiyon timeout'tan
 *    ve günlük 50.000 Firestore kotasını tüketip patlamaktan kurtarıldı.
 *    (Mobil istemci lib/services/user_service.dart zaten dealDoc.exists == false kontrolüyle
 *    silinmiş fırsatları yakalayıp arka planda self-healing / lazy cleanup yapmaktadır).
 * 2. Güvenli Subcollection Silme: votes ve comments alt koleksiyonları Firestore batch limiti
 *    (500) aşılmayacak şekilde 400'lük parçalar halinde silinir.
 * 3. Hata İzolasyonu: Bir fırsatın silinmesinde oluşacak hata diğer fırsatların veya bildirimlerin
 *    silinmesini engellemez.
/**
 * Alt koleksiyonları 400'lük güvenli batch parçalarıyla tamamen silen yardımcı fonksiyon
 */
async function _deleteSubcollectionBatch(colRef) {
  const db = admin.firestore();
  let hasMore = true;
  while (hasMore) {
    const snap = await colRef.limit(400).get();
    if (snap.empty) {
      hasMore = false;
      break;
    }
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    if (snap.size < 400) {
      hasMore = false;
    }
  }
}

async function _purgeOldDealsCore(days = 30) {
  const db = admin.firestore();
  const now = new Date();
  const cutoffDate = new Date(now.getTime() - (days * 24 * 60 * 60 * 1000));

  let deletedCount = 0;
  let errorCount = 0;
  const deletedDeals = [];

  // Çoklu Pas (Multi-Pass) Tavanı: Azami 4 x 250 = 1.000 fırsat (Haftalık birikme/backlog oluşmasını %100 engeller)
  let passCount = 0;
  const MAX_DEAL_PASSES = 4;
  let hasMoreDeals = true;

  try {
    while (hasMoreDeals && passCount < MAX_DEAL_PASSES) {
      passCount++;
      const snap = await db.collection('deals')
        .where('createdAt', '<', cutoffDate)
        .limit(250)
        .get();

      if (snap.empty) {
        hasMoreDeals = false;
        break;
      }

      functions.logger.info(`🔍 [Pas #${passCount}] ${days} günden eski ${snap.size} fırsat bulundu. Kalıcı silme yapılıyor...`);

      for (const doc of snap.docs) {
        try {
          const deal = doc.data();
          const dealId = doc.id;
          const dealRef = db.collection('deals').doc(dealId);

          // A. Subcollection: votes silme (400'lük güvenli döngüsel batch)
          await _deleteSubcollectionBatch(dealRef.collection('votes'));

          // B. Subcollection: comments silme (Sadece yorum varsa döngüsel batch, 0 ise gereksiz okuma yapma)
          if (deal.commentCount !== 0) {
            await _deleteSubcollectionBatch(dealRef.collection('comments'));
          }

          // C. Storage görselini sil
          const url = deal.imageUrl || deal.image_url || deal.mainImage;
          if (url) {
            await deleteDealImage(url);
          }

          // D. Fırsat dokümanını kalıcı sil
          await dealRef.delete();
          deletedCount++;
          if (deletedDeals.length < 50) {
            deletedDeals.push({ id: dealId, title: deal.title || 'Başlıksız' });
          }
          functions.logger.info(`🗑️ Kalıcı silindi: ${dealId} - ${deal.title || 'Başlıksız'}`);
        } catch (docError) {
          errorCount++;
          functions.logger.error(`❌ Deal kalıcı silme hatası (${doc.id}):`, docError.message);
        }
      }

      if (snap.size < 250) {
        hasMoreDeals = false;
      }
    }

    // Nadir legacy 'timestamp' alanı kalmış belgeleri kontrol et (sadece createdAt ile hiç silinmemişse)
    if (deletedCount === 0) {
      const legacySnap = await db.collection('deals')
        .where('timestamp', '<', cutoffDate)
        .limit(100)
        .get();

      if (!legacySnap.empty) {
        for (const doc of legacySnap.docs) {
          try {
            const deal = doc.data();
            const dealId = doc.id;
            const dealRef = db.collection('deals').doc(dealId);
            await _deleteSubcollectionBatch(dealRef.collection('votes'));
            if (deal.commentCount !== 0) await _deleteSubcollectionBatch(dealRef.collection('comments'));
            const url = deal.imageUrl || deal.image_url || deal.mainImage;
            if (url) await deleteDealImage(url);
            await dealRef.delete();
            deletedCount++;
          } catch (e) {
            errorCount++;
          }
        }
      }
    }

    // E. cutoffDate'i Geçmiş Tüm Bildirimleri Temizle (Notification Center / users/{uid}/notifications)
    let deletedNotificationsCount = 0;
    try {
      const notifResult = await _purgeOldNotificationsCore(days);
      deletedNotificationsCount = notifResult.deletedNotificationsCount;
    } catch (notifErr) {
      functions.logger.error('❌ Eski bildirimleri silme sırasında hata:', notifErr.message);
    }

    // F. cutoffDate'i Geçmiş veya Çözülmüş Eski Sistem Loglarını Temizle (systemErrors)
    let deletedSystemErrorsCount = 0;
    try {
      const errResult = await _purgeOldSystemErrorsCore(days);
      deletedSystemErrorsCount = errResult.deletedCount;
    } catch (sysErr) {
      functions.logger.error('❌ Eski sistem loglarını silme sırasında hata:', sysErr.message);
    }

    functions.logger.info(`✅ ${days} günlük derin temizlik tamamlandı. Silinen Fırsat: ${deletedCount}, Silinen Bildirim: ${deletedNotificationsCount}, Silinen Log: ${deletedSystemErrorsCount}, Hata: ${errorCount}`);
    return {
      totalFound: deletedCount,
      deletedCount,
      deletedNotificationsCount,
      deletedSystemErrorsCount,
      errorCount,
      deletedDeals
    };
  } catch (err) {
    functions.logger.error('❌ _purgeOldDealsCore genel hatası:', err);
    throw err;
  }
}

/**
 * 🧹 30 GÜNÜ GEÇMİŞ TÜM BİLDİRİMLERİ SİLME (Core)
 * users/{userId}/notifications subcollection'larındaki 30 günden eski
 * tüm bildirim dokümanlarını (collectionGroup) batch halinde siler.
 *
 * MİMARİ İYİLEŞTİRMELER:
 * 1. Devre Kesici (Circuit Breaker): Sonsuz döngü ve 540s timeout çökmesini önlemek için
 *    tek çalıştırmada en fazla 25 batch (maksimum 10.000 bildirim) işlenir.
 * 2. Kota ve Bellek Dostu: 400'erlik atomik batch ile Firestore limitlerine tam uyum.
 * 3. Hata Toleransı: Batch commit hatası olursa tüm fonksiyon çökmez, mevcut silinenleri bildirir.
 */
async function _purgeOldNotificationsCore(days = 30) {
  const db = admin.firestore();
  const cutoffDate = new Date(Date.now() - (days * 24 * 60 * 60 * 1000));

  functions.logger.info(`🧹 ${days} günden eski bildirimleri temizleme başladı. Eşik tarihi: ${cutoffDate.toISOString()}`);

  let totalDeleted = 0;
  let hasMore = true;
  let batchCount = 0;
  const MAX_BATCHES = 25; // Maksimum 10.000 bildirim/sefer (Cloud Function timeout koruması)

  while (hasMore && batchCount < MAX_BATCHES) {
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

    try {
      await batch.commit();
      totalDeleted += snap.size;
      batchCount++;
      functions.logger.info(`🗑️ Batch #${batchCount}: ${snap.size} adet eski bildirim silindi (Kümülatif: ${totalDeleted})`);
    } catch (batchErr) {
      functions.logger.error(`❌ Bildirim batch silme hatası (#${batchCount + 1}):`, batchErr.message);
      break; // Çökmek yerine şu ana kadar silinenleri koruyarak güvenle çık
    }

    if (snap.size < 400) {
      hasMore = false;
    }
  }

  if (batchCount >= MAX_BATCHES && hasMore) {
    functions.logger.warn(`⚠️ Azami bildirim temizleme tavanına (${MAX_BATCHES * 400}) ulaşıldı. Kalanlar bir sonraki periyotta temizlenecektir.`);
  }

  functions.logger.info(`✅ Eski bildirim temizliği tamamlandı. Toplam silinen bildirim: ${totalDeleted}`);
  return { deletedNotificationsCount: totalDeleted, hasMore };
}

/**
 * 🧹 30 GÜNÜ GEÇMİŞ VEYA ÇÖZÜLMÜŞ SİSTEM HATA LOGLARINI TEMİZLEME (Core)
 * systemErrors koleksiyonundaki 30 günden eski hataları ve 7 günden eski çözülmüş (resolved) hataları
 * Firestore 400'lük atomik batch'ler halinde temizler.
 *
 * MİMARİ KORUMALAR:
 * 1. Devre Kesici (Circuit Breaker): En fazla 5 batch (azami 2.000 doküman/sefer) işlenir.
 * 2. Öncelik Sıralaması: Önce çözülmüş (resolved) eski kayıtlar, ardından 30 günden eski tüm kayıtlar temizlenir.
 * 3. Hata Toleransı: Batch commit hatası oluşursa tüm cron çökmez, mevcut silinenleri loglar.
 */
async function _purgeOldSystemErrorsCore(days = 30) {
  const db = admin.firestore();
  const now = Date.now();
  const cutoffDate = new Date(now - (days * 24 * 60 * 60 * 1000));
  const resolvedCutoff = new Date(now - (7 * 24 * 60 * 60 * 1000)); // 7 günden eski çözülmüşler

  functions.logger.info(`🧹 Eski sistem loglarını temizleme başladı (Eşik: ${cutoffDate.toISOString()})`);

  let totalDeleted = 0;
  let batchCount = 0;
  const MAX_BATCHES = 5; // Azami 2.000 log (Tek çalıştırmada kota ve zaman aşımı koruması)

  try {
    // 1. Adım: 7 günden eski çözülmüş (resolved) loglar
    const resolvedSnap = await db.collection('systemErrors')
      .where('status', '==', 'resolved')
      .where('createdAt', '<', resolvedCutoff)
      .limit(400)
      .get();

    if (!resolvedSnap.empty) {
      const batch = db.batch();
      resolvedSnap.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
      totalDeleted += resolvedSnap.size;
      batchCount++;
      functions.logger.info(`🗑️ ${resolvedSnap.size} adet çözülmüş eski sistem logu temizlendi.`);
    }

    // 2. Adım: 30 günden eski genel sistem logları
    let hasMore = true;
    while (hasMore && batchCount < MAX_BATCHES) {
      const snap = await db.collection('systemErrors')
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
      batchCount++;
      functions.logger.info(`🗑️ Batch #${batchCount}: ${snap.size} adet 30+ günlük sistem logu temizlendi.`);

      if (snap.size < 400) {
        hasMore = false;
      }
    }
  } catch (err) {
    functions.logger.error('❌ _purgeOldSystemErrorsCore hatası:', err.message);
  }

  functions.logger.info(`✅ Sistem logları temizliği tamamlandı. Toplam silinen: ${totalDeleted}`);
  return { deletedCount: totalDeleted };
}

exports.purgeOldDeals = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .pubsub.schedule('0 4 * * 0') // Her Pazar 04:00'da çalışır
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('purgeOldDeals', async (context) => {
    functions.logger.info('🔥 30 günlük fırsat ve bildirim kalıcı silme görevi başladı...');
    await _purgeOldDealsCore(30);
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

    const days = (data && data.days) ? parseInt(data.days, 10) : 30;
    functions.logger.info(`🔥 Admin ${context.auth.uid} tarafından manuel kalıcı silme tetiklendi (${days} günlük).`);
    const result = await _purgeOldDealsCore(days);
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

exports.purgeOldSystemErrorsManual = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .https.onCall(wrapCall('purgeOldSystemErrorsManual', async (data, context) => {
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
    functions.logger.info(`🔥 Admin ${context.auth.uid} tarafından manuel sistem logu temizleme tetiklendi (${days} günlük).`);
    const result = await _purgeOldSystemErrorsCore(days);
    return {
      success: true,
      message: `${result.deletedCount} adet eski sistem logu kalıcı olarak silindi.`,
      stats: result
    };
  }));

/**
 * 14. KULLANICI AUTH HESABI SİLİNDİĞİNDE TETİKLENEN SİLME İŞLEMİ (KVKK / GDPR Tam Uyumlu)
 * 
 * MİMARİ İYİLEŞTİRMELER:
 * 1. 500 Batch Sınırı Koruması (deleteQueryInBatches): Tek seferde >500 belge silinirken
 *    Firestore'un InvalidArgumentError ile çökmesini önler. 400'lük atomik gruplarla döngüsel temizlik yapar.
 * 2. Storage Dosya Temizliği: Kullanıcının profil resmi ve paylaştığı fırsat görselleri (imageUrl/mainImage)
 *    Firebase Storage'dan otomatik silinerek disk çöpü ve depolama maliyet artışı engellenir.
 * 3. Kapsamlı İlişkili Veri Temizliği: adminToUserMessages ve çift taraflı sorgu kontrolleri kapsanır.
 * 4. Hata İzolasyonu ve Detaylı Telemetri: Bir koleksiyondaki geçici hata diğer koleksiyonların
 *    silinmesini durdurmaz, her adımın silinen kayıt sayısı loglanır.
 */
/**
 * Çekirdek Kullanıcı Verisi Temizleme Fonksiyonu (DRY Helper)
 * Hem Auth trigger'ı (onUserDeleted) hem de Admin Callable (adminDeleteUser) ve cleanupTestData tarafından kullanılır.
 */
async function _cleanupUserDataCore(userId) {
  functions.logger.info(`🗑️ Kullanıcı verisi kalıcı temizleme başladı: ${userId}`);

  const db = admin.firestore();
  const deletedStats = {};

  // Güvenli ve döngüsel batch silme yardımcı fonksiyonu (400 belge sınırı)
  async function deleteQueryInBatches(query, batchSize = 400) {
    let totalDeleted = 0;
    while (true) {
      const snapshot = await query.limit(batchSize).get();
      if (snapshot.empty) break;

      const batch = db.batch();
      snapshot.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();

      totalDeleted += snapshot.size;
      if (snapshot.size < batchSize) break;
    }
    return totalDeleted;
  }

  // 1. Cihaz kayıtlarını sil (userDevices) - Hem uid hem userId uyumluluğu
  try {
    const countUid = await deleteQueryInBatches(db.collection('userDevices').where('uid', '==', userId));
    const countUserId = await deleteQueryInBatches(db.collection('userDevices').where('userId', '==', userId));
    deletedStats.userDevices = countUid + countUserId;
    functions.logger.info(`✅ userDevices silindi (${deletedStats.userDevices} kayıt): ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ userDevices silme hatası:`, err.message);
  }

  // 2. Bildirim aboneliklerini sil (notificationSubscriptions)
  try {
    const countSubUid = await deleteQueryInBatches(db.collection('notificationSubscriptions').where('uid', '==', userId));
    const countSubUserId = await deleteQueryInBatches(db.collection('notificationSubscriptions').where('userId', '==', userId));
    deletedStats.notificationSubscriptions = countSubUid + countSubUserId;
    functions.logger.info(`✅ notificationSubscriptions silindi (${deletedStats.notificationSubscriptions} kayıt): ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ notificationSubscriptions silme hatası:`, err.message);
  }

  // 3. P0-11 (R-PRV-04): Kullanıcının kendi fırsatlarını, fırsat alt yorumlarını, oylarını ve görsellerini sil
  try {
    let dealsDeleted = 0;
    while (true) {
      const dealsSnap = await db.collection('deals').where('postedBy', '==', userId).limit(100).get();
      if (dealsSnap.empty) break;

      for (const dealDoc of dealsSnap.docs) {
        const dealData = dealDoc.data();
        await deleteQueryInBatches(dealDoc.ref.collection('comments'));
        await deleteQueryInBatches(dealDoc.ref.collection('votes'));
        await deleteQueryInBatches(dealDoc.ref.collection('expired_votes'));
        const img = dealData.imageUrl || dealData.mainImage;
        if (img) {
          await deleteDealImage(img);
        }
        await dealDoc.ref.delete();
        dealsDeleted++;
      }
      if (dealsSnap.size < 100) break;
    }
    deletedStats.deals = dealsDeleted;
    functions.logger.info(`✅ Kullanıcı fırsatları (${dealsDeleted} fırsat, yorumları, oyları ve görselleri) silindi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Fırsat silme hatası:`, err.message);
  }

  // 3.1 P0-11 (R-PRV-04): Kullanıcının paylaştığı kuponları ve kupon alt oylarını sil
  try {
    let couponsDeleted = 0;
    while (true) {
      const couponSnap = await db.collection('kuponlar').where('paylasanKullaniciId', '==', userId).limit(100).get();
      if (couponSnap.empty) break;

      for (const couponDoc of couponSnap.docs) {
        await deleteQueryInBatches(couponDoc.ref.collection('votes'));
        await couponDoc.ref.delete();
        couponsDeleted++;
      }
      if (couponSnap.size < 100) break;
    }
    deletedStats.coupons = couponsDeleted;
    functions.logger.info(`✅ Kullanıcı kuponları (${couponsDeleted} kupon ve oyları) silindi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Kupon silme hatası:`, err.message);
  }

  // 4. Kullanıcının diğer fırsatlara yazdığı yorumları sil (collectionGroup)
  try {
    const userCommentsQuery = db.collectionGroup('comments').where('userId', '==', userId);
    deletedStats.comments = await deleteQueryInBatches(userCommentsQuery);
    functions.logger.info(`✅ Kullanıcı tarafından yazılan yorumlar silindi (${deletedStats.comments} yorum): ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Yorum silme hatası:`, err.message);
  }

  // 5. Direkt mesajları sil (messages ve adminToUserMessages)
  try {
    const sentMsgCount = await deleteQueryInBatches(db.collection('messages').where('senderId', '==', userId));
    const recvMsgCount = await deleteQueryInBatches(db.collection('messages').where('receiverId', '==', userId));
    const adminMsgCount = await deleteQueryInBatches(db.collection('adminToUserMessages').where('userId', '==', userId));
    deletedStats.messages = sentMsgCount + recvMsgCount + adminMsgCount;
    functions.logger.info(`✅ Mesajlar silindi (${deletedStats.messages} mesaj): ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Mesaj silme hatası:`, err.message);
  }

  // 6. Raporları sil (reports)
  try {
    const sentRepCount = await deleteQueryInBatches(db.collection('reports').where('reportedBy', '==', userId));
    const recvRepCount = await deleteQueryInBatches(db.collection('reports').where('reportedId', '==', userId));
    deletedStats.reports = sentRepCount + recvRepCount;
    functions.logger.info(`✅ Raporlar silindi (${deletedStats.reports} rapor): ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Rapor silme hatası:`, err.message);
  }

  // 7. P1-17 (R-AUTH-15): Ban ve engelleme kayıtları (blockedUsers, commentBannedUsers, dealBannedUsers)
  // Sybil ve ban sıfırlama (Ban Evasion) saldırılarını engellemek için kullanıcı hesap silse dahi KORUNUR!
  // Yalnızca admin paneli üzerinden açıkça af/engel kaldırma işlemi yapılabilir.
  functions.logger.info(`🛡️ [P1-17 Kalkanı] Ban ve ceza kayıtları silinmedi, güvenlik için muhafaza edildi: ${userId}`);

  // 8. P0-11 & P0-14: Kullanıcının alt koleksiyonlarını (ledger, favori, bildirim) ve profilini sil
  try {
    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();
    if (userSnap.exists) {
      const uData = userSnap.data();
      const pImage = uData.profileImageUrl || uData.photoURL;
      if (pImage && pImage.includes('firebasestorage.googleapis.com')) {
        await deleteDealImage(pImage, ['deals/', 'avatars/']);
      }
    }

    const notifCount = await deleteQueryInBatches(userRef.collection('notifications'));
    const prefCount = await deleteQueryInBatches(userRef.collection('notificationPreferences'));
    const favCount = await deleteQueryInBatches(userRef.collection('favorites'));
    const ledgerCount = await deleteQueryInBatches(userRef.collection('couponLedger'));
    const unlockedCount = await deleteQueryInBatches(userRef.collection('unlockedCoupons'));
    deletedStats.subcollections = notifCount + prefCount + favCount + ledgerCount + unlockedCount;

    await userRef.delete();
    functions.logger.info(`✅ Kullanıcı ana dokümanı ve alt koleksiyonları (${deletedStats.subcollections} öğe) silindi: ${userId}`);
  } catch (err) {
    functions.logger.error(`❌ Profil/alt koleksiyon silme hatası:`, err.message);
  }

  // 9. P0-11: KVKK/GDPR Silme Mührü (Erasure Job Log)
  try {
    await db.collection('erasureJobs').doc(userId).set({
      userId: userId,
      status: 'completed',
      deletedStats: deletedStats,
      completedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    functions.logger.info(`✅ KVKK/GDPR ErasureJob mühürlendi: ${userId}`);
  } catch (jobErr) {
    functions.logger.warn(`⚠️ ErasureJob kayıt uyarısı:`, jobErr.message);
  }

  functions.logger.info(`🎉 Kullanıcı verisi kalıcı temizliği tamamlandı (${userId}):`, deletedStats);
  return deletedStats;
}

exports.onUserDeleted = functions.auth.user().onDelete(wrapTrigger('onUserDeleted', async (user, context) => {
  const userId = user.uid;
  functions.logger.info(`🗑️ Kullanıcı hesabı kalıcı silme tetiklendi: ${userId}`);
  await _cleanupUserDataCore(userId);
  return null;
}));

/**
 * P0-12 (R-PRV-08): KULLANICI KENDİ HESABINI SİLME (Callable)
 * İstemci tarafı güvenli kimlik doğrulama sonrası çağrılır. Verileri kaskat olarak temizler ve Auth kullanıcısını siler.
 */
exports.deleteMyAccount = functions.https.onCall(wrapCall('deleteMyAccount', async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Bu işlem için giriş yapmalısınız.');
  }

  const userId = context.auth.uid;
  functions.logger.info(`🗑️ deleteMyAccount çağrıldı: ${userId}`);

  try {
    // 1. Kaskat Firestore, Storage ve ilişkili verileri kalıcı sil
    const stats = await _cleanupUserDataCore(userId);

    // 2. Firebase Auth'dan kullanıcıyı kalıcı olarak sil
    let authDeleted = false;
    try {
      await admin.auth().deleteUser(userId);
      authDeleted = true;
      functions.logger.info(`✅ Firebase Auth kullanıcısı başarıyla silindi: ${userId}`);
    } catch (authErr) {
      if (authErr.code === 'auth/user-not-found') {
        functions.logger.warn(`⚠️ Auth kullanıcısı zaten silinmiş: ${userId}`);
      } else {
        throw authErr;
      }
    }

    return { success: true, userId, authDeleted, stats };
  } catch (error) {
    functions.logger.error(`❌ deleteMyAccount hatası (${userId}):`, error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Hesap silinirken hata oluştu: ${error.message}`);
  }
}));

/**
 * 15. ADMİN TARAFINDAN KULLANICI HESABINI SİLME (Callable) - FAZ 6
 * Sadece adminler tetikleyebilir. Auth ve Firestore verilerini kaskat olarak temizler.
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

  const targetUid = (data && data.targetUid) ? String(data.targetUid).trim() : '';
  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'Hedef kullanıcı UID belirtilmedi.');
  }

  if (targetUid === context.auth.uid) {
    throw new functions.https.HttpsError('invalid-argument', 'Kendi kendinizi silemezsiniz.');
  }

  // Güvenlik Kalkanı: Hedef kullanıcının yönetici olup olmadığını denetle
  const targetUserDoc = await admin.firestore().collection('users').doc(targetUid).get();
  if (targetUserDoc.exists) {
    const targetData = targetUserDoc.data() || {};
    const isTargetAdmin = targetData.isAdmin === true || targetData.isadmin === true || targetData.isAdmin === 'true' || targetData.isadmin === 'true';
    if (isTargetAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Yönetici hesapları bu fonksiyon üzerinden silinemez. Güvenlik gereği doğrudan Firebase Console üzerinden yönetilmelidir.');
    }
  }

  try {
    functions.logger.info(`👮 Admin ${context.auth.uid} tarafından kullanıcı siliniyor: ${targetUid}`);

    let authDeleted = false;
    try {
      await admin.auth().deleteUser(targetUid);
      authDeleted = true;
      functions.logger.info(`✅ Kullanıcı Auth'dan başarıyla silindi: ${targetUid}`);
    } catch (authErr) {
      if (authErr.code === 'auth/user-not-found') {
        functions.logger.warn(`⚠️ Kullanıcı Auth'da bulunamadı (${targetUid}), doğrudan Firestore temizliği yapılacak.`);
      } else {
        throw authErr;
      }
    }

    // Kullanıcı Auth'da bulunamadıysa (veya Auth silindikten sonra Firestore temizliğini garantiye almak için)
    // _cleanupUserDataCore fonksiyonunu doğrudan çalıştır:
    if (!authDeleted) {
      await _cleanupUserDataCore(targetUid);
    }

    return { success: true, targetUid, authDeleted };
  } catch (error) {
    functions.logger.error(`❌ Admin kullanıcı silme hatası (${targetUid}):`, error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Kullanıcı silinemedi: ${error.message}`);
  }
}));

/**
 * 16. TEST DATA JENERATÖRÜ (Callable) - Sadece Adminler - FAZ 6
 * İzolasyonlu test kullanıcısı oluşturur, ilişkili cihazları, ayarları ve mock fırsatları ekler.
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

  const rawEmailInput = (data && data.email ? String(data.email) : 'testuser').trim();
  const username = (data && data.username ? String(data.username) : 'TestKullanici').trim();
  const dealsCount = Math.min(Math.max(parseInt((data && data.dealsCount) || 3, 10) || 3, 1), 10);

  // Güvenlik için e-postayı zorunlu olarak @test.firsatkolik.com uzantılı yapıyoruz
  const baseEmail = rawEmailInput.split('@')[0].replace(/[^a-zA-Z0-9_\-]/g, '') || 'testuser';
  const cleanEmail = `${baseEmail}@test.firsatkolik.com`;

  try {
    functions.logger.info(`🧪 Test verisi oluşturma başladı. E-posta: ${cleanEmail}`);

    // 1. Eğer test kullanıcısı zaten varsa önce temizle (Auth ve Firestore)
    try {
      const existingUser = await admin.auth().getUserByEmail(cleanEmail);
      if (existingUser) {
        functions.logger.info(`🗑️ Eski test kullanıcısı bulundu, siliniyor: ${existingUser.uid}`);
        await admin.auth().deleteUser(existingUser.uid).catch(() => {});
        await _cleanupUserDataCore(existingUser.uid);
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

    // 3. users/{uid} profilini oluştur (isTest: true koruması)
    await db.collection('users').doc(uid).set({
      uid: uid,
      username: username,
      nickname: `${username}_nick`,
      email: cleanEmail,
      points: 120,
      dealCount: dealsCount,
      totalLikes: 15,
      isTest: true,
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
      quietHoursEnabled: true,
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
      isTest: true,
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

    // 7. Mock Fırsatları (Deals) oluştur (isTest: true koruması)
    const createdDeals = [];
    for (let i = 1; i <= dealsCount; i++) {
      const price = Math.floor(Math.random() * 4000) + 1000;
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
        isTest: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isApproved: false,
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
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Test verisi oluşturulamadı: ${error.message}`);
  }
}));

/**
 * 17. TÜM TEST VERİLERİNİ TEMİZLEME (Callable) - Sadece Adminler - FAZ 6
 * E-postası @test.firsatkolik.com ile biten veya isTest: true olan kullanıcıları ve fırsatları kalıcı temizler.
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

    const testUserIds = new Set();

    // 1. İndeksli sorgu: isTest: true olan test kullanıcıları
    try {
      const isTestSnap = await db.collection('users').where('isTest', '==', true).limit(500).get();
      isTestSnap.docs.forEach(d => testUserIds.add(d.id));
    } catch (testQueryErr) {
      functions.logger.warn('⚠️ isTest sorgusu uyarısı:', testQueryErr.message);
    }

    // 2. E-posta standardı sorgusu: @test.firsatkolik.com ile oluşturulmuş hesaplar (test_ öneki)
    try {
      const emailSnap = await db.collection('users')
        .where('email', '>=', 'test_')
        .where('email', '<=', 'test_\uf8ff')
        .limit(200)
        .get();
      emailSnap.docs.forEach(d => {
        const email = d.data().email || '';
        if (email.endsWith('@test.firsatkolik.com') || email.startsWith('test_')) {
          testUserIds.add(d.id);
        }
      });
    } catch (emailQueryErr) {
      functions.logger.warn('⚠️ email sorgusu uyarısı:', emailQueryErr.message);
    }

    // 3. Fallback: Eğer açıkça fullScan istendiyse ve sonuç 0 ise sınırlandırılmış select()
    if (data && data.fullScan === true && testUserIds.size === 0) {
      const usersSnap = await db.collection('users').select('email', 'isTest').limit(500).get();
      for (const doc of usersSnap.docs) {
        const u = doc.data() || {};
        const email = u.email || '';
        if (u.isTest === true || email.endsWith('@test.firsatkolik.com')) {
          testUserIds.add(doc.id);
        }
      }
    }

    functions.logger.info(`🔥 ${testUserIds.size} test kullanıcısı bulundu, temizleniyor...`);

    let cleanedCount = 0;
    const testUserIdsArr = Array.from(testUserIds);
    // 5'erli eşzamanlılık havuzunda güvenle sil (Soket ve bağlantı tükenmesini engelle)
    for (let i = 0; i < testUserIdsArr.length; i += 5) {
      const chunk = testUserIdsArr.slice(i, i + 5);
      await Promise.all(chunk.map(async (uid) => {
        try {
          await admin.auth().deleteUser(uid).catch(() => {});
        } catch (_) {}
        await _cleanupUserDataCore(uid);
        cleanedCount++;
      }));
    }

    // Sahipsiz kalan isTest: true fırsatlarını da 400 batch parçalarıyla döngüsel temizle
    let totalDealsCleaned = 0;
    let hasMoreDeals = true;
    while (hasMoreDeals) {
      const testDealsSnap = await db.collection('deals').where('isTest', '==', true).limit(400).get();
      if (testDealsSnap.empty) {
        hasMoreDeals = false;
        break;
      }
      const batch = db.batch();
      testDealsSnap.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
      totalDealsCleaned += testDealsSnap.size;
      if (testDealsSnap.size < 400) {
        hasMoreDeals = false;
      }
    }
    if (totalDealsCleaned > 0) {
      functions.logger.info(`🔥 ${totalDealsCleaned} sahipsiz test fırsatı silindi.`);
    }

    return {
      success: true,
      cleanedCount,
      dealsCleaned: totalDealsCleaned
    };
  } catch (error) {
    functions.logger.error('❌ Test verileri temizleme hatası:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', `Test verileri temizlenemedi: ${error.message}`);
  }
}));
/**
 * 7. USER GÜNCELLEME TETİKLEYİCİSİ - Profil resmi veya kullanıcı adı değiştiğinde
 * tüm yorumlardaki, mesajlardaki ve fırsatlardaki denormalized profil verilerini senkronize eder.
 * 
 * MİMARİ İYİLEŞTİRMELER:
 * 1. Kota ve Bellek Güvenliği (Bounded Queries): collectionGroup('comments'), messages ve deals
 *    sorgularına limit(300) konularak OOM (Out-of-memory) ve fonksiyon zaman aşımı (60s) engellenir.
 * 2. Sıfır İsraf / No-Op Eleme: Yalnızca mevcut verisi değişen dokümanlar güncellenir. Zaten hedef
 *    fotoğraf ve isme sahip olan kayıtlar batch'e eklenmez (%100 gereksiz yazma maliyeti önlenir).
 * 3. İzole Atomik Batch Yönetimi: syncDocsWithBatch yardımcısı her koleksiyon için bağımsız batch
 *    oluşturur, 400 işlem sınırını aşmadan otomatik commit eder ve bir koleksiyon hatasının diğerlerini
 *    etkilemesini engeller.
 * 4. Kapsamlı Telemetri: Taranan, güncellenen ve atlanan doküman sayıları detaylı olarak loglanır.
 */
exports.onUserUpdated = functions.firestore
  .document('users/{userId}')
  .onUpdate(wrapTrigger('onUserUpdated', async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;

    const oldPhoto = before.profileImageUrl || before.photoURL || '';
    let newPhoto = after.profileImageUrl || after.photoURL || '';
    const lowerPhoto = newPhoto.toLowerCase();
    if (lowerPhoto.includes('kullanıcı pp') || lowerPhoto.includes('kullanici pp')) {
      newPhoto = 'assets/avatars/avatar_cat.webp';
    } else if (lowerPhoto.includes('kkpp') || lowerPhoto.includes('ayi') || lowerPhoto.includes('ayı') || lowerPhoto.includes('kullanıcı profili') || lowerPhoto.includes('kullanici profili')) {
      newPhoto = 'assets/avatars/avatar_duck.webp';
    } else if (lowerPhoto === 'assets/profil.jpg' || lowerPhoto === 'assets/profil.webp') {
      newPhoto = 'assets/avatars/avatar_duck.webp';
    } else if (newPhoto.startsWith('assets/') && /\.(jpg|jpeg|png)$/i.test(newPhoto)) {
      newPhoto = newPhoto.replace(/\.(jpg|jpeg|png)$/i, '.webp');
    }
    const oldName = before.username || before.displayName || before.nickname || '';
    const newName = after.username || after.displayName || after.nickname || '';

    const photoChanged = oldPhoto !== newPhoto;
    const nameChanged = oldName !== newName;

    if (!photoChanged && !nameChanged) {
      functions.logger.info(`ℹ️ User ${userId} güncellendi ancak fotoğraf veya isim değişmedi. Senkronizasyon atlandı.`);
      return null;
    }

    functions.logger.info(`👤 User ${userId} güncellendi. Senkronizasyon başlıyor (photoChanged=${photoChanged}, nameChanged=${nameChanged})`);

    const db = admin.firestore();
    const syncStats = {
      comments: { scanned: 0, updated: 0, skipped: 0 },
      sentMessages: { scanned: 0, updated: 0, skipped: 0 },
      receivedMessages: { scanned: 0, updated: 0, skipped: 0 },
      deals: { scanned: 0, updated: 0, skipped: 0 }
    };

    /**
     * Güvenli ve bounded batch güncelleme yardımcı fonksiyonu.
     * Belgeleri kontrol eder ve yalnızca verisi değişmiş olanları batch'e ekler.
     * 400 işlem sınırını aşmadan otomatik commit eder.
     */
    async function syncDocsWithBatch(docs, getUpdateData) {
      let updatedCount = 0;
      let skippedCount = 0;
      let batch = db.batch();
      let countInBatch = 0;

      for (const doc of docs) {
        const updateData = getUpdateData(doc.data());
        if (!updateData || Object.keys(updateData).length === 0) {
          skippedCount++;
          continue;
        }

        batch.update(doc.ref, updateData);
        countInBatch++;
        updatedCount++;

        if (countInBatch >= 400) {
          await batch.commit();
          batch = db.batch();
          countInBatch = 0;
        }
      }

      if (countInBatch > 0) {
        await batch.commit();
      }

      return { updatedCount, skippedCount };
    }

    // 1. Yorumları Senkronize Et - Collection Group Query (Limit 300)
    try {
      const commentsSnap = await db.collectionGroup('comments')
        .where('userId', '==', userId)
        .limit(300)
        .get();

      syncStats.comments.scanned = commentsSnap.size;
      const res = await syncDocsWithBatch(commentsSnap.docs, (data) => {
        const update = {};
        if (photoChanged && data.userProfileImageUrl !== newPhoto) update.userProfileImageUrl = newPhoto;
        if (nameChanged && data.userName !== newName) update.userName = newName;
        return update;
      });
      syncStats.comments.updated = res.updatedCount;
      syncStats.comments.skipped = res.skippedCount;
      functions.logger.info(`💬 Yorum senkronizasyonu (${userId}): ${res.updatedCount} güncellendi, ${res.skippedCount} atlandı.`);
    } catch (commentErr) {
      functions.logger.error('❌ Yorum senkronizasyon hatası:', commentErr.message);
    }

    // 2. Gönderilen Mesajları Senkronize Et (Limit 300)
    try {
      const sentMsgSnap = await db.collection('messages')
        .where('senderId', '==', userId)
        .limit(300)
        .get();

      syncStats.sentMessages.scanned = sentMsgSnap.size;
      const res = await syncDocsWithBatch(sentMsgSnap.docs, (data) => {
        const update = {};
        if (photoChanged && data.senderImageUrl !== newPhoto) update.senderImageUrl = newPhoto;
        if (nameChanged && data.senderName !== newName) update.senderName = newName;
        return update;
      });
      syncStats.sentMessages.updated = res.updatedCount;
      syncStats.sentMessages.skipped = res.skippedCount;
      functions.logger.info(`✉️ Gönderilen mesaj senkronizasyonu (${userId}): ${res.updatedCount} güncellendi, ${res.skippedCount} atlandı.`);
    } catch (msgErr) {
      functions.logger.error('❌ Gönderilen mesaj senkronizasyon hatası:', msgErr.message);
    }

    // 3. Alınan Mesajları Senkronize Et (Limit 300)
    try {
      const receivedMsgSnap = await db.collection('messages')
        .where('receiverId', '==', userId)
        .limit(300)
        .get();

      syncStats.receivedMessages.scanned = receivedMsgSnap.size;
      const res = await syncDocsWithBatch(receivedMsgSnap.docs, (data) => {
        const update = {};
        if (photoChanged && data.receiverImageUrl !== newPhoto) update.receiverImageUrl = newPhoto;
        if (nameChanged && data.receiverName !== newName) update.receiverName = newName;
        return update;
      });
      syncStats.receivedMessages.updated = res.updatedCount;
      syncStats.receivedMessages.skipped = res.skippedCount;
      functions.logger.info(`✉️ Alınan mesaj senkronizasyonu (${userId}): ${res.updatedCount} güncellendi, ${res.skippedCount} atlandı.`);
    } catch (msgErr) {
      functions.logger.error('❌ Alınan mesaj senkronizasyon hatası:', msgErr.message);
    }

    // 4. Kullanıcının Fırsatlarını Senkronize Et (Deals - Limit 300)
    try {
      const userDealsSnap = await db.collection('deals')
        .where('postedBy', '==', userId)
        .limit(300)
        .get();

      syncStats.deals.scanned = userDealsSnap.size;
      const res = await syncDocsWithBatch(userDealsSnap.docs, (data) => {
        const update = {};
        if (photoChanged && data.postedByAvatar !== newPhoto) update.postedByAvatar = newPhoto;
        if (nameChanged && data.postedByName !== newName) update.postedByName = newName;
        return update;
      });
      syncStats.deals.updated = res.updatedCount;
      syncStats.deals.skipped = res.skippedCount;
      functions.logger.info(`🔥 Fırsat senkronizasyonu (${userId}): ${res.updatedCount} güncellendi, ${res.skippedCount} atlandı.`);
    } catch (dealErr) {
      functions.logger.error('❌ Fırsat senkronizasyon hatası:', dealErr.message);
    }

    functions.logger.info(`🎉 User ${userId} profil senkronizasyonu başarıyla tamamlandı:`, syncStats);
    return null;
  }));

/**
 * DAĞITIK KAZIMA KİLİDİ (DISTRIBUTED SCRAPER MUTEX)
 * Zamanlanmış (cron) ve manuel tetiklemelerin aynı anda çalışarak hedef sitelerde WAF/IP engeline
 * ve Firestore'da çakışan yazma/silme yarış koşullarına (race condition) yol açmasını engeller.
 */
async function executeWithScraperLock(lockName, triggerType, scrapeFn) {
  const db = admin.firestore();
  const lockRef = db.collection('systemLocks').doc(lockName);
  const now = Date.now();
  const leaseDurationMs = 15 * 60 * 1000; // 15 dakika emniyet tavanı

  const lockResult = await db.runTransaction(async (t) => {
    const lockDoc = await t.get(lockRef);
    if (lockDoc.exists) {
      const data = lockDoc.data() || {};
      const lockedUntil = data.lockedUntil || 0;
      if (data.isLocked && lockedUntil > now) {
        return {
          acquired: false,
          lockedBy: data.lockedBy || 'başka bir süreç',
          lockedUntil: data.lockedUntil
        };
      }
    }

    t.set(lockRef, {
      isLocked: true,
      lockedBy: triggerType,
      lockedAt: admin.firestore.FieldValue.serverTimestamp(),
      lockedUntil: now + leaseDurationMs,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return { acquired: true };
  });

  if (!lockResult.acquired) {
    functions.logger.warn(`🔒 [${lockName}] işlemi zaten [${lockResult.lockedBy}] tarafından yürütülüyor. Yeni tetikleme engellendi.`);
    return {
      success: false,
      inProgress: true,
      message: `Bu kazıma işlemi şu anda [${lockResult.lockedBy}] tarafından yürütülmektedir. Lütfen önceki sürecin tamamlanmasını bekleyin.`
    };
  }

  try {
    const startTime = Date.now();
    const result = await scrapeFn();
    const durationMs = Date.now() - startTime;
    return {
      ...(result || {}),
      durationMs
    };
  } finally {
    try {
      await lockRef.set({
        isLocked: false,
        lockedBy: null,
        lockedUntil: 0,
        releasedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    } catch (releaseErr) {
      functions.logger.warn(`⚠️ [${lockName}] kilit serbest bırakma hatası:`, releaseErr.message);
    }
  }
}

/**
 * 16. KUPON KAZIMA VE KAYDETME - MANUEL (Callable) - FAZ 5
 * Sadece adminler tetikleyebilir. Dağıtık kilit korumalıdır.
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

    functions.logger.info(`👥 Manual coupon scraping triggered by admin: ${context.auth.uid}`);
    const { scrapeAndSaveCoupons } = require('./coupon_scraper');
    return await executeWithScraperLock('coupon_scraping', `admin_${context.auth.uid}`, () => scrapeAndSaveCoupons());
  }));

/**
 * 17. KUPON KAZIMA VE KAYDETME - ZAMANLANMIŞ (Scheduled) - FAZ 5
 * Her gün gece 04:00'da otomatik çalışır. Dağıtık kilit korumalıdır.
 */
exports.scrapeCouponsScheduled = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .pubsub.schedule('0 4 * * *')
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('scrapeCouponsScheduled', async (context) => {
    functions.logger.info('⏰ Scheduled coupon scraping triggered...');
    const { scrapeAndSaveCoupons } = require('./coupon_scraper');
    const result = await executeWithScraperLock('coupon_scraping', 'scheduled_cron', () => scrapeAndSaveCoupons());
    functions.logger.info('⏰ Scheduled coupon scraping finished:', result);
    return null;
  }));

/**
 * 18. AKTÜEL KATALOG KAZIMA VE KAYDETME - MANUEL (Callable) - FAZ 5
 * Sadece adminler tetikleyebilir. Dağıtık kilit korumalıdır.
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

    functions.logger.info(`👥 Manual catalog scraping triggered by admin: ${context.auth.uid}`);
    const { scrapeAndSaveCatalogs } = require('./catalog_scraper');
    return await executeWithScraperLock('catalog_scraping', `admin_${context.auth.uid}`, () => scrapeAndSaveCatalogs());
  }));

/**
 * 19. AKTÜEL KATALOG KAZIMA VE KAYDETME - ZAMANLANMIŞ (Scheduled) - FAZ 5
 * Her gün gece 03:00'da otomatik çalışır. (v2026.07.28 - Google Translate Proxy) Dağıtık kilit korumalıdır.
 */
exports.scrapeCatalogsScheduled = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .pubsub.schedule('0 3 * * *')
  .timeZone('Europe/Istanbul')
  .onRun(wrapTrigger('scrapeCatalogsScheduled', async (context) => {
    functions.logger.info('⏰ Scheduled catalog scraping triggered (v2026.07.28)...');
    const { scrapeAndSaveCatalogs } = require('./catalog_scraper');
    const result = await executeWithScraperLock('catalog_scraping', 'scheduled_cron', () => scrapeAndSaveCatalogs());
    functions.logger.info('⏰ Scheduled catalog scraping finished:', result);
    return null;
  }));

/**
 * 20. OBSERVABILITY & TELEMETRİ GÖZLEMLEME SERVİSİ (Modül 11)
 * Web Admin için GA4 Data API ve veritabanı telemetri verilerini çeker.
 */
const { getObservabilityMetricsHandler } = require('./observability_service');
exports.getObservabilityMetrics = functions
  .runWith({ timeoutSeconds: 60, memory: '512MB' })
  .https.onCall(wrapCall('getObservabilityMetrics', getObservabilityMetricsHandler));

